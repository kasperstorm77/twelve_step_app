// asc-status.mjs — read-only: what state is the App Store version in, what
// build is attached, and what is still missing before it can be submitted.
//
// Submitting is deliberately NOT automated. It is the one step that puts the
// app in front of Apple's reviewers and then the public, and it is the owner's
// call. This just answers "what would I be submitting, and is anything empty?"
// so that call is made with the facts.
//
// Inputs (env): ASC_KEY (path to .p8), ASC_KEY_ID, ASC_ISSUER_ID,
//   ASC_BUNDLE_ID (default dk.stormstyrken.twelvestepsapp).

import crypto from 'node:crypto'
import fs from 'node:fs'

const need = (k) => {
  const v = process.env[k]
  if (!v) {
    console.error(`asc-status: missing ${k}`)
    process.exit(2)
  }
  return v
}
const KEY_PATH = need('ASC_KEY')
const KEY_ID = need('ASC_KEY_ID')
const ISSUER = need('ASC_ISSUER_ID')
const BUNDLE_ID = process.env.ASC_BUNDLE_ID || 'dk.stormstyrken.twelvestepsapp'

const b64url = (b) =>
  Buffer.from(b).toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')

const now = Math.floor(Date.now() / 1000)
const input = `${b64url(JSON.stringify({ alg: 'ES256', kid: KEY_ID, typ: 'JWT' }))}.${b64url(
  JSON.stringify({ iss: ISSUER, iat: now, exp: now + 1200, aud: 'appstoreconnect-v1' }),
)}`
const TOKEN = `${input}.${b64url(
  crypto.sign('SHA256', Buffer.from(input), {
    key: fs.readFileSync(KEY_PATH, 'utf8'),
    dsaEncoding: 'ieee-p1363',
  }),
)}`

const API = 'https://api.appstoreconnect.apple.com/v1'
async function asc(path) {
  const r = await fetch(path.startsWith('http') ? path : `${API}${path}`, {
    headers: { Authorization: `Bearer ${TOKEN}`, 'Content-Type': 'application/json' },
  })
  const t = await r.text()
  if (!r.ok) throw new Error(`ASC GET ${path} → ${r.status}: ${t.slice(0, 300)}`)
  return t ? JSON.parse(t) : {}
}

const apps = await asc(`/apps?filter[bundleId]=${encodeURIComponent(BUNDLE_ID)}&limit=1`)
const app = apps.data?.[0]
if (!app) throw new Error(`no app for ${BUNDLE_ID}`)
console.log(`app: ${app.attributes?.name ?? '?'} (${app.id})`)

const versions = await asc(
  `/apps/${app.id}/appStoreVersions?limit=5&fields[appStoreVersions]=versionString,appStoreState,platform,createdDate`,
)
for (const v of versions.data ?? []) {
  const a = v.attributes ?? {}
  console.log(`\nversion ${a.versionString}  [${a.appStoreState}]  ${a.platform}`)

  // Which build is attached — an unattached version cannot be submitted.
  let build = null
  try {
    const b = await asc(`/appStoreVersions/${v.id}/build`)
    build = b.data?.attributes?.version ?? null
  } catch {
    /* no build relationship */
  }
  console.log(`  build attached: ${build ?? 'NONE — attach one before submitting'}`)

  // Per-locale copy + screenshot presence.
  const locs = await asc(`/appStoreVersions/${v.id}/appStoreVersionLocalizations?limit=20`)
  for (const loc of locs.data ?? []) {
    const la = loc.attributes ?? {}
    const missing = []
    if (!la.description?.trim()) missing.push('description')
    if (!la.whatsNew?.trim() && a.appStoreState !== 'PREPARE_FOR_SUBMISSION') {
      // whatsNew is only required for an update, not a first version.
      missing.push('whatsNew')
    }
    let shots = 0
    try {
      const sets = await asc(`/appStoreVersionLocalizations/${loc.id}/appScreenshotSets?limit=20`)
      for (const set of sets.data ?? []) {
        const s = await asc(`/appScreenshotSets/${set.id}/appScreenshots?limit=20`)
        shots += (s.data ?? []).length
      }
    } catch {
      /* ignore */
    }
    if (shots === 0) missing.push('screenshots')
    console.log(
      `  ${la.locale}: ${shots} screenshot(s), keywords=${JSON.stringify(la.keywords ?? '')}` +
        (missing.length ? `  ← missing: ${missing.join(', ')}` : ''),
    )
  }
}

console.log('\nSubmitting is a manual step in App Store Connect, on purpose.')
