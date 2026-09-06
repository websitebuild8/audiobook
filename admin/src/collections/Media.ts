import type { CollectionConfig } from 'payload'
import { authenticated } from '../access'

export const Media: CollectionConfig = {
  slug: 'media',
  labels: { singular: 'ފައިލު', plural: 'ފައިލުތައް' },
  admin: {
    group: 'ފައިލުތައް',
    useAsTitle: 'filename',
    defaultColumns: ['filename', 'mimeType', 'filesize', 'updatedAt'],
  },
  access: {
    read: () => true,
    create: authenticated,
    update: authenticated,
    delete: authenticated,
  },
  upload: {
    mimeTypes: ['image/*', 'application/pdf', 'audio/*'],
  },
  fields: [
    { name: 'alt', type: 'text', label: 'ފައިލުގެ ނަން / ތަޢާރަފު' },
    { name: 'sourcePath', type: 'text', unique: true, index: true, admin: { hidden: true } },
    {
      name: 'kind',
      type: 'select',
      label: 'ފައިލުގެ ބާވަތް',
      options: [
        { label: 'ކަވަރު', value: 'cover' },
        { label: 'PDF ފޮތް', value: 'pdf' },
        { label: 'އޯޑިއޯ', value: 'audio' },
        { label: 'އެހެނިހެން', value: 'other' },
      ],
    },
  ],
}
