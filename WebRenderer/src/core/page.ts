// ページのひな形（ADR 0009）。入口・準備完了の通知・エラーの報告・1フレームにまとめる処理・テーマの適用をここで受け持ち、
// ページは命令の形の検査と描画だけを書く
import { type Bridge, createBridge } from './bridge'
import { listenScrollBoxTouches } from './math'
import { type Theme, applyTheme, parseTheme } from './theme'
import { CommandError, record, string } from './validate'

export interface PageRenderer<Command> {
  /** themeChanged は、文字の大きさなどが変わり、測り直しが要るとき */
  apply(commands: readonly Command[], themeChanged: boolean): void
}

export interface PageDefinition<Command, Message> {
  /** Swift の PageDefinition.name と同じにする */
  readonly name: string
  /** configure 以外の命令の形を確かめる。知らない種類なら CommandError */
  parseCommand(object: Record<string, unknown>, type: string): Command
  createRenderer(root: HTMLElement, bridge: Bridge<Message>): PageRenderer<Command>
}

declare global {
  interface Window {
    page: { apply(json: string): void }
  }
}

// 受信中は命令が頻繁に届く。描くのは1フレームに1回にまとめる。
// 画面に出ていない間は requestAnimationFrame が止まるため、時間でも描く
const FALLBACK_FLUSH_MS = 100

export function startPage<Command, Message>(page: PageDefinition<Command, Message>): void {
  const bridge = createBridge<Message>(page.name)
  window.addEventListener('error', (event) => {
    bridge.reportError('script', `${event.message}（${event.filename}:${event.lineno}:${event.colno}）`)
  })
  window.addEventListener('unhandledrejection', (event) => {
    bridge.reportError('script', String(event.reason))
  })

  const root = document.getElementById('page')
  if (!root) throw new Error('#page が無い')
  const renderer = page.createRenderer(root, bridge)
  listenScrollBoxTouches(bridge)

  let queue: Command[] = []
  let pendingTheme: Theme | null = null
  let scheduled = false

  const flush = (): void => {
    if (!scheduled) return
    scheduled = false
    const theme = pendingTheme
    pendingTheme = null
    if (theme) applyTheme(theme)
    const commands = queue
    queue = []
    renderer.apply(commands, theme !== null)
  }

  const parse = (json: string): { theme: Theme | null; commands: Command[] } => {
    const value: unknown = JSON.parse(json)
    if (!Array.isArray(value)) throw new CommandError('命令が配列ではない')
    let theme: Theme | null = null
    const commands: Command[] = []
    for (const item of value) {
      const object = record(item, '命令')
      const type = string(object, 'type')
      if (type === 'configure') {
        theme = parseTheme(object['theme'])
      } else {
        commands.push(page.parseCommand(object, type))
      }
    }
    return { theme, commands }
  }

  window.page = {
    apply(json) {
      try {
        const { theme, commands } = parse(json)
        if (theme) pendingTheme = theme
        queue.push(...commands)
      } catch (error) {
        if (!(error instanceof CommandError || error instanceof SyntaxError)) throw error
        bridge.reportError('command', error.message)
        return
      }
      if (scheduled) return
      scheduled = true
      requestAnimationFrame(flush)
      setTimeout(flush, FALLBACK_FLUSH_MS)
    },
  }

  bridge.post({ type: 'ready' })
}
