#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
template_file="$repo_root/claude/statusline-config.json"
settings_file="$HOME/.claude/settings.json"

# テンプレート存在チェック
if [[ ! -f "$template_file" ]]; then
  echo "Error: Template not found: $template_file" >&2
  exit 1
fi

# jq 存在チェック
if ! command -v jq &>/dev/null; then
  echo "Error: jq is required but not found. Install with: brew install jq" >&2
  exit 1
fi

# ~/.claude ディレクトリ確保
mkdir -p "$HOME/.claude"

# settings.json がなければ初期化
if [[ ! -f "$settings_file" ]]; then
  echo '{}' > "$settings_file"
  echo "Created new $settings_file"
fi

# __HOME__ を $HOME に置換して JSON 生成
statusline_json=$(sed "s|__HOME__|$HOME|g" "$template_file")

# バリデーション
if ! echo "$statusline_json" | jq empty 2>/dev/null; then
  echo "Error: Generated JSON is invalid" >&2
  exit 1
fi

# 現在値と比較（冪等性）
current=$(jq -c '.statusLine // empty' "$settings_file" 2>/dev/null || echo "")
incoming=$(echo "$statusline_json" | jq -c '.statusLine')

if [[ "$current" == "$incoming" ]]; then
  echo "statusLine is already up to date. No changes needed."
  exit 0
fi

# jq でマージ（statusLine のみ上書き、他キーは保持）
tmp_file=$(mktemp)
jq --argjson sl "$statusline_json" '. * $sl' "$settings_file" > "$tmp_file"
mv "$tmp_file" "$settings_file"

echo "statusLine configuration applied successfully."
echo "  command: $(echo "$statusline_json" | jq -r '.statusLine.command')"
