import { validateNotification, type NotificationDraft } from './message'

export type DispatchStore = {
  claim: () => Promise<unknown | null>
  accepted: (messageId: string) => Promise<void>
  uncertain: () => Promise<void>
}
/** Claim once before any external side effect. Ambiguous sends are not retried. */
export async function dispatchNotification(store: DispatchStore, deliver: (draft: NotificationDraft) => Promise<string>) {
  const draft = await store.claim()
  if (!draft) return 'conflict' as const
  try {
    const id = await deliver(validateNotification(draft))
    await store.accepted(id)
    return 'accepted' as const
  } catch {
    await store.uncertain()
    return 'uncertain' as const
  }
}
