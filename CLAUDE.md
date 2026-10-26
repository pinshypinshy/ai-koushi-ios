# AI講師 iOS

AI講師（Web版）の iOS ネイティブクライアント。講義の受講・確認テスト・誤答の復習を
スマートフォンで行うためのアプリ。サーバーと API は Web版のものをそのまま使い、
このリポジトリにはサーバーのコードを置かない。

**作るものは [Docs/REQUIREMENTS.md](Docs/REQUIREMENTS.md) に書かれている。** 実装で迷ったら推測せず
そちらを読み、書かれていなければユーザーに確認する。

---

## ドキュメント

| ファイル               | 役割                                                                                                       | 更新するとき                       |
| ---------------------- | ---------------------------------------------------------------------------------------------------------- | ---------------------------------- |
| `CLAUDE.md`            | 作業のルールと構成                                                                                         | ルールや構成が変わったとき         |
| `Docs/REQUIREMENTS.md` | **何を作るか**。範囲・画面・振る舞い・各段階で満たす条件                                                   | 要件・仕様が決まった／変わったとき |
| `Docs/ADR/NNNN-*.md`   | **なぜその技術・構造にしたか**。アーキテクチャに関わる判断を1件1ファイルで                                 | 該当する判断をユーザーが下したとき |
| `README.md`            | リポジトリの入口。概要・画面・技術スタック・**開発状況（どの段階まで終わったか）**・各ドキュメントへの案内 | 段階の区切り                       |

- 今どの段階を開発しているかは、`README.md` の開発状況を見る

### 要件と ADR の使い分け

- `Docs/REQUIREMENTS.md` には**現在の正しい仕様だけ**を書く。変更の経緯は書かない
- 選ばなかった案やトレードオフを残す必要がある判断は `Docs/ADR/` に書く
- 例：ユーザーが仕様を変えた → `Docs/REQUIREMENTS.md` を書き換える。技術選定に関わるなら ADR も追加する

### ADR の書き方

- 判断を下すのはユーザー。あなたは、ユーザーが決めた内容をもとに文章を書く
- **ユーザーが決めていない判断・理由・対案を ADR に書き足さない。** 必要だと思ったら提案する
- 書式：`# タイトル` → `## ステータス`（提案／承認／廃止）→ `## コンテキスト` →
  `## 決定` → `## 検討した他の案` → `## 結果（受け入れたコストを含む）`
- 番号は連番（`0001-` から）。承認済みの ADR は書き換えず、変えるときは新しい ADR で置き換える

---

## API とサーバー

- **API の契約の正は、Web版リポジトリの `shared/api.ts`。** Swift の型はこれに合わせる。
  存在しないエンドポイントやフィールドを推測で作らない
- 振る舞いが型だけで分からないとき（エラーの種類、ステータスコードなど）は、Web版の
  `server/src/` を読んで確かめる
- Web版リポジトリ：`https://github.com/pinshypinshy/ai-koushi`（ローカルの場所：このリポジトリと同じ階層の `../ai-koushi`）
- **Web版リポジトリのコードは変更しない。** サーバー側の変更が必要だと判断したら、作業を止めて
  ユーザーに提案する
- 認証はゲストログイン（`POST /auth/guest`）で発行される Cookie（`ak_session`）を使う。
  Cookie は `URLSession` に保存・送信させ、自前で読み書きしない。ただし、ログアウト時の削除（§4.5）は除く
- 受講の応答（講義本文・質問応答）は NDJSON で届く。1行は `delta`／`done`／`error` のいずれか
  （`shared/api.ts` の `LectureStreamLine`）

---

## 構成

機能はローカルパッケージ `AIKoushiKit` のモジュールに分け、アプリ本体は組み立てるだけにする
（`Docs/ADR/0002-modularize-with-local-package.md`）。

```
AIKoushi/                    … アプリ本体（Xcode プロジェクト）。AppFeature と APIClientLive を組み立てるだけ
AIKoushiKit/                 … ローカルパッケージ
├── Package.swift
├── Sources/
│   ├── Models/              … API の型（shared/api.ts に対応）。何にも依存しない
│   ├── APIClient/           … API クライアントのインターフェース（Dependency）
│   ├── APIClientLive/       … URLSession による実装。アプリ本体と自身のテストだけが import する
│   ├── SharedUI/            … 複数の Feature で使う View 部品
│   ├── <Name>Feature/       … 画面ごとの Feature（Reducer と View を同じモジュールに置く）
│   └── AppFeature/          … ルート。起動・セッション切れ・画面の切り替え
└── Tests/
    └── <Name>FeatureTests/  … Feature ごとのテスト
```

- 依存の向き：`Models ← APIClient ← 各 Feature ← AppFeature ← アプリ本体 → APIClientLive`
- Feature と Feature のテストは `APIClientLive` に依存させない（本物の API を呼べない構造にするため）
- `APIClientLive` のテストは、`URLProtocol` で応答を差し替えて書く（本物の API は呼ばない）
- Feature 同士は直接依存させない。組み合わせるのは `AppFeature`
- 1つの Feature は「State・Action・Reducer」と「View」を持つ
- モジュールの追加・依存の変更は `Package.swift` で行い、上の依存の向きを崩す変更はユーザーに確認する

---

## 技術スタックと設定

| 項目                    | 値                                                             |
| ----------------------- | -------------------------------------------------------------- |
| 言語                    | Swift 6（言語モード）。ツールチェーンは Xcode 26.6 の Swift 6.3 |
| UI                      | SwiftUI                                                        |
| アーキテクチャ          | The Composable Architecture（TCA）1.26.2（Exact で固定）      |
| 最低対応OS              | iOS 17（iPhone のみ・縦のみ）                                  |
| テスト                  | Swift Testing ＋ TCA の TestStore                              |
| Default Actor Isolation | nonisolated                                                    |
| Approachable Concurrency | 使わない（アプリ本体を OFF にし、パッケージの標準に揃える。実行時の動きが変わる設定のため） |
| MemberImportVisibility  | アプリ本体・パッケージとも使う（パッケージは `Package.swift` の末尾で全ターゲットに設定） |

- TCA のバージョンは固定する。上げるときはユーザーに確認する
- 外部ライブラリは TCA 以外に追加しない。必要だと思ったら提案する

---

## コマンド

リポジトリのルートで実行する。シミュレータ名は手元にあるものに読み替えてよい。

| 目的   | コマンド |
| ------ | -------- |
| ビルド（アプリ本体） | `xcodebuild build -project AIKoushi/AIKoushi.xcodeproj -scheme AIKoushi -destination 'platform=iOS Simulator,name=iPhone 17'` |
| テスト（パッケージ） | `cd AIKoushiKit && xcodebuild test -scheme AIKoushiKit-Package -destination 'platform=iOS Simulator,name=iPhone 17'` |

- テストはすべてパッケージ側にある。アプリ本体にテストのターゲットは無い

---

## 約束事

### TCA

- State を変えるのは Reducer だけ。View や Dependency の中で状態を変えない
- 通信などの副作用は Effect の中に閉じる。Effect からは Action を送り返すだけ
- 外部とのやり取り（API、時刻、乱数など）は必ず Dependency を通す。テストで差し替えるため
- 途中でキャンセルされうる Effect（受信中の講義など）には、キャンセル用の ID を付ける
- Action に `Result` を使わず、成功と失敗を別の case にする（`Result` の case をたどる key path がコンパイラをクラッシュさせるため。Swift 6.3.3・swift-case-paths 1.10.0 で確認）
- Feature を追加・変更したら、`REQUIREMENTS.md` に書かれた振る舞いを TestStore のテストで確かめる

### 範囲

- `REQUIREMENTS.md` に無い機能・画面・振る舞いを足さない。必要だと思ったら提案する
- 今の段階より先の段階の機能を、先回りして作らない

### コード

- コメントは日本語で書く。「何をしているか」ではなく「なぜそうしたか」を書き、根拠となる
  `REQUIREMENTS.md` の節番号を添える（例：`§5.2`）
- CLAUDE.md・ADR・REQUIREMENTS.md に書いてあることをコメントで繰り返さない。必要なら参照先（節番号や ADR の番号）だけを書く
- Swift ファイルの先頭には Xcode 形式のヘッダー（ファイル名・`AIKoushiKit`・`Created by 平石悠生 on YYYY/MM/DD.`）を書く
- ファイル名は、そのファイルの主たる型の名前にする（補助の型を同じファイルに置いてもよい）
- インデントは4スペース（Xcode の既定）
- 色は SharedUI の `AppColor` を通して使う。View に色を直接書かない（配色を1か所で変えられるようにするため）
- 強制アンラップ（`!`）と `try!` は使わない。使う必要があるときは理由をコメントに書く
- エラーを握りつぶさない（空の `catch` を書かない）

### 秘密情報

- ゲストのパスワード、個人のアカウント情報をコード・テスト・ドキュメントに書かない
- テストは本物の API を呼ばない（Dependency を差し替える）

---

## 進め方

1. 作業を始める前に、`REQUIREMENTS.md` のどの節を実装するかを示す
2. 要件が曖昧なら、実装する前に質問する。推測で埋めない
3. 実装し、テストを実行して結果を報告する
4. ユーザーのレビューを待つ。指摘を受けたら、正しいかを検証してから対応する（誤りだと判断したら根拠を示して反論する）
