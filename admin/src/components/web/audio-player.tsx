'use client'
import { useEffect, useImperativeHandle, useRef, useState, type Ref } from 'react'
import { ChevronUp, ChevronDown, Play, Pause, Square, SkipBack, SkipForward } from 'lucide-react'
import type { Book } from './library-app'
import { mediaURL } from './library-app'
import { DownloadButton, cachedMedia } from './download-button'

export type AudioPlayerHandle = { open: (book: Book) => void }
export function AudioPlayer({ ref }: { ref: Ref<AudioPlayerHandle> }) {
  const audio = useRef<HTMLAudioElement>(null)
  const dialog = useRef<HTMLDialogElement>(null)
  const [book, setBook] = useState<Book | null>(null)
  const [index, setIndex] = useState(0)
  const [playing, setPlaying] = useState(false)
  const [position, setPosition] = useState(0)
  const [duration, setDuration] = useState(0)
  const [message, setMessage] = useState('')
  const [expanded, setExpanded] = useState(false)
  const generation = useRef(0)
  const objectURL = useRef('')
  const active = useRef<{ book: Book; index: number } | null>(null)
  const drag = useRef<number | null>(null)
  const chapters = [...(book?.audioChapters || [])].sort((a, b) => a.order - b.order)
  const save = () => {
    if (!active.current || !audio.current) return
    try { localStorage.setItem(`audio::${active.current.book.id}`, JSON.stringify({ index: active.current.index, position: audio.current.currentTime })) } catch {}
  }
  async function start(next: Book, chapter: number, offset = 0, autoplay = true) {
    save()
    const token = ++generation.current
    const list = [...(next.audioChapters || [])].sort((a, b) => a.order - b.order)
    const url = mediaURL(list[chapter]?.audio)
    if (!url || !audio.current) return
    audio.current.pause(); setMessage(''); setBook(next); setIndex(chapter); setPosition(offset); setDuration(0)
    active.current = { book: next, index: chapter }
    const cached = await cachedMedia(url)
    const blob = cached ? await cached.blob().catch(() => null) : null
    if (token !== generation.current || !audio.current) return
    if (objectURL.current) URL.revokeObjectURL(objectURL.current)
    objectURL.current = blob ? URL.createObjectURL(blob) : ''
    audio.current.src = objectURL.current || url
    audio.current.onloadedmetadata = () => { if (audio.current && token === generation.current) audio.current.currentTime = Math.min(offset, Number.isFinite(audio.current.duration) ? audio.current.duration : offset) }
    audio.current.load()
    if (autoplay) await audio.current.play().catch(() => setMessage('އަޑުއަހަން ޕްލޭ އަށް ފިތާލާ'))
  }
  function open(next: Book) {
    if (active.current?.book.id !== next.id) {
      let restored = { index: 0, position: 0 }
      try { const saved = JSON.parse(localStorage.getItem(`audio::${next.id}`) || '{}'); if (Number.isInteger(saved.index) && saved.index >= 0 && saved.index < (next.audioChapters?.length || 0) && Number.isFinite(saved.position) && saved.position >= 0) restored = saved } catch {}
      void start(next, restored.index, restored.position, false)
    }
    setExpanded(false); dialog.current?.showModal()
  }
  useImperativeHandle(ref, () => ({ open }))
  function playPause() {
    if (!audio.current) return
    if (audio.current.paused) void audio.current.play().catch(() => setMessage('އަޑު ލޯޑުނުވޭ. އަލުން ކުރައްވާ.'))
    else audio.current.pause()
  }
  function stop() { generation.current++; audio.current?.pause(); save() }
  useEffect(() => {
    const timer = window.setInterval(save, 5000)
    const onHide = () => save()
    window.addEventListener('pagehide', onHide)
    return () => { clearInterval(timer); window.removeEventListener('pagehide', onHide); generation.current++; if (objectURL.current) URL.revokeObjectURL(objectURL.current) }
  }, [])
  useEffect(() => {
    if (!book || !('mediaSession' in navigator)) return
    navigator.mediaSession.metadata = new MediaMetadata({ title: chapters[index]?.title || book.title, album: book.title, artist: book.author || 'މަކްތަބާ އަޘަރިއްޔާ', artwork: mediaURL(book.cover) ? [{ src: mediaURL(book.cover) }] : [] })
    navigator.mediaSession.playbackState = playing ? 'playing' : 'paused'
    const handlers: Partial<Record<MediaSessionAction, MediaSessionActionHandler>> = {
      play: () => { void audio.current?.play().catch(() => {}) }, pause: () => audio.current?.pause(), stop,
      previoustrack: () => { if (index > 0) void start(book, index - 1) },
      nexttrack: () => { if (index + 1 < chapters.length) void start(book, index + 1) },
      seekto: event => { if (audio.current && event.seekTime != null) audio.current.currentTime = event.seekTime },
      seekbackward: event => { if (audio.current) audio.current.currentTime = Math.max(0, audio.current.currentTime - (event.seekOffset || 15)) },
      seekforward: event => { if (audio.current && Number.isFinite(audio.current.duration)) audio.current.currentTime = Math.min(audio.current.duration, audio.current.currentTime + (event.seekOffset || 15)) },
    }
    for (const [action, handler] of Object.entries(handlers)) { try { navigator.mediaSession.setActionHandler(action as MediaSessionAction, handler) } catch {} }
    return () => { for (const action of Object.keys(handlers)) { try { navigator.mediaSession.setActionHandler(action as MediaSessionAction, null) } catch {} } }
  }, [book, index, playing])
  const controls = <><button className="media-icon" title="ފަހަތަށް" disabled={index === 0} onClick={() => book && void start(book, index - 1)}><SkipBack /></button><button className="media-icon" title={playing ? 'މަޑުކުރޭ' : 'އަޑުއަހާ'} onClick={playPause}>{playing ? <Pause /> : <Play />}</button><button className="media-icon" title="ހުއްޓާލާ" onClick={stop}><Square size={18} /></button><button className="media-icon" title="ކުރިއަށް" disabled={index + 1 >= chapters.length} onClick={() => book && void start(book, index + 1)}><SkipForward /></button></>
  return <>
    <audio ref={audio} preload="metadata" onPlay={() => setPlaying(true)} onPause={() => setPlaying(false)} onTimeUpdate={() => setPosition(audio.current?.currentTime || 0)} onDurationChange={() => setDuration(Number.isFinite(audio.current?.duration) ? audio.current!.duration : 0)} onError={() => setMessage('އަޑު ލޯޑުނުވޭ. އަލުން ކުރައްވާ.')} onEnded={() => { save(); if (book && index + 1 < chapters.length) void start(book, index + 1) }} />
    {book && <div className="web-mini-player web-glass"><button className="min-w-0 flex-1 text-right" onClick={() => dialog.current?.showModal()} onPointerDown={event => { drag.current = event.clientY }} onPointerUp={event => { if (drag.current != null && drag.current - event.clientY > 20) dialog.current?.showModal(); drag.current = null }}><span className="block truncate font-bold">{book.title}</span><span className="block truncate text-xs opacity-70">{chapters[index]?.title}</span></button><button className="media-icon" title={playing ? 'މަޑުކުރޭ' : 'އަޑުއަހާ'} onClick={playPause}>{playing ? <Pause /> : <Play />}</button><button className="media-icon" title="ހުއްޓާލާ" onClick={stop}><Square size={18} /></button><button className="media-icon" title="ހުޅުވާ" onClick={() => dialog.current?.showModal()}><ChevronUp /></button></div>}
    <dialog ref={dialog} className={`web-audio-sheet web-glass ${expanded ? 'expanded' : ''}`} aria-label="އޯޑިއޯ ފޮތް" onClick={event => { if (event.target === event.currentTarget && event.clientY < event.currentTarget.getBoundingClientRect().top) dialog.current?.close() }}>
      <button className="sheet-grab" aria-label="ހުޅުވާ / ކުޑަކުރޭ" onClick={() => setExpanded(value => !value)} onPointerDown={event => { drag.current = event.clientY; event.currentTarget.setPointerCapture(event.pointerId) }} onPointerUp={event => { const delta = event.clientY - (drag.current ?? event.clientY); if (delta > 40) { dialog.current?.close() } else if (delta < -30) setExpanded(true); drag.current = null }}><span /></button>
      <div className="flex items-center gap-3"><h2 className="min-w-0 flex-1 text-xl font-bold">{book?.title}</h2><button className="media-icon" title="ކުޑަކުރޭ" onClick={() => dialog.current?.close()}><ChevronDown /></button></div>
      <p className="mt-2 text-sm opacity-70">{chapters[index]?.title}</p>
      <div className="my-3 flex justify-center" dir="ltr">{controls}</div>
      <input className="w-full accent-emerald-600" aria-label="އަޑުގެ ތަން" type="range" min={0} max={duration || 1} value={Math.min(position, duration || 1)} step={1} onChange={event => { if (audio.current) { audio.current.currentTime = Number(event.target.value); setPosition(Number(event.target.value)) } }} dir="ltr" />
      <p dir="ltr" className="text-center text-xs tabular-nums">{formatTime(position)} / {formatTime(duration)}</p>
      {message && <p role="status" className="my-2 text-center">{message}</p>}
      <div className="mt-5 grid gap-2">{chapters.map((chapter, chapterIndex) => <div key={chapter.id || chapterIndex} className={`flex items-center gap-2 rounded-2xl border p-3 ${index === chapterIndex ? 'border-emerald-600/50 bg-emerald-500/10' : 'border-stone-400/20'}`}><button className="min-w-0 flex-1 text-right" onClick={() => { if (index === chapterIndex && active.current?.book.id === book?.id) playPause(); else if (book) void start(book, chapterIndex) }} aria-current={index === chapterIndex ? 'true' : undefined}>{chapter.title}</button><DownloadButton url={mediaURL(chapter.audio)} name={`${chapter.title}.mp3`} /></div>)}</div>
    </dialog>
  </>
}
function formatTime(seconds: number) { return `${Math.floor(seconds / 60)}:${Math.floor(seconds % 60).toString().padStart(2, '0')}` }
