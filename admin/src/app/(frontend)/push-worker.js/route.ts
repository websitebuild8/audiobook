import { webPushConfig } from '@/notifications/web'
export const dynamic = 'force-dynamic'
export function GET() {
  const config = webPushConfig()
  if (!config) return new Response('/* Push delivery is not configured. */', { status: 503, headers: { 'Content-Type': 'application/javascript', 'Cache-Control': 'no-store' } })
  // Explicit click handler is registered before Firebase's handler.
  const source = `self.addEventListener('notificationclick', event => {
    event.notification.close();
    event.stopImmediatePropagation();
    event.waitUntil(clients.matchAll({type:'window',includeUncontrolled:true}).then(windows => {
      const existing = windows.find(client => new URL(client.url).origin === self.location.origin);
      return existing ? existing.focus() : clients.openWindow('/');
    }));
  });
  importScripts('https://www.gstatic.com/firebasejs/12.19.0/firebase-app-compat.js');
  importScripts('https://www.gstatic.com/firebasejs/12.19.0/firebase-messaging-compat.js');
  firebase.initializeApp(${JSON.stringify(config)});
  firebase.messaging();`
  return new Response(source, { headers: { 'Content-Type': 'application/javascript', 'Cache-Control': 'no-cache', 'Service-Worker-Allowed': '/' } })
}
