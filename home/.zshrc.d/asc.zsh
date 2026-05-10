# App Store Connect upload helper (Phase 5 of secrets management).
#
# `asc-upload <path-to-ipa>` materializes the .p8 from 1Password, runs
# `xcrun altool --upload-app`, and removes the .p8 on exit. Detailed
# rationale (why we don't use Phase 3's `oprun` env-file pattern, why
# the .p8 has to live on disk briefly): docs/asc-api-key-op.md.
#
# Heavy lifting is in scripts/asc-upload.sh so that non-zsh callers
# (Makefile / Fastfile / CI) can invoke the script directly without
# depending on this zsh function.

asc-upload() {
  ~/.homesick/repos/castle/scripts/asc-upload.sh "$@"
}
