#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

# 使い方表示
usage() {
  cat <<'USAGE'
Usage:
  scripts/sync-codex-skills.sh [--local-codex]

Options:
  --local-codex  Also sync links into $CODEX_HOME/skills (default: ~/.codex/skills)
USAGE
}

# 既存ファイル/ディレクトリに誤ってリンクをネストさせないための安全ラッパー。
# - 宛先が未作成 or シンボリックリンク: 上書きしてOK
# - 宛先が通常ファイル/ディレクトリ: 破壊を避けるためエラーにする
safe_link() {
  local target="$1"
  local dest="$2"

  if [[ -L "$dest" || ! -e "$dest" ]]; then
    ln -sfn "$target" "$dest"
    return 0
  fi

  echo "Error: '$dest' exists and is not a symlink." >&2
  echo "       Move/remove it first, then run this script again." >&2
  return 1
}

# このリンクが「このスクリプト管理下のリンク」かどうかを判定する。
# 管理下のリンクのみ削除対象にすることで、手動で作成したリンクを保護する。
is_managed_link() {
  local link_path="$1"
  local expected_target="$2"
  [[ -L "$link_path" ]] || return 1
  [[ "$(readlink "$link_path")" == "$expected_target" ]]
}

# オプション指定時のみ、現在の端末(~/.codex/skills)にも同期する
sync_local_codex=0

# --local-codex のみ受け付ける
if [[ "${1:-}" == "--local-codex" ]]; then
  sync_local_codex=1
  shift
fi

# 想定外の引数があればヘルプを出して終了
if [[ $# -ne 0 ]]; then
  usage
  exit 1
fi

# リポジトリ内のCodexスキル定義と、homeshick管理下のリンク先
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
codex_source_dir="$repo_root/codex/skills"
home_codex_dir="$repo_root/home/.codex/skills"

# 実行結果サマリー用カウンタ
error_count=0
updated_count=0
removed_count=0
skipped_count=0

# スキル定義ディレクトリがなければ何もしない
if [[ ! -d "$codex_source_dir" ]]; then
  echo "No codex skills directory found: $codex_source_dir"
  exit 0
fi

# homeshick管理下のリンク配置先を用意
mkdir -p "$home_codex_dir"

# codex/skills/* を走査し、SKILL.md があるものだけリンクを作成/更新
for skill_dir in "$codex_source_dir"/*; do
  [[ -d "$skill_dir" ]] || continue
  skill_name="$(basename "$skill_dir")"

  if [[ ! -f "$skill_dir/SKILL.md" ]]; then
    echo "Skip $skill_name: SKILL.md not found"
    ((skipped_count++))
    continue
  fi

  # home/.codex 側は、リポジトリ相対リンクで管理する
  if safe_link "../../../codex/skills/$skill_name" "$home_codex_dir/$skill_name"; then
    ((updated_count++))
  else
    ((error_count++))
  fi
done

# 削除済みスキルに対応する古いリンクを掃除
for codex_link in "$home_codex_dir"/*; do
  skill_name="$(basename "$codex_link")"
  if is_managed_link "$codex_link" "../../../codex/skills/$skill_name" && [[ ! -d "$codex_source_dir/$skill_name" ]]; then
    rm "$codex_link"
    ((removed_count++))
  fi
done

if [[ "$sync_local_codex" -eq 1 ]]; then
  # 現在の端末のCodex設定ディレクトリ（通常は ~/.codex）
  codex_home="${CODEX_HOME:-$HOME/.codex}"
  local_codex_dir="$codex_home/skills"
  mkdir -p "$local_codex_dir"

  # ローカル端末側にも同じリンクを作成/更新
  for skill_dir in "$codex_source_dir"/*; do
    [[ -d "$skill_dir" ]] || continue
    skill_name="$(basename "$skill_dir")"
    if [[ ! -f "$skill_dir/SKILL.md" ]]; then
      ((skipped_count++))
      continue
    fi
    # ~/.codex 側は、実体への絶対パスリンクにする
    if safe_link "$skill_dir" "$local_codex_dir/$skill_name"; then
      ((updated_count++))
    else
      ((error_count++))
    fi
  done

  # ローカル側の削除済みスキルリンクを掃除
  for codex_link in "$local_codex_dir"/*; do
    skill_name="$(basename "$codex_link")"
    if is_managed_link "$codex_link" "$codex_source_dir/$skill_name" && [[ ! -d "$codex_source_dir/$skill_name" ]]; then
      rm "$codex_link"
      ((removed_count++))
    fi
  done
fi

# 同期完了メッセージ
echo "Codex skill links synced. updated=$updated_count removed=$removed_count skipped=$skipped_count errors=$error_count"

# 1件でもエラーがあれば終了コード1を返し、呼び出し元から検知できるようにする
if [[ "$error_count" -gt 0 ]]; then
  exit 1
fi
