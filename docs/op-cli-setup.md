# 1Password CLI シェル統合 & MCP API キー隠匿（Phase 2 + Phase 4）

castle の secrets management は階層を切って運用している。Phase 2 が「shell から `op` を使えるようにする土台」、Phase 4 が「Claude Code MCP の API キーを `op://` 経由で隠匿する application 層」。本ドキュメントは両 Phase の **初回セットアップ手順と詳細**を集約する。CLAUDE.md 本体には「方針・要約・参照」のみ残し、本ドキュメントで実装側の手順を扱う。

関連:

- [`op-env-pattern.md`](op-env-pattern.md) — Phase 3（castle 外プロジェクトの `.env` 運用）
- [`op-touchid-investigation.md`](op-touchid-investigation.md) — tmux ペイン毎の Touch ID が発生する原因究明
- [`asc-api-key-op.md`](asc-api-key-op.md) — Phase 5（ASC API キー `.p8` の op 経由配信）

---

## Phase 2: 1Password CLI シェル統合

`home/.zshrc.d/op.zsh` に 1Password CLI (`op`) のシェル統合スクリプトを集約。`~/.zshrc.d/*.zsh(N)` ループで自動 source される（`home/.zshrc`）。

### 提供ヘルパ

- `op-status` — `op whoami` のラッパ。lock 状態なら non-zero を返してヒント文を出す
- `oprun [--env-file=<path>] -- <command...>` — `op run --env-file=<path> --no-masking -- <command>` のショートカット。env-file は省略時 `./.env.op`（Phase 3 の `.env` テンプレ運用で使う規約 → [`op-env-pattern.md`](op-env-pattern.md)）
- `op-warm-mcp` — `~/.config/op/*.env` を `op run -- bash -c '...'` で resolve し `/tmp/op-mcp-<basename>` に書き出す（mode 0600）。Ghostty 起動時に `home/.zshrc` から自動呼び出し。`~/.claude.json` の MCP `--env-file=` を `/tmp/op-mcp-...` に向け直しておけば、tmux ペイン分割時の per-pane Touch ID を回避できる（詳細: [`op-touchid-investigation.md`](op-touchid-investigation.md)、セットアップ: `scripts/setup-claude-mcp-perplexity.sh`）

### Shell Plugins（`gh`, `aws` 等）

`op plugin init <cli>` を 1 度実行すると `~/.config/op/plugins.sh` に alias が追記される。`op.zsh` はこのファイルが存在すれば source する。

```bash
# 例: gh を Personal Access Token を介さず 1Password 経由で動かす
op plugin init gh   # 対話で 1Password 内のアイテムを選ぶ
exec zsh            # plugins.sh が読まれる
which gh            # → op plugin run -- gh ... に置き換わる alias になっている
```

`op plugin init` は対話プロセスのため自動化できない。各 CLI を 1Password 化したくなったタイミングで個別に実行する。

### 設計上のポイント

- **シェル起動時に `op read` でシークレットをキャッシュしない**: 起動遅延・非対話 shell でのプロンプト・監査ログ希薄化を避けるため、必要時に `op run` / `op plugin run` で都度注入する
- **`OP_ACCOUNT` の machine-local 切り替え**: 個人 / 仕事 Mac でアカウントを変えたい場合は `~/.zshrc.local` に `export OP_ACCOUNT=<short_name>` を書く（castle 共通設定からは分離）。仕事 Mac での具体的な差分手順は [`work-mac-setup.md`](work-mac-setup.md) を参照
- **`op` 未インストール環境では早期 return**: 仕事 Mac の bootstrap 中など、op CLI が無くても zsh 起動が壊れない

### 初回セットアップ手順（新規 Mac で 1 度だけ）

1. 1Password 8 を起動 → Settings → Developer → **Integrate with 1Password CLI** を ON（Touch ID で `op` を unlock するために必須）
2. `homeshick link castle` を実行。`~/.zshrc.d` の symlink が自動で作られない場合は手動で:
   ```bash
   if [ ! -e ~/.zshrc.d ]; then
     ln -s ~/.homesick/repos/castle/home/.zshrc.d ~/.zshrc.d
   fi
   ```
3. 動作確認（新規 zsh セッション or `exec zsh` 後）:
   ```bash
   op-status                   # → my.1password.com / <email> / <user id>
   op item list --vault Private | head
   ```
4. 必要な CLI のみ Shell Plugin 化（任意）:
   ```bash
   op plugin init gh           # 対話で 1Password アイテムを選択
   exec zsh                    # plugins.sh が source される
   ```

---

## Phase 4: MCP API キーを op:// 経由で隠匿する

Claude Code の `~/.claude.json` の `mcpServers.<name>.env.<KEY>` に**生 API キーを書かない**。代わりに `op run --env-file=…` でラップして起動し、env-file は `op://` URI のみを含める。

### 構成

- `config/op/<server>.env` — op:// URI を書くテンプレ（このリポジトリで追跡）
  - 例: `config/op/perplexity.env` → `PERPLEXITY_API_KEY=op://Private/Perplexity API/credential`
  - `.gitignore` で `config/op/*` は無視され、`!config/op/*.env` のみ例外で追跡
- `~/.claude.json` の `mcpServers.<name>` を `command: "op", args: ["run", "--env-file=…", "--", <orig command>...]` に書き換える
- 1Password 側に同名のアイテムを保管（個人 Mac は Private vault、仕事 Mac は別アカウントの vault）

### 初回セットアップ手順（新キーを op 化するとき）

> ⚠️ **`~/.config/op` は `0700` 必須**。group/other に read bit があると `op` 起動時に
> `permissions are too broad. Change its permissions to 700` で拒否される。
> nix-darwin 適用済み Mac では `home.activation.fixSensitiveConfigPermissions`
> （`config/nix-darwin/home.nix`）が `darwin-rebuild switch` 毎に自動で
> 0700 に揃えるため通常は意識不要。nix-darwin 未適用 / `homeshick link` 直後に
> 手動で sign-in したい場合のみ `chmod 700 ~/.config/op` を当てること。

1. 1Password で API Credential テンプレのアイテムを作成（例: `Private/Perplexity API/credential` フィールドに値を保管）
2. `op-status` で signin 状態を確認、`op item get "Perplexity API" --vault Private --fields credential --reveal` で値が引けることを確認
3. `~/.config/op/<server>.env`（castle 経由なら `config/op/<server>.env`）の `op://` URI が 1Password 側のアイテム名・フィールド名と一致しているか確認
4. **Claude Code（および Claude Desktop）を一旦終了**してから `~/.claude.json` を **jq で部分書き換え**（既存の他キーを潰さない）。Claude Code 稼働中だと last-writer-wins の競合で編集が消える可能性があるため:
   ```bash
   jq '.mcpServers.perplexity = {
     type: "stdio",
     command: "op",
     args: [
       "run",
       "--env-file=" + (env.HOME + "/.config/op/perplexity.env"),
       "--",
       "npx", "-y", "@perplexity-ai/mcp-server"
     ]
   }' ~/.claude.json > ~/.claude.json.tmp && mv ~/.claude.json.tmp ~/.claude.json
   ```
5. **Claude Code を再起動**（既存セッションは古い設定を保持しているため）
6. 動作確認: `claude mcp list` で `perplexity ✓ Connected` が出る + Perplexity ツールが応答する

### tmux で複数ペインを使う場合の追加セットアップ (per-pane Touch ID 回避)

1Password 8 は呼び出し元の **pty (= tmux ペイン) ごとに 10 分間の transient grant** を発行するため、上記そのままだと「ペインを分割して各ペインで `claude` を起動 → ペインの数だけ Touch ID」が発生する。castle の Nix tmux は adhoc 署名で「永続認可済みアプリ」リストにも乗らない（詳細: [`op-touchid-investigation.md`](op-touchid-investigation.md)）。

**対策 (A.2 ハイブリッド)**: ghostty 起動時に `op-warm-mcp` (Phase 2 ヘルパ) で `op://` を一度 resolve → `/tmp/op-mcp-perplexity.env` に literal 保存。`~/.claude.json` の `--env-file` をそこへ向け直すと、tmux 内のすべての `op run` が 1Password 呼び出しを skip する。

`~/.claude.json` の書換えは `darwin-rebuild switch` 時に **nix-darwin の `home.activation.patchClaudeMcpPerplexity` で自動適用**される（`config/nix-darwin/home.nix`）。Claude Code CLI 起動中は `pgrep -x claude` で検出して skip + 警告するので state file の競合は回避。例外時 (`~/.claude.json` 未存在 / perplexity 未設定 / 既に正しい) は静かに skip。

手動で実行したい場合（CI / 別 OS / 確認用）は同等の jq 操作を行うスクリプトが残っている:

```bash
# Claude Code を一旦終了してから:
bash ~/.homesick/repos/castle/scripts/setup-claude-mcp-perplexity.sh
# .mcpServers.perplexity.args の --env-file を /tmp/op-mcp-perplexity.env に書き換える
# Claude Code を起動し直す
```

**Trade-off**: secret が `/tmp/op-mcp-*.env` に 0600 で session 中存在する（OS 再起動でクリア）。鍵 rotate 時は `rm /tmp/op-mcp-*.env` してから ghostty 再起動で再 warm。

### ポイント

- **Claude Code 自体は op:// を解釈しない**: `command` 階層で `op run` を噛ませることで、Claude Code には透過に見せる
- **env-file は 1 行 = 1 環境変数**: `KEY=op://...` のみ。複数 MCP サーバを共用にしたい場合でも、サーバごとにファイルを分けると依存関係を局所化できる
- **`--no-masking` は付けない**: Phase 2 の `oprun` ヘルパとは違い、MCP サーバの stdio に対して masking を切る必要は無い（むしろ stderr の意図しない出力が機密扱いになるリスクを減らす）
- **Resolved file (`/tmp/op-mcp-*.env`) も "1 行 = `KEY=literal-value`" の env-file 形式**: `op run` は op:// が無い行を素通しするので、warm 済みファイルへの再アクセスは 1Password を呼ばない（実測 0.05s, silent）
