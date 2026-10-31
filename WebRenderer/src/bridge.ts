// Swift の WebMessage と対になる

export type ErrorKind = 'script' | 'command' | 'math'

export type WebMessage =
  | { readonly type: 'ready' }
  | { readonly type: 'linkTapped'; readonly url: string }
  | { readonly type: 'error'; readonly kind: ErrorKind; readonly message: string }

declare global {
  interface Window {
    webkit?: { messageHandlers?: { conversation?: { postMessage(message: WebMessage): void } } }
  }
}

export function post(message: WebMessage): void {
  const handler = window.webkit?.messageHandlers?.conversation
  if (handler) {
    handler.postMessage(message)
  } else {
    console.info(message)
  }
}

export function reportError(kind: ErrorKind, message: string): void {
  post({ type: 'error', kind, message })
}
