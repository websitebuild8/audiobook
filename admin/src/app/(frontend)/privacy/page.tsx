import type { Metadata } from 'next'
import Link from 'next/link'
import policy from '@/content/privacy-policy.json'

export const metadata: Metadata = {
  title: 'Privacy Policy | Maktaba Athariyyah',
  description: 'How Makthaba Athariyya handles reading data, downloads, and privacy inquiries.',
}

export default function PrivacyPage() {
  return (
    <main lang="en" dir="ltr" className="min-h-dvh bg-[#faf8f3] px-5 py-12 text-stone-800 sm:py-20" style={{ fontFamily: 'system-ui, sans-serif' }}>
      <article className="mx-auto max-w-3xl">
        <Link href="/" className="text-sm font-semibold text-emerald-800 underline underline-offset-4">← Back to the library</Link>
        <header className="mb-10 mt-10 border-b border-emerald-900/15 pb-8">
          <p className="mb-3 text-sm font-semibold text-emerald-800">Maktaba Athariyyah</p>
          <h1 className="text-4xl font-bold tracking-tight sm:text-5xl">{policy.title}</h1>
          <p className="mt-4 text-stone-600">{policy.appName} · Last updated: {policy.updated}</p>
          <a href="mailto:athariyya@gmail.com" className="mt-4 inline-block text-emerald-800 underline underline-offset-4">athariyya@gmail.com</a>
        </header>
        {policy.sections.map((section) => (
          <section key={section.title} className="mb-9">
            <h2 className="mb-3 text-xl font-semibold">{section.title}</h2>
            {section.paragraphs.map((paragraph) => <p key={paragraph} className="mb-4 break-words text-base leading-8">{paragraph}</p>)}
          </section>
        ))}
      </article>
    </main>
  )
}
