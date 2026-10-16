# ローカルパッケージでモジュールを分割する

## ステータス

提案

## コンテキスト

- このアプリのコードは、大部分を AI が書く
- 依存の向き（Models が上の層に依存しない、Feature 同士が互いの内部に触れない、テストが本物の API を
  呼ばない）を `CLAUDE.md` の約束だけで守らせると、守られなかったときにレビューまで気付けない

## 決定

- 機能をローカルパッケージ `AIKoushiKit` のモジュールに分け、アプリ本体は組み立てるだけにする
- モジュールと依存の向きは次のとおり

  ```
  Models ← APIClient ← 各 Feature ← AppFeature ← アプリ本体 → APIClientLive
  ```

- API クライアントはインターフェース（`APIClient`）と URLSession による実装（`APIClientLive`）に分け、
  `APIClientLive` に依存するのはアプリ本体と `APIClientLive` 自身のテストだけにする
- `APIClientLive` のテストは `URLProtocol` で応答を差し替えて書き、本物の API は呼ばない。
  ステータスコードからエラーの種類への振り分け（`Docs/REQUIREMENTS.md` §4.2・§4.4）を、本番で再現せずに確かめるため

## 検討した他の案

### 1つのターゲットの中をフォルダで分ける

- 利点：`Package.swift` の管理と、モジュールの外へ出す型への `public` の付与が要らない
- 採らなかった理由：
  - `Package.swift` と `public` を書くのは主に AI なので、その手間は大きな費用にならない
  - 依存の向きをコンパイラに守らせられない。モジュールに分ければ、誤った依存を書いた時点でビルドが通らず、
    間違った実装に気付きやすい

## 結果（受け入れたコストを含む）

- 依存の向きの誤りがビルドエラーとして検出される。Feature と Feature のテストは `APIClientLive` を
  import できないため、Feature のテストから本物の API は呼べない
- `public` の初期化子や `Package.swift` の分だけ差分が増え、レビューする量が増える
- Feature の中で `URLSession` を直接使うことは防げない（Foundation から使えるため）。ここはレビューで確かめる
- 境界の引き方を誤ると、守らせたい規則が守られない、または定型のコードが増える
