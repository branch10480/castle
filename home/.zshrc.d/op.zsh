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
  if op whoami >/dev/null 2>&1; then
    op whoami
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
  if [[ ! -f "$env_file" ]]; then
    print -r -- "oprun: env-file not found: $env_file" >&2
    return 1
  fi
  op run --env-file="$env_file" --no-masking -- "$@"
}

# ── 1Password Shell Plugins ──────────────────────────────
# `op plugin init <cli>` is interactive and per-machine (it writes a
# config under ~/.config/op/ and appends aliases to plugins.sh). Source
# whatever the user has already initialized; do nothing if absent.
[[ -f ~/.config/op/plugins.sh ]] && source ~/.config/op/plugins.sh
