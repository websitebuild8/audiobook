// App-scoped downloads survive reader/sheet navigation. Completed files are cached
// separately; a browser shutdown may interrupt pending requests.
const CACHE = 'makthaba-media-v1'
export type Transfer = { status: 'loading' | 'saved' | 'error'; received: number; total: number }
const states = new Map<string, Transfer>()
const active = new Map<string, AbortController>()
const listeners = new Set<() => void>()
const emit = () => listeners.forEach(listener => listener())
export const subscribeDownloads = (listener: () => void) => { listeners.add(listener); return () => { listeners.delete(listener) } }
export const downloadState = (url: string) => states.get(url)
export async function cachedMedia(url: string) {
  try { return await (await caches.open(CACHE)).match(url) } catch { return undefined }
}
export async function discoverDownload(url: string) {
  if (!states.has(url) && await cachedMedia(url)) { states.set(url, { status: 'saved', received: 0, total: 0 }); emit() }
}
export function cancelDownload(url: string) { active.get(url)?.abort() }
export async function removeDownload(url: string) {
  if (active.has(url)) return
  await (await caches.open(CACHE)).delete(url); states.delete(url); emit()
}
export async function downloadMedia(url: string) {
  if (active.has(url)) return
  const controller = new AbortController(); active.set(url, controller)
  states.set(url, { status: 'loading', received: 0, total: 0 }); emit()
  try {
    const response = await fetch(url, { signal: controller.signal })
    if (!response.ok || !response.body) throw new Error('download')
    const total = Number(response.headers.get('content-length')) || 0
    let received = 0
    const counter = new TransformStream<Uint8Array, Uint8Array>({ transform(chunk, stream) {
      received += chunk.byteLength; states.set(url, { status: 'loading', received, total }); emit(); stream.enqueue(chunk)
    } })
    const cache = await caches.open(CACHE)
    await cache.put(url, new Response(response.body.pipeThrough(counter), { headers: response.headers }))
    states.set(url, { status: 'saved', received, total })
  } catch {
    if (controller.signal.aborted) states.delete(url)
    else states.set(url, { status: 'error', received: 0, total: 0 })
  } finally { active.delete(url); emit() }
}
export async function exportDownload(url: string, name: string) {
  const response = await cachedMedia(url)
  if (!response) { states.delete(url); emit(); return }
  const objectURL = URL.createObjectURL(await response.blob())
  const anchor = document.createElement('a'); anchor.href = objectURL; anchor.download = name; anchor.click()
  setTimeout(() => URL.revokeObjectURL(objectURL), 60_000)
}
