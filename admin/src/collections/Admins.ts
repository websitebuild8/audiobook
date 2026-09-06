import type { CollectionConfig } from 'payload'

export const Admins: CollectionConfig = {
  slug: 'admins',
  labels: { singular: 'އެޑްމިން', plural: 'އެޑްމިނުން' },
  auth: true,
  admin: {
    group: 'ސިސްޓަމް',
    useAsTitle: 'name',
    defaultColumns: ['name', 'email', 'role'],
  },
  access: {
    read: ({ req }) => Boolean(req.user),
    create: ({ req }) => !req.user || req.user.role === 'super-admin',
    update: ({ req, id }) => req.user?.role === 'super-admin' || req.user?.id === id,
    delete: ({ req }) => req.user?.role === 'super-admin',
  },
  fields: [
    { name: 'name', type: 'text', label: 'ނަން', required: true },
    {
      name: 'role',
      type: 'select',
      label: 'މަޤާމު',
      defaultValue: 'editor',
      required: true,
      options: [
        { label: 'މައި އެޑްމިން', value: 'super-admin' },
        { label: 'އެޑިޓަރ', value: 'editor' },
      ],
    },
  ],
}
