import { test } from 'node:test'
import assert from 'node:assert/strict'
import { dispatchNotification, type DispatchStore } from './dispatch'

test('concurrent sends claim a draft once and record acceptance', async () => {
  let claimed = false, sent = 0, accepted = ''
  const store: DispatchStore = {
    claim: async () => { if (claimed) return null; claimed = true; return { title: 'Notice', message: 'New book' } },
    accepted: async id => { accepted = id }, uncertain: async () => { throw Error('unexpected') },
  }
  const deliver = async () => { sent++; return 'provider-id' }
  assert.deepEqual((await Promise.all([dispatchNotification(store, deliver), dispatchNotification(store, deliver)])).sort(), ['accepted', 'conflict'])
  assert.equal(sent, 1); assert.equal(accepted, 'provider-id')
})
test('unclear provider response and failed history write never auto-retry', async () => {
  for (const failAt of ['send', 'history']) {
    let claimed = false, sends = 0, uncertain = false
    const store: DispatchStore = {
      claim: async () => { if (claimed) return null; claimed = true; return { title: 'Notice', message: 'New book' } },
      accepted: async () => { if (failAt === 'history') throw Error('db unavailable') },
      uncertain: async () => { uncertain = true },
    }
    const send = async () => { sends++; if (failAt === 'send') throw Error('timeout'); return 'accepted' }
    assert.equal(await dispatchNotification(store, send), 'uncertain')
    assert.equal(await dispatchNotification(store, send), 'conflict')
    assert.equal(sends, 1); assert.equal(uncertain, true)
  }
})
