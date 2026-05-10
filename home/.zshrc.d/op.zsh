# 1Password CLI shell integration (Phase 2 of secrets management).
#
# Design principles:
# - Never `op read` secrets at shell startup. Pulling at startup degrades
#   shell-launch latency, triggers biometric prompts in non-interactive
#   shells (cron, scripts, IDE shells), and weakens the audit trail.
#   Always inject on demand via `op run` or `op plugin run`.
# - Per-machine OP_ACCOUNT (personal vs work) is selected in
#   ~/.zshrc.local, which sources earlier in ~/.zshrc.
# - 1Password GUI must be running with "Integrate with 1Password CLI"
#   enabled (Settings → Developer) for biometric unlock. CLI-only signin
#   via `op signin` also works but loses Touch ID convenience.

# `op` not installed yet (e.g. fresh work Mac before nix-darwin switch).
(( $+commands[op] )) || return 0

# ── op CLI helpers ───────────────────────────────────────
# Check current signin / unlock state. Returns non-zero if locked, so it
# can be chained: `op-status && oprun -- foo` style.
op-status() {
  local out
  if out=$(op whoami 2>/dev/null); then
    print -r -- "$out"
  else
    print -r -- "1Password CLI is locked. Open the desktop app or run 'op signin'." >&2
    return 1
  fi
}

# Wrapper around `op run --env-file=<file> -- <command>`. Defaults to
# `.env.op` in CWD so project setups can adopt a single convention
# (Phase 3 of the migration). `--no-masking` keeps tool output usable
# (e.g. error messages that include URLs) at the cost of less aggressive
# secret redaction in stdout — acceptable for interactive use.
oprun() {
  local env_file=".env.op"
  while [[ "${1-}" == --env-file=* ]]; do
    env_file="${1#--env-file=}"
    shift
  done
  # Accept (but do not require) a `--` separator before the command,
  # so the documented `oprun [--env-file=…] -- cmd args…` form does not
  # get re-injected into `op run`'s own argv (which would make op treat
  # the second `--` as the executable name and fail with ENOENT).
  [[ "${1-}" == "--" ]] && shift
  if [[ ! -f "$env_file" ]]; then
    print -r -- "oprun: env-file not found: $env_file" >&2
    return 1
  fi
  op run --env-file="$env_file" --no-masking -- "$@"
}

# ── op-warm-mcp: pre-resolve op:// MCP env-files into /tmp ──
# 課題: 1Password 8 は呼び出し元アプリの「ターミナルセッション」(=pty)
# 単位で 10 分の transient authorization grant を出す。tmux のペインを
# 分割すると新 pty → 新 grant が必要 → ペインごとに Touch ID が出る。
# しかも castle の tmux は Nix-darwin の adhoc 署名 (Team ID 無し /
# /nix/store/<hash>/... が rebuild で動く) なので、1Password から
# 「永続認可済みアプリ」として扱われる回路すら無い。詳細:
# docs/op-touchid-investigation.md
#
# 対策 (A.2 ハイブリッド): ghostty 起動時にこの関数を 1 度だけ呼び、
# `~/.config/op/*.env` (op:// URI を含む) を `/tmp/op-mcp-<basename>`
# (解決済み値の literal) に書き出す。`~/.claude.json` の MCP サーバ
# (perplexity 等) の `op run --env-file=` を `/tmp/op-mcp-...` に
# 向け直しておけば、`op run` は op:// を発見せず 1Password 呼び出しを
# skip → ペイン分割しても Touch ID 不要。
#
# Trade-off: secret が /tmp に 0600 で session 中存在する (Phase 5 の
# .p8 一時展開と同じ思想)。/tmp は OS 再起動でクリアされるため永続漏洩
# リスクは限定的。鍵 rotate 時は /tmp/op-mcp-*.env を手動で消して再warm。
#
# 多重 ghostty 注意: 各 ghostty 起動でこの関数が走り、/tmp ファイルを
# 上書きする (=また 1 回 Touch ID)。EXIT trap は `exec tmux` が直後に
# 走る都合で確実に発火させづらいので採用していない (file 残存は意図)。
#
# Idempotency: 同 boot 中の 2 回目以降は /tmp ファイルが既存 → skip。
op-warm-mcp() {
  local in out
  for in in ~/.config/op/*.env(N); do
    [[ -r "$in" ]] || continue
    out="/tmp/op-mcp-$(basename "$in")"
    # Skip if already warmed this boot (file persists in /tmp until reboot)
    [[ -s "$out" ]] && continue
    # Extract env var keys from the input file (KEY=...)
    local keys=( ${(f)"$(awk -F= '!/^[[:space:]]*#/ && NF>=2 {print $1}' "$in")"} )
    (( ${#keys[@]} == 0 )) && continue
    # Run op run once for this env-file. Inside, bash dumps KEY=value
    # for each requested key using ${!k} (indirect expansion). The whole
    # output is redirected to $out under umask 077 so the file is 0600.
    if ( umask 077; op run --env-file="$in" -- bash -c '
      for k in "$@"; do
        printf "%s=%s\n" "$k" "${!k}"
      done
    ' bash "${keys[@]}" > "$out" 2>/dev/null ); then
      print -r -- "op-warm-mcp: warmed $out"
    else
      print -r -- "op-warm-mcp: failed to warm $out (input: $in)" >&2
      rm -f "$out"
    fi
  done
}

# ── 1Password Shell Plugins ──────────────────────────────
# `op plugin init <cli>` is interactive and per-machine (it writes a
# config under ~/.config/op/ and appends aliases to plugins.sh). Source
# whatever the user has already initialized; do nothing if absent.
[[ -f ~/.config/op/plugins.sh ]] && source ~/.config/op/plugins.sh
