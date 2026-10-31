// 成果物はコミットする（CLAUDE.md「コマンド」）。同じソースから同じ成果物になるよう、
// 名前にハッシュを付けず、古いファイルを消してから書き出す
import { build } from 'esbuild'
import { copyFile, mkdir, rm } from 'node:fs/promises'

const outdir = '../AIKoushiKit/Sources/ConversationWebView/Resources'

await rm(outdir, { recursive: true, force: true })
await mkdir(outdir, { recursive: true })

await build({
  entryPoints: { conversation: 'src/main.ts', 'conversation-style': 'src/conversation.css' },
  outdir,
  bundle: true,
  minify: true,
  format: 'iife',
  target: 'safari17',
  loader: { '.woff2': 'file', '.woff': 'file', '.ttf': 'file' },
  assetNames: 'fonts/[name]',
  logLevel: 'warning',
})

await copyFile('src/index.html', `${outdir}/index.html`)
