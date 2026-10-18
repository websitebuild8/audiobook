// Retire installations of the old worker on their next update check.
export function GET() {
  return new Response(`
    self.addEventListener('install', () => self.skipWaiting());
    self.addEventListener('activate', event => event.waitUntil((async () => {
      try { const subscription = await self.registration.pushManager.getSubscription(); if (subscription) await subscription.unsubscribe(); } catch {}
      await self.registration.unregister();
    })()));
  `, { headers: { 'Content-Type': 'application/javascript', 'Cache-Control': 'no-store', 'Service-Worker-Allowed': '/' } })
}
