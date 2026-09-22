export type EditionId = number | string

/** Keep original IDs stable so existing bookmarks still refer to the audiobook. */
export function expandBookEditions<T extends {
  id: EditionId
  title: string
  audioChapters?: unknown[] | null
  publishReadingOnlyEdition?: boolean | null
}>(books: T[]): Array<Omit<T, 'id'> & { id: EditionId }> {
  return books.flatMap((book) => book.publishReadingOnlyEdition === true && book.audioChapters?.length
    ? [book, { ...book, id: `reading::${book.id}`, title: `${book.title} (PDF)`, audioChapters: [], publishReadingOnlyEdition: false }]
    : [book])
}

export function isEditionId(value: unknown): value is EditionId {
  return Number.isInteger(value) || (typeof value === 'string' && /^reading::\d+$/.test(value))
}
