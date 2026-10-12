'use client'

import { useEffect, useMemo, useRef, useState, type PointerEvent } from 'react'
import { Document, Page, pdfjs } from 'react-pdf'
import type { PDFDocumentProxy } from 'pdfjs-dist'
import 'react-pdf/dist/Page/AnnotationLayer.css'
import 'react-pdf/dist/Page/TextLayer.css'
import './pdf-reader.css'
import { indexTextItems, searchPages, highlightItem, type SearchPage } from './pdf-search'

pdfjs.GlobalWorkerOptions.workerSrc = new URL('pdfjs-dist/build/pdf.worker.min.mjs', import.meta.url).toString()
const options = { cMapUrl: '/pdf-assets/cmaps/', standardFontDataUrl: '/pdf-assets/standard_fonts/', wasmUrl: '/pdf-assets/wasm/' }

export default function PdfReader({ url, title, bookId }: { url: string; title: string; bookId: string }) {
  // A new source mounts an independent document and cancels the previous loading work.
  return <PdfDocument key={url} url={url} title={title} bookId={bookId} />
}

function PdfDocument({ url, title, bookId }: { url: string; title: string; bookId: string }) {
  const [textPages, setTextPages] = useState<(SearchPage | undefined)[]>([])
  const [indexing, setIndexing] = useState(false)
  const [partialIndex, setPartialIndex] = useState(false)
  const [searchOpen, setSearchOpen] = useState(false)
  const [query, setQuery] = useState('')
  const [debouncedQuery, setDebouncedQuery] = useState('')
  const [activeMatch, setActiveMatch] = useState(0)
  const [showResults, setShowResults] = useState(false)
  const pendingMatch = useRef<number | null>(null)
  const matches = useMemo(() => searchPages(textPages, debouncedQuery), [textPages, debouncedQuery])
  const searchable = textPages.some(page => page?.text.trim())
  const viewport = useRef<HTMLDivElement>(null)
  const rail = useRef<HTMLDivElement>(null)
  const grab = useRef(26)
  const restored = useRef(false)
  const [pdf, setPdf] = useState<PDFDocumentProxy | null>(null)
  const [ratios, setRatios] = useState<number[]>([])
  const [width, setWidth] = useState(700)
  const [zoom, setZoom] = useState(1)
  const [scroll, setScroll] = useState(0)
  const [height, setHeight] = useState(600)
  const [dragging, setDragging] = useState(false)
  const [focused, setFocused] = useState(false)
  const [error, setError] = useState(false)
  const [attempt, setAttempt] = useState(0)

  useEffect(() => {
    const node = viewport.current
    if (!node) return
    const observer = new ResizeObserver(() => { setWidth(Math.max(180, Math.min(1000, node.clientWidth - 60))); setHeight(node.clientHeight) })
    observer.observe(node)
    return () => observer.disconnect()
  }, [])

  useEffect(() => {
    if (!pdf) return
    let cancelled = false
    // Only read page geometry here. Canvas rendering is limited to the visible window.
    const sizes: number[] = Array(pdf.numPages)
    let next = 1
    async function readSizes() {
      while (!cancelled && next <= pdf!.numPages) {
        const page = next++
        const item = await pdf!.getPage(page)
        const box = item.getViewport({ scale: 1 })
        sizes[page - 1] = box.height / box.width
      }
    }
    Promise.all(Array.from({ length: Math.min(6, pdf.numPages) }, readSizes)).then(() => {
      if (!cancelled) setRatios(sizes)
    }).catch(() => { if (!cancelled) setError(true) })
    return () => { cancelled = true }
  }, [pdf])

  useEffect(() => {
    setTextPages([]); setQuery(''); setDebouncedQuery(''); setSearchOpen(false); setPartialIndex(false)
    if (!pdf) return
    let cancelled = false
    setIndexing(true)
    async function indexText() {
      const pages: (SearchPage | undefined)[] = []
      for (let number = 1; number <= pdf!.numPages; number++) {
        if (cancelled) return
        try {
          const page = await pdf!.getPage(number)
          const content = await page.getTextContent()
          if (cancelled) return
          pages[number - 1] = indexTextItems(content.items)
        } catch {
          if (cancelled) return
          setPartialIndex(true)
        }
        if (!cancelled) setTextPages([...pages])
        await new Promise(resolve => setTimeout(resolve, 0))
      }
      if (!cancelled) setIndexing(false)
    }
    void indexText()
    return () => { cancelled = true }
  }, [pdf])

  useEffect(() => {
    const timer = setTimeout(() => { setDebouncedQuery(query); setActiveMatch(0); pendingMatch.current = 0 }, 250)
    return () => clearTimeout(timer)
  }, [query])

  const revealMatch = () => {
    if (pendingMatch.current === null || !viewport.current) return
    const element = viewport.current.querySelector<HTMLElement>(`mark[data-pdf-match="${pendingMatch.current}"]`)
    if (!element) return
    const box = element.getBoundingClientRect(), container = viewport.current.getBoundingClientRect()
    viewport.current.scrollTop += box.top - container.top - viewport.current.clientHeight / 2
    pendingMatch.current = null
  }

  const pageWidth = width * zoom
  const offsets = useMemo(() => {
    const result = [0]
    for (const ratio of ratios) result.push(result[result.length - 1] + ratio * pageWidth + 16)
    return result
  }, [ratios, pageWidth])
  const total = offsets[offsets.length - 1]
  const maxScroll = Math.max(0, total + 32 - height)
  const progress = maxScroll ? Math.min(1, scroll / maxScroll) : 0
  const pageAt = (position: number) => {
    let low = 0, high = ratios.length - 1
    while (low < high) { const mid = Math.ceil((low + high) / 2); if (offsets[mid] <= position) low = mid; else high = mid - 1 }
    return low
  }
  const current = ratios.length ? (maxScroll > 0 && scroll >= maxScroll - 1 ? ratios.length : pageAt(Math.max(0, scroll - 16) + height * .25) + 1) : 1
  const first = Math.max(0, pageAt(Math.max(0, scroll - height)) - 1)
  const last = Math.min(ratios.length - 1, pageAt(scroll + height * 2) + 1)
  const goTo = (page: number) => {
    if (!viewport.current) return
    viewport.current.scrollTop = offsets[Math.max(0, Math.min(ratios.length - 1, page - 1))] + 16
  }
  useEffect(() => {
    if (!ratios.length || restored.current || !viewport.current) return
    restored.current = true
    try { const saved = Number(localStorage.getItem(`page::${bookId}`)); if (Number.isInteger(saved) && saved > 0) goTo(saved) } catch {}
  }, [ratios, bookId])
  useEffect(() => {
    if (!restored.current) return
    const timer = setTimeout(() => { try { localStorage.setItem(`page::${bookId}`, String(current)) } catch {} }, 300)
    return () => clearTimeout(timer)
  }, [current, bookId])
  const selectMatch = (index: number) => {
    if (!matches.length) return
    const next = (index + matches.length) % matches.length
    setActiveMatch(next)
    pendingMatch.current = next
    goTo(matches[next].page)
    requestAnimationFrame(revealMatch)
  }
  useEffect(() => {
    if (searchOpen && matches.length && pendingMatch.current !== null && ratios.length) {
      goTo(matches[Math.min(pendingMatch.current, matches.length - 1)].page)
      requestAnimationFrame(revealMatch)
    }
  }, [matches, searchOpen, ratios])
  const closeSearch = () => {
    setSearchOpen(false); setQuery(''); setDebouncedQuery(''); setShowResults(false); pendingMatch.current = null
  }
  const dragTo = (event: PointerEvent<HTMLButtonElement>) => {
    if (!rail.current || !viewport.current) return
    const box = rail.current.getBoundingClientRect()
    const position = Math.max(0, Math.min(1, (event.clientY - box.top - grab.current) / Math.max(1, box.height - 52)))
    viewport.current.scrollTop = position * maxScroll
  }
  const fallback = <div className="pdf-message" role="alert"><p>ފޮތް ލޯޑުނުވޭ. އަލުން ކުރައްވާ.</p><button onClick={() => { setError(false); setPdf(null); setRatios([]); setAttempt(value => value + 1) }}>އަލުން ކުރައްވާ</button><a href={url} target="_blank" rel="noreferrer">ފައިލް ހުޅުވާ ↗</a></div>
  return <section className="glass-pdf" dir="ltr" aria-label={`${title} PDF reader`}>
    <div className="pdf-tools">
      {searchable && !error && <button type="button" aria-label="ހޯދާ" aria-expanded={searchOpen} onClick={() => searchOpen ? closeSearch() : setSearchOpen(true)}><svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden="true"><circle cx="10" cy="10" r="6"/><path d="m15 15 6 6"/></svg></button>}
      <span aria-live="off">{ratios.length ? `${current} / ${ratios.length}` : 'ފޮތް ލޯޑުވަނީ…'}</span>
      <label>ސައިޒު <select aria-label="PDF zoom" value={zoom} onChange={event => setZoom(Number(event.target.value))}><option value={1}>ފުޅާމިން</option><option value={1.25}>125%</option><option value={1.5}>150%</option><option value={2}>200%</option></select></label>
      <a href={url} target="_blank" rel="noreferrer">ފައިލް ހުޅުވާ ↗</a>
    </div>
    {searchOpen && searchable && <div className="pdf-search" dir="rtl">
      <div className="pdf-search-controls">
        <input autoFocus aria-label="ލަފްޒެއް ހޯދާ" placeholder="ލަފްޒެއް ހޯދާ" value={query} onChange={event => { setQuery(event.target.value); setDebouncedQuery(''); pendingMatch.current = null }} onKeyDown={event => { if (event.key === 'Escape') closeSearch(); if (event.key === 'Enter') { event.preventDefault(); selectMatch(event.shiftKey ? activeMatch - 1 : activeMatch + 1) } }} />
        <span role="status">{indexing ? 'ހޯދަނީ… ' : ''}{debouncedQuery.trim() ? (matches.length ? `${activeMatch + 1} / ${matches.length}` : 'ނުފެނުނު') : ''}</span>
        <button aria-label="ކުރީގެ" disabled={!matches.length} onClick={() => selectMatch(activeMatch - 1)}>↑</button>
        <button aria-label="ދެން އޮތް" disabled={!matches.length} onClick={() => selectMatch(activeMatch + 1)}>↓</button>
        <button aria-label="ނަތީޖާ" aria-expanded={showResults} disabled={!matches.length} onClick={() => setShowResults(!showResults)}>☷</button>
        <button aria-label="ބަންދުކުރޭ" onClick={closeSearch}>×</button>
      </div>
      {partialIndex && <p role="status">ބައެއް ޞަފްޙާތަކުން ހޯދެވުނީނުވެ.</p>}
      {showResults && <div className="pdf-search-results">{matches.map((match, index) => <button key={`${match.page}-${match.start}`} aria-current={index === activeMatch ? 'true' : undefined} onClick={() => selectMatch(index)}><strong>ޞަފްޙާ {match.page}</strong><span>{match.snippet}</span></button>)}</div>}
    </div>}
    <div ref={viewport} className="pdf-viewport" tabIndex={0} aria-label="PDF pages" onScroll={event => setScroll(event.currentTarget.scrollTop)}>
      {error ? fallback : <Document key={attempt} file={url} options={options} suspense={false} onLoadSuccess={setPdf} onLoadError={() => setError(true)} loading={<p className="pdf-message" role="status">ފޮތް ލޯޑުވަނީ…</p>} onItemClick={({ pageNumber }) => { if (pageNumber) goTo(pageNumber) }}>
        {pdf && !ratios.length && <p className="pdf-message" role="status">ޞަފްޙާ {pdf.numPages} ލޯޑުވަނީ…</p>}
        {ratios.length > 0 && <div style={{ height: total, width: pageWidth, position: 'relative', margin: '0 auto' }}>
          {Array.from({ length: Math.max(0, last - first + 1) }, (_, index) => first + index).map(index => <div key={index} className="pdf-sheet" style={{ position: 'absolute', top: offsets[index], width: pageWidth, height: ratios[index] * pageWidth }} aria-label={`Page ${index + 1}`}>
            <Page customTextRenderer={({ str, itemIndex }) => highlightItem(str, itemIndex, textPages[index], searchOpen ? matches : [], activeMatch, index + 1)} onRenderTextLayerSuccess={revealMatch} pageNumber={index + 1} width={pageWidth} devicePixelRatio={Math.min(window.devicePixelRatio || 1, 2)} renderAnnotationLayer renderTextLayer loading={<span className="pdf-page-loading">ޞަފްޙާ {index + 1}…</span>} error={<a href={url} target="_blank" rel="noreferrer">ޞަފްޙާ ލޯޑުނުވޭ. ފައިލް ހުޅުވާ.</a>} />
          </div>)}
        </div>}
      </Document>}
    </div>
    {!error && ratios.length > 1 && maxScroll > 0 && <div className="pdf-scroll-rail" ref={rail}>
      <button className="pdf-scroll-thumb" type="button" role="slider" aria-label="PDF page" aria-orientation="vertical" aria-valuemin={1} aria-valuemax={ratios.length} aria-valuenow={current} aria-valuetext={`Page ${current} of ${ratios.length}`} style={{ top: `calc(${progress * 100}% - ${progress * 52}px)` }}
        onPointerDown={event => { grab.current = event.clientY - event.currentTarget.getBoundingClientRect().top; event.currentTarget.setPointerCapture(event.pointerId); setDragging(true) }}
        onPointerMove={event => { if (event.currentTarget.hasPointerCapture(event.pointerId)) dragTo(event) }}
        onPointerUp={event => { if (event.currentTarget.hasPointerCapture(event.pointerId)) event.currentTarget.releasePointerCapture(event.pointerId); setDragging(false) }}
        onPointerCancel={() => setDragging(false)} onLostPointerCapture={() => setDragging(false)} onFocus={event => setFocused(event.currentTarget.matches(':focus-visible'))} onBlur={() => setFocused(false)}
        onKeyDown={event => { setFocused(true); const targets: Record<string, number> = { ArrowDown: current + 1, ArrowUp: current - 1, PageDown: current + 5, PageUp: current - 5, Home: 1, End: ratios.length }; if (event.key in targets) { event.preventDefault(); goTo(targets[event.key]) } }}>
        <span className="pdf-scroll-grip" aria-hidden="true">☰</span>
        {(dragging || focused) && <span className="pdf-page-bubble" aria-hidden="true">{current} / {ratios.length}</span>}
      </button>
    </div>}
  </section>
}
