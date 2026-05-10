#!/usr/bin/env bash
# Upload an iOS IPA to App Store Connect via a 1Password-managed API key
# (Phase 5 of secrets management).
#
# `xcrun altool` cannot read the API key from an environment variable or
# an arbitrary path — it scans `~/.appstoreconnect/private_keys/` for a
# file literally named `AuthKey_<KEY_ID>.p8`. The Phase 3 `oprun` /
# env-file pattern therefore does NOT apply: the key has to be a real
# file on disk during the upload. To avoid persisting the .p8 between
# uploads, we materialize it from 1Password (`op read`) just before the
# upload and remove it on EXIT (success, failure, or interrupt).
#
# Usage:
#   asc-upload.sh <path-to-ipa>
#
# Environment overrides (work-Mac / multi-account):
#   ASC_OP_ITEM   1Password item title           (default: "App Store Connect API Key")
#   ASC_OP_VAULT  1Password vault name           (default: "Private")

set -euo pipefail

IPA="${1:-}"
if [[ -z "$IPA" ]]; then
  printf 'usage: %s <path-to-ipa>\n' "${0##*/}" >&2
  exit 2
fi
if [[ ! -f "$IPA" ]]; then
  printf 'asc-upload: IPA not found: %s\n' "$IPA" >&2
  exit 2
fi

ITEM="${ASC_OP_ITEM:-App Store Connect API Key}"
VAULT="${ASC_OP_VAULT:-Private}"

if ! command -v op >/dev/null 2>&1; then
  printf 'asc-upload: 1Password CLI (op) not found in PATH\n' >&2
  exit 127
fi
if ! command -v xcrun >/dev/null 2>&1; then
  printf 'asc-upload: xcrun not found (Xcode command line tools required)\n' >&2
  exit 127
fi

# Pull metadata first so we fail fast on a misconfigured item before we
# touch the filesystem. Do NOT redirect stderr to /dev/null: under
# `set -e` an op failure here aborts immediately, and silenced stderr
# leaves the user with no clue (no "item not found", no "vault locked").
KEY_ID="$(op item get "$ITEM" --vault "$VAULT" --fields "key id")"
ISSUER="$(op item get "$ITEM" --vault "$VAULT" --fields "issuer id")"
if [[ -z "$KEY_ID" || -z "$ISSUER" ]]; then
  printf 'asc-upload: missing "key id" or "issuer id" field on item: %s/%s\n' "$VAULT" "$ITEM" >&2
  exit 1
fi

P8_DIR="$HOME/.appstoreconnect/private_keys"
P8_PATH="$P8_DIR/AuthKey_${KEY_ID}.p8"

mkdir -p "$P8_DIR"
chmod 700 "$P8_DIR"

# Install the cleanup trap BEFORE writing the .p8: bash's `>` redirection
# creates the file with O_CREAT|O_TRUNC *before* `op read` writes any
# byte, so a Ctrl-C / SIGTERM / Touch ID cancel / network drop between
# create and the trap below would otherwise leave a partial PEM behind.
cleanup() { rm -f "$P8_PATH"; }
trap cleanup EXIT INT TERM

# Remove any stale .p8 (e.g. from a previous SIGKILL / power cut that
# bypassed the trap). bash's `>` preserves the existing file mode, so
# without this `rm` an old 0644 file would defeat the umask 077 below.
rm -f "$P8_PATH"

# umask 077 so the key is created 0600 from the start (no readable window).
# Use a subshell so the umask change does not leak to subsequent commands.
( umask 077 && op read "op://$VAULT/$ITEM/credential" > "$P8_PATH" )

xcrun altool --upload-app \
  -f "$IPA" \
  --type ios \
  --apiKey "$KEY_ID" \
  --apiIssuer "$ISSUER" \
  --show-progress
