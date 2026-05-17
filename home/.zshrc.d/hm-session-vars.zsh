# Source Home Manager session variables.
#
# 背景:
#   castle は nix-darwin + Home Manager を採用しているが、`programs.zsh.enable`
#   は homeshick 管理の zshrc と衝突するため **Home Manager 側で有効化していない**。
#   その結果、HM が生成する `hm-session-vars.sh` (env var の宣言的ソース) は
#   shell の起動経路に自動接続されない。castle としては machine-global な env
#   を `home.sessionVariables` (home.nix) で宣言する以上、その読み込み口を
#   castle 側で明示する必要がある。
#
# パス:
#   `home-manager.useUserPackages = true` (flake.nix で設定済み) のため、HM
#   packages は `/etc/profiles/per-user/$USER/` 配下に install される。session
#   vars もこの user-scoped profile 配下に着地する:
#       /etc/profiles/per-user/$USER/etc/profile.d/hm-session-vars.sh
#   `~/.nix-profile/etc/profile.d/` ではないので注意 (useUserPackages を
#   無効化した場合はそちらに動く)。
#
# 罠:
#   castle CLAUDE.md「~/.zshrc.d/ の auto-source」セクションを参照。zsh は rc
#   を 1 度だけ source するため、この snippet を追加・symlink した直後の
#   既存セッションには反映されない。`exec "$SHELL" -l` または個別 source
#   `source ~/.zshrc.d/hm-session-vars.zsh` が必要。

if [[ -r /etc/profiles/per-user/$USER/etc/profile.d/hm-session-vars.sh ]]; then
  source /etc/profiles/per-user/$USER/etc/profile.d/hm-session-vars.sh
fi
