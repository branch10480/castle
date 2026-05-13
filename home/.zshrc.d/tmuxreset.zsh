# Claude Code `teammateMode = "tmux"` が TeamCreate 時に tmux window へ
# 書き込む pane-border 系の override (分割線・タイトル表示) を消して、
# castle のグローバル設定 (off / グレー) に戻す手動エスケープハッチ。
#
# 通常は ~/.claude/settings.json の Stop / SubagentStop hook で自動発火
# するので叩く必要はないが、以下のケース用に残す:
#   - hook が発火する前に視覚的に消したい
#   - hook が何らかの理由 (jq 失敗 / 設定削除) で動いていない
#   - tmux 内で他のアプリ (例: 別エージェントツール) が同じ override を
#     残した場合のリセット
#
# 詳細: castle CLAUDE.md「Claude Code TeamCreate の tmux 残骸クリーンアップ」

tmuxreset() {
  local script="$HOME/.homesick/repos/castle/scripts/tmux-clear-pane-border-overrides.sh"
  if [[ ! -x $script ]]; then
    print -u2 "tmuxreset: スクリプトが見つからないか実行権限がありません: $script"
    return 1
  fi
  "$script" && print "tmuxreset: pane-border override を全 window から削除しました"
}
