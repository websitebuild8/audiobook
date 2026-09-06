import 'dotenv/config'
import fs from 'node:fs/promises'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { getPayload } from 'payload'
import config from '../payload.config'

type Entry = {
  id: string
  title: string
  category: string
  pdfAsset: string
  coverAsset?: string
  audioAssets?: string[]
}

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../..')
const { books } = JSON.parse(await fs.readFile(path.join(root, 'assets/catalog.json'), 'utf8')) as { books: Entry[] }
const payload = await getPayload({ config })

async function media(sourcePath: string, kind: 'cover' | 'pdf' | 'audio') {
  const found = await payload.find({ collection: 'media', limit: 1, where: { sourcePath: { equals: sourcePath } } })
  if (found.docs[0]) return found.docs[0].id
  const absolute = path.join(root, sourcePath)
  await fs.access(absolute)
  const created = await payload.create({
    collection: 'media',
    data: { alt: path.basename(sourcePath), kind, sourcePath },
    filePath: absolute,
    overrideAccess: true,
  })
  payload.logger.info(`Uploaded: ${sourcePath}`)
  return created.id
}

for (const [index, entry] of books.entries()) {
  const existing = await payload.find({ collection: 'books', limit: 1, where: { sourceId: { equals: entry.id } } })
  if (existing.totalDocs) {
    payload.logger.info(`Book already exists: ${entry.title}`)
    continue
  }
  const category = await payload.find({ collection: 'categories', limit: 1, where: { name: { equals: entry.category.trim() } } })
  if (!category.docs[0]) throw new Error(`Missing category: ${entry.category}`)
  const pdf = await media(entry.pdfAsset, 'pdf')
  const cover = entry.coverAsset ? await media(entry.coverAsset, 'cover') : undefined
  const audioChapters = []
  for (const [audioIndex, audioPath] of (entry.audioAssets || []).entries()) {
    audioChapters.push({ title: path.basename(audioPath, path.extname(audioPath)).replace(/^\d+\.\s*/, '').split(' - ')[0], audio: await media(audioPath, 'audio'), order: audioIndex + 1 })
  }
  await payload.create({
    collection: 'books',
    draft: false,
    overrideAccess: true,
    data: { sourceId: entry.id, title: entry.title, category: category.docs[0].id, pdf, cover, audioChapters, order: index + 1, _status: 'published' },
  })
  payload.logger.info(`Imported book ${index + 1}/${books.length}: ${entry.title}`)
}

payload.logger.info(`Catalogue import complete (${books.length} books).`)
process.exit(0)
