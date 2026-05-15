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

  # sudo を Touch ID 化する。macOS Sonoma 14+ の /etc/pam.d/sudo_local 経路を
  # 使うため、softwareupdate で /etc/pam.d/sudo が上書きされても消えない。
  # `reattach = true` は tmux / screen 越しでも Touch ID プロンプトを出すため
  # に必須 (pam_reattach.so が console session に re-attach する)。
  # 旧 `security.pam.enableSudoTouchIdAuth` は deprecated のため使わない。
  security.pam.services.sudo_local = {
    enable = true;
    touchIdAuth = true;
    reattach = true;
  };

  # Minimal system packages. Per-user CLI tools live in home.nix.
  environment.systemPackages = with pkgs; [
    coreutils
  ];

  # フォントは Nix 経由で供給する。Homebrew Cask 経由だとネットワークエラー等で
  # silent に skip されることがあり、別マシンで `nrs` 後もフォントが入らず
  # CSS のフォールバック（Hiragino 等）に落ちる事故が起きるため。
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    nerd-fonts.fira-code
    nerd-fonts.symbols-only
    ibm-plex
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
      # 1Password GUI: Touch ID 解錠 / SSH agent / op-ssh-sign を提供。
      # CLI 本体 (`op`) は home.nix の _1password-cli (Nix) で供給する。
      "1password"
      # codex (CLI) は home.nix の home.packages で Nix 管理（phase 8）。
      # Caskroom の codex-app (GUI) は Nix 配布が無いため brew cask で継続。
      "codex-app"
      "drawio"
      # font-* casks は fonts.packages (Nix) に移行済み。
      # cleanup = "zap" により次回 switch で Cask 側の残骸が自動削除される。
      "ghostty"
      "hammerspoon"
      "proxyman"
      "raycast"
      "vlc"
    ];

    masApps = {
      # mas is not installed; populate via `brew install mas && mas list` if needed.
    };
  };
}
