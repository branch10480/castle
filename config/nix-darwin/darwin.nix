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
      # zap = 宣言外の brew/cask を次回 switch で自動削除する。
      # 「宣言＝真実」を強制し、手動 `brew install` した残骸が積もるのを防ぐ。
      cleanup = "zap";
    };

    global = {
      brewfile = true;
      # `lockfiles` は Homebrew 4.4.0 で機能廃止のため削除。
    };

    taps = [
      "anomalyco/tap"
      "branch10480/tap"
      "satococoa/tap"
    ];

    brews = [
      "anomalyco/tap/opencode"
      "anyenv"
      "branch10480/tap/markdownobserver-fork"
      "cocoapods"
      "homeshick"
      "libyaml"
      # mint: Swift 製 yonaskolb/Mint。nixpkgs の `mint` は Mint Programming
      # Language で別物のため brew を採用（Scripts/start.sh が `mint bootstrap`
      # を要求する）。
      "mint"
      "pandoc"
      "rbenv-bundler"
      "satococoa/tap/wtp"
      "weasyprint"
      "xcode-build-server"  # nixpkgs に未収載のため brew のまま
    ];

    casks = [
      # codex (CLI) は npm 版 @openai/codex を使うため Nix 宣言から除外。
      # Caskroom の codex-app (GUI) はそのまま残す。
      "codex-app"
      "drawio"
      "font-fira-code-nerd-font"
      "font-ibm-plex-mono"
      "font-jetbrains-mono-nerd-font"
      "font-symbols-only-nerd-font"
      "ghostty"
      "hammerspoon"
      "raycast"
      "vlc"
    ];

    masApps = {
      # mas is not installed; populate via `brew install mas && mas list` if needed.
    };
  };
}
