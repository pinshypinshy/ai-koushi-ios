import type { Bridge } from '../core/bridge'
import { element, markdownFragment } from '../core/dom'
import { wrapWideMath } from '../core/math'
import type { PageRenderer } from '../core/page'
import { assertNever } from '../core/validate'
import type { ConversationCommand, ConversationItem, ConversationMessage } from './commands'

// 位置の計算の端数を吸収する分だけ余裕を持たせる。末尾を表示しているときだけ追従する（§3.2）
const END_TOLERANCE_PX = 2

export class ConversationRenderer implements PageRenderer<ConversationCommand> {
  readonly #root: HTMLElement
  readonly #bridge: Bridge<ConversationMessage>
  #streamingNode: HTMLElement | null = null
  #streamingText: string | null = null
  #waitingText = ''
  #stuckToEnd = true

  constructor(root: HTMLElement, bridge: Bridge<ConversationMessage>) {
    this.#root = root
    this.#bridge = bridge
    window.addEventListener('scroll', () => {
      this.#stuckToEnd = isAtEnd()
    })
    // キーボードが出て WebView が縮んだときも、末尾を表示していたなら末尾に留める
    window.addEventListener('resize', () => {
      wrapWideMath(this.#root)
      if (this.#stuckToEnd) scrollToEnd()
    })
  }

  apply(commands: readonly ConversationCommand[], themeChanged: boolean): void {
    let forceScrollToEnd = false
    let streamingChanged = false
    let measuresAll = themeChanged
    const added: HTMLElement[] = []
    for (const command of commands) {
      switch (command.type) {
        case 'reset':
          this.#root.replaceChildren(...command.items.map((item) => this.#itemNode(item)))
          this.#streamingNode = null
          this.#streamingText = command.streaming
          this.#waitingText = command.waitingText
          streamingChanged = true
          measuresAll = true
          forceScrollToEnd ||= command.scrollToEnd
          break
        case 'append':
          for (const item of command.items) {
            const node = this.#itemNode(item)
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
      this.#streamingNode.replaceChildren(markdownFragment(text))
    }
  }

  #itemNode(item: ConversationItem): HTMLElement {
    switch (item.type) {
      case 'divider': {
        const node = element('div', 'divider')
        node.textContent = item.label
        node.dataset['id'] = item.id
        return node
      }
      case 'assistant': {
        const node = element('div', 'message assistant md')
        node.append(markdownFragment(item.markdown, (message) => this.#bridge.reportError('math', message)))
        node.dataset['id'] = item.id
        return node
      }
      case 'user': {
        const node = element('div', 'message user')
        node.textContent = item.text
        node.dataset['id'] = item.id
        return node
      }
      case 'notice': {
        const node = element('div', 'notice')
        node.textContent = item.text
        node.dataset['id'] = item.id
        return node
      }
      default:
        return assertNever(item)
    }
  }
}

function isAtEnd(): boolean {
  const scroller = document.scrollingElement ?? document.documentElement
  return scroller.scrollHeight - (scroller.scrollTop + scroller.clientHeight) <= END_TOLERANCE_PX
}

function scrollToEnd(): void {
  const scroller = document.scrollingElement ?? document.documentElement
  scroller.scrollTop = scroller.scrollHeight
}
