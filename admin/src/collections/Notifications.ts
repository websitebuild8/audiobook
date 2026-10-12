import type { CollectionConfig } from 'payload'
import { sql } from '@payloadcms/db-postgres'
import { webPushEndpoints } from '../notifications/web'
import { adminOrigins } from '../config/admin-origins'
import { dispatchNotification } from '../notifications/dispatch'
import { validateNotification } from '../notifications/message'
import { ANNOUNCEMENTS_TOPIC, pushMessaging } from '../notifications/firebase'

export const Notifications: CollectionConfig = {
  slug: 'notifications',
  labels: { singular: 'Notification', plural: 'Notifications' },
  admin: { useAsTitle: 'title', defaultColumns: ['title', 'status', 'sentAt', 'createdAt'], description: 'Save a draft, preview it, then send it to readers who enabled notifications. Accepted means Firebase accepted the message, not that every phone received it.' },
  access: {
    read: ({ req }) => req.user?.collection === 'admins',
    create: ({ req }) => req.user?.collection === 'admins',
    update: ({ req }) => req.user?.collection === 'admins' ? { status: { equals: 'draft' } } : false,
    delete: ({ req }) => req.user?.collection === 'admins' ? { status: { equals: 'draft' } } : false,
  },
  hooks: { beforeValidate: [({ data, operation, originalDoc }) => {
    if (data && (operation === 'create' || data.title !== undefined || data.message !== undefined)) {
      const valid = validateNotification({ ...originalDoc, ...data }); data.title = valid.title; data.message = valid.message
    }
    return data
  }] },
  fields: [
    { name: 'title', type: 'text', required: true, maxLength: 100, defaultValue: 'މަކްތަބާ އަޘަރިއްޔާ' },
    { name: 'message', type: 'textarea', required: true, maxLength: 600 },
    { name: 'status', type: 'text', defaultValue: 'draft', admin: { readOnly: true }, access: { create: () => false, update: () => false } },
    { name: 'sentAt', type: 'date', admin: { readOnly: true }, access: { create: () => false, update: () => false } },
    { name: 'providerMessageId', type: 'text', admin: { readOnly: true }, access: { create: () => false, update: () => false } },
    { name: 'sentBy', type: 'text', admin: { readOnly: true }, access: { create: () => false, update: () => false } },
    { name: 'deliveryNote', type: 'textarea', admin: { readOnly: true }, access: { create: () => false, update: () => false } },
    { name: 'sendControl', type: 'ui', admin: { components: { Field: './src/components/SendNotification#SendNotification' } } },
  ],
  endpoints: [...webPushEndpoints, { path: '/:id/send', method: 'post', handler: async req => {
    if (req.user?.collection !== 'admins') return Response.json({ error: 'Sign in as an admin.' }, { status: 401 })
    const origin = req.headers.get('origin')
    const allowed = [...adminOrigins, req.payload.config.serverURL].filter(Boolean)
    if (!origin || !allowed.includes(origin)) return Response.json({ error: 'Untrusted request origin.' }, { status: 403 })
    const id = Number(req.routeParams?.id)
    if (!Number.isSafeInteger(id) || id < 1) return Response.json({ error: 'Invalid notification.' }, { status: 400 })
    let messaging: ReturnType<typeof pushMessaging>
    try { messaging = pushMessaging() } catch { return Response.json({ error: 'Firebase delivery is not configured. Follow docs/push-notifications.md.' }, { status: 503 }) }
    // One atomic database claim prevents double clicks and concurrent admins
    // from broadcasting the same draft twice. Never retry an uncertain send.
    const status = await dispatchNotification({
      claim: async () => {
        const result = await req.payload.db.drizzle.execute(sql`UPDATE notifications SET status = 'sending', sent_by = ${String(req.user!.id)}, updated_at = now() WHERE id = ${id} AND status = 'draft' RETURNING title, message`)
        return result.rows[0] || null
      },
      accepted: async providerId => {
        await req.payload.db.drizzle.execute(sql`UPDATE notifications SET status = 'accepted', sent_at = now(), provider_message_id = ${providerId}, updated_at = now() WHERE id = ${id}`)
      },
      uncertain: async () => {
        await req.payload.db.drizzle.execute(sql`UPDATE notifications SET status = 'uncertain', delivery_note = 'Delivery could not be confirmed. Do not resend automatically: some devices may already have received it.', updated_at = now() WHERE id = ${id}`)
      },
    }, async content => {
      return await messaging.send({
        topic: ANNOUNCEMENTS_TOPIC,
        notification: { title: content.title, body: content.message },
        data: { notificationId: String(id), screen: 'library' },
        android: { priority: 'high', ttl: 86400000, notification: { tag: `announcement-${id}`, icon: 'ic_stat_notification' } },
        apns: { headers: { 'apns-push-type': 'alert', 'apns-priority': '10', 'apns-expiration': String(Math.floor(Date.now() / 1000) + 86400) }, payload: { aps: { sound: 'default' } } },
      })
    })
    if (status === 'conflict') return Response.json({ error: 'Already sent, sending, or not found. Refresh this page.' }, { status: 409 })
    if (status === 'uncertain') return Response.json({ error: 'Delivery could not be confirmed. Check history before creating another notification.' }, { status: 502 })
    return Response.json({ status })
  } }],
}
