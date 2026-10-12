import { test } from 'node:test'
import assert from 'node:assert/strict'
import { validateNotification } from './message'

test('accepts Dhivehi and trims draft content', () => {
  assert.deepEqual(validateNotification({ title: ' އާ ފޮތެއް ', message: ' ކިޔާލައްވާ ' }), { title: 'އާ ފޮތެއް', message: 'ކިޔާލައްވާ' })
})
test('rejects empty and oversized messages before contacting a push provider', () => {
  for (const input of [null, {}, { title: ' ', message: 'message' }, { title: 'title', message: 'x'.repeat(601) }, { title: 'x'.repeat(101), message: 'message' }]) assert.throws(() => validateNotification(input))
})
