#!/usr/bin/env bash
# Claude Code の `teammateMode = "tmux"` が TeamCreate 時に書き込む
# pane-border 系の **window-scope override** を全 window から unset し、
# castle の `home/.tmux.conf` で定義したグローバル設定
# (pane-border-status off / fg=colour240) にフォールバックさせる。
#
# Why: Claude Code は TeamCreate でサブエージェントを tmux ペインに割り当てる
# 際、`pane-border-status top` (タイトル表示) と `pane-active-border-style`
# (アクティブペイン側のオレンジ色) などを **window 単位**で set-option する。
# `pane-border-indicators = colour` モード下では active-border-style 色が
# 「境界線の半分だけ」描画されるため、TeamDelete 後にも「タイトル + 片側
# だけオレンジの境界線」が居座る。これら window-scope override を `-uw` で
# 一括 unset し、castle グローバル (off / グレー) にフォールバックさせる。
#
# Idempotent: 既に unset 済みでもエラーにならない。tmux 未起動環境では
# silent exit するので、CI / non-tmux session の Stop hook から呼ばれても
# 副作用ゼロ。
#
# 呼び出し元:
#   - ~/.claude/settings.json の Stop / SubagentStop hook (自動)
#   - home/.zshrc.d/tmuxreset.zsh の `tmuxreset` 関数 (手動エスケープハッチ)

set -euo pipefail

# tmux 未インストール / server 未起動なら何もしない
command -v tmux >/dev/null 2>&1 || exit 0
tmux info >/dev/null 2>&1 || exit 0

# `list-windows -a` で全 session の全 window を列挙し、各 window から
# pane-border-status / -style / -format の window-scope override を unset。
# `set-option -uw` の `-u` が "unset" で、`-w` が "window-scope" を指定する。
while IFS= read -r target; do
  [[ -n "$target" ]] || continue
  tmux set-option -uw -t "$target" pane-border-status        2>/dev/null || true
  tmux set-option -uw -t "$target" pane-border-style         2>/dev/null || true
  tmux set-option -uw -t "$target" pane-active-border-style  2>/dev/null || true
  tmux set-option -uw -t "$target" pane-border-format        2>/dev/null || true
  tmux set-option -uw -t "$target" pane-border-indicators    2>/dev/null || true
done < <(tmux list-windows -a -F '#{session_name}:#{window_index}')
