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

  # ====== トラックパッド設定 ======
  # System Settings > Trackpad の現在値を全部宣言化する。新規 Mac でも
  # `nrs` 1 回で同じ挙動を再現できるようにするのが狙い。
  #
  # nix-darwin の `system.defaults.trackpad.*` module は **内蔵 trackpad**
  # (com.apple.AppleMultitouchTrackpad) と **Magic Trackpad**
  # (com.apple.driver.AppleBluetoothMultitouch.trackpad) の両ドメインに
  # 同じ値を書いてくれるため、デバイス追加時の食い違いを気にしなくていい。
  #
  # ただし module が option 化していないキーがある
  # (`TrackpadHandResting` / `TrackpadScroll` / `TrackpadHorizScroll` /
  #  `TrackpadFiveFingerPinchGesture` / `USBMouseStopsTrackpad` /
  #  `UserPreferences`) ので、漏れ分は `system.defaults.CustomUserPreferences`
  # で両ドメインに直書きしている。
  #
  # 反映タイミング: defaults は cfprefsd の cache を経由するため `nrs` 直後
  # に効かないことがある。確実に反映したければ `killall cfprefsd` か再ログイン。
  system.defaults.trackpad = {
    Clicking = true;                                  # tap to click
    Dragging = false;                                 # tap to drag は OFF
    DragLock = false;
    TrackpadRightClick = true;                        # 二本指タップで右クリック
    TrackpadThreeFingerDrag = true;                   # 三本指ドラッグ
    TrackpadCornerSecondaryClick = 0;                 # 0=角クリック無し
    TrackpadThreeFingerTapGesture = 0;                # 0=off, 2=Look up & data detectors
    FirstClickThreshold = 2;                          # 通常クリック圧: 0=軽 / 1=中 / 2=重
    SecondClickThreshold = 2;                         # フォースクリック圧: 同上
    ForceSuppressed = true;                           # force click を無効化
    ActuateDetents = false;                           # 触覚フィードバック OFF
    TrackpadMomentumScroll = true;                    # 慣性スクロール
    TrackpadPinch = true;                             # 二本指ピンチでズーム
    TrackpadRotate = true;                            # 二本指回転
    TrackpadTwoFingerDoubleTapGesture = true;         # 二本指ダブルタップ = smart zoom
    TrackpadTwoFingerFromRightEdgeSwipeGesture = 3;   # 右端から二本指 = 3=通知センター
    TrackpadThreeFingerHorizSwipeGesture = 0;         # 三本指水平 = 0=無効
    TrackpadThreeFingerVertSwipeGesture = 0;          # 三本指垂直 = 0=無効 (3本指ドラッグと両立しない)
    TrackpadFourFingerHorizSwipeGesture = 2;          # 四本指水平 = 2=フルスクリーン app 間移動
    TrackpadFourFingerPinchGesture = 2;               # 四本指ピンチ = Desktop / Launchpad
    TrackpadFourFingerVertSwipeGesture = 2;           # 四本指垂直 = Mission Control / App Exposé
  };

  # NSGlobalDomain 配下の trackpad 関連キー
  system.defaults.NSGlobalDomain = {
    "com.apple.trackpad.scaling" = 3.0;               # トラッキング速度 (0..3)
    "com.apple.trackpad.forceClick" = false;          # force click 無効 (ForceSuppressed と整合)
    "com.apple.swipescrolldirection" = true;          # ナチュラルスクロール ON
  };

  # nix-darwin module が option 化していない trackpad キーを両ドメインに直書き。
  # 内蔵 / Bluetooth で **同じ値** にしないと挙動が割れるため必ず両方書く。
  system.defaults.CustomUserPreferences = {
    "com.apple.AppleMultitouchTrackpad" = {
      TrackpadFiveFingerPinchGesture = 2;             # 五本指ピンチ = Launchpad
      TrackpadHandResting = 1;                        # 手のひら検知
      TrackpadHorizScroll = 1;                        # 横スクロール許可
      TrackpadScroll = 1;                             # スクロール許可
      USBMouseStopsTrackpad = 0;                      # USB マウス接続中も trackpad 有効
      UserPreferences = 1;                            # ユーザー設定を優先 (default の guest 設定を無視)
    };
    "com.apple.driver.AppleBluetoothMultitouch.trackpad" = {
      TrackpadFiveFingerPinchGesture = 2;
      TrackpadHandResting = 1;
      TrackpadHorizScroll = 1;
      TrackpadScroll = 1;
      USBMouseStopsTrackpad = 0;
      UserPreferences = 1;
    };
  };

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
