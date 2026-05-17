- 日本語でフレンドリーに回答してください。（絵文字を使う）
- GitHubに対する操作は `gh` コマンドを使ってください。
- 報告は見やすくmd 形式ですること。
- serena mcpが使える場合は積極的に使用すること
- PR本文がGitHub上で崩れないように、`gh pr create` の本文は `--body-file -` + クォート付きheredoc（例: `<<'EOF'`）で渡し、シェル展開（`$`/バッククォート/`\` など）を避ける
- `--body "$(cat ... )"` のような形は、引用/エスケープの都合で意図せず崩れることがあるため避ける（本文をそのまま流し込む）
- PR本文内のコードフェンス（```）は閉じ忘れで全体が崩れやすいので、必要性が低い場合は使わない（使う場合は必ず対応する閉じを入れる）

## castle リポジトリで作業する場合の追加ルール

castle (`~/.homesick/repos/castle/`) 配下、または `~/.claude.json` / `~/.codex/auth.json` などのユーザー設定ファイルを触る場合は、以下の castle 共通ルールも適用すること。詳細は castle 側の中央索引 [`~/.homesick/repos/castle/CLAUDE.md`](../../CLAUDE.md) を参照。

### 機密情報の取り扱い（最重要）

- 生 API キーが付くファイル（`~/.claude.json` / `~/.codex/auth.json` / 各種 `.env` / `claude_desktop_config.json`）は **値を直接 `cat` / Read / `jq -r` で読まない**。`jq -r 'paths(scalars) | join(".")' <file>` でキーパスのみ抽出する
- 万一 transcript に流出したら **即座にユーザーに通知し当該キーを rotate**
- castle で commit する直前に `scripts/scan-secrets.sh --staged` を走らせる
- env-file テンプレ（`config/op/*.env`）は **`op://` URI のみ**。生キーが入った瞬間にこのファイルは secret 化する
- API キー・秘密鍵は 1Password を真実の源として、`op run` / `op-ssh-sign` 経由で実行時注入する（Phase 2-10 の運用、詳細は castle CLAUDE.md の "Secrets management" 表）

### `~/.claude.json` を編集するときの掟

- このファイルは Claude Code が動的に書き換える状態ファイル。**ファイル全体を書き換えない**（jq で `.mcpServers.<name>` のように局所更新する）
- 編集前にバックアップ: `cp ~/.claude.json{,.bak.$(date +%Y%m%d-%H%M%S)}`
- 編集後は **Claude Code を再起動**してから `claude mcp list` で反映を確認

### Secrets management の運用詳細（必要時に参照）

- 1Password CLI シェル統合・MCP API キー隠匿: [`../../docs/op-cli-setup.md`](../../docs/op-cli-setup.md)
- 仕事 Mac での差分セットアップ: [`../../docs/work-mac-setup.md`](../../docs/work-mac-setup.md)
- SSH / Git 初回セットアップ: [`../../docs/ssh-git-setup.md`](../../docs/ssh-git-setup.md)
