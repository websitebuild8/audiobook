'use client'
import { useDocumentInfo, useFormModified } from '@payloadcms/ui'
import { useState } from 'react'

export function SendNotification() {
  const { id } = useDocumentInfo()
  const modified = useFormModified()
  const [busy, setBusy] = useState(false)
  const [result, setResult] = useState('')
  async function send() {
    if (!id || modified || busy) return
    setBusy(true); setResult('')
    try {
      const saved = await fetch(`/api/notifications/${id}`, { credentials: 'same-origin' })
      if (!saved.ok) throw new Error('Unable to load the saved draft.')
      const draft = await saved.json()
      if (draft.status !== 'draft') throw new Error('This notification has already been submitted. Refresh to see its status.')
      if (!confirm(`${draft.title}\n\n${draft.message}\n\nSend this message to ALL opted-in readers? This cannot be recalled.`)) return
      const response = await fetch(`/api/notifications/${id}/send`, { method: 'POST', credentials: 'same-origin' })
      const data = await response.json()
      if (!response.ok) throw new Error(data.error || 'Unable to send.')
      setResult('Accepted by Firebase. Refresh this page to see the send history.')
    } catch (error) { setResult(error instanceof Error ? error.message : 'Unable to send.') }
    finally { setBusy(false) }
  }
  return <div dir="ltr" style={{ padding: '16px 0' }}><p>Save your draft before sending. Recipients must have allowed notifications.</p><button type="button" disabled={!id || modified || busy} onClick={() => void send()} style={{ padding: '12px 20px', cursor: 'pointer' }}>{busy ? 'Sending…' : 'Preview and send notification'}</button>{result && <p role="status">{result}</p>}</div>
}
