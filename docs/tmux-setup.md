# tmux + Ghostty セットアップ解説

ターミナルマルチプレクサとして **tmux** を採用し、Ghostty は「キー入力と表示の窓」に専念させる構成。元々 Ghostty 単体でペイン分割・移動・コピーモードを完結していたが、(1) 雪だるま式に tmux session が増える、(2) Ghostty pane と tmux pane が二重化する、(3) nvim とのシームレス移動が成立しないという 3 つの摩擦を解消するために移行した。

> 関連: 移行前のペイン CWD 問題は [`ghostty-cwd-workaround.md`](ghostty-cwd-workaround.md) を参照。

---

## 1. 役割分担

| レイヤ | 担当 |
|---|---|
| Ghostty | キー入力・フォント・テーマ・ウィンドウ/タブ管理・OSC 7 (CWD 報告) |
| tmux | ペイン分割・ナビゲーション・リサイズ・コピーモード・セッション管理 |
| zsh (`~/.zshrc`) | Ghostty 起動時に tmux に自動 attach（後述の session group 方式） |
| nvim (Phase 4 = 別 PR) | tmux と協調する `vim-tmux-navigator` を導入予定 |

Ghostty 側のペイン操作キーバインドは **コメントアウト残置** ([`config/ghostty/config`](../config/ghostty/config))。tmux に同等キーが移植されているので二重発火しないように無効化したまま、ロールバック容易性のために履歴は残す。

---

## 2. キーマッピング（Ghostty 互換）

すべて tmux の `bind -n`（prefix なし）で登録。`extended-keys on` + `terminal-features ',*:extkeys'` により Ghostty が CSI u (fixterms) で送る `Ctrl+;` 等の拡張キーを tmux が正しく拾える。

| 操作 | キー | tmux 実装 |
|---|---|---|
| 右に分割 | `Ctrl+;` | `bind -n C-\; split-window -h -c "#{pane_current_path}"` |
| 下に分割 | `Ctrl+'` | `bind -n "C-'" split-window -v -c "#{pane_current_path}"` |
| ペイン移動（左 / 下 / 上 / 右） | `Ctrl+h/j/k/l` | `vim-tmux-navigator` 経由で nvim と seamless |
| リサイズ（左 / 下 / 上 / 右、5 セル / 連打可） | `Ctrl+Shift+h/j/k/l` | `bind -n C-S-h resize-pane -L 5` 等 |
| ペイン均等化 | `Ctrl+Shift+=` | `bind -n C-S-= select-layout -E` |
| Copy mode 開始 | `Ctrl+Shift+x` | `bind -n C-S-x copy-mode` |
| Copy mode 内 (vi mode) | `j/k/g/G/n/N` (デフォルト) `u/d` (half page) `y` (pbcopy) `q` (cancel) | `setw -g mode-keys vi` ＋ 個別 `bind -T copy-mode-vi` |

`Ctrl+a` を tmux prefix として残しているので `prefix s` でセッション一覧、`prefix [` で copy mode 等の native UI も併用可能。

---

## 3. session group 方式（雪だるま回避）

`~/.zshrc` の Ghostty 検出ブロックで以下の分岐を実行する。

```zsh
if [[ -z "$TMUX" && -z "$NO_AUTO_TMUX" && -n "${GHOSTTY_RESOURCES_DIR:-}" && $- == *i* ]] \
  && (( $+commands[tmux] )); then
  if tmux has-session -t '=main' 2>/dev/null; then
    exec tmux new-session -t main -s "ghostty-$$"
  else
    exec tmux new-session -s main
  fi
fi
```

挙動：

- 1 つ目の Ghostty タブ → `main` セッションを新規作成
- 2 つ目以降 → 既存 `main` を **session group として join**、独立 client `ghostty-<pid>` で attach

`tmux ls` の見た目：

```
ghostty-12345: 1 windows (...) (group main) (attached)
main:          1 windows (...) (group main) (attached)
```

`(group main)` が複数行に付いていれば成立。各 Ghostty タブは「同じ session の windows を共有しつつ、自分が見ている active window は独立に切り替えられる」状態になる（`prefix s` でグループ内 window 一覧）。

`NO_AUTO_TMUX=1 exec zsh -l` で一時的に無効化できる。

---

## 4. 道中で踏んだ罠（再発防止）

### 罠①: tmux のシングルクォート禁止 — `'C-\;'` は `unknown key`

```tmux
# NG: tmux のシングルクォートは「完全リテラル」なので \ が処理されず
#     キー名「C-\;」をそのまま探しに行って unknown key になる
bind -n 'C-\;' split-window -h

# OK: クォートなしで書くと tmux の lexer が \; を ; のエスケープとして解釈し
#     キー名「C-;」として正しく登録される
bind -n C-\; split-window -h
```

ダブルクォート `"C-;"` でも動くがクォートなしが慣用。`Ctrl+'` 側は `;` が入らないので `"C-'"` で問題なし。

### 罠②: zsh の EQUALS expansion — `=main` が `main not found` で if abort

zsh の `EQUALS` オプション（デフォルト ON）は `=word` を「`word` というコマンドの絶対パスに展開」する（`=ls` → `/bin/ls` のように）。

```zsh
# NG: zsh が tmux 引数評価より先に =main を見て「main」を絶対パス展開
#     しようとし、見つからずに `zsh: main not found` を出して
#     if 全体が abort する → then も else も実行されず auto-attach が無音 skip
if tmux has-session -t =main 2>/dev/null; then ...

# OK: シングルクォートで囲んで EQUALS 展開を抑止し、リテラル =main を tmux に渡す
if tmux has-session -t '=main' 2>/dev/null; then ...
```

tmux 側の `-t '=main'` の先頭 `=` は **完全一致** を意味する記号（前方一致 `-t main` と区別）。session 名に `main-2` などがあっても誤マッチしないため必須。

### 一般化された教訓

> **zsh で `=` から始まる文字列を外部コマンドに渡す時は常にシングルクォートで囲う**

`git` / `awk` / `sed` の `=value` 引数や、tmux の `-t =name` のような構文を扱う場合に同じ罠を踏む。

### 罠③: Ghostty が `Ctrl+Shift+<letter>` の Shift を落とす

`Ctrl+;` や `Ctrl+'` は ASCII にマップできない（`;` の Ctrl コードが存在しない）ため Ghostty が CSI u (fixterms) にフォールバックして送る ＝ tmux が `bind -n C-\;` を発火できる。

しかし `Ctrl+Shift+h` のような **ASCII にマップ可能なキー**（`h` の Ctrl コード = `^H` = 0x08 が存在）は、Ghostty が古い経路を優先して **Shift 修飾を落として `^H` だけを送信**してしまう。tmux の `bind -n C-S-h` は発火しない。

`cat -v` での確認:

| `Ctrl+Shift+h` を押した時の `cat -v` 出力 | 意味 |
|---|---|
| `^[[104;6u` | ✅ CSI u 経由で Shift+Ctrl 修飾子付き送信 |
| `^H` | ❌ Shift 落ち、Ctrl+H と区別不能 |

**解決策**: `config/ghostty/config` で該当キーを **明示的に CSI u 送信に割り当て**る。

```ghostty
# Modifier 値: 1 + Shift(1) + Alt(2) + Ctrl(4) → Ctrl+Shift は 6
# ASCII 値: h=104, j=106, k=107, l=108, ==61
keybind = ctrl+shift+h=csi:104;6u
keybind = ctrl+shift+j=csi:106;6u
keybind = ctrl+shift+k=csi:107;6u
keybind = ctrl+shift+l=csi:108;6u
keybind = ctrl+shift+equal=csi:61;6u
```

Ghostty 側でこれを敷くと CSI u シーケンスが強制送信され、tmux 側の `bind -n C-S-h resize-pane -L 30` が正しく発火する。

> 一般化: **ASCII Ctrl にマップできるキー組み合わせを修飾子付きで使いたい場合、Ghostty 側で `keybind = ...=csi:<ascii>;<mod>u` を明示すること**。これは Ghostty に限らず多くのターミナルで起きる古典的な fixterms 移行問題。

---

## 5. 反映 / 動作確認手順

新規 Mac か、tmux 設定を大きく変えた後の手順：

```bash
# 1. tmux server を落とす（既存 session 全破棄）
tmux kill-server

# 2. Ghostty を Cmd+Q で完全終了 → 再度起動
#    (Cmd+Shift+, の reload では既存タブの zsh は再評価されない)

# 3. 自動で main セッションが立ち上がる。session 名を確認
tmux display-message -p 'session=#S'   # → main

# 4. Cmd+T で 2 タブ目を開く → ghostty-<pid> が join
tmux ls
# 期待:
#   ghostty-XXXXX: 1 windows (...) (group main) (attached)
#   main:          1 windows (...) (group main) (attached)

# 5. tpm の plugin install (vim-tmux-navigator)
#    tmux 内で C-a (prefix) → Shift+I (大文字 I)
ls ~/.tmux/plugins/  # tpm / tmux-sensible / vim-tmux-navigator

# 6. キー登録の確認
tmux list-keys -T root | grep -E 'C-S-|C-;|C-'\''
# 期待: split×2, resize×4, equalize, copy-mode の 8 行
tmux list-keys -T root | grep -E "select-pane|is_vim" | head
# 期待: vim-tmux-navigator の C-h/j/k/l/\\ 5 行
```

---

## 6. 関連ファイル

| 役割 | パス |
|---|---|
| tmux 設定本体 | [`home/.tmux.conf`](../home/.tmux.conf) |
| Ghostty 設定（multiplexer keybind は無効化済み） | [`config/ghostty/config`](../config/ghostty/config) |
| Ghostty 起動時 auto-attach | [`home/.zshrc`](../home/.zshrc)（"Ghostty: auto-attach tmux" ブロック） |
| プラグイン管理 (TPM) | `~/.tmux/plugins/tpm/`（user 領域、castle 追跡外） |
| Ghostty CWD 問題のワークアラウンド | [`ghostty-cwd-workaround.md`](ghostty-cwd-workaround.md) |

## 7. 残タスク（Phase 4 = 別 PR）

nvim 側でも `vim-tmux-navigator` を導入して、本物の seamless 移動を完成させる：

1. `config/nvim/lua/plugins/vim-tmux-navigator.lua` を新規作成
   ```lua
   return { "christoomey/vim-tmux-navigator", lazy = false }
   ```
2. `config/nvim/lua/config/keymaps.lua` の `<C-w>h/j/k/l` 直接マップを撤去（プラグインに任せる）
3. `:checkhealth vim-tmux-navigator` で連携確認
