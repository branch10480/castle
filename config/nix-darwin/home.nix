{ pkgs, username, ... }:

{
  home.username = username;
  home.homeDirectory = "/Users/${username}";

  # Bound to the Home Manager release used at first activation. DO NOT change
  # without reading the HM release notes for the migration path.
  home.stateVersion = "24.11";

  programs.home-manager.enable = true;

  # CLI tools delivered by Nix. Configuration files keep living in
  # castle/config/* via homeshick — we only ship the binaries here, so do NOT
  # enable `programs.<tool>` modules that would write configs into ~/.config
  # and clash with homeshick-managed dotfiles.
  #
  # NOTE: tools currently provided by Homebrew (gh, ghq, fzf, zoxide, starship,
  # neovim, tmux, direnv, etc.) are intentionally omitted here to avoid PATH
  # collisions during the first `darwin-rebuild switch`. After verifying the
  # initial activation, migrate them from `darwin.nix#brews` to here one by
  # one.
  home.packages = with pkgs; [
    git
    jq
    ripgrep
    fd
    bat
    eza
    tig
    # Migrated from Homebrew (phase 1: low-risk CLIs)
    tree
    # direnv: kept on Homebrew because Nix's checkPhase hangs on macOS
    # (zsh/fish/bash integration tests block waiting for TTY).
  ];
}
