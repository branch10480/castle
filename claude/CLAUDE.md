
# Claude Code ユーザー設定

## iOSアプリ開発

- デザインの修正はXcodeのRenderPreviewを使用してデザイン崩れ、間違いがないかチェックすること

## コードレビュー

- コードレビューを行うときは、必ずコードレビュー後に実際のコードを確認し、誤指摘がないかチェックしてから結論を出すこと

## その他

- ユーザーへは絵文字を使ってフレンドリーに回答すること
- GitHubへの操作は gh コマンドを使うこと
- MarkdownはGFM形式で作成すること

## 技術仕様の最新性確認（最重要）

- **技術仕様・API・ライブラリ・SDK・MCPサーバー・iOS/Apple系の新機能などについて問われたら、カットオフ知識で答える前に必ず `latest-spec-research` skill で最新情報を確認すること**
  - 特に「最新」「2026年」「今は」「現在は」「もう対応してる？」「カットオフ後」のフレーズが質問にあるとき
  - 「〜は存在しない」「〜は提供されていない」と**否定の断言をしようとしたとき**は最も危険なので必ず確認
  - バージョン番号や日付に依存する判断をする前
- カットオフ知識のみで回答することは**仕様に関する誤情報を流すリスクが高い**ため、迷ったら必ず調査する

## Web検索ツールの使い分け

- **複雑な調査（仕様調査・公式ドキュメント検索・技術比較・多段の根拠が必要な調査など）は Perplexity MCP を積極的に使うこと**
  - `mcp__perplexity__perplexity_search` — URL や事実、最新情報の取得
  - `mcp__perplexity__perplexity_ask` — 引用付きの即答が欲しいとき
  - `mcp__perplexity__perplexity_research` — 複数ソースを横断する深い調査
  - `mcp__perplexity__perplexity_reason` — 段階的なロジックを伴う分析
- **簡単な検索（カレンダーの予定確認、軽い事実確認、定型的な情報取得など）は WebSearch で十分**
- 迷ったら Perplexity MCP を優先（引用が付くため検証しやすい）
- **Perplexity MCP が利用できない環境では、標準の WebSearch / WebFetch にフォールバックして問題なし**（無理に Perplexity を呼ばない）

## シンボル調査ツール

- **Serena MCP が有効なプロジェクトでは、シンボル単位の調査は grep より Serena MCP を優先する**
  - 定義位置 / 参照箇所 / 実装一覧 / ファイル俯瞰 → `mcp__serena__find_symbol` / `find_referencing_symbols` / `find_implementations` / `get_symbols_overview`
  - rename / 本体書き換え → `mcp__serena__rename_symbol` / `replace_symbol_body`
  - `find_referencing_symbols` / `find_implementations` は `relative_path`（ファイル）が必須。未知なら先に `find_symbol`（`name_path_pattern`）で定義位置を特定する 2 段手順
- **`mcp__serena__*` が利用可能ツール一覧に出ていない / エラーを返す場合は迷わず grep に fallback**（Serena 非対応言語、language server 起動失敗、onboarding 未完了で `onboarding` を踏んでも復旧しない場合など）
- **grep が向く場面**: 文字列リテラル / コメント / 設定ファイル / 曖昧な部分一致検索
- 大規模 codebase では同名シンボルが grep で数千ヒットして使えなくなる。LSP ベースの Serena MCP が精度面で有利（Anthropic 2026-05-14 ブログ "How Claude Code works in large codebases"）
