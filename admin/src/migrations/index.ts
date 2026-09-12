import * as readerNotice from './20260912_120000_reader_notice'

export const migrations = [
  { up: readerNotice.up, down: readerNotice.down, name: '20260912_120000_reader_notice' },
]
