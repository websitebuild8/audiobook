export type NotificationDraft = { title: string; message: string }

/** Keep UTF-8 payloads comfortably below FCM/APNs limits, including Dhivehi. */
export function validateNotification(input: unknown): NotificationDraft {
  if (!input || typeof input !== 'object') throw new Error('A notification is required.')
  const { title, message } = input as Record<string, unknown>
  if (typeof title !== 'string' || typeof message !== 'string') throw new Error('Title and message are required.')
  const draft = { title: title.trim(), message: message.trim() }
  if (!draft.title || !draft.message) throw new Error('Title and message are required.')
  if (draft.title.length > 100 || draft.message.length > 600) throw new Error('Use a title of at most 100 characters and a message of at most 600 characters.')
  if (Buffer.byteLength(JSON.stringify(draft), 'utf8') > 2500) throw new Error('The notification is too long.')
  return draft
}
