import { strict as assert } from 'node:assert'
import { test } from 'node:test'
import { summarize, readCollection, readSnapshot, formatBytes } from './analytics'

test('empty collections produce zero counts without a misleading coverage percentage', () => {
  const result = summarize({ books: [], categories: [], media: [] })
  assert.equal(result.total, 0)
  assert.equal(result.audio, 0)
  assert.deepEqual(result.formats, { both: 0, pdf: 0, audio: 0, neither: 0 })
  assert.equal(formatBytes(0), '0 B')
})

test('coverage counts attachments, includes drafts, and reconciles unknown categories and sizes', () => {
  const result = summarize({
    books: [
      { id: 1, category: 1, pdf: 10, audioChapters: [{ audio: 11 }, { audio: 12 }], _status: 'published', updatedAt: '2026-01-01' },
      { id: 2, category: { id: '1' }, pdf: 13, audioChapters: [{ audio: null }], _status: 'draft', updatedAt: '2026-02-01' },
      { id: 3, category: 99, audioChapters: [{ audio: 15 }], updatedAt: 'invalid' },
      { id: 4, pdf: null, category: null },
    ],
    categories: [{ id: 1, name: 'Category' }, { id: 2, name: 'Empty category' }],
    media: [{ id: 1, filesize: 1024 }, { id: 2, filesize: null }, { id: 3, filesize: 0 }, { id: 4, filesize: -1 }],
  })
  assert.deepEqual(result.formats, { both: 1, pdf: 1, audio: 1, neither: 1 })
  assert.equal(result.audio, 2)
  assert.equal(result.published, 1)
  assert.equal(result.drafts, 1)
  assert.equal(result.unknownStatus, 2)
  assert.equal(result.distribution.reduce((sum, category) => sum + category.count, 0), 4)
  assert.deepEqual(result.storage, { bytes: 1024, unknown: 2 })
  assert.equal(result.recent[0].id, 2)
  assert.equal(formatBytes(1024), '1 KB')
})

test('REST pagination reads all pages and refuses partial data on failure', async () => {
  const original = globalThis.fetch
  const requests: string[] = []
  try {
    globalThis.fetch = async (url, options) => {
      requests.push(String(url))
      assert.equal(options?.credentials, 'same-origin')
      assert.equal(options?.cache, 'no-store')
      return Response.json(requests.length === 1 ? { docs: [{ id: 1 }], hasNextPage: true, nextPage: 2 } : { docs: [{ id: 2 }], hasNextPage: false })
    }
    assert.deepEqual(await readCollection('books', new AbortController().signal), [{ id: 1 }, { id: 2 }])
    assert.match(requests[1], /page=2/)
    assert.match(requests[0], /select%5BaudioChapters%5D=true/)
    globalThis.fetch = async () => new Response('', { status: 403 })
    await assert.rejects(readCollection('books', new AbortController().signal), /session may have expired/)
    globalThis.fetch = async () => Response.json({ docs: [{ id: 1 }], hasNextPage: true, nextPage: 1 })
    await assert.rejects(readCollection('books', new AbortController().signal), /complete library/)
  } finally { globalThis.fetch = original }
})

test('expired sessions never fall back to public-only totals', async () => {
  const original = globalThis.fetch
  try {
    let requests = 0
    globalThis.fetch = async () => { requests++; return Response.json({ user: null }) }
    await assert.rejects(readSnapshot(new AbortController().signal), /session may have expired/)
    assert.equal(requests, 1)
    let sessionChecks = 0
    globalThis.fetch = async url => String(url).includes('/admins/me')
      ? Response.json({ user: ++sessionChecks === 1 ? { id: 1 } : null })
      : Response.json({ docs: [], hasNextPage: false })
    await assert.rejects(readSnapshot(new AbortController().signal), /session may have expired/)
    assert.equal(sessionChecks, 2)
  } finally { globalThis.fetch = original }
})
