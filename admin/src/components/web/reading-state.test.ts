import { strict as assert } from 'node:assert'
import { test } from 'node:test'
import { storedCompleted, completionCount } from './reading-state'
test('completed state tolerates malformed storage and counts catalogue editions only', () => {
  assert.deepEqual(storedCompleted('broken'), [])
  assert.deepEqual(storedCompleted('[1,1,"reading::1",{},null,"bad"]'), [1, 'reading::1'])
  assert.equal(completionCount([1, 2, 2, 'reading::1'], [1, 77]), 1)
  assert.equal(completionCount([], [1]), 0)
})
