# nix-darwin + Home Manager

このディレクトリは [nix-darwin](https://github.com/LnL7/nix-darwin) と
[Home Manager](https://github.com/nix-community/home-manager) による
macOS 環境の宣言的構成を管理する。

homeshick の `castle` リポジトリ配下にあり、`home/.config -> ../config` の
シンボリックリンク経由で実体は `~/.config/nix-darwin/` から参照される。

## ファイル構成

| ファイル | 役割 |
| --- | --- |
| `flake.nix` | エントリポイント。inputs（nixpkgs / nix-darwin / home-manager）と `darwinConfigurations` を定義 |
| `darwin.nix` | システムレベル設定。`homebrew` モジュールで Cask / brew / mas を宣言管理 |
| `home.nix`   | Home Manager モジュール。CLI バイナリのみ供給し、dotfiles は homeshick 管理を維持 |
| `flake.lock` | inputs の固定（`nix flake update` で更新） |

## 設計方針

- **CLI = Nix / GUI = Homebrew** で住み分け。
- Homebrew は `homebrew.onActivation.cleanup = "none"` で安全側起動。
  既存パッケージの転記が完了し、差分が落ち着いたら `"zap"` に切り替えを検討。
- `programs.<tool>` 系の HM モジュールは **意図的に有効化しない**。
  zsh / git / nvim 等の設定は homeshick 配下 (`config/`, `home/`) を
  唯一のソース・オブ・トゥルースとし、二重管理を避ける。

## 初期セットアップ

```bash
# Nix 本体（Determinate Systems installer 推奨）
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

# 初回適用
~/.homesick/repos/castle/scripts/bootstrap-nix-darwin.sh
```

## 日常運用

```bash
# 設定を編集後に適用
darwin-rebuild switch --flake ~/.config/nix-darwin

# inputs 更新
nix flake update --flake ~/.config/nix-darwin

# 評価のみ（適用なし）
nix flake check ~/.config/nix-darwin
```

## 既存 Homebrew 環境の取り込み

```bash
brew leaves          # → darwin.nix の brews へ転記
brew list --cask     # → casks へ転記
mas list             # → masApps へ転記
```

転記後 `darwin-rebuild switch` で差分ゼロを確認できたら `cleanup = "zap"` 化。
