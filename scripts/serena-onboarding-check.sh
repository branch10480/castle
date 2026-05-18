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

  # 4. worktree なら main の .serena/ を cp で複製して onboarding 済として扱う
  #    cp 方式: 大規模リファクタで構造が乖離しても LSP cache が main と独立し、
  #    stale な symbol index による誤参照を防ぐ。
  local copied_from_main=0
  local git_common git_dir main_root
  git_common=$(git -C "$cwd" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)
  git_dir=$(git -C "$cwd" rev-parse --path-format=absolute --git-dir 2>/dev/null || true)
  if [[ -n "$git_common" && "$git_common" != "$git_dir" && ! -e "$cwd/.serena" ]]; then
    main_root="${git_common%/.git}"
    if [[ -d "$main_root/.serena" && -f "$main_root/.serena/project.yml" ]]; then
      cp -R "$main_root/.serena" "$cwd/.serena" 2>/dev/null && copied_from_main=1
    fi
  fi

  # 5. Already onboarded - still nudge to prefer Serena tools
  if [[ -f "$cwd/.serena/project.yml" ]]; then
    if (( copied_from_main )); then
      cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "Serena MCP: この worktree では main の .serena/ を cp で複製して onboarding 済の状態にしました。LSP cache は main から独立しているため、大規模な構造変更でも main 側を汚しません。シンボル定義/参照/実装の探索は mcp__serena__find_symbol / find_referencing_symbols / find_implementations、ファイル俯瞰は mcp__serena__get_symbols_overview、rename/本体書き換えは mcp__serena__rename_symbol / replace_symbol_body を優先してください。grep/Read への fallback は Serena が非対応・エラー時のみ。最初の symbol 操作の前に mcp__serena__initial_instructions を 1 回読んでください。通知停止はプロジェクト直下に空ファイル .serena/.no-onboarding を作成。"
  }
}
EOF
      return 0
    fi
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

  # 6. Not yet onboarded - prompt onboarding flow
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
