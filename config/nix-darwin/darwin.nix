{ pkgs, username, ... }:

{
  # nix-darwin module schema version. DO NOT change after first switch.
  system.stateVersion = 5;

  # Required by recent nix-darwin: system activation runs as root, but
  # user-scoped options (homebrew, home-manager) need to know which account
  # they belong to.
  system.primaryUser = username;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  nixpkgs.config.allowUnfree = true;
  nixpkgs.hostPlatform = "aarch64-darwin";

  users.users.${username} = {
    home = "/Users/${username}";
  };

  # System-level zsh. Existing ~/.zshrc (managed by homeshick) keeps working.
  programs.zsh.enable = true;

  # Minimal system packages. Per-user CLI tools live in home.nix.
  environment.systemPackages = with pkgs; [
    coreutils
  ];

  fonts.packages = with pkgs; [
    # add fonts here as needed, e.g. nerd-fonts.jetbrains-mono
  ];

  # Homebrew is used for macOS GUI apps (casks) and App Store apps that Nix
  # cannot ship. nix-darwin runs `brew bundle` during activation against the
  # declarations below.
  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = false;
      upgrade = false;
      # IMPORTANT: keep "none" until every existing brew package has been
      # transcribed into the lists below. Switching to "zap" removes any
      # brew/cask not declared here.
      cleanup = "none";
    };

    global = {
      brewfile = true;
      # `lockfiles` は Homebrew 4.4.0 で機能廃止のため削除。
    };

    # Imported from `brew tap` / `brew leaves` / `brew list --cask` on
    # 2026-04-26. Optimization (deduping with Nix-provided CLI) is deferred
    # until after the first successful `darwin-rebuild switch`.
    taps = [
      "anomalyco/tap"
      "branch10480/tap"
      "oven-sh/bun"
      "satococoa/tap"
    ];

    brews = [
      "anomalyco/tap/opencode"
      "anyenv"
      "branch10480/tap/markdownobserver-fork"
      # "direnv"  # → migrated to home.nix (Nix, doCheck=false)
      "ffmpeg"
      "fzf"
      "gh"
      "ghq"
      "go"
      "homeshick"
      "libyaml"
      "mint"
      "nb"
      "neovim"
      "node"
      "oven-sh/bun/bun"
      "satococoa/tap/wtp"
      "starship"
      "tmux"
      # "tree"    # → migrated to home.nix (Nix)
      "uv"
      "watch"
      "xcode-build-server"
      "xcodegen"
      "zoxide"
      "zsh-autosuggestions"
      "zsh-syntax-highlighting"
    ];

    casks = [
      "codex"
      "codex-app"
      "font-fira-code-nerd-font"
      "font-ibm-plex-mono"
      "font-jetbrains-mono-nerd-font"
      "font-symbols-only-nerd-font"
      "ghostty"
      "hammerspoon"
      "raycast"
      "vlc"
      "wezterm@nightly"
    ];

    masApps = {
      # mas is not installed; populate via `brew install mas && mas list` if needed.
    };
  };
}
