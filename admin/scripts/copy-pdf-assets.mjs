import { createRequire } from 'node:module'
import { dirname, resolve } from 'node:path'
import { cpSync, mkdirSync } from 'node:fs'
const require = createRequire(import.meta.url)
const source = dirname(require.resolve('pdfjs-dist/package.json'))
for (const folder of ['cmaps', 'standard_fonts', 'wasm']) {
  const destination = resolve('public/pdf-assets', folder)
  mkdirSync(destination, { recursive: true })
  cpSync(resolve(source, folder), destination, { recursive: true })
}
