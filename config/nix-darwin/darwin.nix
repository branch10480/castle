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

  # NSGlobalDomain 配下のキー（trackpad / キーボード / テキスト入力補正）。
  # 同じ NSGlobalDomain なので 1 ブロックに集約し、サブコメントで区切る。
  system.defaults.NSGlobalDomain = {
    # ---- trackpad ----
    "com.apple.trackpad.scaling" = 3.0;               # トラッキング速度 (0..3)
    "com.apple.trackpad.forceClick" = false;          # force click 無効 (ForceSuppressed と整合)
    "com.apple.swipescrolldirection" = true;          # ナチュラルスクロール ON

    # ---- キーボード（キーリピート系）----
    # GUI 最速の値 (Initial=15 / KeyRepeat=2) を宣言化。CLI からはさらに小さい値も
    # 入れられるが、KeyRepeat=1 は操作不能になりうるため castle では 2 を下限とする。
    InitialKeyRepeat = 15;                            # キーリピート開始までの遅延 (内部 tick)
    KeyRepeat = 2;                                    # リピート間隔 (GUI 最速 = 2)
    ApplePressAndHoldEnabled = false;                 # 長押し accent ポップアップを無効化（Vim hjkl 等の連打を活かす）
    AppleKeyboardUIMode = 3;                          # ダイアログで Tab が全コントロールを巡回 (0=textのみ, 3=全要素)

    # ---- 自動補正・テキスト置換（全 OFF）----
    # コード / Markdown を主に書く環境では誤検知のほうが大きいので OS レベルで止める。
    # アプリ独自ドメイン（Notes 等）が上書きする場合は別途その domain で対処。
    NSAutomaticCapitalizationEnabled = false;         # 文頭自動大文字化
    NSAutomaticDashSubstitutionEnabled = false;       # -- → em dash
    NSAutomaticPeriodSubstitutionEnabled = false;     # ダブルスペース → ピリオド
    NSAutomaticQuoteSubstitutionEnabled = false;      # "..." → smart quotes
    NSAutomaticSpellingCorrectionEnabled = false;     # スペル自動修正
    NSAutomaticInlinePredictionEnabled = false;       # macOS 15+ のインライン予測入力
  };

  # ====== Dock 設定 ======
  # Dock サイズ・hide 挙動・hot corner を宣言化。
  # tile 配列 (persistent-apps / persistent-others) は手動操作の頻度が高いため
  # 宣言化しない（nix で固定すると並び替えが毎 nrs で巻き戻る）。
  system.defaults.dock = {
    autohide = true;                                  # マウス out で Dock を隠す
    tilesize = 51;                                    # 通常時のアイコンサイズ (px)
    largesize = 113;                                  # zoom 時の最大サイズ (px)
    magnification = true;                             # カーソルホバーで拡大
    minimize-to-application = true;                   # ウィンドウ最小化先をアプリアイコンに統合
    mru-spaces = false;                               # Space を使用順で並べ替えない（位置記憶を保つ）
    show-recents = false;                             # Dock 右側「最近使ったアプリ」セクションを非表示
    wvous-br-corner = 14;                             # 右下 hot corner = Quick Note (14)
                                                      # modifier 系 (wvous-*-modifier) は unset のまま：触れただけで発火
  };

  # ====== Finder 設定 ======
  # 表示 / 検索範囲 / デスクトップアイコンの可視性を宣言化。
  # サイドバー項目 (FK_DefaultTags / ShowSidebar 個別アイテム) は手動カスタム余地が
  # 大きいため宣言化しない。
  system.defaults.finder = {
    AppleShowAllExtensions = true;                    # ファイル拡張子を常に表示
    ShowPathbar = true;                               # 下部パスバー表示
    ShowStatusBar = true;                             # 下部ステータスバー表示
    FXPreferredViewStyle = "clmv";                    # 既定表示形式 = カラムビュー
                                                      # (icnv=icon / Nlsv=list / glyv=gallery / clmv=column)
    FXDefaultSearchScope = "SCcf";                    # 検索範囲 = 現在のフォルダ (SCev=Mac全体)
    _FXSortFoldersFirst = true;                       # フォルダを先に並べる
    NewWindowTarget = "Home";                         # ⌘N の新規ウィンドウ起点 = Home
                                                      # （nix-darwin が friendly enum 化しているため
                                                      #  raw "PfHm" ではなく "Home" を渡す。
                                                      #  選択肢: Computer/OS volume/Home/Desktop/
                                                      #  Documents/Recents/iCloud Drive/Other）
    FXEnableExtensionChangeWarning = false;           # 拡張子変更時の確認ダイアログを抑止
    # デスクトップ表示するボリュームの種類（現状値の宣言化）
    ShowExternalHardDrivesOnDesktop = true;
    ShowHardDrivesOnDesktop = false;
    ShowMountedServersOnDesktop = false;
    ShowRemovableMediaOnDesktop = true;
  };

  # ====== スクリーンショット設定 ======
  # 保存先を Desktop から専用フォルダへ逃がし、Desktop を汚さない。
  # location 先のディレクトリは activationScripts で事前作成する（存在しないと
  # macOS が silent に Desktop へフォールバックするため）。
  system.defaults.screencapture = {
    location = "~/Pictures/Screenshots";
    type = "png";
    disable-shadow = true;                            # ウィンドウキャプチャ時の影を消す
    show-thumbnail = true;                            # 撮影直後の右下サムネイル
  };

  # screencapture.location 指定先を pre-create。存在しないと macOS は silent に
  # Desktop へフォールバックする。
  # nix-darwin は activation を root 一本に統一済み（postUserActivation は削除済）。
  # `postActivation` は root で走るため、ユーザー所有 dir を掘るには sudo -u が必要。
  # ※ カスタム attribute 名 (例: screenshotDir) は activate に source されず
  #    silent ignore されるため、必ず既定キー (preActivation/postActivation) を使う。
  system.activationScripts.postActivation.text = ''
    sudo -u ${username} mkdir -p /Users/${username}/Pictures/Screenshots
  '';

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
      # cmux: Ghostty ベースの AI コーディングエージェント向けターミナル。
      # 旧 NIGHTLY ビルド (`/Applications/cmux NIGHTLY.app`, bundle id
      # `com.cmuxterm.app.nightly`) は brew 管理外で zap の対象外なので、
      # stable 移行後は手動削除が必要。設定 (`~/.config/cmux/cmux.json`、
      # 旧 `settings.json` は cmux v0.64.6 で deprecated) は homeshick 管理。
      # ターミナル描画 (font / theme / keybind) は libghostty 経由で
      # `~/.config/ghostty/config` を共有する (詳細: docs/theme-appearance-switching.md)。
      "cmux"
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
