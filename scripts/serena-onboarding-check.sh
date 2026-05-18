#!/usr/bin/env bash
# SessionStart hook: nudge Claude to run mcp__serena__onboarding when the
# current project is a git repo, Serena MCP is registered in user scope,
# and .serena/project.yml does not yet exist.
#
# Opt-out per project: touch .serena/.no-onboarding
set -euo pipefail

main() {
  local cwd="${PWD}"

  # 1. Only act inside git working trees (skip /tmp, scratch dirs)
  git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0

  # 2. Only act if Serena MCP is registered in user-scope mcpServers
  grep -q '"serena"' "$HOME/.claude.json" 2>/dev/null || return 0

  # 3. Already onboarded - nothing to do
  [[ -f "$cwd/.serena/project.yml" ]] && return 0

  # 4. Explicit opt-out for this project
  [[ -f "$cwd/.serena/.no-onboarding" ]] && return 0

  # 5. Emit additionalContext via SessionStart JSON schema
  cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "Serena MCP の onboarding がこのプロジェクトで未実行です (.serena/project.yml が存在しません)。シンボル探索ツール (mcp__serena__find_symbol 等) を最初に使う前に mcp__serena__onboarding を実行して言語サーバー設定を生成してください。この通知を止めたい場合はプロジェクト直下に空ファイル .serena/.no-onboarding を作成すればこの hook はスキップされます。"
  }
}
EOF
}

main "$@" || true
