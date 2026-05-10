#!/usr/bin/env bash
# Re-point ~/.claude.json's perplexity MCP entry from
#   --env-file=$HOME/.config/op/perplexity.env  (op:// URI source)
# to
#   --env-file=/tmp/op-mcp-perplexity.env       (resolved by op-warm-mcp)
#
# Why: 1Password 8 issues per-pty authorization grants. Each tmux pane
# launching `claude` would otherwise prompt Touch ID for the perplexity
# MCP's `op run`. By making `op run` read a pre-resolved file (no op://
# URIs), 1Password is never queried and Touch ID never fires.
#
# Pairs with: home/.zshrc.d/op.zsh's op-warm-mcp() function (called from
# home/.zshrc's Ghostty pre-attach block) which writes the /tmp file.
#
# Idempotent: if already pointing at the /tmp path, this script is a no-op.
#
# Run when:
#   - First-time setup on a new Mac (after homeshick link castle)
#   - After Phase 4 setup (CLAUDE.md) created the original op:// entry
#
# IMPORTANT: Quit Claude Code BEFORE running this. Claude Code holds an
# in-memory copy of ~/.claude.json and will overwrite your changes on exit.

set -euo pipefail

CLAUDE_JSON="${HOME}/.claude.json"
NEW_ENV_FILE="/tmp/op-mcp-perplexity.env"
OLD_ENV_FILE="${HOME}/.config/op/perplexity.env"

if [[ ! -f "${CLAUDE_JSON}" ]]; then
  echo "error: ${CLAUDE_JSON} not found" >&2
  exit 1
fi

if ! command -v jq >/dev/null; then
  echo "error: jq is required" >&2
  exit 1
fi

current=$(jq -r '.mcpServers.perplexity.args[]?
                 | select(startswith("--env-file="))
                 | sub("--env-file="; "")' "${CLAUDE_JSON}" 2>/dev/null || true)

if [[ -z "${current}" ]]; then
  echo "error: no --env-file arg found under .mcpServers.perplexity" >&2
  echo "(was Phase 4 setup completed? See CLAUDE.md.)" >&2
  exit 1
fi

if [[ "${current}" == "${NEW_ENV_FILE}" ]]; then
  echo "ok: already pointing at ${NEW_ENV_FILE} (no-op)"
  exit 0
fi

if [[ "${current}" != "${OLD_ENV_FILE}" ]]; then
  echo "warn: current --env-file is '${current}'" >&2
  echo "      expected '${OLD_ENV_FILE}' (Phase 4 default) or '${NEW_ENV_FILE}'" >&2
  echo "      proceeding anyway — verify the result manually" >&2
fi

backup="${CLAUDE_JSON}.bak.$(date +%Y%m%d-%H%M%S)"
cp "${CLAUDE_JSON}" "${backup}"
echo "backup: ${backup}"

tmp=$(mktemp)
trap 'rm -f "${tmp}"' EXIT

jq --arg new "--env-file=${NEW_ENV_FILE}" --arg old "--env-file=${OLD_ENV_FILE}" '
  .mcpServers.perplexity.args = (
    .mcpServers.perplexity.args | map(
      if startswith("--env-file=") then $new else . end
    )
  )
' "${CLAUDE_JSON}" > "${tmp}"

mv "${tmp}" "${CLAUDE_JSON}"
echo "updated: .mcpServers.perplexity.args[--env-file=...] -> ${NEW_ENV_FILE}"
echo
echo "next steps:"
echo "  1. (re)start your terminal — op-warm-mcp will fire on next ghostty session"
echo "  2. start Claude Code; perplexity MCP should connect without per-pane Touch ID"
echo "  3. verify: claude mcp list  # perplexity ✓ Connected"
