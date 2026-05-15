---
name: latest-spec-research
description: 技術仕様・API・ライブラリ・SDK・MCPサーバー・iOSの新機能・Swift/SwiftUIの新APIなどの最新状況を調べる。「最新」「2026年」「今の仕様」「現在は」「もう対応してる？」「カットオフ後」と感じる質問には**必ず**起動する。Claudeが記憶ベースで答えそうになる前に自動起動するのが目的。`/latest-spec-research <調査対象>` で明示起動も可能。「最新仕様を調べて」「今どうなってる？」「最新情報で」と言ったときにも使う。
---

# 最新仕様調査スキル

## 目的

**Claude のカットオフ知識に頼らず、最新情報を確認したうえで結論を出す**ためのスキル。記憶ベースの古い情報で誤った判断をする失敗を防ぐ。

## いつ起動するか

以下のいずれかに該当したら起動する。明示的にユーザーから呼ばれなくても、Claude が自分から起動して良い。

### 自動起動トリガー

- 「最新」「2026年」「現在は」「今の仕様」「今もそう？」「もう対応してる？」「カットオフ後」「最近どう？」のフレーズ
- 技術仕様・API・SDK・ライブラリ・MCPサーバー・公式ツール について断言しそうになった瞬間
- バージョン番号や日付に依存する判断をしようとしたとき
- 「〜は存在しない」「〜は提供されていない」と否定の断言をしようとしたとき（最も危険）

### 起動しないでよい場合

- ユーザーが「カットオフ知識でいい」「ざっくりでいい」と明示した
- 普遍的な原理（プログラミング概念、数学、物理）
- ユーザーのコードベース内の事実確認（これは Read / Grep でやる）

## 調査手順

### Step 1: ツール選択

**優先順位**:
1. `mcp__perplexity__perplexity_research` — 複数ソース横断・引用付き（複雑な調査）
2. `mcp__perplexity__perplexity_ask` — 引用付きの即答（単発の事実確認）
3. `mcp__perplexity__perplexity_search` — URL や事実取得
4. `WebSearch` — Perplexity が使えない / 単純検索で十分なとき
5. `WebFetch` — 特定 URL の詳細取得（公式 docs、GitHub Issue など）

**判断**: 迷ったら Perplexity を選ぶ。引用が付くため検証しやすい。

### Step 2: 検索クエリ設計

- **必ず現在の年を含める**（例: `2026`）
- 公式名称を正確に書く（`Firebase Crashlytics MCP server` など）
- 「2026」「latest」「current」を含めて古い情報を弾く

**良いクエリ例**:
- `"Firebase Crashlytics MCP server" iOS support 2026`
- `Swift Concurrency strict mode latest 2026`
- `XcodeBuildMCP commands list current`

**悪いクエリ例**:
- `Firebase Crashlytics` （広すぎ、古い情報混入）
- `iOS new API` （主語不足）

### Step 3: 一次情報を確認

検索結果から以下を優先して開く:
1. **公式ドキュメント**（`firebase.google.com/docs/`, `developer.apple.com/documentation/` 等）
2. **公式ブログ**（リリース告知）
3. **公式 GitHub リポジトリの Issue / Discussion**（既知バグ・実装状況）
4. 信頼できる技術ブログ・stackoverflow（補助情報）

**避けるもの**:
- 個人ブログの2-3年前の記事
- まとめサイトの古い情報
- アフィリエイトサイト

### Step 4: 制約事項を必ず確認

公式ドキュメントを鵜呑みにせず、以下を必ず確認する：

| 確認項目 | 確認手段 |
|---|---|
| **iOS/Android/Web 等のプラットフォーム別対応状況** | GitHub Issue で「No XXX for iOS」等を検索 |
| **既知バグ・Experimental状態** | GitHub Issue の open 状況 |
| **認証方式・権限要件** | ドキュメントの Authentication セクション |
| **無料/有料、課金条件** | Pricing ページ |
| **最終更新日** | ドキュメントの更新日付 |

### Step 5: 出力フォーマット

ユーザーへの回答には**必ず以下を含める**：

```markdown
## 結論
（1-2行で最新の事実）

## 詳細
（表や箇条書きで整理）

## 制約・既知の問題
（Experimentalか？iOS制約は？認証方式は？）

## Sources
- [Title](URL)  ← 公式優先
- [Title](URL)
```

**Sources は必須**。引用がない情報は信用してはいけない。

## アンチパターン

以下は絶対にやらない：

- ❌ 「私の記憶では…」で断言する
- ❌ 「〜は存在しないはず」を検索せずに言う
- ❌ 1つのソースだけで判断する
- ❌ 古い情報（2-3年前）を最新として扱う
- ❌ Sources を省略する

## ユーザー教育的役割

このスキルを起動したら、回答の冒頭で**「最新情報を確認しました」と明示する**。
ユーザーが「ちゃんと調べてくれたのか」を判別できるようにする。

例:
> 🔍 latest-spec-research を起動して最新情報を確認しました。
>
> ## 結論
> Firebase Crashlytics MCP server は 2025年11月に公式リリース...

## 関連

- グローバル設定: `~/.claude/CLAUDE.md` の「Web検索ツールの使い分け」セクション
- Perplexity MCP が利用不可な環境では WebSearch / WebFetch にフォールバック
