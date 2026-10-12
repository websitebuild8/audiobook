import { cert, getApps, initializeApp } from 'firebase-admin/app'
import { getMessaging } from 'firebase-admin/messaging'

export const ANNOUNCEMENTS_TOPIC = 'library-announcements-v1'
export function pushMessaging() {
  if (process.env.PUSH_NOTIFICATIONS_ENABLED !== 'true') throw new Error('Push delivery is not enabled. Complete Firebase setup first.')
  const raw = process.env.FIREBASE_SERVICE_ACCOUNT_JSON
  if (!raw) throw new Error('Firebase server credentials are not configured.')
  const existing = getApps().find(app => app.name === 'library-push')
  if (existing) return getMessaging(existing)
  // Credentials stay server-side and must never be included in public config.
  const key = JSON.parse(raw)
  if (!key.project_id || !key.client_email || !key.private_key) throw new Error('Firebase server credentials are incomplete.')
  return getMessaging(initializeApp({ credential: cert(key) }, 'library-push'))
}
