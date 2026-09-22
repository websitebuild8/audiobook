import * as readerNotice from './20260912_120000_reader_notice'
import * as readingEdition from './20260923_120000_reading_edition'

export const migrations = [
  { up: readerNotice.up, down: readerNotice.down, name: '20260912_120000_reader_notice' },
  { up: readingEdition.up, down: readingEdition.down, name: '20260923_120000_reading_edition' },
]
