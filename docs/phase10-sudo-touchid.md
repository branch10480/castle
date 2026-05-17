# Phase 10: `sudo` を Touch ID で承認する

`darwin-rebuild switch` をはじめとする `sudo` 実行を Touch ID で承認できるようにする。castle が頼る password 入力のうち実用上いちばん頻度が高いのは sudo なので、ここを潰すと「Mac で password を打つ機会」が login 画面以外ほぼ無くなる。

## 構成

- `config/nix-darwin/darwin.nix` の `security.pam.services.sudo_local` ブロックで宣言的に有効化:
  ```nix
  security.pam.services.sudo_local = {
    enable = true;
    touchIdAuth = true;
    reattach = true;
  };
  ```
- nix-darwin が `/etc/pam.d/sudo_local`（macOS Sonoma 14+ の optional include）を生成し、`pam_reattach.so`（絶対パス、`pkgs.pam-reattach` 由来）と `pam_tid.so` を auth stack に差し込む
- `/etc/pam.d/sudo` 本体は触らない。`softwareupdate` で上書きされても Touch ID 設定は消えない

## macOS Sonoma 以前のパターンとの違い

旧パターンは `/etc/pam.d/sudo` を直接書き換える方式で、`security.pam.enableSudoTouchIdAuth = true;`（**deprecated**）を使っていた。OS アップデートのたびに `/etc/pam.d/sudo` が macOS デフォルトに上書きされ、Touch ID 設定が静かに消える既知の落とし穴があった。Phase 10 は macOS 14+ の `sudo_local` include 機構に乗ることでこの問題を構造的に回避する。

新規記述では必ず `security.pam.services.sudo_local.touchIdAuth` を使う（旧オプション名はネット記事にまだ大量に残っているので参考にしない）。

## `reattach = true` が必須な理由

`pam_tid.so` は Touch ID プロンプトを出すために **GUI helper (`bioutil` / `LocalAuthentication`) と通信する必要がある**。tmux / screen の中で `sudo` を叩くと、子プロセスが GUI session に attach されていないため Touch ID プロンプトが silently fail し password fallback になる（castle は tmux 常用なのでここを外すと意味が無い）。

`pam_reattach.so` は auth フェーズの先頭で **console session に re-attach** することでこのギャップを埋める。`reattach = true` を入れると nix-darwin が `pkgs.pam-reattach` の絶対パスを `sudo_local` の auth stack 先頭に書き込む（PATH 経由の解決に依存しない）。

## 検証手順

```bash
darwin-rebuild switch --flake ~/.config/nix-darwin

# 1) ローカル sudo で Touch ID が出るか
sudo -k && sudo true

# 2) tmux ペイン内でも Touch ID が出るか (reattach 効果)
tmux new-window
sudo -k && sudo true

# 3) 生成物の確認 (任意)
cat /etc/pam.d/sudo_local
#   auth  optional   /nix/store/.../lib/pam/pam_reattach.so
#   auth  sufficient pam_tid.so
# が並んでいれば期待通り
```

## 制約・適用外

- **SSH 越しの sudo は Touch ID 化できない**: `pam_tid.so` はローカル biometric に依存するため、SSH session では fallback で password を聞かれる（macOS 仕様、nix-darwin で解決不能）
- **Apple Watch 承認も追加可能**: 必要なら `watchIdAuth = true;` を併記する。Touch ID と OR 関係で動く
- **MCP server 起動時の per-pane Touch ID は別問題**: あれは 1Password の `op run` 経由の API キー取得時に起きる現象で、Phase 4 の `op-warm-mcp` で warm-cache 化済み（Phase 10 では解決しない）

## ポイント

- **`enable = true;` は厳密には冗長**: nix-darwin の `security.pam.services.sudo_local.enable` は module default が true。意図を読み手に明示するために残しているが、削除しても挙動は同じ
- **切り戻しは追加ブロックをコメントアウトして `darwin-rebuild switch`**: 生成物 `/etc/pam.d/sudo_local` も activation 時に nix-darwin が削除するので痕跡は残らない。`/etc/pam.d/sudo` 本体を一切触っていないため、`softwareupdate` との競合も発生しない
- **新規 Mac での適用順序**: Phase 2（1Password CLI）と Phase 10 は独立しているのでどちらが先でも良い。ただし Phase 10 を入れる前の最初の `darwin-rebuild switch` だけは password 入力が要る（chicken-and-egg）
