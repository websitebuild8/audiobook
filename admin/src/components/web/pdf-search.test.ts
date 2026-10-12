import assert from 'node:assert/strict'
import { test } from 'node:test'
import { highlightItem, indexTextItems, searchPages } from './pdf-search'

test('scans and whitespace are empty; later text pages remain searchable', () => {
  const pages = [indexTextItems([]), indexTextItems([{ str: 'ފޮތް ފޮތް' }])]
  const results = searchPages(pages, 'ފޮތް')
  assert.equal(results.length, 2)
  assert.deepEqual(results.map(m => m.page), [2, 2])
  assert.equal(searchPages(pages, '  ').length, 0)
})
test('phrases across items and lines, literal punctuation, and case', () => {
  const page = indexTextItems([{ str: 'Hello', hasEOL: true }, { str: 'world [a+b] hello' }])
  assert.equal(searchPages([page], 'hello world').length, 1)
  assert.equal(searchPages([page], '[a+b]').length, 1)
  assert.equal(searchPages([page], 'HELLO').length, 2)
  assert.equal(searchPages([page], 'missing').length, 0)
})
test('highlights a match spanning items, escapes PDF HTML, selects correct occurrence', () => {
  const page = indexTextItems([{ str: 'hello ' }, { str: 'world <script> hello world' }])
  const matches = searchPages([page], 'hello world')
  const first = highlightItem('hello ', 0, page, matches, 1, 1)
  const second = highlightItem('world <script> hello world', 1, page, matches, 1, 1)
  assert.match(first, /data-pdf-match="0"/)
  assert.match(second, /data-pdf-match="0"/)
  assert.match(second, /data-pdf-match="1" class="pdf-match-active"/)
  assert.ok(second.includes('&lt;script&gt;'))
  assert.ok(!second.includes('<script>'))
})
