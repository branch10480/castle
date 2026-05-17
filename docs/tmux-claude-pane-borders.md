# Claude Code TeamCreate の tmux 残骸クリーンアップ

Claude Code の `teammateMode = "tmux"`（`~/.claude/settings.json`）で TeamCreate を使うと、サブエージェント割り当て先 tmux ペインに **window-scope の override** が書き込まれる: `pane-border-status top` (タイトル表示) と `pane-active-border-style fg=colour208` (オレンジ)。TeamDelete でもメインエージェント終了でもこの override は巻き戻されず、castle グローバル設定 (`pane-border-status off` / グレー) を覆い隠したまま「分割線・タイトル・片側オレンジ境界」が居座る。

`pane-border-indicators = colour` モード（castle / tmux デフォルト）下では active-border-style 色が **境界線の半分のみ**描画されるため、「タイトル + 片側だけオレンジ」という独特の見た目になるのが特徴。

## 自動クリーンアップ

`scripts/tmux-clear-pane-border-overrides.sh` が全 window から `pane-border-status` / `pane-border-style` / `pane-active-border-style` / `pane-border-format` / `pane-border-indicators` の window-scope override を `set-option -uw` で unset し、上位（server-global = castle `home/.tmux.conf`）にフォールバックさせる。

`~/.claude/settings.json` の `hooks` で **`Stop` と `SubagentStop`** に配線され、エージェント停止イベント毎に上記スクリプトが発火する。

### マシン間同期: nix-darwin home.activation で自動 jq merge

`settings.json` は `extraKnownMarketplaces` の絶対パスや `enabledPlugins` などマシン固有値を含む machine-local ファイル（castle `.gitignore` で除外）なので丸ごと symlink できない。代わりに **`config/nix-darwin/home.nix` の `home.activation.patchClaudeHooks`** が `.hooks` キーだけを jq で部分上書きする（[Phase 4 の `patchClaudeMcpPerplexity`](op-cli-setup.md) と同じ思想）。

```bash
darwin-rebuild switch --flake ~/.config/nix-darwin
# → ~/.claude/settings.json の .hooks が castle 起源の値に揃う
# → Claude Code 再起動で反映
```

真実の源は `home.nix` の `desired=$(jq -n ...)` ブロック（hooks を増減したければここを編集）。Claude Code CLI 起動中は `pgrep -x claude` で skip + 警告を出し、settings.json の競合を防ぐ。既に同値なら no-op で再実行コストはほぼゼロ。

新規 Mac でも `homeshick link castle && darwin-rebuild switch` だけで hooks が反映されるため、手動セットアップ手順は不要。nix-darwin 未適用環境で手動同期したい場合のみ `jq` で local 編集（[Phase 4 の jq パターン](op-cli-setup.md)を参照）。

## 手動エスケープハッチ: `tmuxreset`

`home/.zshrc.d/tmuxreset.zsh` が同名 zsh 関数を提供する。hook が発火する前に視覚的に消したい時、hook が何らかの理由で動いていない時、あるいは別ツールが同じ override を残した時に叩く:

```bash
tmuxreset   # 全 window から pane-border 系 override を削除
```

## ポイント

- **`set -uw` の `-u`** が "unset" で、`-w` が window-scope を指定する。tmux のオプションは server / session / window の 3 階層で**下位がより限定的**。window-level の override を unset すれば自動的に上位 (castle グローバル) にフォールバックする
- **`pane-active-border-style` を unset し忘れない**: `pane-border-style` (非アクティブ側) と `pane-active-border-style` (アクティブ側) は別系統。前者だけ unset すると「片側オレンジ」が残る (実装時に踏んだ罠)
- **tmux 未起動環境では silent exit**: Stop hook は CI / non-tmux session でも発火し得るので、`command -v tmux` と `tmux info` の双方でガード
