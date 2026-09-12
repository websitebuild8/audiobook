'use client'

import { useEffect, useState, type CSSProperties } from 'react'
import { ArrowUpLeft, BookOpen, FolderOpen, Headphones, HardDrive, Plus, RefreshCw, ExternalLink, FileText, AlertCircle } from 'lucide-react'
import { summarize, readSnapshot, formatBytes, type Snapshot } from './dashboard/analytics'

const number = (value: number) => value.toLocaleString('en')
const collectionURL = (slug: string) => `/admin/collections/${slug}`
const formatLabels = ['Audio + PDF', 'PDF only', 'Audio only', 'No files attached']
const colors = ['#17664e', '#b69a64', '#769e91', '#d8dedb']

export function Welcome() {
  const [snapshot, setSnapshot] = useState<Snapshot | null>(null)
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(true)
  const [revision, setRevision] = useState(0)
  const [updated, setUpdated] = useState('')
  useEffect(() => {
    const controller = new AbortController()
    setLoading(true)
    setError('')
    const timeout = setTimeout(() => controller.abort(new Error('The request timed out. Please try again.')), 60000)
    readSnapshot(controller.signal).then(result => {
      setSnapshot(result)
      setUpdated(new Date().toLocaleTimeString('en', { hour: '2-digit', minute: '2-digit' }))
    }).catch((reason: unknown) => {
      if (!controller.signal.aborted || controller.signal.reason instanceof Error && controller.signal.reason.name !== 'AbortError') {
        setError(reason instanceof Error ? reason.message : 'Unable to load the overview. Please try again.')
      }
    }).finally(() => { clearTimeout(timeout); if (!controller.signal.aborted || controller.signal.reason?.name !== 'AbortError') setLoading(false) })
    return () => { clearTimeout(timeout); controller.abort() }
  }, [revision])
  const data = snapshot ? summarize(snapshot) : null
  const values = data ? Object.values(data.formats) : []
  let offset = 0
  const gradient = values.map((value, i) => {
    const start = offset
    offset += data?.total ? value / data.total * 100 : 0
    return `${colors[i]} ${start}% ${offset}%`
  }).join(', ')

  return (
    <section className="mk-dashboard" dir="rtl" aria-label="Library overview">
      <header className="mk-heading">
        <div><p className="mk-eyebrow" lang="en">MAKTHABA / WORKSPACE</p><h1>އިދާރާއަށް މަރުޙަބާ</h1><p>ފޮތްތަކާއި، އޯޑިއޯތަކާއި، ބައިތައް މިތަނުން މެނޭޖްކުރައްވާ.</p></div>
        <a className="mk-button mk-button--primary" href={`${collectionURL('books')}/create`}><Plus size={18} aria-hidden="true" />ފޮތެއް އިތުރުކުރައްވާ</a>
      </header>

      <div className="mk-banner">
        <div><span className="mk-eyebrow" lang="en">A HOME FOR KNOWLEDGE</span><h2>މަކްތަބާ އަލްއަޘަރިއްޔާ</h2><p lang="en" dir="ltr">Your library. Thoughtfully organised.</p><a href="/" className="mk-banner-link" lang="en">Open public library <ExternalLink size={15} aria-hidden="true" /></a></div>
        <img src="/makthaba-logo.png" alt="" className="mk-banner-logo" />
      </div>

      <nav className="mk-shortcuts" aria-label="Manage library">
        {[{ slug: 'books', label: 'ފޮތްތައް', english: 'Books', icon: BookOpen }, { slug: 'categories', label: 'ބައިތައް', english: 'Categories', icon: FolderOpen }, { slug: 'media', label: 'ފައިލުތައް', english: 'Media library', icon: HardDrive }].map(({ slug, label, english, icon: Icon }) => <a key={slug} href={collectionURL(slug)}><span className="mk-icon"><Icon size={20} aria-hidden="true" /></span><span><strong>{label}</strong><small lang="en">{english}</small></span><ArrowUpLeft size={18} aria-hidden="true" /></a>)}
      </nav>

      <div className="mk-section-heading"><div><h2 lang="en">Library overview</h2><p lang="en">All saved books, including drafts</p></div><button type="button" className="mk-button" onClick={() => setRevision(value => value + 1)} disabled={loading}><RefreshCw size={15} className={loading ? 'mk-spin' : ''} aria-hidden="true" /><span lang="en">{loading ? 'Refreshing…' : 'Refresh'}</span></button></div>
      <p className="mk-live" role="status" lang="en">{loading ? 'Loading library data…' : error ? 'Overview could not be refreshed.' : `Updated at ${updated} · Live collection data`}{error && snapshot ? ' Showing the previous snapshot.' : ''}</p>
      {error && <div className="mk-error" role="alert" dir="ltr"><AlertCircle size={20} aria-hidden="true" /><span>{error}</span><button className="mk-button" onClick={() => setRevision(value => value + 1)} disabled={loading}>Try again</button></div>}
      {!data && loading && <div className="mk-stats" aria-hidden="true">{[0, 1, 2, 3].map(i => <div className="mk-stat mk-skeleton" key={i} />)}</div>}
      {data && snapshot && <div aria-busy={loading}>
        <div className="mk-stats">
          {[{ label: 'Total books', value: number(data.total), note: `${number(data.published)} published · ${number(data.drafts)} drafts${data.unknownStatus ? ` · ${data.unknownStatus} unknown` : ''}`, icon: BookOpen, href: 'books' }, { label: 'Categories', value: number(snapshot.categories.length), note: 'Across your library', icon: FolderOpen, href: 'categories' }, { label: 'Audiobooks', value: number(data.audio), note: 'With attached audio chapters', icon: Headphones, href: 'books' }, { label: 'Recorded media', value: data.storage.unknown === snapshot.media.length && snapshot.media.length > 0 ? 'Unavailable' : formatBytes(data.storage.bytes), note: `${number(snapshot.media.length)} files${data.storage.unknown ? ` · ${number(data.storage.unknown)} sizes unavailable` : ' · Original uploads'}`, icon: HardDrive, href: 'media' }].map(({ label, value, note, icon: Icon, href }) => <a href={collectionURL(href)} className="mk-stat" key={label} dir="ltr" lang="en"><div><span>{label}</span><Icon size={19} aria-hidden="true" /></div><strong>{value}</strong><small>{note}</small></a>)}
        </div>
        <div className="mk-charts">
          <article className="mk-panel"><div className="mk-panel-heading"><div><h3 lang="en">Books by category</h3><p lang="en">Distribution across the collection</p></div><FolderOpen size={20} aria-hidden="true" /></div>
            {data.total === 0 ? <Empty text="Add your first book to see category distribution." /> : <div className="mk-bars">{data.distribution.map(category => <div className="mk-bar-row" key={category.id}><div><span dir="auto">{category.name}</span><strong>{number(category.count)}</strong></div><div className="mk-track" role="img" aria-label={`${category.name}: ${category.count} of ${data.total} books`}><span style={{ width: `${category.count / data.total * 100}%` }} /></div></div>)}</div>}
          </article>
          <article className="mk-panel"><div className="mk-panel-heading"><div><h3 lang="en">Format coverage</h3><p lang="en">Based on attached files</p></div><Headphones size={20} aria-hidden="true" /></div><div className="mk-coverage" dir="ltr"><div className="mk-donut" role="img" aria-label={`${data.audio} of ${data.total} books have audio; ${data.pdf} have PDFs`} style={{ background: data.total ? `conic-gradient(${gradient})` : '#d8dedb' }}><div><strong>{data.total ? `${Math.round(data.audio / data.total * 100)}%` : '—'}</strong><small lang="en">with audio</small></div></div><ul className="mk-legend" lang="en">{values.map((value, i) => <li key={formatLabels[i]}><span className="mk-dot" style={{ '--dot': colors[i] } as CSSProperties} /><span>{formatLabels[i]}</span><strong>{number(value)}</strong></li>)}</ul></div><p className="mk-footnote" lang="en">A book with both formats is counted once. File availability is not a playback check.</p></article>
        </div>
        <article className="mk-panel mk-recent"><div className="mk-panel-heading"><div><h3 lang="en">Recently updated</h3><p lang="en">The latest additions and edits</p></div><a href={`${collectionURL('books')}?sort=-updatedAt`} className="mk-text-link" lang="en">View all books <ArrowUpLeft size={16} aria-hidden="true" /></a></div>
          {!data.recent.length ? <Empty text="Your library starts here. Add a book to begin." /> : <ul className="mk-book-list">{data.recent.map(book => <li key={book.id}><a href={`${collectionURL('books')}/${encodeURIComponent(book.id)}`}><span className="mk-book-icon"><BookOpen size={23} aria-hidden="true" /></span><span className="mk-book-title"><strong dir="auto">{book.title || 'Untitled book'}</strong><small lang="en" dir="ltr">{book.updatedAt && !Number.isNaN(Date.parse(book.updatedAt)) ? new Date(book.updatedAt).toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric', timeZone: 'Indian/Maldives' }) : 'Date unavailable'}</small></span><span className="mk-format-icons">{book.pdf != null && <FileText size={17} aria-label="PDF attached" />}{book.audioChapters?.some(chapter => chapter.audio != null) && <Headphones size={17} aria-label="Audio attached" />}</span><span lang="en" className={`mk-status ${book._status === 'published' ? 'mk-status--published' : ''}`}>{book._status === 'published' ? 'Published' : book._status === 'draft' ? 'Draft' : 'Unknown'}</span><ArrowUpLeft size={16} aria-hidden="true" /></a></li>)}</ul>}
        </article>
        <p className="mk-footnote mk-storage-note" lang="en" dir="ltr"><HardDrive size={15} aria-hidden="true" /> Storage totals use recorded original file sizes. R2 bucket usage, derivatives, quotas and listening analytics are not available.</p>
      </div>}
    </section>
  )
}

function Empty({ text }: { text: string }) {
  return <div className="mk-empty" lang="en"><BookOpen size={28} aria-hidden="true" /><p>{text}</p><a className="mk-text-link" href={`${collectionURL('books')}/create`}>Add a book <Plus size={16} aria-hidden="true" /></a></div>
}
