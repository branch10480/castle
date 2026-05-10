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
# touch the filesystem.
KEY_ID="$(op item get "$ITEM" --vault "$VAULT" --fields "key id" 2>/dev/null)"
ISSUER="$(op item get "$ITEM" --vault "$VAULT" --fields "issuer id" 2>/dev/null)"
if [[ -z "$KEY_ID" || -z "$ISSUER" ]]; then
  printf 'asc-upload: missing "key id" or "issuer id" field on item: %s/%s\n' "$VAULT" "$ITEM" >&2
  exit 1
fi

P8_DIR="$HOME/.appstoreconnect/private_keys"
P8_PATH="$P8_DIR/AuthKey_${KEY_ID}.p8"

mkdir -p "$P8_DIR"
chmod 700 "$P8_DIR"

# umask 077 so the key is created 0600 from the start (no readable window).
# Use a subshell so the umask change does not leak to subsequent commands.
( umask 077 && op read "op://$VAULT/$ITEM/credential" > "$P8_PATH" )

cleanup() { rm -f "$P8_PATH"; }
trap cleanup EXIT INT TERM

xcrun altool --upload-app \
  -f "$IPA" \
  --type ios \
  --apiKey "$KEY_ID" \
  --apiIssuer "$ISSUER" \
  --show-progress
