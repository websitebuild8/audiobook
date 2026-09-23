import assert from 'node:assert/strict'
import test from 'node:test'
import { extractJWT } from '../node_modules/payload/dist/auth/extractJWT.js'
import { adminOrigins } from '../src/config/admin-origins.ts'

const serverURL = 'https://deployment.example.com'
const token = 'test-cookie-not-a-real-token'
function extract(origin, csrf, cookie = `payload-token=${token}`) {
  return extractJWT({
    headers: new Headers({ Origin: origin, Cookie: cookie }),
    payload: { config: { csrf, cookiePrefix: 'payload', auth: { jwtOrder: ['cookie'] } } },
  })
}

test('custom-domain saves keep the session cookie when serverURL is the deployment host', () => {
  assert.equal(extract(adminOrigins[0], [serverURL]), null)
  for (const origin of [...adminOrigins, serverURL]) {
    assert.equal(extract(origin, [...adminOrigins, serverURL]), token)
  }
})

test('untrusted origins and unauthenticated requests are still rejected', () => {
  const csrf = [...adminOrigins, serverURL]
  for (const origin of ['https://untrusted.example', 'https://www.athariyya.online.untrusted.example', 'http://www.athariyya.online']) {
    assert.equal(extract(origin, csrf), null)
  }
  assert.equal(extract(adminOrigins[0], csrf, ''), null)
})
