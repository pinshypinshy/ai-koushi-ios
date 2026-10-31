// Web版の app/src/components/Markdown.tsx と同じ処理と設定にする（ADR 0003）。
// react-markdown は内部で次の unified の並びを使っている。React は描画にしか使われていないため持ち込まない
import rehypeKatex from 'rehype-katex'
import rehypeStringify from 'rehype-stringify'
import remarkCjkFriendly from 'remark-cjk-friendly'
import remarkGfm from 'remark-gfm'
import remarkMath from 'remark-math'
import remarkParse from 'remark-parse'
import remarkRehype from 'remark-rehype'
import { unified } from 'unified'

// 生の HTML は残したうえで rehype-stringify に文字として書き出させる。
// react-markdown も生の HTML を文字に置き換えて表示しており、それと同じ見え方にするため。
// errorColor は Web版に無い指定。KaTeX はエラーの色を style 属性に書くため、配色を CSS の変数で渡す
const processor = unified()
  .use(remarkParse)
  .use(remarkGfm)
  .use(remarkMath)
  .use(remarkCjkFriendly)
  .use(remarkRehype, { allowDangerousHtml: true })
  .use(rehypeKatex, { macros: { '\\frac': '\\dfrac' }, errorColor: 'var(--color-error)' })
  .use(rehypeStringify)
  .freeze()

export interface RenderedMarkdown {
  readonly html: string
  readonly mathErrors: readonly string[]
}

export function renderMarkdown(markdown: string): RenderedMarkdown {
  const file = processor.processSync(markdown)
  const mathErrors = file.messages
    .filter((message) => message.source === 'rehype-katex')
    .map((message) => `${message.reason}：${String(message.cause)}`)
  return { html: String(file), mathErrors }
}
