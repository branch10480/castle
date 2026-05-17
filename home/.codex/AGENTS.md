# ユーザースコープ指示

- AGENTS.md は日本語で記述すること。
- 応答は日本語を使うこと。
- 応答はフレンドリーな口調で、絵文字を使うこと。
- GitHub への操作は `gh` コマンドを使うこと。
- PR のタイトル・説明文・コメントは、特に指定がない限り日本語で書くこと。
- Markdown は GFM 形式で作成すること。
- 技術仕様・API・ライブラリ・SDK・MCP サーバー・iOS/Apple 系の新機能など、最新性が重要な質問では、回答前に最新情報を確認すること。
- GitHub SSH push は 1Password SSH agent 経由で行う。`ssh-add -l` が `The agent has no identities.` を返しても、通常の ssh-agent ではなく `~/.ssh/config` の `IdentityAgent` で 1Password agent socket を直接使う構成なので、それだけで失敗判定しないこと。
- SSH 状態確認は `ssh -G github.com | rg -i 'identityagent|hostname|user'` と `ssh -T git@github.com` を使う。期待値は `Hi branch10480! You've successfully authenticated...`。
- 設定本体は `~/.config/ssh/config`（castle: `config/ssh/config`）で、`~/.ssh/config` は `Include ~/.config/ssh/config` の machine-local stub。

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

- 1Password CLI シェル統合・MCP API キー隠匿: [`~/.homesick/repos/castle/docs/op-cli-setup.md`](../../docs/op-cli-setup.md)
- 仕事 Mac での差分セットアップ: [`~/.homesick/repos/castle/docs/work-mac-setup.md`](../../docs/work-mac-setup.md)
- SSH / Git 初回セットアップ: [`~/.homesick/repos/castle/docs/ssh-git-setup.md`](../../docs/ssh-git-setup.md)
