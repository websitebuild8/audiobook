import assert from 'node:assert/strict'
import { test } from 'node:test'
import { expandBookEditions, isEditionId } from './book-editions'

test('both editions reuse media but retain separate bookmark identities', () => {
  const book = { id: 12, title: 'Book', pdf: { url: '/book.pdf' }, audioChapters: [{ title: 'Chapter' }], publishReadingOnlyEdition: true }
  const [audio, reading] = expandBookEditions([book])
  assert.equal(audio, book)
  assert.equal(reading.id, 'reading::12')
  assert.equal(reading.pdf, book.pdf)
  assert.deepEqual(reading.audioChapters, [])
  assert.equal(book.audioChapters.length, 1)
  assert.equal(expandBookEditions([audio, reading]).filter(b => b.id === 'reading::reading::12').length, 0)
})
test('legacy and PDF-only books are not duplicated', () => {
  assert.equal(expandBookEditions([{ id: 1, title: 'Legacy', audioChapters: [{}] }]).length, 1)
  assert.equal(expandBookEditions([{ id: 1, title: 'PDF', audioChapters: [], publishReadingOnlyEdition: true }]).length, 1)
})
test('stored numeric bookmarks remain valid alongside reading edition IDs', () => {
  assert.deepEqual([12, 'reading::12', null, {}, '12', 'arbitrary'].filter(isEditionId), [12, 'reading::12'])
})
