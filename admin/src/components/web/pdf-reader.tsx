'use client'

import { useEffect, useMemo, useRef, useState, type PointerEvent } from 'react'
import { Document, Page, pdfjs } from 'react-pdf'
import type { PDFDocumentProxy } from 'pdfjs-dist'
import 'react-pdf/dist/Page/AnnotationLayer.css'
import 'react-pdf/dist/Page/TextLayer.css'
import './pdf-reader.css'

pdfjs.GlobalWorkerOptions.workerSrc = new URL('pdfjs-dist/build/pdf.worker.min.mjs', import.meta.url).toString()
const options = { cMapUrl: '/pdf-assets/cmaps/', standardFontDataUrl: '/pdf-assets/standard_fonts/', wasmUrl: '/pdf-assets/wasm/' }

export default function PdfReader({ url, title }: { url: string; title: string }) {
  // A new source mounts an independent document and cancels the previous loading work.
  return <PdfDocument key={url} url={url} title={title} />
}

function PdfDocument({ url, title }: { url: string; title: string }) {
  const viewport = useRef<HTMLDivElement>(null)
  const rail = useRef<HTMLDivElement>(null)
  const grab = useRef(26)
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
  const dragTo = (event: PointerEvent<HTMLButtonElement>) => {
    if (!rail.current || !viewport.current) return
    const box = rail.current.getBoundingClientRect()
    const position = Math.max(0, Math.min(1, (event.clientY - box.top - grab.current) / Math.max(1, box.height - 52)))
    viewport.current.scrollTop = position * maxScroll
  }
  const fallback = <div className="pdf-message" role="alert"><p>This PDF could not be displayed. You can retry or open it in your browser.</p><button onClick={() => { setError(false); setPdf(null); setRatios([]); setAttempt(value => value + 1) }}>Try again</button><a href={url} target="_blank" rel="noreferrer">Open original PDF ↗</a></div>
  return <section className="glass-pdf" dir="ltr" aria-label={`${title} PDF reader`}>
    <div className="pdf-tools">
      <span aria-live="off">{ratios.length ? `${current} / ${ratios.length}` : 'Loading PDF…'}</span>
      <label>Zoom <select aria-label="PDF zoom" value={zoom} onChange={event => setZoom(Number(event.target.value))}><option value={1}>Fit width</option><option value={1.25}>125%</option><option value={1.5}>150%</option><option value={2}>200%</option></select></label>
      <a href={url} target="_blank" rel="noreferrer">Open original ↗</a>
    </div>
    <div ref={viewport} className="pdf-viewport" tabIndex={0} aria-label="PDF pages" onScroll={event => setScroll(event.currentTarget.scrollTop)}>
      {error ? fallback : <Document key={attempt} file={url} options={options} suspense={false} onLoadSuccess={setPdf} onLoadError={() => setError(true)} loading={<p className="pdf-message" role="status">Loading PDF…</p>} onItemClick={({ pageNumber }) => { if (pageNumber) goTo(pageNumber) }}>
        {pdf && !ratios.length && <p className="pdf-message" role="status">Preparing {pdf.numPages} pages…</p>}
        {ratios.length > 0 && <div style={{ height: total, width: pageWidth, position: 'relative', margin: '0 auto' }}>
          {Array.from({ length: Math.max(0, last - first + 1) }, (_, index) => first + index).map(index => <div key={index} className="pdf-sheet" style={{ position: 'absolute', top: offsets[index], width: pageWidth, height: ratios[index] * pageWidth }} aria-label={`Page ${index + 1}`}>
            <Page pageNumber={index + 1} width={pageWidth} devicePixelRatio={Math.min(window.devicePixelRatio || 1, 2)} renderAnnotationLayer renderTextLayer loading={<span className="pdf-page-loading">Page {index + 1}…</span>} error={<a href={url} target="_blank" rel="noreferrer">Unable to render this page. Open original PDF.</a>} />
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
