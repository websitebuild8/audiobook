import { createHash } from 'node:crypto'
import { sql } from '@payloadcms/db-postgres'
import type { Endpoint } from 'payload'
import { adminOrigins } from '../config/admin-origins'
import { ANNOUNCEMENTS_TOPIC, pushMessaging } from './firebase'

export function webPushConfig() {
  if (process.env.PUSH_NOTIFICATIONS_ENABLED !== 'true') return null
  const { FIREBASE_WEB_API_KEY: apiKey, FIREBASE_WEB_APP_ID: appId, FIREBASE_PROJECT_ID: projectId, FIREBASE_MESSAGING_SENDER_ID: messagingSenderId, FIREBASE_WEB_VAPID_KEY: vapidKey } = process.env
  return apiKey && appId && projectId && messagingSenderId && vapidKey ? { apiKey, appId, projectId, messagingSenderId, vapidKey } : null
}
export const webPushEndpoints: Omit<Endpoint, 'root'>[] = [
  { path: '/push-config', method: 'get', handler: async () => Response.json(webPushConfig(), { headers: { 'Cache-Control': 'no-store' } }) },
  { path: '/subscription', method: 'post', handler: async req => {
    if (!webPushConfig()) return Response.json({ error: 'Push is not configured.' }, { status: 503 })
    const origin = req.headers.get('origin')
    if (!origin || ![...adminOrigins, req.payload.config.serverURL].includes(origin)) return Response.json({}, { status: 403 })
    if (!req.headers.get('content-type')?.startsWith('application/json')) return Response.json({}, { status: 415 })
    const raw = await req.text!()
    if (raw.length > 4096) return Response.json({}, { status: 413 })
    let data: { token?: unknown; enabled?: unknown }
    try { data = JSON.parse(raw) } catch { return Response.json({}, { status: 400 }) }
    if (typeof data.token !== 'string' || data.token.length < 20 || data.token.length > 2048 || typeof data.enabled !== 'boolean') return Response.json({}, { status: 400 })
    // Public opt-in only; fixed topic, no arbitrary topics or sending capability.
    // A shared Neon limit works across Vercel instances. Raw IPs/tokens are not saved.
    const ip = req.headers.get('x-vercel-forwarded-for')?.split(',')[0] || req.headers.get('x-forwarded-for')?.split(',')[0] || 'local'
    const key = createHash('sha256').update(`${process.env.PAYLOAD_SECRET}:${ip}`).digest('hex')
    const window = Math.floor(Date.now() / 600000)
    const limit = await req.payload.db.drizzle.execute(sql`INSERT INTO push_registration_limits (key, window_id, attempts) VALUES (${key}, ${window}, 1) ON CONFLICT (key) DO UPDATE SET attempts = CASE WHEN push_registration_limits.window_id = ${window} THEN push_registration_limits.attempts + 1 ELSE 1 END, window_id = ${window} RETURNING attempts`)
    if (Number(limit.rows[0]?.attempts) > 20) return Response.json({}, { status: 429 })
    await req.payload.db.drizzle.execute(sql`DELETE FROM push_registration_limits WHERE window_id < ${window - 144}`)
    try {
      const messaging = pushMessaging()
      const result = data.enabled ? await messaging.subscribeToTopic([data.token], ANNOUNCEMENTS_TOPIC) : await messaging.unsubscribeFromTopic([data.token], ANNOUNCEMENTS_TOPIC)
      if (result.failureCount) return Response.json({ error: 'Registration failed.' }, { status: 400 })
      return Response.json({ ok: true })
    } catch { return Response.json({ error: 'Registration unavailable.' }, { status: 503 }) }
  } },
]
