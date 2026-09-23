'use client'

import {
  ArrowLeft,
  CheckCircle2,
  ShieldCheck,
  BookOpen,
  Bookmark,
  BookmarkCheck,
  ChevronLeft,
  ChevronRight,
  Clock3,
  Download,
  Headphones,
  Home,
  LoaderCircle,
  Menu,
  Moon,
  Search,
  Sun,
  X,
} from 'lucide-react'
import Image from 'next/image'
import dynamic from 'next/dynamic'
import { useCallback, useEffect, useMemo, useState, useRef } from 'react'
import { Button } from '@/components/ui/button'
import { cn } from '@/lib/utils'
import { expandBookEditions, isEditionId, type EditionId } from './book-editions'

import { ReadingProvider, ReadingProgress, ReadBadge, useReading } from './reading-state'
import { AudioPlayer, type AudioPlayerHandle } from './audio-player'
import { DownloadButton, cachedMedia } from './download-button'

type Media = { id: number; url?: string | null; alt?: string | null; filename?: string | null }
type Category = { id: number; name: string; slug: string; description?: string | null; order?: number | null; active?: boolean | null }
type Chapter = { id?: string | null; title: string; order: number; audio: number | Media }
export type Book = {
  showReaderNotice?: boolean | null
  id: EditionId
  publishReadingOnlyEdition?: boolean | null
  title: string
  author?: string | null
  description?: string | null
  category: number | Category
  cover?: number | Media | null
  pdf: number | Media
  featured?: boolean | null
  order?: number | null
  audioChapters?: Chapter[] | null
}
type ApiList<T> = { docs: T[] }
type Tab = 'home' | 'audio' | 'bookmarks' | 'recent'

const PAGE_SIZE = 10
const BOOKMARK_KEY = 'makthaba-web-bookmarks'
const RECENT_KEY = 'makthaba-web-recent'

const labels = {
  home: 'މައި ޞަފްޙާ',
  audio: 'އޯޑިއޯ ފޮތް',
  bookmarks: 'ފާހަގަ',
  recent: 'ފަހުން ކިޔެވި',
}

export function mediaURL(value: number | Media | null | undefined) {
  return value && typeof value === 'object' ? value.url || '' : ''
}

function categoryOf(book: Book) {
  return typeof book.category === 'object' ? book.category : undefined
}

function readStored(key: string) {
  try {
    const value = JSON.parse(localStorage.getItem(key) || '[]')
    return Array.isArray(value) ? value.filter(isEditionId) : []
  } catch {
    return []
  }
}

export function LibraryApp() { return <ReadingProvider><LibraryContent /></ReadingProvider> }

function LibraryContent() {
  const player = useRef<AudioPlayerHandle>(null)
  const [books, setBooks] = useState<Book[]>([])
  const [categories, setCategories] = useState<Category[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [tab, setTab] = useState<Tab>('home')
  const [query, setQuery] = useState('')
  const [category, setCategory] = useState<number | null>(null)
  const [page, setPage] = useState(1)
  const [selected, setSelected] = useState<Book | null>(null)
  const [bookmarks, setBookmarks] = useState<EditionId[]>([])
  const [recent, setRecent] = useState<EditionId[]>([])
  const [dark, setDark] = useState(false)
  const [menuOpen, setMenuOpen] = useState(false)

  const loadCatalogue = useCallback(async () => {
    setLoading(true)
    setError('')
    try {
      const [bookResponse, categoryResponse] = await Promise.all([
        fetch('/api/books?depth=2&limit=500&sort=order&where[_status][equals]=published'),
        fetch('/api/categories?depth=1&limit=100&sort=order&where[active][equals]=true'),
      ])
      if (!bookResponse.ok || !categoryResponse.ok) throw new Error('catalogue')
      const bookData = (await bookResponse.json()) as ApiList<Book>
      const categoryData = (await categoryResponse.json()) as ApiList<Category>
      setBooks(expandBookEditions(bookData.docs))
      setCategories(categoryData.docs)
    } catch {
      setError('ފޮތްތައް ލޯޑުނުވޭ. އިންޓަނެޓް ޗެކްކުރައްވާ.')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    setBookmarks(readStored(BOOKMARK_KEY))
    setRecent(readStored(RECENT_KEY))
    let savedTheme: string | null = null
    try { savedTheme = localStorage.getItem('makthaba-web-theme') } catch {}
    setDark(savedTheme ? savedTheme === 'dark' : matchMedia('(prefers-color-scheme: dark)').matches)
    void loadCatalogue()
  }, [loadCatalogue])

  useEffect(() => {
    document.documentElement.classList.toggle('dark', dark)
    try { localStorage.setItem('makthaba-web-theme', dark ? 'dark' : 'light') } catch {}
  }, [dark])

  useEffect(() => setPage(1), [tab, query, category])

  const audioBooks = useMemo(() => books.filter((book) => book.audioChapters?.length), [books])
  const visibleBooks = useMemo(() => {
    let result = tab === 'audio' ? audioBooks : books
    if (tab === 'bookmarks') result = bookmarks.map((id) => books.find((book) => book.id === id)).filter((book): book is Book => Boolean(book))
    if (tab === 'recent') result = recent.slice(0, 3).map((id) => books.find((book) => book.id === id)).filter((book): book is Book => Boolean(book))
    if (category !== null) result = result.filter((book) => categoryOf(book)?.id === category || book.category === category)
    const normalized = query.trim().toLocaleLowerCase()
    if (normalized) result = result.filter((book) => `${book.title} ${book.author || ''}`.toLocaleLowerCase().includes(normalized))
    return result
  }, [audioBooks, bookmarks, books, category, query, recent, tab])

  const pages = Math.max(1, Math.ceil(visibleBooks.length / PAGE_SIZE))
  const pageBooks = visibleBooks.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE)
  const featured = books.find((book) => book.featured) || books[0]

  function toggleBookmark(id: EditionId) {
    setBookmarks((current) => {
      const next = current.includes(id) ? current.filter((value) => value !== id) : [id, ...current]
      try { localStorage.setItem(BOOKMARK_KEY, JSON.stringify(next)) } catch {}
      return next
    })
  }

  function openBook(book: Book) {
    const next = [book.id, ...recent.filter((id) => id !== book.id)].slice(0, 3)
    setRecent(next)
    try { localStorage.setItem(RECENT_KEY, JSON.stringify(next)) } catch {}
    setSelected(book)
  }

  function selectTab(next: Tab) {
    setTab(next)
    setCategory(null)
    setMenuOpen(false)
    window.scrollTo({ top: 0, behavior: 'smooth' })
  }

  return (
    <div className="min-h-dvh bg-[#faf8f3] text-stone-900 transition-colors duration-300 dark:bg-[#07120d] dark:text-stone-100">
      <Header dark={dark} menuOpen={menuOpen} onMenu={() => setMenuOpen((value) => !value)} onTheme={() => setDark((value) => !value)} query={query} setQuery={setQuery} ids={books.map(book => book.id)} />
      {menuOpen && <MobileMenu active={tab} onSelect={selectTab} />}

      <main className="mx-auto w-full max-w-[1440px] px-4 pb-52 pt-4 sm:px-6 lg:px-10 lg:pb-36 lg:pt-8">
        <DesktopNav active={tab} onSelect={selectTab} />

        {tab === 'home' && featured && !query && !category && <Hero book={featured} onOpen={() => openBook(featured)} />}

        <section className="mt-7">
          <div className="mb-4 flex items-end justify-between gap-4">
            <div>
              <p className="mb-1 text-xs font-bold tracking-[.15em] text-emerald-700 dark:text-emerald-400">މަކްތަބާ އަޘަރިއްޔާ</p>
              <h1 className="text-2xl font-bold sm:text-3xl">{category ? categories.find((item) => item.id === category)?.name : labels[tab]}</h1>
            </div>
            <span className="rounded-full bg-white px-3 py-1 text-sm text-stone-500 shadow-sm dark:bg-white/5 dark:text-stone-400">{visibleBooks.length} ފޮތް</span>
          </div>

          {(tab === 'home' || tab === 'audio') && (
            <CategoryRail categories={categories} selected={category} onSelect={setCategory} />
          )}

          {loading ? (
            <div className="grid min-h-64 place-items-center"><LoaderCircle className="size-9 animate-spin text-emerald-700" /></div>
          ) : error ? (
            <EmptyState icon={BookOpen} title={error} action={<Button onClick={() => void loadCatalogue()}>އަލުން ލޯޑުކުރައްވާ</Button>} />
          ) : pageBooks.length ? (
            <div className="web-fade-up grid grid-cols-2 gap-x-4 gap-y-7 sm:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5">
              {pageBooks.map((book, index) => (
                <BookCard key={book.id} book={book} bookmarked={bookmarks.includes(book.id)} index={index} onBookmark={() => toggleBookmark(book.id)} onOpen={() => tab === 'audio' ? player.current?.open(book) : openBook(book)} />
              ))}
            </div>
          ) : (
            <EmptyState icon={tab === 'bookmarks' ? Bookmark : Search} title={tab === 'bookmarks' ? 'ފާހަގަކޮށްފައި ފޮތެއް ނެތް' : 'ހޯދާ ފޮތެއް ނުފެނުނު'} />
          )}

          {!loading && pages > 1 && <Pagination page={page} pages={pages} onChange={setPage} />}
        </section>
      </main>

      <MobileNav active={tab} onSelect={selectTab} />
      {selected && <Reader key={selected.id} onAudio={() => player.current?.open(selected)} book={selected} bookmarked={bookmarks.includes(selected.id)} onBookmark={() => toggleBookmark(selected.id)} onClose={() => setSelected(null)} />}
      <AudioPlayer ref={player} />
    </div>
  )
}

function Header({ ids, dark, menuOpen, onMenu, onTheme, query, setQuery }: { ids: EditionId[]; dark: boolean; menuOpen: boolean; onMenu: () => void; onTheme: () => void; query: string; setQuery: (value: string) => void }) {
  return (
    <header className="sticky top-0 z-30 border-b border-stone-200/70 bg-[#faf8f3]/90 backdrop-blur-xl dark:border-white/10 dark:bg-[#07120d]/88">
      <div className="mx-auto flex flex-wrap py-3 max-w-[1440px] items-center gap-3 px-4 sm:px-6 lg:px-10">
        <div className="flex min-w-0 items-center gap-3">
          <Image src="/makthaba-logo.png" width={52} height={52} priority alt="މަކްތަބާ އަޘަރިއްޔާ" className="size-12 rounded-2xl object-cover shadow-sm" />
          <div className="hidden min-w-0 sm:block">
            <p className="truncate text-lg font-bold">މަކްތަބާ އަޘަރިއްޔާ</p>
            <p className="truncate text-xs text-stone-500 dark:text-stone-400">ކިޔާލައްވާ • އަޑުއައްސަވާ</p>
          </div>
        </div>
        <div className="order-last w-full sm:order-none sm:mx-auto sm:max-w-xl sm:flex-1"><ReadingProgress ids={ids} /><label className="relative flex w-full items-center">
          <Search className="pointer-events-none absolute right-4 size-4 text-stone-400" />
          <input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="ފޮތެއް ހޯއްދަވާ..." className="h-11 w-full rounded-2xl border border-stone-200 bg-white/80 pr-11 pl-4 text-sm outline-none transition focus:border-emerald-600 focus:ring-4 focus:ring-emerald-600/10 dark:border-white/10 dark:bg-white/5 dark:focus:border-emerald-400" />
        </label></div>
        <a href="/privacy" aria-label="ޕްރައިވަސީ ޕޮލިސީ" title="ޕްރައިވަސީ ޕޮލިސީ" className="media-icon"><ShieldCheck className="size-5" /></a>
        <Button variant="ghost" size="icon" aria-label="ތީމް" onClick={onTheme}>{dark ? <Sun /> : <Moon />}</Button>
        <Button variant="ghost" size="icon" className="lg:hidden" aria-label="މެނޫ" onClick={onMenu}>{menuOpen ? <X /> : <Menu />}</Button>
      </div>
    </header>
  )
}

const navItems: { id: Tab; icon: typeof Home; label: string }[] = [
  { id: 'home', icon: Home, label: labels.home },
  { id: 'audio', icon: Headphones, label: labels.audio },
  { id: 'bookmarks', icon: Bookmark, label: labels.bookmarks },
  { id: 'recent', icon: Clock3, label: labels.recent },
]

function DesktopNav({ active, onSelect }: { active: Tab; onSelect: (tab: Tab) => void }) {
  return <nav className="web-glass mb-4 hidden items-center gap-2 rounded-3xl p-2 lg:flex">{navItems.map(({ id, icon: Icon, label }) => <Button key={id} variant={active === id ? 'default' : 'ghost'} onClick={() => onSelect(id)}><Icon className="size-4" />{label}</Button>)}</nav>
}

function MobileMenu({ active, onSelect }: { active: Tab; onSelect: (tab: Tab) => void }) {
  return <div className="fixed inset-x-4 top-24 z-40 grid gap-1 rounded-3xl border border-stone-200 bg-white p-3 shadow-2xl lg:hidden dark:border-white/10 dark:bg-[#102018]">{navItems.map(({ id, icon: Icon, label }) => <Button key={id} variant={active === id ? 'default' : 'ghost'} className="justify-start" onClick={() => onSelect(id)}><Icon />{label}</Button>)}</div>
}

function MobileNav({ active, onSelect }: { active: Tab; onSelect: (tab: Tab) => void }) {
  return <nav className="fixed inset-x-3 bottom-3 z-30 grid grid-cols-4 rounded-[1.7rem] border border-stone-200/70 web-glass bg-white/45 p-2 shadow-[0_14px_50px_rgba(0,0,0,.16)] backdrop-blur-xl lg:hidden dark:border-white/10 dark:bg-stone-900/45">{navItems.map(({ id, icon: Icon, label }) => <button key={id} onClick={() => onSelect(id)} aria-label={label} title={label} className={cn('grid h-12 place-items-center rounded-2xl transition-all', active === id ? 'bg-white/65 text-emerald-800 shadow-sm dark:bg-white/15 dark:text-emerald-300' : 'text-stone-500 dark:text-stone-400')}><Icon className="size-5" /></button>)}</nav>
}

function Hero({ book, onOpen }: { book: Book; onOpen: () => void }) {
  const cover = mediaURL(book.cover)
  return (
    <section className="relative overflow-hidden rounded-[2rem] bg-emerald-50 px-6 py-7 text-black dark:bg-emerald-950 dark:text-white shadow-xl sm:px-10 sm:py-9 lg:mt-7">
      {cover && <Image src={cover} alt="" fill sizes="100vw" className="object-cover opacity-20 blur-xl" unoptimized />}
      <div className="absolute inset-0 bg-gradient-to-l from-emerald-50 via-emerald-50/90 to-white/40 dark:from-emerald-950 dark:via-emerald-950/90 dark:to-emerald-900/40" />
      <div className="relative flex items-center justify-between gap-8">
        <div className="max-w-2xl">
          <span className="rounded-full bg-white/10 px-3 py-1 text-xs">ޚާއްޞަ ފޮތް</span>
          <h2 className="mt-4 text-3xl font-bold leading-tight sm:text-5xl">{book.title}</h2>
          {book.author && <p className="mt-2 text-stone-700 dark:text-emerald-100">{book.author}</p>}
          <Button className="mt-6 bg-white text-emerald-950 hover:bg-emerald-50" onClick={onOpen}><BookOpen className="size-4" />ފޮތް ހުޅުއްވާ</Button>
        </div>
        <BookCover book={book} className="hidden w-36 rotate-[-3deg] sm:block lg:w-44" priority />
      </div>
    </section>
  )
}

function CategoryRail({ categories, selected, onSelect }: { categories: Category[]; selected: number | null; onSelect: (id: number | null) => void }) {
  return (
    <div className="no-scrollbar mb-7 flex snap-x gap-2 overflow-x-auto pb-2">
      <button onClick={() => onSelect(null)} className={cn('shrink-0 snap-start rounded-full border px-5 py-2 text-sm font-semibold transition', selected === null ? 'border-emerald-800 bg-emerald-800 text-white dark:border-emerald-500 dark:bg-emerald-500 dark:text-emerald-950' : 'border-stone-200 bg-white dark:border-white/10 dark:bg-white/5')}>ހުރިހާ</button>
      {categories.map((item) => <button key={item.id} onClick={() => onSelect(item.id)} className={cn('shrink-0 snap-start rounded-full border px-5 py-2 text-sm font-semibold transition', selected === item.id ? 'border-emerald-800 bg-emerald-800 text-white dark:border-emerald-500 dark:bg-emerald-500 dark:text-emerald-950' : 'border-stone-200 bg-white dark:border-white/10 dark:bg-white/5')}>{item.name}</button>)}
    </div>
  )
}

function BookCover({ book, className, priority = false }: { book: Book; className?: string; priority?: boolean }) {
  const cover = mediaURL(book.cover)
  return (
    <div className={cn('relative aspect-[2/3] overflow-hidden rounded-r-md rounded-l-xl bg-gradient-to-br from-emerald-700 to-emerald-950 shadow-[10px_12px_24px_rgba(0,0,0,.22)] before:absolute before:inset-y-0 before:right-0 before:z-10 before:w-[5px] before:bg-white/20', className)}>
      {cover ? <Image src={cover} fill sizes="(max-width: 640px) 45vw, 220px" alt={book.title} priority={priority} unoptimized className="object-cover" /> : <div className="grid h-full place-items-center p-5 text-center text-lg font-bold text-white"><span>{book.title}</span></div>}
      <ReadBadge id={book.id} />
      <div className="pointer-events-none absolute inset-y-0 left-0 w-2 bg-gradient-to-r from-black/20 to-transparent" />
    </div>
  )
}

function BookCard({ book, bookmarked, index, onBookmark, onOpen }: { book: Book; bookmarked: boolean; index: number; onBookmark: () => void; onOpen: () => void }) {
  return (
    <article className="group min-w-0" style={{ animationDelay: `${Math.min(index * 35, 220)}ms` }}>
      <div className="relative mx-auto max-w-[220px] cursor-pointer" onClick={onOpen}>
        <BookCover book={book} />
        <button aria-label={bookmarked ? 'ފާހަގަ ނައްތާލާ' : 'ފާހަގަކުރައްވާ'} onClick={(event) => { event.stopPropagation(); onBookmark() }} className="absolute left-2 top-2 z-20 grid size-9 place-items-center rounded-full bg-black/60 text-white backdrop-blur transition hover:scale-105">{bookmarked ? <BookmarkCheck className="size-4 fill-current" /> : <Bookmark className="size-4" />}</button>
        {book.audioChapters?.length ? <span className="absolute bottom-2 right-2 z-20 grid size-9 place-items-center rounded-full bg-emerald-500 text-emerald-950 shadow"><Headphones className="size-4" /></span> : null}
      </div>
      <button className="mt-4 block w-full text-right" onClick={onOpen}>
        <h3 className="line-clamp-2 text-base font-bold leading-snug transition group-hover:text-emerald-700 dark:group-hover:text-emerald-400">{book.title}</h3>
        <p className="mt-1 truncate text-xs text-stone-500 dark:text-stone-400">{book.author || categoryOf(book)?.name || 'މަކްތަބާ އަޘަރިއްޔާ'}</p>
      </button>
    </article>
  )
}

function Pagination({ page, pages, onChange }: { page: number; pages: number; onChange: (page: number) => void }) {
  const values = Array.from({ length: pages }, (_, index) => index + 1).filter((value) => pages <= 7 || value === 1 || value === pages || Math.abs(value - page) <= 1)
  return (
    <nav dir="ltr" aria-label="Pagination" className="mt-10 flex items-center justify-center gap-2">
      <Button variant="outline" size="icon" disabled={page === 1} onClick={() => onChange(page - 1)}><ChevronLeft /></Button>
      {values.map((value, index) => <span key={value} className="contents">{index > 0 && value - values[index - 1] > 1 ? <span className="px-1 text-stone-400">…</span> : null}<Button variant={page === value ? 'default' : 'outline'} size="icon" onClick={() => onChange(value)}>{value}</Button></span>)}
      <Button variant="outline" size="icon" disabled={page === pages} onClick={() => onChange(page + 1)}><ChevronRight /></Button>
    </nav>
  )
}

function EmptyState({ icon: Icon, title, action }: { icon: typeof Search; title: string; action?: React.ReactNode }) {
  return <div className="grid min-h-72 place-items-center rounded-3xl border border-dashed border-stone-300 bg-white/40 text-center dark:border-white/15 dark:bg-white/[.02]"><div><Icon className="mx-auto mb-4 size-10 text-emerald-700 dark:text-emerald-400" /><p className="mb-5 text-lg font-semibold">{title}</p>{action}</div></div>
}

const PdfReader = dynamic(() => import('./pdf-reader'), { ssr: false, loading: () => <p className="p-8 text-center">ފޮތް ލޯޑުވަނީ…</p> })

function Reader({ book, bookmarked, onBookmark, onClose, onAudio }: { book: Book; bookmarked: boolean; onBookmark: () => void; onClose: () => void; onAudio: () => void }) {
  const pdf = mediaURL(book.pdf)
  const [source, setSource] = useState(pdf)
  const [notice, setNotice] = useState(book.showReaderNotice === true)
  const { completed, toggle } = useReading()
  useEffect(() => {
    let cancelled = false, objectURL = ''
    void cachedMedia(pdf).then(async response => {
      if (!response) return
      const blob = await response.blob()
      if (cancelled) return
      objectURL = URL.createObjectURL(blob); setSource(objectURL)
    }).catch(() => {})
    return () => { cancelled = true; if (objectURL) URL.revokeObjectURL(objectURL) }
  }, [pdf])
  useEffect(() => { const timer = setTimeout(() => setNotice(false), 30_000); return () => clearTimeout(timer) }, [])
  return (
    <div className="fixed inset-0 z-50 flex flex-col bg-[#faf8f3] pb-24 dark:bg-[#07120d]">
      <div className="flex min-h-16 flex-wrap items-center gap-2 border-b border-stone-200 bg-white/90 px-3 backdrop-blur dark:border-white/10 dark:bg-[#102018]/90 sm:px-6">
        <Button variant="ghost" size="icon" onClick={onClose} aria-label="ފަހަތަށް"><ArrowLeft /></Button>
        <div className="min-w-0 flex-1"><h2 className="truncate font-bold">{book.title}</h2><p className="truncate text-xs text-stone-500 dark:text-stone-400">{book.author}</p></div>
        <Button variant="ghost" size="icon" onClick={() => toggle(book.id)} aria-label={completed.includes(book.id) ? 'ކިޔައި ނިމިފައި' : 'ކިޔާ ނިމުނު ގޮތުގައި ފާހަގަކުރޭ'}><CheckCircle2 className={completed.includes(book.id) ? 'text-green-700 dark:text-green-400' : 'opacity-50'} /></Button>
        <Button variant="ghost" size="icon" onClick={onBookmark} aria-label="ފާހަގަ">{bookmarked ? <BookmarkCheck className="fill-current text-emerald-700 dark:text-emerald-400" /> : <Bookmark />}</Button>
        {book.audioChapters?.length ? <Button variant="ghost" size="icon" onClick={onAudio} aria-label="އަޑުއަހާ"><Headphones /></Button> : null}
        {pdf && <DownloadButton url={pdf} name={`${book.title}.pdf`} />}
      </div>
      <div className="relative flex-1 bg-stone-200 dark:bg-black/30">
        {source ? <PdfReader url={source} title={book.title} bookId={String(book.id)} /> : <div className="grid h-full place-items-center">ފައިލެއް ނެތް</div>}
        {notice && <div className="absolute inset-x-4 top-5 z-20 mx-auto max-w-xl rounded-3xl border border-white/50 bg-white/80 p-5 text-center text-black shadow-xl backdrop-blur-xl dark:bg-stone-900/80 dark:text-white" role="status"><button className="media-icon float-left" aria-label="ލައްޕާލާ" onClick={() => setNotice(false)}><X /></button><p className="max-h-52 overflow-auto leading-loose">ތަންބީހު: ބައެއް ޝަޔްޚުންގެ ފޮތްތަކާއި ޢިލްމީ މަސައްކަތްތައް މި ދާރުން ނެރުމަކީ، އެޝަޔްޚުންގެ ގޯސް ރައުޔުތަކާއި ފުރެދުންތަކަށް އެއްބަސްވުން ލާޒިމު ކަމެއް ނޫންކަމަށް އަންގާލަމެވެ. އެގޮތުން މިއިން ބައެއް ޝަޔްޚުންގެ ކިބައިން ޙާކިމިއްޔަތާއި، ޙަރަކިއްޔަތާއި، އެނޫންވެސް ފިކްރުތަކާއި ރައުޔުތަކާ މި ދާރު އެއްބަސްނުވާ ކަމަށް ފާހަގަކުރަމެވެ.</p></div>}
      </div>
    </div>
  )
}
