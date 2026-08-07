// asc-attach-build.mjs — point an App Store version at a specific build.
//
// This is the gap that let a stale binary sit in front of a submission: the
// pending version was still attached to build 108 while TestFlight had 112, and
// nothing in the tooling showed it. Uploading to TestFlight does NOT attach the
// build to the version — that is a separate relationship, and it is the one
// that decides what reviewers and the public actually get.
//
// Inputs (env): ASC_KEY, ASC_KEY_ID, ASC_ISSUER_ID,
//   ASC_BUNDLE_ID (default dk.stormstyrken.twelvestepsapp),
//   ASC_VERSION   (versionString, e.g. "2.3.5"),
//   ASC_BUILD     (CFBundleVersion, e.g. "113"),
//   ASC_APPLY     ("1" to write; anything else is a dry run).

import crypto from 'node:crypto'
import fs from 'node:fs'

const need = (k) => {
  const v = process.env[k]
  if (!v) {
    console.error(`asc-attach-build: missing ${k}`)
    process.exit(2)
  }
  return v
}
const KEY_PATH = need('ASC_KEY')
const KEY_ID = need('ASC_KEY_ID')
const ISSUER = need('ASC_ISSUER_ID')
const BUNDLE_ID = process.env.ASC_BUNDLE_ID || 'dk.stormstyrken.twelvestepsapp'
const VERSION = need('ASC_VERSION')
const BUILD = need('ASC_BUILD')
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
if (!version) throw new Error(`no App Store version ${VERSION}`)
const state = version.attributes?.appStoreState
if (['READY_FOR_SALE', 'REMOVED_FROM_SALE'].includes(state)) {
  throw new Error(`version ${VERSION} is ${state}; its build cannot be changed`)
}

const builds = await asc(
  `/builds?filter[app]=${appId}&filter[version]=${encodeURIComponent(BUILD)}&limit=1`,
)
const build = builds.data?.[0]
if (!build) {
  throw new Error(
    `build ${BUILD} not found — Apple may still be processing it; wait and re-run`,
  )
}
const processing = build.attributes?.processingState
console.log(`version ${VERSION} [${state}]  ←  build ${BUILD} (${processing})`)
if (processing && processing !== 'VALID') {
  throw new Error(`build ${BUILD} is ${processing}, not VALID — wait for processing to finish`)
}

let current = null
try {
  current = (await asc(`/appStoreVersions/${version.id}/build`)).data?.attributes?.version ?? null
} catch {
  /* none attached */
}
console.log(`  currently attached: ${current ?? 'none'}`)
if (current === BUILD) {
  console.log('  already correct')
  process.exit(0)
}
if (!APPLY) {
  console.log(`  would attach build ${BUILD} — dry run`)
  process.exit(0)
}

await asc(`/appStoreVersions/${version.id}/relationships/build`, {
  method: 'PATCH',
  body: JSON.stringify({ data: { type: 'builds', id: build.id } }),
})
const after = (await asc(`/appStoreVersions/${version.id}/build`)).data?.attributes?.version
if (after !== BUILD) throw new Error(`read back build ${after}, expected ${BUILD}`)
console.log(`  attached and verified: build ${after}`)
