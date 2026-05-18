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

  # 3. Explicit opt-out for this project
  [[ -f "$cwd/.serena/.no-onboarding" ]] && return 0

  # 4. Already onboarded - still nudge to prefer Serena tools
  if [[ -f "$cwd/.serena/project.yml" ]]; then
    cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "Serena MCP がこのプロジェクトで利用可能です (onboarding 済)。コード調査・編集は以下を優先してください: シンボル定義/参照/実装の探索は mcp__serena__find_symbol / find_referencing_symbols / find_implementations、ファイル俯瞰は mcp__serena__get_symbols_overview、rename/本体書き換えは mcp__serena__rename_symbol / replace_symbol_body。grep/Read への fallback は Serena が非対応・エラー時のみ。最初の symbol 操作の前に mcp__serena__initial_instructions を 1 回読んでください。通知停止はプロジェクト直下に空ファイル .serena/.no-onboarding を作成。"
  }
}
EOF
    return 0
  fi

  # 5. Not yet onboarded - prompt onboarding flow
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
