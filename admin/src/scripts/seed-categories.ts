import 'dotenv/config'
import fs from 'node:fs/promises'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { getPayload } from 'payload'
import config from '../payload.config'

type Catalog = { books: Array<{ category: string }> }

const here = path.dirname(fileURLToPath(import.meta.url))
const catalogPath = path.resolve(here, '../../../assets/catalog.json')
const catalog = JSON.parse(await fs.readFile(catalogPath, 'utf8')) as Catalog
const payload = await getPayload({ config })

const names = [...new Set(catalog.books.map(({ category }) => category.trim()))]
const slugOverrides: Record<string, string> = {
  'ދާރް އަލް ފިތިޔާ': 'dar-al-fitya',
  'މަރްކަޒް އަލް މީޒާން': 'markaz-al-meezan',
  'މަރްކަޒްްް އަލްް ފުރްސާން': 'markaz-al-fursan',
  'އެހެނިހެން': 'ehenihen',
}

for (const [order, name] of names.entries()) {
  const existing = await payload.find({
    collection: 'categories',
    limit: 1,
    where: { name: { equals: name } },
  })

  if (existing.totalDocs > 0) {
    payload.logger.info(`Category already exists: ${name}`)
    continue
  }

  await payload.create({
    collection: 'categories',
    data: {
      name,
      slug: slugOverrides[name] || `category-${order + 1}`,
      active: true,
      order: order + 1,
    },
  })
  payload.logger.info(`Created category: ${name}`)
}

payload.logger.info(`Category import complete (${names.length} catalogue categories).`)
process.exit(0)
