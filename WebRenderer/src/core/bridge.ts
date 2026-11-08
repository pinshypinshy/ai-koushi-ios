// Swift の CommonMessage と対になる

export type ErrorKind = 'script' | 'command' | 'math'

export type CommonMessage =
  | { readonly type: 'ready' }
  | { readonly type: 'scrollBoxTouched'; readonly canScrollBack: boolean }
  | { readonly type: 'error'; readonly kind: ErrorKind; readonly message: string }

/** Message はページ固有の知らせ。ほかのページの知らせは型で送れない */
export interface Bridge<Message> {
  post(message: Message | CommonMessage): void
  reportError(kind: ErrorKind, message: string): void
}

interface MessageHandler {
  postMessage(message: unknown): void
}

declare global {
  interface Window {
    webkit?: { messageHandlers?: Record<string, MessageHandler | undefined> }
  }
}

/** name は Swift の PageDefinition.name と同じにする */
export function createBridge<Message>(name: string): Bridge<Message> {
  const post = (message: Message | CommonMessage): void => {
    const handler = window.webkit?.messageHandlers?.[name]
    if (handler) {
      handler.postMessage(message)
    } else {
      console.info(message)
    }
  }
  return {
    post,
    reportError: (kind, message) => post({ type: 'error', kind, message }),
  }
}
