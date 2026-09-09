import type { Metadata, Viewport } from 'next'
import type { ReactNode } from 'react'
import './globals.css'

export const metadata: Metadata = {
  title: 'މަކްތަބާ އަޘަރިއްޔާ',
  description: 'ދިވެހި ފޮތްތަކާއި އޯޑިއޯ ފޮތްތައް ކިޔާލައްވާ، އަޑުއައްސަވާ.',
  icons: { icon: '/makthaba-logo.png', apple: '/makthaba-logo.png' },
}

export const viewport: Viewport = {
  width: 'device-width',
  initialScale: 1,
  themeColor: [
    { media: '(prefers-color-scheme: light)', color: '#faf8f3' },
    { media: '(prefers-color-scheme: dark)', color: '#08140f' },
  ],
}

export default function FrontendLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="dv" dir="rtl" suppressHydrationWarning>
      <body>{children}</body>
    </html>
  )
}
