/** Offsets link full-page search results back to PDF.js text-layer items. */
export type SearchPage = { text: string; items: { start: number; end: number; index: number }[] }
export type SearchMatch = { page: number; start: number; end: number; snippet: string }

export function indexTextItems(items: readonly unknown[]): SearchPage {
  let text = ''
  const offsets: SearchPage['items'] = []
  items.forEach((value, index) => {
    if (!value || typeof value !== 'object' || !('str' in value) || typeof value.str !== 'string') return
    const start = text.length
    text += value.str
    offsets.push({ start, end: text.length, index })
    // PDF.js splits words and lines into items; only explicit line breaks add whitespace.
    if ('hasEOL' in value && value.hasEOL) text += '\n'
  })
  return { text, items: offsets }
}

export function searchPages(pages: readonly (SearchPage | undefined)[], value: string): SearchMatch[] {
  const query = value.trim()
  if (!query) return []
  const escaped = query.split(/\s+/u).map(part => part.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')).join('\\s+')
  const matches: SearchMatch[] = []
  pages.forEach((page, index) => {
    if (!page) return
    for (const match of page.text.matchAll(new RegExp(escaped, 'giu'))) {
      const start = match.index, end = start + match[0].length
      matches.push({ page: index + 1, start, end, snippet: page.text.slice(Math.max(0, start - 30), end + 45).replace(/\s+/gu, ' ') })
    }
  })
  return matches
}

const escapeHTML = (text: string) => text.replace(/[&<>"']/g, char => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[char]!)

export function highlightItem(text: string, itemIndex: number, page: SearchPage | undefined, matches: SearchMatch[], active: number, pageNumber: number): string {
  const item = page?.items.find(item => item.index === itemIndex)
  if (!item) return escapeHTML(text)
  let result = '', cursor = 0
  matches.forEach((match, index) => {
    if (match.page !== pageNumber || match.end <= item.start || match.start >= item.end) return
    const start = Math.max(0, match.start - item.start), end = Math.min(text.length, match.end - item.start)
    result += escapeHTML(text.slice(cursor, start)) + `<mark data-pdf-match="${index}" class="${index === active ? 'pdf-match-active' : 'pdf-match'}">${escapeHTML(text.slice(start, end))}</mark>`
    cursor = end
  })
  return result + escapeHTML(text.slice(cursor))
}
