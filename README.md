# AI講師 iOS

[AI講師](https://github.com/pinshypinshy/ai-koushi) の iOS ネイティブクライアント。
講義の受講・確認テスト・誤答の復習を、スマートフォンで短い空き時間に少しずつ進めるためのアプリ。

講義の作成（教材の貼り付け）は、大きな画面とキーボードが向いているため Web版で行う。
サーバー・API・認証は Web版の本番環境（https://ai-koushi.yuki-hiraishi.com ）をそのまま使い、
このリポジトリにはサーバーのコードを置かない。

段階的に開発している。現在の開発状況は [Docs/PROGRESS.md](Docs/PROGRESS.md) にある。

## 技術構成

| 項目 | 内容 |
|---|---|
| 言語 | Swift 6 |
| UI | SwiftUI |
| アーキテクチャ | [The Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture)（TCA）1.26.2 |
| 対応OS・端末 | iOS 17 以上、iPhone のみ、縦のみ |
| テスト | Swift Testing ＋ TCA の TestStore |

機能はローカルパッケージ `AIKoushiKit` のモジュールに分け、アプリ本体（`AIKoushi`）は組み立てるだけにしている。

```
AIKoushi/        … アプリ本体（Xcode プロジェクト）
AIKoushiKit/     … ローカルパッケージ
  Models         … API の型（Web版の shared/api.ts に対応）
  AppConfig      … アプリ全体で共有する設定値（本番の URL など）
  APIClient      … API クライアントのインターフェース
  APIClientLive  … URLSession による実装
  SharedUI       … 複数の画面で使う View 部品
  *Feature       … 画面ごとの Feature（Login・Sidebar・Course・App）
```

モジュールの依存の向きはコンパイラに守らせている。Feature とそのテストは API クライアントの実装に依存できず、
テストから本物の API を呼べない。判断の理由は [ADR 0002](Docs/ADR/0002-modularize-with-local-package.md) にある。

## 開発

必要なもの：Xcode 26.6

`AIKoushi/AIKoushi.xcodeproj` を Xcode で開いて実行する。コマンドで行う場合は、リポジトリのルートで次を実行する。

```bash
# ビルド（アプリ本体）
xcodebuild build -project AIKoushi/AIKoushi.xcodeproj -scheme AIKoushi -destination 'platform=iOS Simulator,name=iPhone 17'

# テスト（パッケージ）
cd AIKoushiKit && xcodebuild test -scheme AIKoushiKit-Package -destination 'platform=iOS Simulator,name=iPhone 17'
```

- 接続先は本番環境。ログインには、本番で発行したゲストアカウントが必要になる
- テストは API を差し替えて実行するため、通信は発生しない

## ドキュメント

| ファイル | 内容 |
|---|---|
| [Docs/REQUIREMENTS.md](Docs/REQUIREMENTS.md) | 何を作るか。範囲・画面・振る舞い・各段階で満たす条件 |
| [Docs/ADR/](Docs/ADR/) | なぜその技術・構造にしたか。アーキテクチャに関わる判断を1件1ファイルで |
| [Docs/PROGRESS.md](Docs/PROGRESS.md) | 開発状況。どの段階まで終わったか |
| [CLAUDE.md](CLAUDE.md) | 開発のルールと構成 |
