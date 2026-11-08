import { renderMarkdown } from './markdown'

export function element(tagName: string, className: string): HTMLElement {
  const node = document.createElement(tagName)
  node.className = className
  return node
}

/** onMathError を渡さないときは、数式のエラーを知らせない（受信の途中など、数式が閉じていないことがあるとき） */
export function markdownFragment(markdown: string, onMathError?: (message: string) => void): DocumentFragment {
  const { html, mathErrors } = renderMarkdown(markdown)
  if (onMathError) for (const message of mathErrors) onMathError(message)
  // template の中身は文書に入るまで読み込みが起きない。画像は入れる前に説明の文字へ置き換える（§3.2）
  const template = document.createElement('template')
  template.innerHTML = html
  for (const image of template.content.querySelectorAll('img')) image.replaceWith(image.alt)
  return template.content
}
