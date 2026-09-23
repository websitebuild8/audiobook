'use client'
import { createContext, useContext, useEffect, useState, type ReactNode } from 'react'
import { CheckCircle2 } from 'lucide-react'
import { isEditionId, type EditionId } from './book-editions'

const KEY = 'makthaba-web-completed'
export function storedCompleted(raw: string | null): EditionId[] {
  try { const value: unknown = JSON.parse(raw || '[]'); return Array.isArray(value) ? [...new Set(value.filter(isEditionId))] : [] } catch { return [] }
}
export function completionCount(ids: EditionId[], completed: EditionId[]) {
  return [...new Set(ids)].filter(id => completed.includes(id)).length
}
const Context = createContext<{ completed: EditionId[]; toggle: (id: EditionId) => void }>({ completed: [], toggle: () => {} })
export const useReading = () => useContext(Context)
export function ReadingProvider({ children }: { children: ReactNode }) {
  const [completed, setCompleted] = useState<EditionId[]>([])
  useEffect(() => {
    const sync = () => { try { setCompleted(storedCompleted(localStorage.getItem(KEY))) } catch {} }
    sync(); window.addEventListener('storage', sync)
    return () => window.removeEventListener('storage', sync)
  }, [])
  function toggle(id: EditionId) {
    const read = completed.includes(id)
    if (!window.confirm(read ? 'ނުކިޔާ ފޮތެއްގެ ގޮތުގައި ފާހަގަކުރަން؟' : 'ފޮތް ކިޔާ ނިމިއްޖެތަ؟')) return
    const next = read ? completed.filter(value => value !== id) : [...completed, id]
    try { localStorage.setItem(KEY, JSON.stringify(next)); setCompleted(next) }
    catch { window.alert('ސޭވް ނުކުރެވުނު. އަލުން ކުރައްވާ.') }
  }
  return <Context.Provider value={{ completed, toggle }}>{children}</Context.Provider>
}
export function ReadBadge({ id }: { id: EditionId }) {
  const { completed } = useReading()
  return completed.includes(id) ? <span title="ކިޔައި ނިމިފައި" className="absolute right-2 top-2 z-20 rounded-full bg-white p-1 text-green-700 shadow"><CheckCircle2 aria-label="ކިޔައި ނިމިފައި" className="size-6" /></span> : null
}
export function ReadingProgress({ ids }: { ids: EditionId[] }) {
  const { completed } = useReading()
  const total = new Set(ids).size, count = completionCount(ids, completed)
  if (!total) return null
  return <div className="reading-progress mb-2 rounded-2xl border border-stone-200/70 bg-white/40 px-4 py-3 dark:border-white/10 dark:bg-white/5">
    <div className="mb-2 flex items-center gap-2 text-sm"><CheckCircle2 className="size-4 text-emerald-700 dark:text-emerald-400" /><span className="flex-1">ކިޔައި ނިމިފައި</span><b dir="ltr">{count}/{total}</b></div>
    <div role="progressbar" aria-label="ކިޔައި ނިމިފައި" aria-valuenow={count} aria-valuemin={0} aria-valuemax={total} className="h-1.5 overflow-hidden rounded-full bg-emerald-700/10"><div className="h-full rounded-full bg-emerald-700 transition-[width] duration-300 motion-reduce:transition-none dark:bg-emerald-400" style={{ width: `${count / total * 100}%` }} /></div>
  </div>
}
