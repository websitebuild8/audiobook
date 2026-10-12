'use client'
import { Bell } from 'lucide-react'
import { useEffect, useState } from 'react'

export function PushSettings() {
  const [available, setAvailable] = useState(false)
  useEffect(() => { void fetch('/api/notifications/push-config').then(r => r.ok ? r.json() : null).then(config => setAvailable(Boolean(config))).catch(() => {}) }, [])
  const [enabled, setEnabled] = useState(false)
  const [busy, setBusy] = useState(false)
  const [message, setMessage] = useState('')
  async function messaging() {
    const config = await fetch('/api/notifications/push-config').then(response => response.ok ? response.json() : null)
    if (!config) throw new Error('not configured')
    const [{ getApps, initializeApp }, sdk] = await Promise.all([import('firebase/app'), import('firebase/messaging')])
    if (!await sdk.isSupported()) throw new Error('unsupported')
    const app = getApps().find(app => app.name === 'reader-push') || initializeApp(config, 'reader-push')
    const registration = await navigator.serviceWorker.register('/push-worker.js', { scope: '/push-messaging/' })
    await new Promise<void>((resolve, reject) => {
      if (registration.active) return resolve()
      const worker = registration.installing || registration.waiting
      if (!worker) return reject(new Error('worker'))
      const timeout = setTimeout(() => reject(new Error('worker timeout')), 15000)
      worker.addEventListener('statechange', () => { if (worker.state === 'activated') { clearTimeout(timeout); resolve() } else if (worker.state === 'redundant') { clearTimeout(timeout); reject(new Error('worker')) } })
    })
    return { sdk, instance: sdk.getMessaging(app), registration, config }
  }
  async function subscribe(token: string, value: boolean) {
    const response = await fetch('/api/notifications/subscription', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ token, enabled: value }) })
    if (!response.ok) throw new Error('registration')
  }
  useEffect(() => {
    let unsubscribe: (() => void) | undefined, cancelled = false
    try {
      if (localStorage.getItem('push-enabled') !== 'true' || !('Notification' in window) || Notification.permission !== 'granted') return
    } catch { return }
    setEnabled(true); setBusy(true)
    void messaging().then(async ({ sdk, instance, registration, config }) => {
      if (cancelled) return
      unsubscribe = sdk.onMessage(instance, payload => setMessage(`${payload.notification?.title || ''} — ${payload.notification?.body || ''}`))
      const token = await sdk.getToken(instance, { vapidKey: config.vapidKey, serviceWorkerRegistration: registration })
      if (!cancelled) await subscribe(token, true)
    }).catch(() => {}).finally(() => { if (!cancelled) setBusy(false) })
    return () => { cancelled = true; unsubscribe?.() }
  }, [enabled])
  async function toggle() {
    if (busy) return
    setBusy(true); setMessage('')
    try {
      if (!('Notification' in window)) throw new Error('unsupported')
      if (!enabled && await Notification.requestPermission() !== 'granted') throw new Error('permission')
      const { sdk, instance, registration, config } = await messaging()
      const token = await sdk.getToken(instance, { vapidKey: config.vapidKey, serviceWorkerRegistration: registration })
      await subscribe(token, !enabled)
      if (enabled) await sdk.deleteToken(instance)
      localStorage.setItem('push-enabled', String(!enabled)); setEnabled(!enabled)
      setMessage(enabled ? 'ނޯޓިފިކޭޝަން އޮފްކުރެވިއްޖެ' : 'ނޯޓިފިކޭޝަން އޮންކުރެވިއްޖެ')
    } catch { setMessage('ނޯޓިފިކޭޝަން އޮން ނުކުރެވުނު. ބްރައުޒާގެ ސެޓިންގްސް ޗެކްކުރައްވާ.') }
    finally { setBusy(false) }
  }
  if (!available) return null
  return <><button className="media-icon" aria-label="ނޯޓިފިކޭޝަން" aria-pressed={enabled} disabled={busy} onClick={() => void toggle()}><Bell className={enabled ? 'size-5 text-emerald-600' : 'size-5'} /></button>{message && <div role="status" className="fixed inset-x-4 bottom-28 z-[80] mx-auto max-w-lg rounded-2xl bg-stone-900 p-4 text-center text-white shadow-xl"><button onClick={() => setMessage('')} className="float-left px-2" aria-label="ލައްޕާލާ">×</button>{message}</div>}</>
}
