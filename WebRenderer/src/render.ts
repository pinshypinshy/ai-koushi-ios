import { reportError } from './bridge'
import { type Command, type Configuration, type ConversationItem, colorNames } from './commands'
import { renderMarkdown } from './markdown'

// 位置の計算の端数を吸収する分だけ余裕を持たせる。末尾を表示しているときだけ追従する（§3.2）
const END_TOLERANCE_PX = 2

// 受信中は命令が頻繁に届く。描くのは1フレームに1回にまとめる。
// 画面に出ていない間は requestAnimationFrame が止まるため、時間でも描く
const FALLBACK_FLUSH_MS = 100

export class ConversationRenderer {
  readonly #root: HTMLElement
  #queue: Command[] = []
  #scheduled = false
  #streamingNode: HTMLElement | null = null
  #streamingText: string | null = null
  #waitingText = ''
  #stuckToEnd = true

  constructor(root: HTMLElement) {
    this.#root = root
    window.addEventListener('scroll', () => {
      this.#stuckToEnd = isAtEnd()
    })
    // キーボードが出て WebView が縮んだときも、末尾を表示していたなら末尾に留める
    window.addEventListener('resize', () => {
      wrapWideMath(this.#root)
      if (this.#stuckToEnd) scrollToEnd()
    })
  }

  enqueue(commands: readonly Command[]): void {
    this.#queue.push(...commands)
    if (this.#scheduled) return
    this.#scheduled = true
    requestAnimationFrame(() => this.#flush())
    setTimeout(() => this.#flush(), FALLBACK_FLUSH_MS)
  }

  #flush(): void {
    if (!this.#scheduled) return
    this.#scheduled = false
    const commands = this.#queue
    this.#queue = []

    let forceScrollToEnd = false
    let streamingChanged = false
    // 数式の幅を測り直す範囲。文字の大きさや全体が変わったときは全体を測る
    let measuresAll = false
    const added: HTMLElement[] = []
    for (const command of commands) {
      switch (command.type) {
        case 'configure':
          this.#configure(command.configuration)
          streamingChanged = true
          measuresAll = true
          break
        case 'reset':
          this.#root.replaceChildren(...command.items.map(itemNode))
          this.#streamingNode = null
          this.#streamingText = command.streaming
          streamingChanged = true
          measuresAll = true
          forceScrollToEnd ||= command.scrollToEnd
          break
        case 'append':
          for (const item of command.items) {
            const node = itemNode(item)
            this.#root.insertBefore(node, this.#streamingNode)
            added.push(node)
          }
          forceScrollToEnd ||= command.scrollToEnd
          break
        case 'setStreaming':
          this.#streamingText = command.text
          streamingChanged = true
          break
        default:
          assertNever(command)
      }
    }
    if (streamingChanged) this.#renderStreaming()
    if (measuresAll) {
      wrapWideMath(this.#root)
    } else {
      for (const node of added) wrapWideMath(node)
      if (streamingChanged && this.#streamingNode) wrapWideMath(this.#streamingNode)
    }
    if (forceScrollToEnd || this.#stuckToEnd) scrollToEnd()
  }

  #configure(configuration: Configuration): void {
    const style = document.documentElement.style
    for (const name of colorNames) style.setProperty(`--color-${name}`, configuration.colors[name])
    style.setProperty('--font-size', `${configuration.fontSize}px`)
    this.#waitingText = configuration.waitingText
  }

  #renderStreaming(): void {
    const text = this.#streamingText
    if (text === null) {
      this.#streamingNode?.remove()
      this.#streamingNode = null
      return
    }
    if (!this.#streamingNode) {
      this.#streamingNode = element('div', 'message assistant md streaming')
      this.#root.append(this.#streamingNode)
    }
    if (text === '') {
      const waiting = element('span', 'waiting')
      waiting.textContent = this.#waitingText
      this.#streamingNode.replaceChildren(waiting)
    } else {
      // 受信の途中は数式が閉じていないことがあるため、数式のエラーは確定した発言でだけ知らせる
      this.#streamingNode.replaceChildren(markdownFragment(text, false))
    }
  }
}

function itemNode(item: ConversationItem): HTMLElement {
  switch (item.type) {
    case 'divider': {
      const node = element('div', 'divider')
      node.textContent = item.label
      node.dataset['id'] = item.id
      return node
    }
    case 'assistant': {
      const node = element('div', 'message assistant md')
      node.append(markdownFragment(item.markdown, true))
      node.dataset['id'] = item.id
      return node
    }
    case 'user': {
      const node = element('div', 'message user')
      node.textContent = item.text
      node.dataset['id'] = item.id
      return node
    }
    default:
      return assertNever(item)
  }
}

function markdownFragment(markdown: string, reportsMathErrors: boolean): DocumentFragment {
  const { html, mathErrors } = renderMarkdown(markdown)
  if (reportsMathErrors) for (const message of mathErrors) reportError('math', message)
  // template の中身は文書に入るまで読み込みが起きない。画像は入れる前に説明の文字へ置き換える（§3.2）
  const template = document.createElement('template')
  template.innerHTML = html
  for (const image of template.content.querySelectorAll('img')) image.replaceWith(image.alt)
  return template.content
}

// 文中の数式は改行できない幅になると発言の右端からはみ出す。そうなった数式だけを、
// 横にスクロールする枠に入れる（§3.2）。表とコードブロックは自身がスクロールするため除く
function wrapWideMath(scope: HTMLElement): void {
  for (const math of scope.querySelectorAll<HTMLElement>('.katex')) {
    if (math.closest('.katex-display, .math-scroll, table, pre')) continue
    const message = math.closest('.message')
    if (!message) continue
    const messageRect = message.getBoundingClientRect()
    // 幅が決まる前（WebView が画面に出る前）は測れない。resize で測り直す
    if (messageRect.width === 0) continue
    if (math.getBoundingClientRect().right <= messageRect.right + 0.5) continue
    const box = element('span', 'math-scroll')
    math.replaceWith(box)
    box.append(math)
  }
}

function element(tagName: string, className: string): HTMLElement {
  const node = document.createElement(tagName)
  node.className = className
  return node
}

function isAtEnd(): boolean {
  const scroller = document.scrollingElement ?? document.documentElement
  return scroller.scrollHeight - (scroller.scrollTop + scroller.clientHeight) <= END_TOLERANCE_PX
}

function scrollToEnd(): void {
  const scroller = document.scrollingElement ?? document.documentElement
  scroller.scrollTop = scroller.scrollHeight
}

function assertNever(value: never): never {
  throw new Error(`想定していない値：${JSON.stringify(value)}`)
}
