'use client'
import { useEffect, useReducer } from 'react'
import { Download, X, Trash2, Save } from 'lucide-react'
import { cachedMedia, cancelDownload, discoverDownload, downloadMedia, downloadState, exportDownload, removeDownload, subscribeDownloads } from './media-downloads'
export { cachedMedia }
export function DownloadButton({ url, name }: { url: string; name: string }) {
  const [, update] = useReducer(value => value + 1, 0)
  useEffect(() => { const unsubscribe = subscribeDownloads(update); void discoverDownload(url); return unsubscribe }, [url])
  const state = downloadState(url)
  if (!url) return null
  return <div className="flex items-center gap-1 text-xs" role="group" aria-label="ޑައުންލޯޑް">
    {state?.status === 'loading' ? <><span aria-live="off" dir="ltr">{state.total ? `${Math.min(100, Math.floor(state.received / state.total * 100))}%` : `${(state.received / 1048576).toFixed(1)} MB`}</span><button className="media-icon" title="ކެންސަލް" onClick={() => cancelDownload(url)}><X size={18} /></button></> : state?.status === 'saved' ? <><span className="text-green-700 dark:text-green-400">ސޭވްވެފައި</span><button className="media-icon" title="ޑައުންލޯޑް" onClick={() => void exportDownload(url, name).catch(() => window.alert('ސޭވް ނުކުރެވުނު'))}><Save size={18} /></button><button className="media-icon" title="ފުހެލާ" onClick={() => { if (confirm('ސޭވްކޮށްފައިވާ ފައިލް ފުހެލަން؟')) void removeDownload(url).catch(() => window.alert('ފުހެނުލެވުނު')) }}><Trash2 size={18} /></button></> : <>{state?.status === 'error' && <span role="status">އަލުން ކުރައްވާ</span>}<button className="media-icon" title="ޑައުންލޯޑް" onClick={() => void downloadMedia(url)}><Download size={18} /></button></>}
    {state?.status === 'error' && <a href={url} target="_blank" rel="noreferrer" className="underline">ފައިލް ހުޅުވާ</a>}
  </div>
}
