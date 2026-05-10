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

# ── op-warm: pre-populate daemon cache to dodge per-pane Touch ID ──
# Each tmux pane that runs `claude` spawns Claude Code → spawns its
# configured MCP servers → those wrapped in `op run` (e.g. perplexity)
# trigger biometric unlock if the op-daemon's cache is cold. The cache
# IS shared across processes (tested: 3 parallel `op run` after a warm
# cache complete in ~1.5s with no prompt), but its TTL is bounded by
# the 1Password GUI app's "Lock after" setting (Settings → Security).
# Past that window every call goes cold again, so splitting panes
# minutes apart re-prompts every time.
#
# This helper warms the cache once so a burst of subsequent `op run`
# (across N panes) costs at most one Touch ID instead of N.
#
# Usage:
#   op-warm                       # warms every ~/.config/op/*.env file
#   op-warm path/to/file.env ...  # warms specific files only
#
# Mechanics: `op run --env-file=<f> -- true` performs the same auth +
# secret resolution path as the real MCP launch but spawns a no-op.
# The daemon then holds the unlock until GUI auto-lock kicks in.
#
# Trade-off: this helper does NOT extend the cache window — only fills
# it. To stretch the window itself, lift the GUI's "Lock after" timer.
op-warm() {
  local -a files
  if (( $# > 0 )); then
    files=("$@")
  else
    files=(~/.config/op/*.env(N))
  fi
  if (( ${#files} == 0 )); then
    print -r -- "op-warm: no env files to warm (looked in ~/.config/op/*.env)" >&2
    return 1
  fi
  local f rc=0
  for f in "${files[@]}"; do
    if op run --env-file="$f" -- true >/dev/null 2>&1; then
      print -r -- "warmed: $f"
    else
      print -r -- "failed: $f" >&2
      rc=1
    fi
  done
  return $rc
}

# ── 1Password Shell Plugins ──────────────────────────────
# `op plugin init <cli>` is interactive and per-machine (it writes a
# config under ~/.config/op/ and appends aliases to plugins.sh). Source
# whatever the user has already initialized; do nothing if absent.
[[ -f ~/.config/op/plugins.sh ]] && source ~/.config/op/plugins.sh
