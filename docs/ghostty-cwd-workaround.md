# Ghostty split CWD 問題のワークアラウンド解説

Ghostty のターミナル split 時に、homeshick 管理の dotfiles（symlink ベース）が原因で CWD が `~/.homesick/repos/castle/...` に変わってしまう問題と、`.zshrc` に実装したワークアラウンドについて解説する。

> ref: [ghostty-org/ghostty#647](https://github.com/ghostty-org/ghostty/issues/647)

---

## 1. 前提：homeshick のシンボリンク構造

homeshick は dotfiles を Git で管理するツール。実際のファイルは castle リポジトリ内にあり、ホームディレクトリにはシンボリンクが張られる。

```
~/.zshrc  →  ~/.homesick/repos/castle/home/.zshrc（実体）
```

普段はこのシンボリンクを意識する必要はない。`~/.zshrc` を読んでも、透過的に実体ファイルの中身が返る。

## 2. 問題：Ghostty の split で CWD がおかしくなる

Ghostty はターミナルを左右・上下に分割（split）できる。split すると**親ペインと同じディレクトリ**で新しいシェルが開くのが期待される動作。

```
┌─────────────────────┬─────────────────────┐
│ ~/projects/myapp    │ ~/projects/myapp    │ ← 同じCWDで開いてほしい
│ $                   │ $                   │
│                     │                     │
└─────────────────────┴─────────────────────┘
```

しかし、**たまに**新しいペインの CWD が `~/.homesick/repos/castle/home/` になってしまうことがある。

### なぜ起きるのか？

Ghostty は **OSC 7** というプロトコルで各ペインの CWD を追跡している。

```
シェルが「今のCWDはここだよ」とGhosttyに報告する仕組み：

  [ユーザーがcdする]
       ↓
  シェルのprecmd（プロンプト表示前）が発火
       ↓
  _ghostty_report_pwd() が実行される
       ↓
  OSC 7 エスケープシーケンスで CWD を Ghostty に送信
       ↓
  Ghostty が「このペインのCWDは /xxx/yyy」と記憶
```

split 時、Ghostty はこの記憶した CWD を新しいシェルの作業ディレクトリに設定する。

**問題は、シェルの初期化中に `$PWD` が一瞬 `.homesick/` パスになることがある点。** もしそのタイミングで OSC 7 が報告されると、Ghostty はそのパスを「最新のCWD」として記憶してしまう。以降の split はすべてその汚染されたパスを継承する。

```
親ペインのシェル初期化中:
  $PWD = ~/projects/myapp                ← 本来のCWD
     ↓（何かの処理で一瞬変わる）
  $PWD = ~/.homesick/repos/castle/home/  ← symlink解決の副作用
     ↓（OSC 7 が報告してしまう）
  Ghosttyの記憶: "CWD = ~/.homesick/repos/castle/home/"
     ↓
  split作成時、新シェルがこのCWDで起動
```

## 3. ワークアラウンドの仕組み

### Step 1：CWD の保存（`.zshrc` 冒頭）

```zsh
_SHELL_INIT_PWD="$PWD"
```

`.zshrc` が読み込まれる**最初の瞬間**に、現在の CWD を変数に保存する。この時点ではまだ各種ツール（anyenv, starship, direnv 等）の初期化が走っていないので、CWD が変わる前の値をキャプチャできる可能性が高い。

### Step 2：通常の初期化処理

```zsh
eval "$(anyenv init -)"              # 言語バージョン管理
source .../zsh-autosuggestions.zsh    # 補完
eval "$(starship init zsh)"          # プロンプト
source .../homeshick.sh              # ← これがCWDを変える可能性
eval "$(zoxide init zsh)"            # ディレクトリジャンプ
eval "$(direnv hook zsh)"            # 環境変数の自動切替
# ... etc
```

この間に CWD が `.homesick/` 配下に変わってしまう場合がある。

### Step 3：CWD の復元（`.zshrc` 末尾）

```zsh
if [[ "$PWD" == "$HOME/.homesick/"* ]]; then
  #                 ↑ 現在のCWDが .homesick 配下か？

  if [[ -n "$_SHELL_INIT_PWD" && "$_SHELL_INIT_PWD" != "$HOME/.homesick/"* ]]; then
    # ┌─ Case 1 ──────────────────────────────────────┐
    # │ 保存したCWDは正常（.homesick外）               │
    # │ → .zshrc処理中にCWDが変わったので元に戻す      │
    # └────────────────────────────────────────────────┘
    cd "$_SHELL_INIT_PWD"

  elif [[ -n "${GHOSTTY_RESOURCES_DIR:-}" ]]; then
    # ┌─ Case 2 ──────────────────────────────────────┐
    # │ 保存したCWD自体も .homesick 配下               │
    # │ → シェル起動時点で既にCWDが汚染されていた       │
    # │ → Ghostty環境限定で $HOME にフォールバック      │
    # └────────────────────────────────────────────────┘
    cd "$HOME"
  fi
fi
unset _SHELL_INIT_PWD
```

## 4. 過去の実装が「たまに失敗」した理由

以前のコード：

```zsh
if [[ -n "$_SHELL_INIT_PWD"
   && "$PWD" == "$HOME/.homesick/"*      # 条件A: 今 .homesick にいる
   && "$PWD" != "$_SHELL_INIT_PWD"       # 条件B: 保存時と違う場所にいる
]]; then
  cd "$_SHELL_INIT_PWD"
fi
```

**失敗するケース：**

```
Ghosttyが汚染されたCWDでシェルを起動
  ↓
_SHELL_INIT_PWD = "~/.homesick/repos/castle/home/"  ← 既に汚染
  ↓
（.zshrc の初期化処理が走る）
  ↓
$PWD = "~/.homesick/repos/castle/home/"  ← 変わらずそのまま
  ↓
条件A: OK  .homesick 配下にいる
条件B: NG  $PWD == $_SHELL_INIT_PWD（同じ値！）
  ↓
→ 復元されない！
```

保存した値と現在の値が同じ（どちらも汚染済み）なので、「CWD は変わっていない」と判定されてしまう。

## 5. 現在の修正でどう直ったか

```
同じ失敗ケースで：
  ↓
外側の条件: OK  .homesick 配下にいる
  ↓
Case 1: NG  _SHELL_INIT_PWD も .homesick 配下（正常な値ではない）
Case 2: OK  GHOSTTY_RESOURCES_DIR が存在（Ghostty環境）
  ↓
→ $HOME にフォールバック！
```

`GHOSTTY_RESOURCES_DIR` は Ghostty が自動的に設定する環境変数。これでスコープを限定することで、WezTerm 等で意図的に `cd ~/.homesick/repos/castle` して作業するケースには影響しない。

## 6. `.zshenv` に移しても解決しない理由

zsh の起動ファイルは以下の順で読み込まれる：

| 順序 | ファイル | 実行条件 |
|------|----------|----------|
| 1 | `~/.zshenv` | **常に**（interactive/non-interactive 問わず） |
| 2 | `~/.zprofile` | login shell のみ |
| 3 | `~/.zshrc` | interactive shell のみ |
| 4 | `~/.zlogin` | login shell のみ |

`_SHELL_INIT_PWD="$PWD"` を `.zshenv` に移せば最も早いタイミングでキャプチャできるが、**Ghostty がシェルを起動する時点で既に CWD が汚染されている場合**（OSC 7 経由の誤継承）、`.zshenv` の段階でも `$PWD` は汚染された値になる。つまり保存タイミングを早めても根本解決にはならない。

加えて、`~/.zshenv` は別の castle リポジトリ（`castle-work`）で管理されているため、このリポジトリから追加すると homeshick でシンボリンクが競合する制約もある。

## 7. フロー全体図

```
シェル起動
  │
  ├─ .zshenv（castle-work）  ← Bedrock設定等
  ├─ .zprofile（castle）     ← brew shellenv
  │
  ▼
┌─ .zshrc 開始 ──────────────────────────┐
│                                         │
│  (1) _SHELL_INIT_PWD="$PWD"  ← CWD保存 │
│                                         │
│  (2) anyenv / starship / homeshick /    │
│      zoxide / direnv 等の初期化         │
│     （この間にCWDが変わる可能性あり）    │
│                                         │
│  (3) 復元チェック:                      │
│      CWDが.homesick配下？               │
│        ├─ Yes & 保存値が正常 → 復元     │
│        ├─ Yes & 保存値も汚染            │
│        │   └─ Ghostty？→ $HOME         │
│        └─ No → 何もしない（正常）        │
│                                         │
└─────────────────────────────────────────┘
  │
  ▼
プロンプト表示（ここで OSC 7 が正しいCWDを報告）
```
