import type { Bridge } from '../core/bridge'
import { element, markdownFragment } from '../core/dom'
import { wrapWideMath } from '../core/math'
import type { PageRenderer } from '../core/page'
import { assertNever } from '../core/validate'
import type { QuizChoice, QuizCommand, QuizContent, QuizExplanation, QuizMessage, QuizScroll } from './commands'

export class QuizRenderer implements PageRenderer<QuizCommand> {
  readonly #root: HTMLElement
  readonly #bridge: Bridge<QuizMessage>

  constructor(root: HTMLElement, bridge: Bridge<QuizMessage>) {
    this.#root = root
    this.#bridge = bridge
    window.addEventListener('resize', () => wrapWideMath(this.#root))
  }

  apply(commands: readonly QuizCommand[], themeChanged: boolean): void {
    // 毎回全体を描き直すので、まとめて届いたら最後の内容だけを描けばよい
    const last = commands.at(-1)
    if (!last) {
      if (themeChanged) wrapWideMath(this.#root)
      return
    }
    const scroller = document.scrollingElement ?? document.documentElement
    const previousTop = scroller.scrollTop
    this.#root.replaceChildren(...this.#contentNodes(last.content))
    wrapWideMath(this.#root)
    this.#scroll(last.scroll, previousTop)
  }

  #contentNodes(content: QuizContent): HTMLElement[] {
    switch (content.kind) {
      case 'question': {
        const nodes = [
          this.#markdownNode('stem md', content.stem),
          this.#choicesNode(content.choices, content.explanation !== null),
        ]
        if (content.explanation) nodes.push(this.#explanationNode(content.explanation))
        return nodes
      }
      case 'result': {
        const list = element('div', 'wrong-list')
        list.append(...content.wrongStems.map((stem) => this.#markdownNode('wrong-stem md', stem)))
        return [list]
      }
      default:
        return assertNever(content)
    }
  }

  // ブロック要素（独立した行の数式など）を含みうるため、<button> ではなく役割で示す
  #choicesNode(choices: readonly QuizChoice[], isAnswered: boolean): HTMLElement {
    const list = element('div', 'choices')
    for (const choice of choices) {
      const node = element('div', `choice ${choice.mark}`)
      node.setAttribute('role', 'button')
      node.setAttribute('aria-pressed', String(choice.mark === 'selected'))
      node.setAttribute('aria-disabled', String(isAnswered))
      node.dataset['choiceId'] = choice.id
      const label = element('span', 'choice-label')
      label.textContent = choice.label
      node.append(label, this.#markdownNode('choice-body md', choice.markdown))
      if (choice.badge !== null) {
        const badge = element('span', 'choice-badge')
        badge.textContent = choice.badge
        node.append(badge)
      }
      list.append(node)
    }
    return list
  }

  #explanationNode(explanation: QuizExplanation): HTMLElement {
    const node = element('section', 'explanation')
    const heading = element('div', 'explanation-heading')
    heading.textContent = explanation.heading
    const related = element('div', 'related')
    related.textContent = explanation.relatedSteps
    node.append(heading, this.#markdownNode('explanation-body md', explanation.markdown), related)
    return node
  }

  #markdownNode(className: string, markdown: string): HTMLElement {
    const node = element('div', className)
    node.append(markdownFragment(markdown, (message) => this.#bridge.reportError('math', message)))
    return node
  }

  #scroll(scroll: QuizScroll, previousTop: number): void {
    const scroller = document.scrollingElement ?? document.documentElement
    switch (scroll) {
      case 'top':
        scroller.scrollTop = 0
        break
      case 'explanation':
        this.#root.querySelector('.explanation')?.scrollIntoView({ block: 'start' })
        break
      case 'keep':
        scroller.scrollTop = previousTop
        break
      default:
        assertNever(scroll)
    }
  }
}

/** 選択肢の中のリンクはリンクとして扱い、選択として知らせない */
export function listenChoiceTaps(onTap: (id: string) => void): void {
  document.addEventListener('click', (event) => {
    if (!(event.target instanceof Element) || event.target.closest('a[href]')) return
    const choice = event.target.closest<HTMLElement>('[data-choice-id]')
    const id = choice?.dataset['choiceId']
    if (id !== undefined) onTap(id)
  })
}
