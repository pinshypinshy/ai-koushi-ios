import { post, reportError } from './bridge'
import { CommandError, parseCommands } from './commands'
import { ConversationRenderer } from './render'

declare global {
  interface Window {
    conversation: { apply(json: string): void }
  }
}

window.addEventListener('error', (event) => {
  reportError('script', `${event.message}（${event.filename}:${event.lineno}:${event.colno}）`)
})
window.addEventListener('unhandledrejection', (event) => {
  reportError('script', String(event.reason))
})

const root = document.getElementById('conversation')
if (!root) throw new Error('#conversation が無い')
const renderer = new ConversationRenderer(root)

document.addEventListener('click', (event) => {
  const anchor = event.target instanceof Element ? event.target.closest('a[href]') : null
  if (!(anchor instanceof HTMLAnchorElement)) return
  event.preventDefault()
  post({ type: 'linkTapped', url: anchor.href })
})

window.conversation = {
  apply(json) {
    try {
      renderer.enqueue(parseCommands(json))
    } catch (error) {
      if (!(error instanceof CommandError || error instanceof SyntaxError)) throw error
      reportError('command', error.message)
    }
  },
}

post({ type: 'ready' })
