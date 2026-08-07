// asc-version-notes.mjs — set the App Store *version's* "What's New" per locale.
//
// Not to be confused with asc-testflight-notes.mjs, which sets a TestFlight
// BUILD's "What to Test" (betaBuildLocalizations). This one writes
// appStoreVersionLocalizations.whatsNew — the release notes the public sees on
// the store page. Nothing was writing it, so it drifted: the Danish locale
// carried the English notes and en-GB carried none at all, while both
// descriptions were correctly localized. A store page in one language with
// release notes in another is exactly the kind of mixture nobody catches from
// the upload output.
//
// Locales: release.md is tagged en-GB / da-DK; App Store Connect uses whatever
// localizations the version actually has (here `en-GB` and `da`). Matching is
// by language prefix so da-DK → da.
//
// Inputs (env): ASC_KEY, ASC_KEY_ID, ASC_ISSUER_ID,
//   ASC_BUNDLE_ID (default dk.stormstyrken.twelvestepsapp),
//   ASC_VERSION   (versionString to target, e.g. "2.3.5"),
//   ASC_NOTES_JSON ('{"en-GB":"…","da-DK":"…"}'),
//   ASC_APPLY     ("1" to write; anything else is a dry run).

import crypto from 'node:crypto'
import fs from 'node:fs'

const need = (k) => {
  const v = process.env[k]
  if (!v) {
    console.error(`asc-version-notes: missing ${k}`)
    process.exit(2)
  }
  return v
}
const KEY_PATH = need('ASC_KEY')
const KEY_ID = need('ASC_KEY_ID')
const ISSUER = need('ASC_ISSUER_ID')
const BUNDLE_ID = process.env.ASC_BUNDLE_ID || 'dk.stormstyrken.twelvestepsapp'
const VERSION = need('ASC_VERSION')
const NOTES = JSON.parse(need('ASC_NOTES_JSON'))
const APPLY = process.env.ASC_APPLY === '1'

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
async function asc(path, opts = {}) {
  const r = await fetch(path.startsWith('http') ? path : `${API}${path}`, {
    ...opts,
    headers: {
      Authorization: `Bearer ${TOKEN}`,
      'Content-Type': 'application/json',
      ...(opts.headers || {}),
    },
  })
  const t = await r.text()
  if (!r.ok) throw new Error(`ASC ${opts.method || 'GET'} ${path} → ${r.status}: ${t.slice(0, 400)}`)
  return t ? JSON.parse(t) : {}
}

const apps = await asc(`/apps?filter[bundleId]=${encodeURIComponent(BUNDLE_ID)}&limit=1`)
const appId = apps.data?.[0]?.id
if (!appId) throw new Error(`no app for ${BUNDLE_ID}`)

const versions = await asc(
  `/apps/${appId}/appStoreVersions?limit=10&fields[appStoreVersions]=versionString,appStoreState`,
)
const version = (versions.data ?? []).find((v) => v.attributes?.versionString === VERSION)
if (!version) throw new Error(`no App Store version ${VERSION} on this app`)
const state = version.attributes?.appStoreState
console.log(`version ${VERSION} [${state}] → ${version.id}`)
if (['READY_FOR_SALE', 'REMOVED_FROM_SALE'].includes(state)) {
  throw new Error(`version ${VERSION} is ${state}; its notes are frozen`)
}

// Match release.md's tags to the version's actual locales by language prefix.
const lang = (l) => l.toLowerCase().split('-')[0]
const noteFor = (locale) => {
  if (NOTES[locale] != null) return NOTES[locale]
  const hit = Object.keys(NOTES).find((k) => lang(k) === lang(locale))
  return hit ? NOTES[hit] : null
}

const locs = await asc(`/appStoreVersions/${version.id}/appStoreVersionLocalizations?limit=20`)
let changed = 0
for (const loc of locs.data ?? []) {
  const locale = loc.attributes?.locale
  const want = noteFor(locale)
  if (want == null) {
    console.log(`  ${locale}: no notes in release.md for this locale — left alone`)
    continue
  }
  if (loc.attributes?.whatsNew === want) {
    console.log(`  ${locale}: already correct`)
    continue
  }
  if (!APPLY) {
    console.log(`  ${locale}: would set (${want.length} chars) — dry run`)
    continue
  }
  await asc(`/appStoreVersionLocalizations/${loc.id}`, {
    method: 'PATCH',
    body: JSON.stringify({
      data: {
        type: 'appStoreVersionLocalizations',
        id: loc.id,
        attributes: { whatsNew: want },
      },
    }),
  })
  const after = await asc(`/appStoreVersionLocalizations/${loc.id}`)
  if (after.data?.attributes?.whatsNew !== want) {
    throw new Error(`${locale}: read back did not match what was sent`)
  }
  console.log(`  ${locale}: set and verified (${want.length} chars)`)
  changed++
}
console.log(`\nchanged: ${changed}`)
