import type { CollectionConfig } from 'payload'
import { authenticated, publishedOrAuthenticated } from '../access'

export const Books: CollectionConfig = {
  slug: 'books',
  labels: { singular: 'ފޮތް', plural: 'ފޮތްތައް' },
  admin: {
    group: 'ފޮތްތައް',
    useAsTitle: 'title',
    defaultColumns: ['title', 'category', 'hasAudio', 'status', 'updatedAt'],
    description: 'އެޕްގައި ދައްކާ ފޮތްތަކާއި އޯޑިއޯތައް މެނޭޖްކުރައްވާ',
  },
  access: {
    read: publishedOrAuthenticated,
    create: authenticated,
    update: authenticated,
    delete: authenticated,
  },
  versions: { drafts: true, maxPerDoc: 20 },
  fields: [
    {
      type: 'tabs',
      tabs: [
        {
          label: 'ފޮތުގެ މަޢުލޫމާތު',
          fields: [
            { name: 'sourceId', type: 'text', unique: true, index: true, admin: { hidden: true } },
            { name: 'title', type: 'text', label: 'ފޮތުގެ ނަން', required: true },
            { name: 'author', type: 'text', label: 'ލިޔުނީ' },
            { name: 'description', type: 'textarea', label: 'ފޮތުގެ ތަޢާރަފު' },
            { name: 'category', type: 'relationship', relationTo: 'categories', label: 'ބައި', required: true },
            {
              name: 'cover',
              type: 'upload',
              relationTo: 'media',
              label: 'ފޮތުގެ ކަވަރު',
              admin: { description: 'ކަވަރެއް ނެތްނަމަ އެޕްގައި އޮޓޯ ކަވަރެއް ދައްކާނެ.' },
            },
            { name: 'pdf', type: 'upload', relationTo: 'media', label: 'PDF ފައިލު', required: true },
            { name: 'featured', type: 'checkbox', label: 'ޚާއްޞަ ފޮތަކަށް ހޮވާ', defaultValue: false },
            { name: 'order', type: 'number', label: 'ތަރުތީބު', defaultValue: 0, min: 0 },
          ],
        },
        {
          label: 'އޯޑިއޯ',
          fields: [
            {
              name: 'audioChapters',
              type: 'array',
              label: 'އޯޑިއޯ ބައިތައް',
              labels: { singular: 'އޯޑިއޯ ބައި', plural: 'އޯޑިއޯ ބައިތައް' },
              fields: [
                { name: 'title', type: 'text', label: 'ބައިގެ ނަން', required: true },
                { name: 'audio', type: 'upload', relationTo: 'media', label: 'އޯޑިއޯ ފައިލު', required: true },
                { name: 'order', type: 'number', label: 'ތަރުތީބު', required: true, min: 1 },
              ],
            },
          ],
        },
      ],
    },
  ],
}
