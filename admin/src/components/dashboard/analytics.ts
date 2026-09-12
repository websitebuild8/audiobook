export type Book = {
  id: string | number
  title?: string | null
  category?: string | number | { id: string | number } | null
  pdf?: unknown
  audioChapters?: { audio?: unknown }[] | null
  _status?: string | null
  updatedAt?: string
}
export type Category = { id: string | number; name?: string | null }
export type Media = { id: string | number; filesize?: number | null; mimeType?: string | null }
export type Snapshot = { books: Book[]; categories: Category[]; media: Media[] }

export function summarize({ books, categories, media }: Snapshot) {
  const distribution = new Map(categories.map(c => [String(c.id), { id: String(c.id), name: c.name || 'Unnamed category', count: 0 }]))
  let uncategorized = 0
  const formats = { both: 0, pdf: 0, audio: 0, neither: 0 }
  for (const book of books) {
    const audio = Boolean(book.audioChapters?.some(chapter => chapter.audio != null))
    const pdf = book.pdf != null
    formats[audio ? (pdf ? 'both' : 'audio') : (pdf ? 'pdf' : 'neither')]++
    const id = typeof book.category === 'object' ? book.category?.id : book.category
    const category = id == null ? undefined : distribution.get(String(id))
    if (category) category.count++
    else uncategorized++
  }
  const storage = media.reduce((result, file) => {
    if (typeof file.filesize === 'number' && Number.isFinite(file.filesize) && file.filesize >= 0) result.bytes += file.filesize
    else result.unknown++
    return result
  }, { bytes: 0, unknown: 0 })
  const published = books.filter(book => book._status === 'published').length
  const drafts = books.filter(book => book._status === 'draft').length
  return {
    total: books.length, audio: formats.both + formats.audio, pdf: formats.both + formats.pdf,
    published, drafts, unknownStatus: books.length - published - drafts, formats, storage,
    distribution: [...distribution.values(), ...(uncategorized ? [{ id: '', name: 'Unassigned / unavailable category', count: uncategorized }] : [])].sort((a, b) => b.count - a.count),
    recent: [...books].sort((a, b) => (Date.parse(b.updatedAt || '') || 0) - (Date.parse(a.updatedAt || '') || 0)).slice(0, 6),
  }
}

const fields = {
  books: ['title', 'category', 'pdf', 'audioChapters', '_status', 'updatedAt'],
  categories: ['name'],
  media: ['filesize', 'mimeType'],
}

// Follow every page, selecting only dashboard fields and never bypassing Payload access control.
export async function readCollection<T>(collection: keyof typeof fields, signal: AbortSignal): Promise<T[]> {
  const docs: T[] = []
  let page = 1
  while (true) {
    const query = new URLSearchParams({ depth: '0', limit: '250', page: String(page), sort: 'id' })
    for (const field of fields[collection]) query.set(`select[${field}]`, 'true')
    const response = await fetch(`/api/${collection}?${query}`, { signal, credentials: 'same-origin', cache: 'no-store' })
    if (!response.ok) throw new Error(response.status === 401 || response.status === 403 ? 'Your session may have expired. Sign in again to view the overview.' : 'The library data could not be loaded. Please try again.')
    const result = await response.json()
    if (!Array.isArray(result.docs) || typeof result.hasNextPage !== 'boolean') throw new Error('The library returned an unexpected response. Please try again.')
    docs.push(...result.docs)
    if (!result.hasNextPage) return docs
    if (result.nextPage !== page + 1 || !result.docs.length) throw new Error('The complete library could not be loaded. Please try again.')
    page++
  }
}

export function formatBytes(bytes: number) {
  if (!bytes) return '0 B'
  const unit = Math.min(Math.floor(Math.log(bytes) / Math.log(1024)), 4)
  return `${(bytes / 1024 ** unit).toLocaleString('en', { maximumFractionDigits: 1 })} ${['B', 'KB', 'MB', 'GB', 'TB'][unit]}`
}

// Public collection reads remain available after a session expires. Verify the session
// around the snapshot so public-only results are never presented as admin totals.
export async function readSnapshot(signal: AbortSignal): Promise<Snapshot> {
  async function requireSession() {
    const response = await fetch('/api/admins/me', { signal, credentials: 'same-origin', cache: 'no-store' })
    if (!response.ok || !(await response.json()).user) {
      throw new Error('Your session may have expired. Sign in again to view the overview.')
    }
  }
  await requireSession()
  const [books, categories, media] = await Promise.all([
    readCollection<Book>('books', signal),
    readCollection<Category>('categories', signal),
    readCollection<Media>('media', signal),
  ])
  await requireSession()
  return { books, categories, media }
}
