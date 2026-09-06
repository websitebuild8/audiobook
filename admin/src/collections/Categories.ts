import type { CollectionConfig } from 'payload'
import { authenticated } from '../access'

export const Categories: CollectionConfig = {
  slug: 'categories',
  labels: { singular: 'ބައެއް', plural: 'ބައިތައް' },
  admin: {
    group: 'ފޮތްތައް',
    useAsTitle: 'name',
    defaultColumns: ['name', 'slug', 'order', 'active'],
  },
  access: {
    read: () => true,
    create: authenticated,
    update: authenticated,
    delete: authenticated,
  },
  defaultSort: 'order',
  fields: [
    { name: 'name', type: 'text', label: 'ބައިގެ ނަން', required: true },
    {
      name: 'slug',
      type: 'text',
      label: 'ލިންކުގެ ނަން',
      required: true,
      unique: true,
      admin: { description: 'މިސާލު: dar-al-fitya (އިނގިރޭސި އަކުރު ބޭނުންކުރައްވާ)' },
    },
    { name: 'description', type: 'textarea', label: 'ކުރު ތަޢާރަފެއް' },
    { name: 'cover', type: 'upload', relationTo: 'media', label: 'ބައިގެ ފޮޓޯ' },
    { name: 'order', type: 'number', label: 'ތަރުތީބު', defaultValue: 0, min: 0 },
    { name: 'active', type: 'checkbox', label: 'އެޕްގައި ދައްކާ', defaultValue: true },
  ],
}
