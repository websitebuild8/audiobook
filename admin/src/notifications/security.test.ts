import { test } from 'node:test'
import assert from 'node:assert/strict'
import { Notifications } from '../collections/Notifications'
import type { PayloadRequest } from 'payload'

const endpoints = Notifications.endpoints
if (!endpoints) throw new Error('Missing endpoints')
const send = endpoints.find(endpoint => endpoint.path === '/:id/send')!.handler
function request(user: unknown, origin: string): PayloadRequest {
  return { user, headers: new Headers({ origin }), routeParams: { id: '1' }, payload: { config: { serverURL: 'https://www.athariyya.online' }, db: { drizzle: { execute: () => { throw new Error('Database should not be touched') } } } } } as unknown as PayloadRequest
}
test('unauthenticated callers cannot send', async () => {
  assert.equal((await send(request(null, 'https://www.athariyya.online'))).status, 401)
})
test('cross-origin requests cannot send, even with an admin identity', async () => {
  assert.equal((await send(request({ collection: 'admins', id: 1 }, 'https://untrusted.example'))).status, 403)
})
test('unconfigured delivery does not claim a draft or contact Firebase', async () => {
  const previous = process.env.PUSH_NOTIFICATIONS_ENABLED
  delete process.env.PUSH_NOTIFICATIONS_ENABLED
  try { assert.equal((await send(request({ collection: 'admins', id: 1 }, 'https://www.athariyya.online'))).status, 503) }
  finally { if (previous !== undefined) process.env.PUSH_NOTIFICATIONS_ENABLED = previous }
})

test('public admin creation and editor self-promotion are forbidden', async () => {
  const { Admins } = await import('../collections/Admins')
  const create = Admins.access!.create!
  assert.equal(await create({ req: { user: null } as unknown as PayloadRequest }), false)
  assert.equal(await create({ req: { user: { collection: 'admins', role: 'super-admin' } } as unknown as PayloadRequest }), true)
  const role = Admins.fields.find(field => 'name' in field && field.name === 'role')
  if (!role || !('access' in role) || !role.access?.update) throw Error('Role access missing')
  assert.equal(await role.access.update({ req: { user: { collection: 'admins', role: 'editor' } } as unknown as PayloadRequest }), false)
})
