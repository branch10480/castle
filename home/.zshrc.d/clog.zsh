# Claude Code セッション横断検索 (clog = Claude log)
#
# ~/.claude/projects/**/*.jsonl を全 working directory 横断で grep し、
# 「あの話をしたのはどの worktree だったっけ」を解決する。
#
# 例:
#   clog Privacy Manifest                # AND 検索 (Privacy AND Manifest)
#   clog -g 'Phase 9'                    # cwd ごとのマッチ件数だけ集計
#   clog --since 7d 'ranking'            # 直近 7 日のみ
#   clog --cwd ebookjapan-ios 'crash'    # 特定リポジトリ系のみ
#   clog --regex 'op://[^ ]+/credential' # 正規表現
#   clog --role user 'やめてほしい'      # 自分の発話だけを検索
#
# スクリプト本体は castle/scripts/claude-session-search.py.
# 詳しい引数は `clog --help`.
clog() {
  local script="${HOME}/.homesick/repos/castle/scripts/claude-session-search.py"
  if [[ ! -x $script ]]; then
    echo "clog: script not found or not executable: $script" >&2
    return 127
  fi
  if [[ $1 == -h || $1 == --help ]]; then
    cat <<'EOF'
clog — Claude Code セッション横断検索 (~/.claude/projects/**/*.jsonl)
「あの話をしたのはどの worktree だったっけ」を解決するための CLI。

usage:
  clog <query>...                       # AND 検索 (ignore-case)
  clog -g <query>...                    # cwd ごとのマッチ件数だけ集計
  clog --since 7d <query>...            # 期間絞り込み (7d / 12h / 30m / 2w / 2026-05-01)
  clog --cwd <part> <query>...          # cwd 部分一致で絞り込み
  clog --regex <pattern>                # 正規表現
  clog --role user <query>...           # 自分の発話だけ (feedback 発掘に便利)
  clog --role assistant <query>...      # アシスタントの発話だけ
  clog --full -n 0 <query>...           # preview を切り詰めず全件

例:
  clog Privacy Manifest                 # Privacy AND Manifest を全 worktree から
  clog -g 'Phase 9'                     # どこで話したかランキング
  clog --cwd ebookjapan-ios 'crash'     # 特定リポジトリ系のみ
  clog --regex 'op://[^ ]+/credential'  # op:// 参照を全部洗う
  clog --since 7d ''                    # 直近 7 日のセッション一覧 (空 query = 全件)

resume 連携:
  各ヒットには `session=<id>` が出る。
  `clog-resume <id>` でそのセッションに 1 コマンドで cd + resume できる
  (詳細は `clog-resume -h`)。

----------------- python script の --help (詳細フラグ) -----------------
EOF
    python3 "$script" --help
    return 0
  fi
  python3 "$script" "$@"
}

# `clog` の結果からコピペした session id を resume する。
# cwd は jsonl から自動解決し、その worktree に cd してから `claude --resume` を呼ぶ。
#
# usage:
#   clog-resume <session-id> [追加で claude に渡す引数...]
#
# 例:
#   clog-resume eb697d30-9327-438d-825a-3a6b50b3d3d2
#   clog-resume eb697d30-9327-438d-825a-3a6b50b3d3d2 --fork-session
#
# ドライラン（実際に claude を起動せず cwd 解決だけ確認したい時）:
#   CLOG_RESUME_CMD=echo clog-resume <session-id>
clog-resume() {
  emulate -L zsh
  setopt local_options null_glob

  if [[ $1 == -h || $1 == --help ]]; then
    cat <<'EOF'
clog-resume — session id を渡して cd + `claude --resume` を 1 ステップ実行

usage:
  clog-resume <session-id> [追加で claude に渡す引数...]

例:
  clog-resume eb697d30-9327-438d-825a-3a6b50b3d3d2
  clog-resume eb697d30-9327-438d-825a-3a6b50b3d3d2 --fork-session   # 元 session を温存

ドライラン (claude を起動せず cwd 解決だけ確認):
  CLOG_RESUME_CMD=echo clog-resume <session-id>

挙動:
  1. ~/.claude/projects/*/<session-id>.jsonl を探す
  2. 見つかった jsonl の先頭から "cwd" キーを持つ最初の行を python3 で抽出
  3. その cwd が存在すれば `cd <cwd> && claude --resume <session-id>` を実行
     (cwd が消えていれば `git worktree add <cwd> <branch>` または
      jsonl 移植のヒントを出して非ゼロ終了)

session id がうろ覚えなときは:
  clog --regex '<先頭 8 桁>'   # session id を全件 grep
  clog --since 7d ''           # 直近 7 日のセッション一覧

環境変数:
  CLOG_RESUME_CMD   実行コマンドを差し替え (既定: claude)
                    ドライランや代替フロントエンドのテスト用
EOF
    return 0
  fi

  local sid="$1"
  if [[ -z $sid ]]; then
    echo "usage: clog-resume <session-id> [extra claude args...]" >&2
    echo "       詳細は 'clog-resume -h'" >&2
    return 2
  fi
  shift

  local -a matches
  matches=( "${HOME}/.claude/projects"/*/"${sid}.jsonl" )
  if (( ${#matches} == 0 )); then
    echo "clog-resume: session not found: $sid" >&2
    echo "  hint: 'clog --regex \"${sid:0:8}\"' で session の所在を再確認" >&2
    return 1
  fi
  local jsonl=${matches[1]}

  local cwd
  cwd=$(python3 -c '
import json, sys
for line in open(sys.argv[1], encoding="utf-8", errors="replace"):
    try:
        d = json.loads(line)
    except json.JSONDecodeError:
        continue
    if d.get("cwd"):
        print(d["cwd"])
        break
' "$jsonl")

  if [[ -z $cwd ]]; then
    echo "clog-resume: could not resolve cwd from $jsonl" >&2
    return 1
  fi
  if [[ ! -d $cwd ]]; then
    echo "clog-resume: cwd no longer exists: $cwd" >&2
    echo "  hint: 'git worktree add $cwd <branch>' で復元するか、" >&2
    echo "        jsonl を別 cwd の encoded ディレクトリに移植してください" >&2
    return 1
  fi

  local cmd=${CLOG_RESUME_CMD:-claude}
  echo "clog-resume: cd $cwd && $cmd --resume $sid $*"
  ( cd "$cwd" && "$cmd" --resume "$sid" "$@" )
}
