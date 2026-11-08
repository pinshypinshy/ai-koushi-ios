import type { Bridge } from './bridge'
import { element } from './dom'

// 文中の数式は改行できない幅になると、Markdown の表示（.md）の右端からはみ出す。そうなった数式だけを、
// 横にスクロールする枠に入れる（§3.2）。表とコードブロックは自身がスクロールするため除く
export function wrapWideMath(scope: HTMLElement): void {
  for (const math of scope.querySelectorAll<HTMLElement>('.katex')) {
    if (math.closest('.katex-display, .math-scroll, table, pre')) continue
    const container = math.closest('.md')
    if (!container) continue
    const containerRect = container.getBoundingClientRect()
    // 幅が決まる前（WebView が画面に出る前）は測れない。resize で測り直す
    if (containerRect.width === 0) continue
    if (math.getBoundingClientRect().right <= containerRect.right + 0.5) continue
    const box = element('span', 'math-scroll')
    math.replaceWith(box)
    box.append(math)
  }
}

// 枠を右へ戻すスライドで、サイドバーが開かないようにする（§3.4）。
// touchcancel では解除しない。スクロールが始まると届くことがあり、スライドの途中で開いてしまうため
const SCROLL_BOX_SELECTOR = 'pre, table, .katex-display, .math-scroll'

export function listenScrollBoxTouches(bridge: Bridge<never>): void {
  document.addEventListener(
    'touchstart',
    (event) => {
      const box = event.target instanceof Element ? event.target.closest(SCROLL_BOX_SELECTOR) : null
      bridge.post({ type: 'scrollBoxTouched', canScrollBack: box !== null && box.scrollLeft > 0 })
    },
    { passive: true },
  )
  document.addEventListener(
    'touchend',
    () => {
      bridge.post({ type: 'scrollBoxTouched', canScrollBack: false })
    },
    { passive: true },
  )
}
