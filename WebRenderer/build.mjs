// 同じソースから同じ成果物になるよう、名前にハッシュを付けず、古いファイルを消してから書き出す
import { build } from 'esbuild'
import { copyFile, mkdir, rm } from 'node:fs/promises'

// バンドルの直下に Resources という名前のフォルダがあると、codesign がバンドルの形式を認識できずに失敗するため、1段深くする
const outdir = '../AIKoushiKit/Sources/MarkdownWebView/Resources/WebRenderer'

await rm(outdir, { recursive: true, force: true })
await mkdir(outdir, { recursive: true })

// ページごとに、<名前>.html・<名前>.js・<名前>.css を書き出す（ADR 0009）。名前は Swift の PageDefinition.name と同じにする
const pages = ['conversation', 'quiz']

await build({
  entryPoints: pages.flatMap((page) => [
    { in: `src/${page}/main.ts`, out: page },
    { in: `src/${page}/style.css`, out: page },
  ]),
  outdir,
  bundle: true,
  minify: true,
  format: 'iife',
  target: 'safari17',
  loader: { '.woff2': 'file', '.woff': 'file', '.ttf': 'file' },
  assetNames: 'fonts/[name]',
  logLevel: 'warning',
})

for (const page of pages) {
  await copyFile(`src/${page}/${page}.html`, `${outdir}/${page}.html`)
}
