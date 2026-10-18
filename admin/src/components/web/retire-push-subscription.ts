/** Unregister only the retired announcement worker, leaving other workers alone. */
export async function retirePushSubscription(): Promise<void> {
  try { localStorage.removeItem('push-enabled') } catch {}
  if (!('serviceWorker' in navigator)) return
  try {
    const registrations = await navigator.serviceWorker.getRegistrations()
    await Promise.all(registrations.filter(registration =>
      registration.scope === new URL('/push-messaging/', location.origin).href,
    ).map(async registration => {
      try { await (await registration.pushManager.getSubscription())?.unsubscribe() } catch {}
      await registration.unregister()
    }))
  } catch { /* Browser restrictions must not prevent reading. */ }
}
