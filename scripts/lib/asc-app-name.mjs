// asc-app-name.mjs — read, and optionally correct, the App Store app name.
//
// The store name is the app's NAME. It must equal CFBundleDisplayName /
// android:label / MaterialApp.title exactly — "12 Steps App" — in every
// localization. It is not translated and it does not carry a marketing suffix:
// "12 Steps App - Recovery" on the store and "12 Steps App" on the home screen
// are two different apps to the person who installed it.
//
// Apple keeps the name on `appInfoLocalizations`, hanging off an `appInfo`.
// There are usually two appInfos: the one that is live (READY_FOR_SALE — its
// name is frozen; changing it needs a new version submission) and an editable
// one (PREPARE_FOR_SUBMISSION and friends). Only the editable one can be
// PATCHed, so this reports what it finds rather than guessing.
//
// Inputs (env): ASC_KEY (path to .p8), ASC_KEY_ID, ASC_ISSUER_ID,
//   ASC_BUNDLE_ID (default dk.stormstyrken.twelvestepsapp),
//   ASC_APP_NAME   (the name to set; omit to only report),
//   ASC_APPLY      ("1" to write; anything else is a dry run).
//
// Dependency-free: Node 18+, same ES256 JWT as asc-testflight-notes.mjs.

import crypto from 'node:crypto'
import fs from 'node:fs'

const need = (k) => {
  const v = process.env[k]
  if (!v) {
    console.error(`asc-app-name: missing ${k}`)
    process.exit(2)
  }
  return v
}
const KEY_PATH = need('ASC_KEY')
const KEY_ID = need('ASC_KEY_ID')
const ISSUER = need('ASC_ISSUER_ID')
const BUNDLE_ID = process.env.ASC_BUNDLE_ID || 'dk.stormstyrken.twelvestepsapp'
const WANT = process.env.ASC_APP_NAME || ''
const APPLY = process.env.ASC_APPLY === '1'

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
  if (!r.ok) {
    throw new Error(`ASC ${opts.method || 'GET'} ${path} → ${r.status}: ${text.slice(0, 500)}`)
  }
  return text ? JSON.parse(text) : {}
}

const apps = await asc(`/apps?filter[bundleId]=${encodeURIComponent(BUNDLE_ID)}&limit=1`)
const appId = apps.data?.[0]?.id
if (!appId) throw new Error(`no app found for bundleId ${BUNDLE_ID}`)
console.log(`app ${BUNDLE_ID} → ${appId}`)

const infos = await asc(`/apps/${appId}/appInfos?limit=20`)
let changed = 0
let blocked = 0

for (const info of infos.data ?? []) {
  const state = info.attributes?.appStoreState ?? info.attributes?.state ?? 'UNKNOWN'
  // A live appInfo's name is frozen; only an editable one accepts a PATCH.
  const editable = !['READY_FOR_SALE', 'REMOVED_FROM_SALE', 'DEVELOPER_REMOVED_FROM_SALE'].includes(
    state,
  )
  const locs = await asc(`/appInfos/${info.id}/appInfoLocalizations?limit=50`)

  for (const loc of locs.data ?? []) {
    const locale = loc.attributes?.locale
    const name = loc.attributes?.name
    const subtitle = loc.attributes?.subtitle ?? ''
    const flag = WANT && name !== WANT ? '  ← WRONG' : ''
    console.log(
      `  appInfo ${info.id} [${state}] ${locale}: name=${JSON.stringify(name)} subtitle=${JSON.stringify(subtitle)}${flag}`,
    )

    if (!WANT || name === WANT) continue
    if (!editable) {
      blocked++
      console.log(
        `    cannot patch: this appInfo is ${state}. The live name changes only with a new version submission.`,
      )
      continue
    }
    if (!APPLY) {
      console.log(`    would set name → ${JSON.stringify(WANT)} (dry run)`)
      continue
    }
    await asc(`/appInfoLocalizations/${loc.id}`, {
      method: 'PATCH',
      body: JSON.stringify({
        data: { type: 'appInfoLocalizations', id: loc.id, attributes: { name: WANT } },
      }),
    })
    // Read back rather than trusting the 200.
    const after = await asc(`/appInfoLocalizations/${loc.id}`)
    const now = after.data?.attributes?.name
    if (now !== WANT) throw new Error(`${locale}: read back ${JSON.stringify(now)}, expected ${JSON.stringify(WANT)}`)
    console.log(`    set → ${JSON.stringify(now)} (verified)`)
    changed++
  }
}

console.log(`\nchanged: ${changed}${blocked ? `, blocked by a live appInfo: ${blocked}` : ''}`)
if (blocked && !changed) process.exit(3)
