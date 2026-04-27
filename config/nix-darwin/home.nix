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
    # direnv: Nix の checkPhase が macOS でハング（zsh/fish/bash の統合テスト
    # が TTY 待ちでブロックする）するため doCheck=false でテストを skip する。
    (direnv.overrideAttrs (_: { doCheck = false; }))
    # Migrated from Homebrew (phase 2: medium-risk CLIs with shell integrations)
    gh
    ghq
    zoxide
    starship
    # Migrated from Homebrew (phase 3: low-risk standalone CLIs)
    ffmpeg
    xcodegen
    # fzf: direnv と同様に macOS の checkPhase ハングリスクを避けるため
    # 最初から doCheck=false で起動。問題なければ標準 attr に戻して良い。
    (fzf.overrideAttrs (_: { doCheck = false; }))
    # xcode-build-server: nixpkgs に未収載。brew で運用継続。
    nb
    mint
    uv
    # Migrated from Homebrew (phase 4: safe-tier batch 2)
    tmux
    go
    procps  # `watch` バイナリを提供（Homebrew の watch formula 相当）
    # Migrated from Homebrew (phase 5: editor & runtime)
    neovim
    bun
    # Migrated from Homebrew (phase 6: zsh plugins)
    # 注意: バイナリではなく share/ 配下にスクリプトを配置するパッケージ。
    # autosuggestions は share/zsh/plugins/ に置かれるため自動で profile に
    # merge されるが、syntax-highlighting は share/zsh-syntax-highlighting/
    # （非標準サブディレクトリ）に置かれ、useUserPackages が拾わない。
    # 後段の home.file で安定パスへ symlink して .zshrc から参照する。
    zsh-autosuggestions
    zsh-syntax-highlighting
  ];

  # zsh-syntax-highlighting の本体スクリプトを安定パスへ露出させる。
  home.file.".local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh".source =
    "${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh";
}
