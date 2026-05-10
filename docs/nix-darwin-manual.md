# nix-darwin 運用マニュアル

このリポジトリ (`castle`) における **nix-darwin + Home Manager + 宣言 Homebrew** の
運用手順をまとめたドキュメント。日々の操作・トラブル対応・設計意図の参照用。

> [!NOTE]
> 構成ファイルの実体は `castle/config/nix-darwin/` に存在し、homeshick の
> `home/.config -> ../config` symlink により `~/.config/nix-darwin/` から参照される。

---

## 1. 全体像

```mermaid
flowchart LR
    flake[flake.nix<br/>入口] --> darwin[darwin.nix<br/>システム全体]
    flake --> home[home.nix<br/>ユーザー領域]
    darwin -- 宣言 --> brew[(Homebrew<br/>tap/brew/cask/mas)]
    home -- 宣言 --> nixpkgs[(nixpkgs<br/>CLI ツール群)]
    flake -. 固定 .-> lock[flake.lock]
```

| ファイル | 役割 | 何を書く |
| --- | --- | --- |
| `flake.nix` | エントリポイント | inputs（nixpkgs / nix-darwin / home-manager）と `darwinConfigurations` |
| `darwin.nix` | システム全体（root 権限） | `/etc/*`, launchd, Homebrew 宣言, `system.primaryUser` |
| `home.nix` | ユーザー領域 (`~/`) | CLI ツール（`home.packages`）, 個人 launchd agent |
| `flake.lock` | inputs 固定 | 自動生成・コミット対象 |

### 設計方針

- **CLI = Nix / GUI = Homebrew** で住み分け。
- `programs.<tool>` 系の Home Manager モジュールは **意図的に有効化しない**。
  zsh / git / nvim 等の設定は homeshick 配下を唯一のソース・オブ・トゥルースとし、
  `~/.config/*` の二重管理を避ける。
- Homebrew は `homebrew.onActivation.cleanup = "none"` で安全側起動。
  未宣言パッケージを自動削除する `"zap"` への切り替えは、移管が安定してから検討。

---

## 2. 日常運用コマンド

### 2.1 設定変更を反映する

```bash
sudo darwin-rebuild switch --flake ~/.config/nix-darwin
```

- **sudo 必須**。最近の nix-darwin は activation を root 化した。
- 所要時間: 軽微な変更なら 30 秒〜1 分。新規パッケージのビルド/取得が走ると数分。
- 完了時に `Activating ...` 系のログが流れて、最後にプロンプトに戻る。

### 2.2 inputs を更新する

```bash
nix flake update --flake ~/.config/nix-darwin
sudo darwin-rebuild switch --flake ~/.config/nix-darwin
```

- `nix flake update` は `flake.lock` を最新の nixpkgs / nix-darwin / home-manager に書き換える。
- そのまま switch すれば反映。問題があれば `git checkout flake.lock` で巻き戻せる。

### 2.3 評価のみ（適用なし）

```bash
nix flake check ~/.config/nix-darwin
```

- 構文エラー・型エラーを早期検出。実環境に変更を加えない。
- 編集中に走らせて素早くフィードバックを得る用。

### 2.4 状態確認

```bash
darwin-rebuild --list-generations           # これまでの世代一覧
sudo darwin-rebuild rollback                # 直前の世代に戻す
nix-env --list-generations -p /nix/var/nix/profiles/system   # 同上 (詳細版)
```

- generation は世代管理。環境を壊しても直前に戻せるのが Nix の強み。

---

## 3. パッケージ管理

### 3.1 CLI ツールを追加する（Nix）

> [!IMPORTANT]
> 追加する前に nixpkgs での提供有無を確認する:
> ```bash
> nix --extra-experimental-features 'nix-command flakes' eval --raw \
>   "github:NixOS/nixpkgs/nixpkgs-unstable#<name>.pname"
> ```
> 未収載のツール（例: `xcode-build-server`）は brew のままにする。

`home.nix` の `home.packages` に追加して switch:

```nix
home.packages = with pkgs; [
  ...既存...
  ripgrep
  fd
  bat
];
```

```bash
sudo darwin-rebuild switch --flake ~/.config/nix-darwin
which <tool>   # /etc/profiles/per-user/$USER/bin/<tool> を返せば OK
```

### 3.2 GUI アプリを追加する（Homebrew Cask）

`darwin.nix` の `homebrew.casks` に追加:

```nix
casks = [
  ...既存...
  "iterm2"
  "discord"
];
```

switch すると `brew install --cask <name>` が自動実行される。

### 3.3 サードパーティ tap を使う

```nix
taps = [
  "homebrew/services"
  "anomalyco/tap"        # 例: anomalyco/tap/opencode を入れる場合
];

brews = [
  "anomalyco/tap/opencode"
];
```

- `<owner>/<tap>/<formula>` 形式で書けば自動で tap 解決される。
- 明示的に `taps` に書いた方が依存関係が読みやすい（推奨）。

### 3.4 Mac App Store アプリを追加する（mas）

```bash
brew install mas              # 初回のみ
mas list                      # アプリ ID を取得
```

```nix
masApps = {
  "Xcode" = 497799835;
  "Magnet" = 441258766;
};
```

---

## 4. brew → Nix 移管手順

CLI ツールを Homebrew から Nix 管理へ移したい場合の安全手順。

### 4.1 標準フロー

1. **Nix 側に追加**（`home.nix` の `home.packages` に書く）
2. **switch して Nix 版が PATH に乗ることを確認**
   ```bash
   sudo darwin-rebuild switch --flake ~/.config/nix-darwin
   exec "$SHELL" -l    # 新シェルで PATH を読み直し
   which <tool>   # /etc/profiles/per-user/.../bin/<tool> を期待
   ```
3. **brew 側を削除**（`darwin.nix` の `brews` からコメントアウト）
4. もう一度 switch（宣言を反映）
5. **brew バイナリの実体を掃除**
   ```bash
   brew uninstall <tool>
   which <tool>   # まだ Nix 版が見えれば成功
   ```

### 4.2 リスク別の移管推奨順

| リスク | 対象 | 注意点 |
| --- | --- | --- |
| 低 | `tree`, `watch`, `jq`, `ripgrep`, `fd`, `bat`, `eza`, `tig` | 単発 CLI、設定なし。安全 |
| 中 | `gh`, `ghq`, `zoxide`, `starship` | シェル統合あり。動作確認しっかり |
| 対処済み | `direnv`, `fzf` | macOS で checkPhase ハングリスクあり → `doCheck=false` で回避（実例あり） |
| 高 | `neovim`, `tmux` | プラグイン管理が効く。設定の互換性確認 |
| 高 | `node`, `go` | anyenv と競合する可能性。最後に検討 |
| nixpkgs 未収載 | `xcode-build-server` 等 | nixpkgs に存在しないツールは brew のまま運用 |

### 4.3 checkPhase ハング回避

direnv のように Nix のテストが macOS で固まる場合の選択肢:

- **A**: brew のままにする（合理的）
- **B**: `home.packages` で `overrideAttrs` を使ってテスト無効化（**実績あり**）

```nix
home.packages = with pkgs; [
  ...
  (direnv.overrideAttrs (_: { doCheck = false; }))
  (fzf.overrideAttrs (_: { doCheck = false; }))
];
```

`fzf` のように **実際には今ハングしないが過去に実績がある** ツールは、保険として
`doCheck = false` を残すか、標準ビルドに戻すか運用判断する。安定が確認できたら
override を外して標準ビルドに戻す方が望ましい。

### 4.4 シェル hook を持つツール移管時の追加手順

`direnv` / `zoxide` / `starship` 等は **シェル起動時に `eval "$(<tool> hook zsh)"` で
hook 関数を生成し、その中に当該バイナリのフルパスが焼き込まれる**。
brew → Nix 移管時の流れ:

1. Nix 版インストール（switch）
2. `brew uninstall <tool>` で旧バイナリを物理削除
3. `exec "$SHELL" -l` で新シェル起動 → hook 関数が Nix 版のパスで再生成される
4. `<tool> hook zsh | head -5` で `/nix/store/.../bin/<tool>` が埋め込まれていることを確認

`brew uninstall` を飛ばすと「hook が brew パスを参照したまま、実体は消えている」状態
になり、`_direnv_hook:2: no such file or directory: ...` エラーが出続ける。

---

## 5. 既知の落とし穴

### 5.1 PATH 順序: Homebrew が Nix を上書きする

macOS の `/etc/zprofile` が `path_helper` を呼び、`/etc/paths.d/Homebrew` を読んで
`/opt/homebrew/bin` を **PATH 先頭に再挿入** する。これが nix-darwin の `/etc/zshrc` より
**後**に効くため、放置すると brew 版が常に勝つ。

**対処**: `home/.zshrc` 冒頭で Nix プロファイルを強制 prepend:

```bash
for _nix_dir in \
  "/etc/profiles/per-user/$USER/bin" \
  /run/current-system/sw/bin \
  /nix/var/nix/profiles/default/bin; do
  [[ -d "$_nix_dir" ]] && PATH="$_nix_dir:${PATH//$_nix_dir:/}"
done
unset _nix_dir
export PATH
```

### 5.2 sudo パスワードと TTY

`sudo darwin-rebuild` は対話入力を要求するので、Claude Code のような非 TTY 環境からは
直接実行できない。**必ず手元のターミナル**で叩く。

### 5.3 `system.primaryUser` の必須化

最近の nix-darwin は activation を root 化した影響で、`homebrew.enable` などの
ユーザー紐付けオプションは `system.primaryUser` 明示が必須。未設定だと:

```
error: Failed assertions: ... `homebrew.enable` ...
       you have been using to run `darwin-rebuild`.
```

→ `darwin.nix` に `system.primaryUser = "<username>";` を追加する。

### 5.4 deprecated `homebrew.global.lockfiles`

Homebrew 4.4.0 (2024-10) で lockfile 機能が削除されたため、
`homebrew.global.lockfiles` / `noLock` は no-op。設定から削除すべし（warning が出る）。

### 5.5 `/Users/...` not owned by you の警告

```
warning: $HOME ('/Users/...') is not owned by you, falling back to /var/root
```

`sudo` 配下で `$HOME` が継承されているための無害警告。動作に影響なし。
気になる場合は `sudo -H darwin-rebuild ...` を使う。

### 5.6 `useUserPackages` は `share/<任意名>/` を merge しない

home-manager の `useUserPackages = true` は store path 配下の **定型ディレクトリ**
（`bin/`, `lib/`, `share/man/`, `share/info/`, `share/zsh/`, `share/locale/`,
`share/terminfo/` など）だけを `/etc/profiles/per-user/$USER/` に merge する。

つまり、パッケージが `share/<custom-name>/` のような非標準サブディレクトリに
ファイルを置くと、profile 配下からは見えなくなる。

**実例**: `zsh-syntax-highlighting`
- 本体: `/nix/store/.../share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh`
- profile: 露出しない（`share/zsh-syntax-highlighting/` は捨てられる）

**対応パターン**: `home.nix` の `home.file` で安定パスへ symlink する。

```nix
home.file.".local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh".source =
  "${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh";
```

`darwin-rebuild switch` のたびに symlink が貼り直されるので、store path の
バージョン変動にも自動追従。`.zshrc` 側はバージョンを意識せず source できる。

参考: 同じ作りでも `zsh-autosuggestions` は `share/zsh/plugins/...` に置かれる
ため `share/zsh/` 経由で自動 merge され、追加対応は不要。

### 5.7 ロールバック

何か壊れたら:

```bash
sudo darwin-rebuild rollback
```

または特定の世代に戻す:

```bash
darwin-rebuild --list-generations
sudo darwin-rebuild switch --switch-generation <番号>
```

### 5.8 `/etc/bashrc` / `/etc/zshrc` Unexpected files エラー（初回 activation）

新規マシンの初回 `darwin-rebuild switch` で以下のように停止することがある:

```
error: Unexpected files in /etc, aborting activation
The following files have unrecognized content and would be overwritten:
  /etc/bashrc
  /etc/zshrc
Please check there is nothing critical in these files, rename them by adding
.before-nix-darwin to the end, and then try again.
```

**原因**: nix-darwin は `/etc/bashrc` `/etc/zshrc` 等を自分で管理対象にしようとするが、既存ファイルの内容ハッシュが「macOS 出荷時」「nix-darwin 由来」のいずれにも一致しない場合は安全装置が発動して停止する。Determinate Systems Nix インストーラが Nix daemon の PATH 設定行を追記したケースなどで該当する。

**対処**: メッセージ通りリネームして再実行:

```bash
sudo mv /etc/bashrc /etc/bashrc.before-nix-darwin
sudo mv /etc/zshrc  /etc/zshrc.before-nix-darwin
sudo darwin-rebuild switch --flake ~/.config/nix-darwin
```

リネーム後は nix-darwin が新しい `/etc/bashrc` `/etc/zshrc` を `/etc/static/` 配下の symlink として作り直す。Nix daemon の PATH も新しい方には自動的に組み込まれるので機能は失われない。リネームなのでいつでも元に戻せる安全な操作。

### 5.9 既存 `/opt/homebrew/bin/<tool>` と cask の衝突

cask を新たに `homebrew.casks` に宣言した時、`brew bundle` が以下のように失敗することがある:

```
Installing codex
Installing codex has failed!
==> Installing Cask codex
Error: It seems there is already a Binary at '/opt/homebrew/bin/codex'.
==> Purging files for version 0.124.0 of Cask codex
```

**原因**: その cask が `/opt/homebrew/bin/<tool>` に symlink を張ろうとしたが、既に **別経路** (formula、npm `-g`、手動 symlink、別 cask など) で同名のバイナリが存在しているため Homebrew が上書きを拒否する。

**対処の選択肢**:

| 方針 | アクション |
| --- | --- |
| **既存を残し cask 宣言を外す** | `darwin.nix` の `casks` から該当行を削除。npm/anyenv 等で更新を回したい CLI 向け |
| **cask 版にバトンタッチ** | `rm /opt/homebrew/bin/<tool>`（user 所有 symlink なら sudo 不要）→ `darwin-rebuild switch` 再実行 |
| **両方残したいが衝突回避** | 既存を別パス（例 `/opt/homebrew/bin/<tool>.npm`）にリネームし、cask は既定パスに置く |

**実例**: `codex` は OpenAI Codex CLI で、cask 版と npm 版 `@openai/codex` の両方が存在する。本リポジトリでは npm 管理を選択して cask 宣言から外している（`darwin.nix` の `casks` リスト直前のコメント参照）。

> [!TIP]
> ログの末尾には `Using ghostty 1.x.x` のように **失敗とは無関係の "Using" 表示**が
> 続くことがある。`brew bundle` は失敗 1 件でも処理を継続して残りを `Using` として
> 列挙するため、エラー本体は **`failed to install` の前**を `grep` する必要がある。

### 5.10 アプリ別 symlink 非対応の罠（Xcode テーマ等）

Home Manager の `home.file` は **store path への symlink** をホーム配下に貼る方式で、ほとんどのアプリはこれを正しく解決する（`~/.zshrc`、`~/.config/<app>/config` など）。**しかし Xcode のカスタムテーマだけは、symlink ではなく実ファイルでないと認識されない**。

#### 症状

`config/nix-darwin/files/xcode/MyTheme.xccolortheme` を `home.file."Library/Developer/Xcode/UserData/FontAndColorThemes/MyTheme.xccolortheme".source = ...;` で配布すると:

```bash
ls -la ~/Library/Developer/Xcode/UserData/FontAndColorThemes/
# → MyTheme.xccolortheme -> /nix/store/.../MyTheme.xccolortheme  (symlink として作成成功)

# しかし Xcode の Settings → Themes には MyTheme が出てこない
```

同じディレクトリに **`cp -L` で実ファイルとして配置**すると Themes 一覧に現れる。Xcode が theme 検出時に `realpath` 経由で symlink を辿らない実装になっている疑い。

#### 対処パターン: `home.activation` で `install -m 0644`

`home.file`（symlink）ではなく、`home.activation` で実ファイルとしてコピーする：

```nix
{ lib, ... }:
{
  home.activation.installXcodeThemeMyTheme =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD mkdir -p "$HOME/Library/Developer/Xcode/UserData/FontAndColorThemes"
      # 旧 generation の symlink が残っていれば剥がす（home.file 撤去後の保険）
      $DRY_RUN_CMD rm -f "$HOME/Library/Developer/Xcode/UserData/FontAndColorThemes/MyTheme.xccolortheme"
      $DRY_RUN_CMD install -m 0644 \
        ${./files/xcode/MyTheme.xccolortheme} \
        "$HOME/Library/Developer/Xcode/UserData/FontAndColorThemes/MyTheme.xccolortheme"
    '';
}
```

> 上記はテンプレ。実装側 (`config/nix-darwin/home.nix`) では `{ pkgs, lib, username, ... }:` で他の引数も受けつつ、`installXcodeThemeClaudeDay` という具体名で `Claude Day.xccolortheme` を配置している。テンプレと実装の対比は本節末「実装」サブセクション参照。

ポイント：

- `lib.hm.dag.entryAfter [ "writeBoundary" ]` で `home.file` の symlink 配置 (`writeBoundary`) より後に走らせる
- `$DRY_RUN_CMD` を前置すると `home-manager build`（dry-run モード）で実行されない
- `install -m 0644` で **mode を明示**しつつ、必要なら親ディレクトリ作成 (`-D` オプション併用) や既存ファイル上書きも 1 動詞でこなせる。`cp` だと nix store 由来の `0444` (read-only) を引き継いでしまい、**Xcode が theme を再書き換えするシナリオ** (例: Settings → Themes 上で当該テーマを fork して "Duplicate" した時、Xcode は元ファイルへの書き込み属性を期待するため、`0444` 由来のファイルでは UI 操作が失敗する) で詰む
- `${./files/xcode/MyTheme.xccolortheme}` の Nix path リテラルは flake では **git tracked なファイルのみ**見える（§9 トラブルシューティング表 "not tracked by Git" 行参照）

#### 同種の罠が疑われる挙動を見たら

「`home.file` で symlink を貼ったが、アプリの設定 UI に出てこない / 機能しない」場合、まず symlink を実ファイルに置き換えて確認する：

```bash
TARGET="$HOME/Library/.../<app>/<file>"
cp -L "$TARGET" "${TARGET%.${TARGET##*.}}.real.${TARGET##*.}"
# → アプリで .real.<ext> 側だけ認識されたら、symlink 非対応確定
```

実ファイル必須が確定したら、当該ファイルだけ `home.activation` 経路に切り替える。`home.file` で済むファイルは積極的に symlink を維持する（store path の世代追従が効くメリット）。

#### MarkdownObserver のような対称的な例

同じ `~/Library/Application Support/` 配下でも **MarkdownObserver は symlink を尊重する**。アプリ実装次第なので、「`~/Library/` 配下は全部 activation 経路」のような過剰反応はせず、**罠が確認できたファイルだけ activation に切り替える**のがミニマル。

#### 実装

`config/nix-darwin/home.nix` の `home.activation.installXcodeThemeClaudeDay` を参照。同じ Xcode テーマでも MarkdownObserver の `user.css` は `home.file` のままで動いている対比も含めて読むと意図が掴める。

---

## 6. ファイル別の編集の流れ

### 6.1 「全マシン共通の追加」をしたい場合

→ `darwin.nix` または `home.nix` を直接編集 → switch → `/castle` で push。

### 6.2 「このマシンでだけ動かしたい」場合

マルチホスト構成への移行手順は **§7.2** を参照。
共通設定だけで済む段階では `flake.nix` にホストエントリを足すだけで OK。

---

## 7. 別マシンへの展開

### 7.1 単純複製（同じセットアップでよい場合）

```bash
# ターゲットマシンで
git clone git@github.com:branch10480/castle.git ~/.homesick/repos/castle
homeshick link castle

# Nix インストール
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

# 適用
~/.homesick/repos/castle/scripts/bootstrap-nix-darwin.sh
```

### 7.2 仕事マシンを別ホストとして追加する手順

例: 仕事用マシン `WorkMBA` を追加し、private 機 (`ToshiharunoMacBook-Pro`) と差分管理する。

#### Step 1. ターゲットマシンの hostname を確認

```bash
# 仕事マシン側で
scutil --get LocalHostName   # 例: WorkMBA
hostname -s
```

`flake.nix` の `darwinConfigurations` のキーはこの hostname と一致させる。

#### Step 2. `flake.nix` にホストエントリを追加

> [!NOTE]
> 現行実装の `mkDarwin` は `{ hostname, username }` の attrset を受け取る形に
> 拡張済み（`flake.nix:23` 参照）。username を **ホストごとに切り替えられる**
> ので、業務用 / 私用でアカウント名が違っても同一 flake で管理できる。

```nix
darwinConfigurations = {
  "ToshiharunoMacBook-Pro" =
    mkDarwin { hostname = "ToshiharunoMacBook-Pro"; username = "toshiharuimaeda"; };
  "WorkMBA" =
    mkDarwin { hostname = "WorkMBA"; username = "t-imaeda"; };    # ← 追加
  default =
    mkDarwin { hostname = "ToshiharunoMacBook-Pro"; username = "toshiharuimaeda"; };
};
```

これだけで両機共通の `darwin.nix` / `home.nix` が当たるようになる。

#### Step 3. ホスト別の差分が必要な場合だけディレクトリ分割

共通設定で済むなら Step 2 で終了。仕事用にだけ入れたいパッケージや、
private にしか入れたくないものが出てきた段階で構造を分ける:

```
config/nix-darwin/
├── flake.nix
├── modules/
│   ├── common-darwin.nix      # 既存 darwin.nix の共通部分
│   └── common-home.nix        # 既存 home.nix の共通部分
└── hosts/
    ├── private/
    │   ├── darwin.nix         # private 専用 (例: hammerspoon, vlc)
    │   └── home.nix
    └── work/
        ├── darwin.nix         # 仕事専用 (例: 社内ツール、Slack)
        └── home.nix
```

`flake.nix` の `mkDarwin` を以下のように改造:

```nix
mkDarwin = hostname: hostDir:
  nix-darwin.lib.darwinSystem {
    inherit system;
    specialArgs = { inherit username hostname; };
    modules = [
      ./modules/common-darwin.nix
      (./hosts + "/${hostDir}/darwin.nix")
      home-manager.darwinModules.home-manager
      {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.extraSpecialArgs = { inherit username; };
        home-manager.users.${username} = import (./hosts + "/${hostDir}/home.nix");
        networking.hostName = hostname;
        networking.computerName = hostname;
      }
    ];
  };

darwinConfigurations = {
  "ToshiharunoMacBook-Pro" = mkDarwin "ToshiharunoMacBook-Pro" "private";
  "WorkMBA"                = mkDarwin "WorkMBA" "work";
};
```

各 `hosts/<name>/darwin.nix` は `imports = [ ../../modules/common-darwin.nix ];`
で共通部分を取り込み、上書きしたいキーだけ書く。

#### Step 4. ユーザー名が違う場合（**現行採用の構成**）

`mkDarwin` を attrset 受け取りにすると、ホスト別に username を分岐できる。
本リポジトリで実採用済みの形がこちら:

```nix
mkDarwin = { hostname, username }:
  nix-darwin.lib.darwinSystem {
    inherit system;
    specialArgs = { inherit username hostname; };
    modules = [
      ./darwin.nix
      home-manager.darwinModules.home-manager
      {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.extraSpecialArgs = { inherit username; };
        home-manager.users.${username} = import ./home.nix;
        networking.hostName = hostname;
        networking.computerName = hostname;
      }
    ];
  };

darwinConfigurations = {
  "ToshiharunoMacBook-Pro" =
    mkDarwin { hostname = "ToshiharunoMacBook-Pro"; username = "toshiharuimaeda"; };
  "lymL7VFGX9MD3" =
    mkDarwin { hostname = "lymL7VFGX9MD3"; username = "toimaeda"; };
};
```

`darwin.nix` 側の `system.primaryUser = username;` と `users.users.${username}` は
`specialArgs` 経由で受け取っているのでそのまま動く。新ホストを足したいときは
`darwinConfigurations` に attrset エントリを 1 行追加するだけ。

> [!TIP]
> hostname に macOS が自動付与した識別子（例: `lymL7VFGX9MD3`）を使う場合、
> `bootstrap-nix-darwin.sh` は `hostname -s` の出力で `darwinConfigurations.<key>`
> を引き当てるので、**flake のキーを実機 hostname と完全一致させる**のが最も
> 安全。一致するエントリが無い場合は `default` にフォールバックするが、その
> `default` が他ホスト用なら activation で `users.users.<user>` 不在エラーで
> 落ちる点に注意。

#### Step 5. 仕事マシン側で初回適用

```bash
# 1) dotfiles を入れる
brew install homeshick   # まだ無ければ
homeshick clone branch10480/castle
homeshick link castle

# 2) Nix を入れる
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
exec "$SHELL" -l

# 3) 初回 switch（hostname が flake のキーと一致していれば --flake . でOK）
sudo darwin-rebuild switch --flake ~/.config/nix-darwin#WorkMBA
```

以後は `darwin-rebuild switch --flake ~/.config/nix-darwin` で日常運用可。

#### Step 6. 機密差分の扱い

仕事専用の社内 tap・private registry など **公開リポジトリにコミットしたくない**
設定が出たら、`hosts/work/local.nix` を `.gitignore` に入れて参照する:

```nix
# hosts/work/darwin.nix
imports = [
  ../../modules/common-darwin.nix
  ./local.nix   # gitignored
];
```

または `~/.zshrc.local` と同様に、castle 外のディレクトリに置いて
`builtins.readFile` 等で取り込む方式も可。

---

## 8. クリーンアップ運用（cleanup モード）

`darwin.nix` の `homebrew.onActivation.cleanup` で挙動を選択:

| 値 | 挙動 | 用途 |
| --- | --- | --- |
| `"none"` | 宣言外の brew/cask に触らない | **現在の値**。安全運用、検証期間中 |
| `"uninstall"` | 宣言外を `brew uninstall` する | バイナリは消すが、tap や設定は残す |
| `"zap"` | `brew uninstall --zap` 相当（設定ファイルも削除） | 完全宣言管理。理想形だが破壊的 |

**`"zap"` への切り替え条件**:
- すべての brew/cask が宣言と一致していること
- 試験的に `brew install` した一時パッケージが残っていないこと
- 普段から「宣言ファースト」で運用する習慣がついていること

---

## 9. トラブルシューティング早見表

| 症状 | 原因 | 対処 |
| --- | --- | --- |
| `which <tool>` が brew 版を返す | PATH 順序 | `exec "$SHELL" -l` で再読込。それでもなら §5.1 |
| `system activation must now be run as root` | sudo 忘れ | `sudo darwin-rebuild switch ...` |
| `homebrew.enable ... primaryUser` エラー | `system.primaryUser` 未設定 | §5.3 |
| `nix flake check` で `not tracked by Git` | flake は git tracked ファイルしか見ない | `git add -N <file>` で intent-to-add |
| direnv ビルドが固まる | checkPhase ハング | §4.3 の `doCheck=false` で回避 |
| `_direnv_hook:2: no such file or directory: ...` | hook が古い brew パスを参照 | §4.4: `brew uninstall <tool>` → `exec "$SHELL" -l` |
| switch が途中で止まる | `Sorry, try again.` 後の再入力 / ネットワーク | `Ctrl+C` 後に再実行 |
| 環境を壊した | activation 失敗 | `sudo darwin-rebuild rollback` |
| 初回 activation で `Unexpected files in /etc` で停止 | nix-darwin の安全装置 | §5.8（`.before-nix-darwin` リネーム） |
| `Installing <cask> has failed!` / `there is already a Binary at ...` | 既存 brew/npm/手動 symlink との衝突 | §5.9（cask 宣言を外す or 既存削除） |

---

## 10. 参照リンク

- [nix-darwin (LnL7/nix-darwin)](https://github.com/LnL7/nix-darwin)
- [Home Manager (nix-community/home-manager)](https://github.com/nix-community/home-manager)
- [nix-darwin Manual](https://daiderd.com/nix-darwin/manual/index.html)
- [nixpkgs (NixOS/nixpkgs)](https://github.com/NixOS/nixpkgs)
- [Determinate Nix Installer](https://github.com/DeterminateSystems/nix-installer)
- [Homebrew Bundle 仕様](https://docs.brew.sh/Manpage#bundle-subcommand)

---

## 11. 関連ファイル

- `config/nix-darwin/flake.nix` — 入口
- `config/nix-darwin/darwin.nix` — システム宣言
- `config/nix-darwin/home.nix` — ユーザー宣言
- `config/nix-darwin/flake.lock` — inputs 固定（自動生成）
- `config/nix-darwin/README.md` — 短縮版概要
- `scripts/bootstrap-nix-darwin.sh` — 初回適用スクリプト
- `home/.zshrc` — Nix PATH 強制 prepend ブロックを含む
- `CLAUDE.md` — リポジトリ全体の概要に nix-darwin 節あり

## 12. 便利エイリアス

`home/.zshrc` で定義済み:

```bash
nixman      # このマニュアル (docs/nix-darwin-manual.md) を nvim で開く
nrs         # sudo darwin-rebuild switch --flake ~/.config/nix-darwin
nrb         # darwin-rebuild --rollback
nrl         # darwin-rebuild --list-generations
nru         # nix flake update --flake ~/.config/nix-darwin（inputs を最新化）
nrgc        # system + user 両 profile の "14日より古い" 世代を削除して容量回収
```

`nrs` の名前は **n**ix **r**ebuild **s**witch の略。`nrb` = rollback、`nrl` = list、`nru` = update、`nrgc` = garbage collect。

### 通常の更新フロー

```bash
nru                                                       # flake.lock を更新
git -C ~/.config/nix-darwin diff flake.lock | head -80    # 破壊的差分が無いか確認
nrs                                                       # システムへ反映
nrl                                                       # 世代を確認（問題あれば nrb）

# castle へ反映（別マシンへ伝搬させるため）
cd ~/.homesick/repos/castle && git add config/nix-darwin/flake.lock && git commit -m "chore(nix-darwin): bump flake inputs" && git push
```

> ⚠️ `~/.config/nix-darwin/flake.lock` は castle の `config/nix-darwin/flake.lock` の実体（homeshick リンク）。`nru` で書き換わるので **castle 側でコミットを忘れると別マシンに更新が伝わらない**。

### 容量回収（`nrgc`）の挙動

- `nix-collect-garbage` は **system profile（root）** と **user profile（home-manager）** を別々に管理する。`nrgc` は両方を 1 コマンドで掃除する zsh 関数。
- `--delete-older-than 14d` を採用しているため、直近 2 週間の世代は残る → `nrb` で戻れる安全マージン付き。
- それでも容量が足りない時は手動で `sudo nix-collect-garbage -d && nix-collect-garbage -d` を流す（rollback 余地は失われる）。
