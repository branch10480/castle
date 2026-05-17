{ pkgs, lib, username, ... }:

{
  home.username = username;
  home.homeDirectory = "/Users/${username}";

  # Bound to the Home Manager release used at first activation. DO NOT change
  # without reading the HM release notes for the migration path.
  home.stateVersion = "24.11";

  programs.home-manager.enable = true;

  # ─────────────────────────────────────────────────────────────
  # Session env vars (declarative, machine-global)
  # ─────────────────────────────────────────────────────────────
  # Home Manager がこれを ~/.zshenv 相当のシェル起動最上流に export する。
  # ~/.zshrc.d/*.zsh と違って rc ではなく env レイヤなので、GUI 経由の
  # アプリも (シェル経由で起動される限り) この値を継承する。
  home.sessionVariables = {
    # Claude Code auto-compaction の発火しきい値 override (非公式 env var)。
    # デフォルトは約 83.5% で context が満杯近くなるまで圧縮されないが、
    # 大 context での品質低下 (lost-in-the-middle / generation latency 上昇)
    # を避けるため 25% で早めに圧縮を発火させ、常に十分な作業余地を残す運用
    # にする。Anthropic 公式設定として固まったら settings.json のキーに移行
    # する (関連: anthropics/claude-code #25679 / #34925 / #46695 で feature
    # request 受付中)。CLI バージョンアップで env var 名が変わる可能性あり。
    CLAUDE_AUTOCOMPACT_PCT_OVERRIDE = "25";
  };

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
    # mint: nixpkgs の `mint` は Mint Programming Language (mint-lang) で、
    # Swift の yonaskolb/Mint とは別物。Swift 側 mint は `brew install mint`
    # で導入する（Scripts/start.sh が `mint bootstrap` を要求するため）。
    uv
    # Migrated from Homebrew (phase 4: safe-tier batch 2)
    tmux
    go
    procps  # `watch` バイナリを提供（Homebrew の watch formula 相当）
    # Migrated from Homebrew (phase 5: editor & runtime)
    neovim
    bun
    nodejs  # nixpkgs-unstable では現在の LTS (v24)。明示固定したい場合は nodejs_24 等を指定。
    # Migrated from Homebrew (phase 6: zsh plugins)
    # 注意: バイナリではなく share/ 配下にスクリプトを配置するパッケージ。
    # autosuggestions は share/zsh/plugins/ に置かれるため自動で profile に
    # merge されるが、syntax-highlighting は share/zsh-syntax-highlighting/
    # （非標準サブディレクトリ）に置かれ、useUserPackages が拾わない。
    # 後段の home.file で安定パスへ symlink して .zshrc から参照する。
    zsh-autosuggestions
    zsh-syntax-highlighting

    # Migrated from Homebrew (phase 7: secrets management)
    # 1Password CLI. GUI (Homebrew cask `1password`) と併用。Touch ID 解錠・
    # SSH agent・op-ssh-sign は GUI 側が供給するため、本パッケージは `op`
    # バイナリのみを Nix で提供する責務に絞る。
    _1password-cli

    # Re-managed via Nix (phase 8: AI coding agent CLI)
    # OpenAI Codex CLI (Rust binary). 過去は Homebrew cask → 撤去 → npm の
    # `@openai/codex` を global install で運用していたが、nixpkgs に同じ
    # Rust 本体パッケージが入ったため declarative 化。`ripgrep` のみ依存。
    # GUI 版 (codex-app cask) は Nix 配布が無いため darwin.nix の casks で継続。
    # state file (~/.codex/config.toml 等) はバイナリ更新に追従する。
    codex
  ];

  # zsh-syntax-highlighting の本体スクリプトを安定パスへ露出させる。
  home.file.".local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh".source =
    "${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh";

  # tmux プラグインを Nix で provisioning する。TPM (~/.tmux/plugins/tpm/)
  # を使わず、`pkgs.tmuxPlugins.<name>.rtp` (= `<store>/share/tmux-plugins/
  # <name>/<name>.tmux` への passthru パス) を `run-shell` で直接ロードする。
  # `.tmux.conf` 側は末尾の `source-file ~/.tmux/plugins.conf` でこれを取り込む。
  #
  # 利点: `prefix + I` 不要 / store hash で再現性確保 / 新規 Mac で homeshick
  # link 直後から C-h/j/k/l のペイン移動が機能する。
  # トレードオフ: バージョンは nixpkgs channel に追従。プラグイン更新には
  # `nix flake update` が必要。
  home.file.".tmux/plugins.conf".text = ''
    run-shell ${pkgs.tmuxPlugins.sensible.rtp}
    run-shell ${pkgs.tmuxPlugins.vim-tmux-navigator.rtp}
  '';

  # MarkdownObserver(fork) のユーザー CSS をマシン横断で同期する。
  # 組み込みテーマの上に重ねて当たるカラーパレット調整。アプリ側がこの
  # ディレクトリを読み込むので themes/ 配下に固定で配置する。
  home.file."Library/Application Support/MarkdownObserver/themes/user.css".source =
    ./files/markdownobserver/user.css;

  # Codex app の custom pets "Swiftail" / "Swiftail Pixel" を castle 経由で配布する。
  # Codex app は ~/.codex/pets/<pet-id>/pet.json と spritesheet.png を読む。
  # ~/.codex は auth.json / logs / plugin cache などの machine-local state を
  # 含むため丸ごと symlink しない。また custom pets は symlink だと読み込みが
  # 不安定な可能性があるので、Xcode テーマ配布と同じく activation で実体コピーする。
  home.activation.installCodexPetSwiftail =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      pet_dir="$HOME/.codex/pets/swiftail"

      if [ -L "$pet_dir" ] || [ -f "$pet_dir" ]; then
        $DRY_RUN_CMD rm -f "$pet_dir"
      fi

      $DRY_RUN_CMD mkdir -p "$pet_dir"
      $DRY_RUN_CMD install -m 0644 \
        ${../../codex/pet-assets/swiftail/pet-package/pet.json} \
        "$pet_dir/pet.json"
      $DRY_RUN_CMD install -m 0644 \
        ${../../codex/pet-assets/swiftail/pet-package/spritesheet.png} \
        "$pet_dir/spritesheet.png"
      $DRY_RUN_CMD install -m 0644 \
        ${../../codex/pet-assets/swiftail/pet-package/spritesheet.webp} \
        "$pet_dir/spritesheet.webp"
    '';

  home.activation.installCodexPetSwiftailPixel =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      pet_dir="$HOME/.codex/pets/swiftail-pixel"

      if [ -L "$pet_dir" ] || [ -f "$pet_dir" ]; then
        $DRY_RUN_CMD rm -f "$pet_dir"
      fi

      $DRY_RUN_CMD mkdir -p "$pet_dir"
      $DRY_RUN_CMD install -m 0644 \
        ${../../codex/pet-assets/swiftail-pixel/pet-package/pet.json} \
        "$pet_dir/pet.json"
      $DRY_RUN_CMD install -m 0644 \
        ${../../codex/pet-assets/swiftail-pixel/pet-package/spritesheet.png} \
        "$pet_dir/spritesheet.png"
      $DRY_RUN_CMD install -m 0644 \
        ${../../codex/pet-assets/swiftail-pixel/pet-package/spritesheet.webp} \
        "$pet_dir/spritesheet.webp"
    '';

  # Xcode カスタムテーマ "Claude Day" を castle 経由で配布する。
  # ⚠️ Xcode は ~/Library/.../FontAndColorThemes/ 配下の symlink を辿らない
  # （実ファイルとして配置されたものしか custom theme として認識しない）。
  # そのため home.file による symlink ではなく、activation script で
  # 実ファイルとしてコピーする。
  #
  # castle 側のファイル名は空白なし (ClaudeDay.xccolortheme) で Nix のパス
  # リテラルに優しく、配置先のファイル名 ("Claude Day.xccolortheme") は空白
  # ありで Xcode の Settings → Themes 一覧で「Claude Day」と表示される。
  # トークンの出所は claude/skills/htmla/design-system.html。
  home.activation.installXcodeThemeClaudeDay =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD mkdir -p "$HOME/Library/Developer/Xcode/UserData/FontAndColorThemes"
      # 旧 generation の symlink が残っていれば剥がす（home.file 撤去後の保険）
      $DRY_RUN_CMD rm -f "$HOME/Library/Developer/Xcode/UserData/FontAndColorThemes/Claude Day.xccolortheme"
      $DRY_RUN_CMD install -m 0644 \
        ${./files/xcode/ClaudeDay.xccolortheme} \
        "$HOME/Library/Developer/Xcode/UserData/FontAndColorThemes/Claude Day.xccolortheme"
    '';

  # Xcode カスタムテーマ "Claude Day Dark" を配布する。
  # ハイブリッド設計 (editor chrome = Claude Day Dark パレット / syntax =
  # Sunset Dark 化) の Light 版カウンターパート。dark vocabulary は
  # config/ghostty/themes/Claude Day Dark および
  # config/nix-darwin/files/markdownobserver/user.css の dark mode と共有。
  # Light 版と同じ理由で symlink ではなく activation script で実体コピー。
  home.activation.installXcodeThemeClaudeDayDark =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD mkdir -p "$HOME/Library/Developer/Xcode/UserData/FontAndColorThemes"
      $DRY_RUN_CMD rm -f "$HOME/Library/Developer/Xcode/UserData/FontAndColorThemes/Claude Day Dark.xccolortheme"
      $DRY_RUN_CMD install -m 0644 \
        ${./files/xcode/ClaudeDayDark.xccolortheme} \
        "$HOME/Library/Developer/Xcode/UserData/FontAndColorThemes/Claude Day Dark.xccolortheme"
    '';

  # Kaleidoscope カスタムテーマ "Claude Day" を castle 経由で配布する。
  # Kaleidoscope 4 (6.7+) は ~/Library/Application Support/Kaleidoscope/Highlighting/
  # 配下の highlight.js 互換 CSS をテーマ一覧に拾う (undocumented; 公式 docs
  # には記載なし、KSCore 同梱の Highlighting/ と同等経路として実機検証で確定)。
  # `<basename>-light.css` / `<basename>-dark.css` のペアは **1 つのテーマ**
  # として Settings → Highlight Theme に並び、OS appearance に追従して自動切替。
  #
  # CSS 設計 (前回試行 = commit a08ca48 の revert b7e7795 からの学び):
  #   - KSCore 同梱の Solarized-{light,dark}.css と **完全同一のセレクタ集合・
  #     ルール構造**を保持し、各役割グループに Claude Day トークンを置換する形
  #   - `.hljs { color, background }` は維持するが、chrome (diff view 本体の
  #     背景・本文色) は Kaleidoscope app appearance に任せる前提。CSS は
  #     `.hljs-*` token color のみ責任を持つ。前回試行で `.hljs { ... }` の
  #     background が無視され、暗い token color が暗い背景に溶けて "真っ白"
  #     現象が起きたので、chrome 上書きを期待する設計をやめた
  #   - Solarized 互換構造により Kaleidoscope 6.7 の preview re-layout バグ
  #     (前回 `EXC_BREAKPOINT`) を発火させない (本家動作仕様への寄せ)
  #
  # symlink ではなく実ファイルコピー方式は Xcode 配布と同じ理由 (castle のテーマ
  # 配布パターン一貫性、将来の app 仕様変更への保険)。castle 側ファイル名は
  # スペースなし (ClaudeDay-light.css) で Nix path リテラルに優しく、配置先
  # ファイル名はスペースあり ("Claude Day-light.css") で Kaleidoscope の
  # テーマ一覧に「Claude Day」として表示される (KSCore 内蔵 "Atom One-light.css"
  # → "Atom One" 表示と同じ慣習)。
  home.activation.installKaleidoscopeThemeClaudeDayLight =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD mkdir -p "$HOME/Library/Application Support/Kaleidoscope/Highlighting"
      $DRY_RUN_CMD rm -f "$HOME/Library/Application Support/Kaleidoscope/Highlighting/Claude Day-light.css"
      $DRY_RUN_CMD install -m 0644 \
        ${./files/kaleidoscope/ClaudeDay-light.css} \
        "$HOME/Library/Application Support/Kaleidoscope/Highlighting/Claude Day-light.css"
    '';

  # Kaleidoscope カスタムテーマ "Claude Day" の Dark variant を配布する。
  # Light 版とペアで OS appearance Dark のときに自動適用される。
  # 設計の詳細は Light 版コメント参照。
  home.activation.installKaleidoscopeThemeClaudeDayDark =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD mkdir -p "$HOME/Library/Application Support/Kaleidoscope/Highlighting"
      $DRY_RUN_CMD rm -f "$HOME/Library/Application Support/Kaleidoscope/Highlighting/Claude Day-dark.css"
      $DRY_RUN_CMD install -m 0644 \
        ${./files/kaleidoscope/ClaudeDay-dark.css} \
        "$HOME/Library/Application Support/Kaleidoscope/Highlighting/Claude Day-dark.css"
    '';

  # 1Password CLI (~/.config/op) と SSH client (~/.config/ssh) は
  # group/other に read bit があると op / ssh が起動を拒否するため
  # 0700 を強制する。git はディレクトリ mode を追跡しないので、
  # homeshick link 後や新規 clone 後にここで毎回当て直す。
  # 詳細: docs/op-touchid-investigation.md / SSH セットアップ手順 (CLAUDE.md)
  home.activation.fixSensitiveConfigPermissions =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      for d in "$HOME/.config/op" "$HOME/.config/ssh"; do
        if [ -d "$d" ]; then
          $DRY_RUN_CMD chmod 700 "$d"
        fi
      done
      # ~/.config/ssh/config も 600 を強制（git は file mode を追跡するが、
      # 新規 clone 直後に 644 になっていることがあるため保険）。
      if [ -f "$HOME/.config/ssh/config" ]; then
        $DRY_RUN_CMD chmod 600 "$HOME/.config/ssh/config"
      fi
    '';

  # Claude Code の ~/.claude.json (動的 state file) で perplexity MCP の
  # `--env-file` を /tmp/op-mcp-perplexity.env に向け直す jq 局所書換え。
  # tmux ペイン分割時の per-pane Touch ID 回避用 (A.2 ハイブリッド対策)。
  # 詳細: docs/op-touchid-investigation.md / scripts/setup-claude-mcp-perplexity.sh
  #
  # ⚠️ ~/.claude.json は Claude Code が動的に書き換える state file。
  # CLI 起動中に編集すると終了時に巻き戻されるため、`pgrep -x claude` で
  # 検出して skip + 警告。Desktop app は "Claude" (大文字) なのでマッチしない。
  #
  # 例外時 (~/.claude.json 未存在 / perplexity 未設定 / 既に正しい) は
  # 静かに skip するので fresh Mac でも安全に走る。opt-out したい場合は
  # この activation block を nix config から削除すれば良い (script 自体は
  # scripts/setup-claude-mcp-perplexity.sh で常に手動実行可能)。
  home.activation.patchClaudeMcpPerplexity =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      claude_json="$HOME/.claude.json"
      target="/tmp/op-mcp-perplexity.env"

      # 0) 前提チェック
      if [ ! -f "$claude_json" ]; then
        echo "patchClaudeMcpPerplexity: skip (~/.claude.json not found, run claude once to initialize)"
        exit 0
      fi
      if ! ${pkgs.jq}/bin/jq -e '.mcpServers.perplexity' "$claude_json" \
           >/dev/null 2>&1; then
        echo "patchClaudeMcpPerplexity: skip (.mcpServers.perplexity not configured, complete Phase 4 first)"
        exit 0
      fi

      # 1) 既に正しければ no-op
      current=$(${pkgs.jq}/bin/jq -r '.mcpServers.perplexity.args[]?
                  | select(startswith("--env-file="))
                  | sub("--env-file="; "")' "$claude_json" 2>/dev/null || true)
      if [ "$current" = "$target" ]; then
        exit 0
      fi

      # 2) Claude Code CLI 起動中なら触らない (state file 競合防止)
      if pgrep -x "claude" >/dev/null 2>&1; then
        echo "patchClaudeMcpPerplexity: warn — Claude Code CLI is running, skipping"
        echo "  quit claude then re-run: darwin-rebuild switch --flake ~/.config/nix-darwin"
        exit 0
      fi

      # 3) バックアップ + 局所書換え
      $DRY_RUN_CMD cp "$claude_json" \
        "$claude_json.bak.$(date +%Y%m%d-%H%M%S)"
      tmp=$(mktemp)
      $DRY_RUN_CMD ${pkgs.jq}/bin/jq --arg t "--env-file=$target" '
        .mcpServers.perplexity.args = (
          .mcpServers.perplexity.args | map(
            if startswith("--env-file=") then $t else . end
          )
        )
      ' "$claude_json" > "$tmp" \
        && $DRY_RUN_CMD mv "$tmp" "$claude_json"
      echo "patchClaudeMcpPerplexity: patched ~/.claude.json mcpServers.perplexity --env-file -> $target"
    '';

  # Claude Code の ~/.claude/settings.json に castle 起源の hooks セクションを
  # 流し込む。settings.json は `extraKnownMarketplaces` の絶対パスや
  # `enabledPlugins` などマシン固有の値を含む machine-local ファイルなので
  # 丸ごと symlink せず、**`.hooks` キーだけ**を jq で部分上書きする。
  #
  # 真実の源は下の `desired=...` ブロック (heredoc)。ここを編集して
  # darwin-rebuild switch すれば全 Mac の `~/.claude/settings.json` に
  # 同じ hooks が反映される。手動同期スクリプトは不要。
  #
  # 現状の hooks:
  #   - Stop / SubagentStop で tmux pane-border override を unset
  #     (scripts/tmux-clear-pane-border-overrides.sh)
  #
  # ⚠️ ~/.claude/settings.json は ~/.claude.json ほど頻繁ではないが
  # Claude Code が GUI 経由などで書き換える可能性がある。安全側で
  # `pgrep -x claude` で CLI 起動中は skip。バックアップは patchClaudeMcpPerplexity
  # と同じ命名規則 (.bak.YYYYMMDD-HHMMSS)。
  home.activation.patchClaudeHooks =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      settings_json="$HOME/.claude/settings.json"
      cleanup_script="$HOME/.homesick/repos/castle/scripts/tmux-clear-pane-border-overrides.sh"

      # castle 起源の hooks JSON。これを編集して darwin-rebuild switch すれば
      # 全 Mac に同期される。
      desired=$(${pkgs.jq}/bin/jq -n --arg cmd "$cleanup_script" '{
        Stop:         [{ hooks: [{ type: "command", command: $cmd }] }],
        SubagentStop: [{ hooks: [{ type: "command", command: $cmd }] }]
      }')

      # 0) 前提チェック
      if [ ! -f "$settings_json" ]; then
        echo "patchClaudeHooks: skip (~/.claude/settings.json not found, run claude once to initialize)"
        exit 0
      fi

      # 1) 既に正しければ no-op (キー順を揃えて比較するため -S)
      current=$(${pkgs.jq}/bin/jq -S -c '.hooks // {}' "$settings_json" 2>/dev/null || echo '{}')
      expected=$(echo "$desired" | ${pkgs.jq}/bin/jq -S -c .)
      if [ "$current" = "$expected" ]; then
        exit 0
      fi

      # 2) Claude Code CLI 起動中なら触らない
      if pgrep -x "claude" >/dev/null 2>&1; then
        echo "patchClaudeHooks: warn — Claude Code CLI is running, skipping"
        echo "  quit claude then re-run: darwin-rebuild switch --flake ~/.config/nix-darwin"
        exit 0
      fi

      # 3) バックアップ + 局所書換え
      $DRY_RUN_CMD cp "$settings_json" \
        "$settings_json.bak.$(date +%Y%m%d-%H%M%S)"
      tmp=$(mktemp)
      $DRY_RUN_CMD ${pkgs.jq}/bin/jq --argjson hooks "$desired" '
        .hooks = $hooks
      ' "$settings_json" > "$tmp" \
        && $DRY_RUN_CMD mv "$tmp" "$settings_json"
      echo "patchClaudeHooks: patched ~/.claude/settings.json .hooks"
    '';
}
