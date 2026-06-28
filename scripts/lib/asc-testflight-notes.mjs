// asc-testflight-notes.mjs — set a TestFlight build's localized "What to Test"
// notes via the App Store Connect API, with NO manual paste in the Console.
//
// Why this exists: `xcrun altool` (app-specific-password auth) uploads the build
// but CANNOT set per-build localized notes. The App Store Connect API can — but it
// needs JWT (ES256) auth signed by a `.p8` key. Node's `crypto.sign(..., {
// dsaEncoding: 'ieee-p1363' })` emits the raw r‖s signature the API wants directly
// (no DER→raw conversion), so this is dependency-free (Node 18+, zero npm).
//
// One-time setup (the ONLY manual step — Apple requires it):
//   App Store Connect → Users and Access → Integrations → App Store Connect API →
//   generate a Team key with the "App Manager" role. Download AuthKey_<KEYID>.p8
//   (Apple lets you download it once), and note the Key ID + the Issuer ID.
//   Save the .p8 git-ignored at the repo root and record the ids — see
//   upload-ipa-to-testflight.sh (--asc-key / --asc-key-id / --asc-issuer or the
//   ASC_KEY / ASC_KEY_ID / ASC_ISSUER_ID env vars).
//
// Inputs (env): ASC_KEY (path to .p8), ASC_KEY_ID, ASC_ISSUER_ID,
//   ASC_BUNDLE_ID (default dk.stormstyrken.twelvestepsapp),
//   ASC_BUILD_VERSION (CFBundleVersion — the pubspec build number, e.g. "106"),
//   ASC_NOTES_JSON ('{"en-GB":"…","da-DK":"…"}' — lifted from release.md).
//
// Flow: JWT → find the app by bundle id → poll for the just-uploaded build (it
// registers a few minutes after altool) → upsert the en-GB + da-DK
// betaBuildLocalizations `whatsNew`. Idempotent: re-running just re-PATCHes.

import crypto from 'node:crypto'
import fs from 'node:fs'

const need = (k) => {
  const v = process.env[k]
  if (!v) {
    console.error(`asc-testflight-notes: missing ${k}`)
    process.exit(2)
  }
  return v
}
const KEY_PATH = need('ASC_KEY')
const KEY_ID = need('ASC_KEY_ID')
const ISSUER = need('ASC_ISSUER_ID')
const BUNDLE_ID = process.env.ASC_BUNDLE_ID || 'dk.stormstyrken.twelvestepsapp'
const VERSION = need('ASC_BUILD_VERSION') // CFBundleVersion (the pubspec build number)
const NOTES = JSON.parse(need('ASC_NOTES_JSON')) // { "en-GB": "...", "da-DK": "..." }

const b64url = (buf) =>
  Buffer.from(buf).toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')

function makeJwt() {
  const header = b64url(JSON.stringify({ alg: 'ES256', kid: KEY_ID, typ: 'JWT' }))
  const now = Math.floor(Date.now() / 1000)
  const payload = b64url(
    JSON.stringify({ iss: ISSUER, iat: now, exp: now + 1200, aud: 'appstoreconnect-v1' }),
  )
  const input = `${header}.${payload}`
  const key = fs.readFileSync(KEY_PATH, 'utf8')
  // ES256 over the EC P-256 .p8; ieee-p1363 = the raw 64-byte r‖s the ASC API wants.
  const sig = crypto.sign('SHA256', Buffer.from(input), { key, dsaEncoding: 'ieee-p1363' })
  return `${input}.${b64url(sig)}`
}

const TOKEN = makeJwt()
const API = 'https://api.appstoreconnect.apple.com/v1'
async function asc(path, opts = {}) {
  const r = await fetch(path.startsWith('http') ? path : `${API}${path}`, {
    ...opts,
    headers: {
      Authorization: `Bearer ${TOKEN}`,
      'Content-Type': 'application/json',
      ...(opts.headers || {}),
    },
  })
  const text = await r.text()
  if (!r.ok) throw new Error(`ASC ${opts.method || 'GET'} ${path} → ${r.status}: ${text.slice(0, 400)}`)
  return text ? JSON.parse(text) : {}
}

// 1. App id by bundle id.
const apps = await asc(`/apps?filter[bundleId]=${encodeURIComponent(BUNDLE_ID)}&limit=1`)
const appId = apps.data?.[0]?.id
if (!appId) throw new Error(`no app found for bundleId ${BUNDLE_ID}`)

// 2. Poll for the uploaded build (it registers a few minutes after altool).
//    ASC's /builds filter[version] is the CFBundleVersion (the build number).
let buildId
for (let i = 0; i < 40; i++) {
  const builds = await asc(
    `/builds?filter[app]=${appId}&filter[version]=${encodeURIComponent(VERSION)}&limit=1`,
  )
  buildId = builds.data?.[0]?.id
  if (buildId) break
  console.log(`waiting for build ${VERSION} to register on App Store Connect… (${i + 1}/40)`)
  await new Promise((r) => setTimeout(r, 30000))
}
if (!buildId) throw new Error(`build ${VERSION} never appeared (still processing?) — re-run later`)
console.log(`build ${VERSION} → ${buildId}`)

// 3. Upsert the localized notes. Apple's locale for Danish is "da"; our release.md
//    block is tagged da-DK. Accept either if the build already carries it.
const existing = await asc(`/builds/${buildId}/betaBuildLocalizations?limit=200`)
const byLocale = {}
for (const l of existing.data || []) byLocale[l.attributes.locale] = l.id

const targets = [
  { locales: ['en-GB'], whatsNew: NOTES['en-GB'] },
  { locales: ['da', 'da-DK'], whatsNew: NOTES['da-DK'] },
]
for (const { locales, whatsNew } of targets) {
  if (!whatsNew) continue
  const present = locales.find((l) => byLocale[l])
  if (present) {
    await asc(`/betaBuildLocalizations/${byLocale[present]}`, {
      method: 'PATCH',
      body: JSON.stringify({
        data: { type: 'betaBuildLocalizations', id: byLocale[present], attributes: { whatsNew } },
      }),
    })
    console.log(`✓ updated ${present} notes`)
  } else {
    const locale = locales[0]
    await asc(`/betaBuildLocalizations`, {
      method: 'POST',
      body: JSON.stringify({
        data: {
          type: 'betaBuildLocalizations',
          attributes: { locale, whatsNew },
          relationships: { build: { data: { type: 'builds', id: buildId } } },
        },
      }),
    })
    console.log(`✓ created ${locale} notes`)
  }
}
console.log('✓ TestFlight "What to Test" notes set via the App Store Connect API — no manual paste.')
