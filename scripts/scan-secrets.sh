#!/usr/bin/env bash
# Lightweight secret scanner for the castle dotfiles repo.
#
# Designed to catch the most common cloud / API key prefixes without
# requiring an external tool. Run before pushing, or wire into a
# pre-commit hook. For a deeper scan, install `gitleaks` and use it
# alongside this script (this script is intentionally minimal so it
# always works on a fresh Mac).
#
# Usage:
#   scripts/scan-secrets.sh                  # scans tracked files at HEAD
#   scripts/scan-secrets.sh --staged         # scans the current git index
#   scripts/scan-secrets.sh path/to/file ... # scans explicit paths

set -euo pipefail

# Patterns to flag. Each line is a description + a grep -E regex.
#
# Notes on regex hygiene (BSD grep on macOS does not support \b
# reliably, so we lean on character-class strictness + minimum length):
# - Restrict the high-entropy tail to [A-Za-z0-9] (no `-`/`_`) when the
#   real key shape allows it. CSS class names like
#   `task-list-item-convert-container` happen to contain a literal
#   `sk-list-item-…` substring; allowing `-` in the tail makes the
#   classic-OpenAI pattern fire on every Markdown CSS file.
# - Minimum-length ({40,}) is calibrated to each provider's real key
#   format so that short identifier-style strings don't match.
# - The classic OpenAI pattern `sk-[A-Za-z0-9]{40,}` intentionally
#   overlaps with the Anthropic / project / service-account variants:
#   one real `sk-ant-…` line may be reported under multiple labels.
#   We accept that noise because we'd rather have a key reported twice
#   than missed once, and BSD grep doesn't support negative lookaheads.
patterns=(
  "Perplexity API key|pplx-[A-Za-z0-9]{40,}"
  "Anthropic API key|sk-ant-(api|admin)[0-9]+-[A-Za-z0-9_-]{40,}"
  "OpenAI API key (classic)|sk-[A-Za-z0-9]{40,}"
  "OpenAI API key (project)|sk-proj-[A-Za-z0-9_-]{40,}"
  "OpenAI API key (svcacct)|sk-svcacct-[A-Za-z0-9_-]{40,}"
  "AWS access key id|AKIA[0-9A-Z]{16}"
  "AWS secret-style|aws_secret_access_key\\s*[:=]\\s*[A-Za-z0-9/+=]{30,}"
  "GitHub PAT (classic)|ghp_[A-Za-z0-9]{36,}"
  "GitHub PAT (fine-grained)|github_pat_[A-Za-z0-9_]{36,}"
  "GitHub OAuth token|gho_[A-Za-z0-9]{36,}"
  "GitHub user-to-server|ghu_[A-Za-z0-9]{36,}"
  "Slack bot token|xoxb-[0-9]+-[0-9]+-[0-9]+-[a-zA-Z0-9]{20,}"
  "Slack user token|xoxp-[0-9]+-[0-9]+-[0-9]+-[a-zA-Z0-9]{20,}"
  "Google API key|AIza[0-9A-Za-z_-]{35}"
  "JWT-shape token|eyJ[A-Za-z0-9_=-]{20,}\\.eyJ[A-Za-z0-9_=-]{20,}\\.[A-Za-z0-9_.+/=-]{20,}"
  "Private key block|-----BEGIN (RSA |OPENSSH |EC |PGP )?PRIVATE KEY-----"
)

# Decide which file set to scan.
mode="head"
explicit_files=()
case "${1-}" in
  --staged)
    mode="staged"
    ;;
  "")
    mode="head"
    ;;
  *)
    mode="explicit"
    explicit_files=("$@")
    ;;
esac

# `head` and `staged` modes shell out to git; bail early with a clear
# message if we're outside a working tree, instead of letting `set -e`
# pull the rug out from under the user partway through list_files().
if [[ "$mode" != "explicit" ]]; then
  if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
    printf 'scan-secrets.sh: not inside a git repository (use explicit paths instead).\n' >&2
    exit 2
  fi
fi

list_files() {
  case "$mode" in
    head)
      git ls-files
      ;;
    staged)
      # ACMR = Added / Copied / Modified / Renamed (post-rename path).
      # `AM` alone misses `git mv old.env new.env`, which would smuggle
      # an existing secret-bearing file past the scanner.
      git diff --cached --name-only --diff-filter=ACMR
      ;;
    explicit)
      printf '%s\n' "${explicit_files[@]}"
      ;;
  esac
}

hit=0
while IFS= read -r file; do
  [[ -z "$file" ]] && continue
  [[ ! -f "$file" ]] && continue
  for entry in "${patterns[@]}"; do
    label="${entry%%|*}"
    regex="${entry#*|}"
    # -I skips binary files (portable across BSD/GNU grep); without it
    # PNGs and fonts can spuriously match high-entropy patterns.
    matches="$(grep -InE -- "$regex" "$file" || true)"
    if [[ -n "$matches" ]]; then
      hit=1
      printf '\n[!] %s\n    file: %s\n' "$label" "$file"
      printf '%s\n' "$matches" | sed 's/^/    /'
    fi
  done
done < <(list_files)

if (( hit == 1 )); then
  printf '\nSecret-shaped strings found. If they are real, rotate now and switch to op:// URIs.\n' >&2
  exit 1
fi

printf 'No known secret patterns matched.\n'
