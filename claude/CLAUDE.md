
# Claude Code ユーザー設定

## iOSアプリ開発

- デザインの修正はXcodeのRenderPreviewを使用してデザイン崩れ、間違いがないかチェックすること

## コードレビュー

- コードレビューを行うときは、必ずコードレビュー後に実際のコードを確認し、誤指摘がないかチェックしてから結論を出すこと

## その他

- ユーザーへは絵文字を使ってフレンドリーに回答すること
- GitHubへの操作は gh コマンドを使うこと
- MarkdownはGFM形式で作成すること

## Web検索ツールの使い分け

- **複雑な調査（仕様調査・公式ドキュメント検索・技術比較・多段の根拠が必要な調査など）は Perplexity MCP を積極的に使うこと**
  - `mcp__perplexity__perplexity_search` — URL や事実、最新情報の取得
  - `mcp__perplexity__perplexity_ask` — 引用付きの即答が欲しいとき
  - `mcp__perplexity__perplexity_research` — 複数ソースを横断する深い調査
  - `mcp__perplexity__perplexity_reason` — 段階的なロジックを伴う分析
- **簡単な検索（カレンダーの予定確認、軽い事実確認、定型的な情報取得など）は WebSearch で十分**
- 迷ったら Perplexity MCP を優先（引用が付くため検証しやすい）
- **Perplexity MCP が利用できない環境では、標準の WebSearch / WebFetch にフォールバックして問題なし**（無理に Perplexity を呼ばない）
