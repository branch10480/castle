# フォント戦略：アプリ横断で「JBM + ヒラギノ明朝」を貫く設計

開発作業の中心となる **ターミナル / エディタ / チャット** で、英数字・記号は等幅 Nerd Font、日本語は明朝体に統一するための設計指針。各アプリのフォント指定機構が異なるため、本ドキュメントでは**意図と実装の対応**を整理する。

---

## 1. 設計方針

### 1.1 採用するフォント

| 用途 | フォント |
|---|---|
| 英数字・記号・コード合字・Nerd Font アイコン | **JetBrainsMono Nerd Font** |
| 日本語（ひらがな・カタカナ・漢字・全角記号） | **ヒラギノ明朝ProN W3** |

### 1.2 採用理由

- **JetBrainsMono**: ハンドルフリー（合字対応）、`0` と `O` の判別性、`l` と `1` の判別性、長時間コーディングでの可読性が高い。Nerd Font 化版は `` などのアイコンも含む
- **ヒラギノ明朝ProN**: macOS 標準で追加インストール不要、字面が美しく長文の日本語を読み疲れしにくい
- **明朝（serif）を選ぶ理由**: 単に好み……ではなく、「コードのゴシック感とのコントラスト」がメリット。コードと混在する日本語が**視覚的に区別しやすくなる**

---

## 2. 落とし穴：macOS CoreText のデフォルト挙動

何もしないとアプリは「英字フォントに無い文字」を CoreText のフォールバックに丸投げする。macOS の CoreText は日本語ロケール環境で**デフォルトで `ヒラギノ角ゴシック (Hiragino Sans)` を選ぶ**。

```
[何もしない場合]
"Hello こんにちは"
  ↓ 文字ごとフォント探索
  H → JetBrainsMono ✓
  こ → JetBrainsMono ✗ → CoreText fallback
                          ↓
                      Hiragino Sans (角ゴシック) ← ここがゴシックになる
```

つまり「**ゴシック調を許容するなら何もしなくて良い**」。明朝にしたければ、**全アプリで明示的に明朝へ寄せる必要**がある。これが本戦略の核心。

---

## 3. アプリごとの実装

### 3.1 Ghostty（ターミナル）

**設定ファイル**: `~/.config/ghostty/config`（実体は `config/ghostty/config`）

```ini
font-family = JetBrainsMono Nerd Font
font-family = Hiragino Mincho ProN W3
font-style = Light
font-size = 14

# Force JP code points to Mincho (CoreText auto-cascade prefers Hiragino Sans otherwise)
font-codepoint-map = U+3000-U+303F=Hiragino Mincho ProN W3   # 全角記号
font-codepoint-map = U+3040-U+309F=Hiragino Mincho ProN W3   # ひらがな
font-codepoint-map = U+30A0-U+30FF=Hiragino Mincho ProN W3   # カタカナ
font-codepoint-map = U+3400-U+4DBF=Hiragino Mincho ProN W3   # CJK統合漢字拡張A
font-codepoint-map = U+4E00-U+9FFF=Hiragino Mincho ProN W3   # CJK統合漢字（基本）
font-codepoint-map = U+FF00-U+FFEF=Hiragino Mincho ProN W3   # 半角・全角形
```

#### 仕組み

Ghostty は **`font-codepoint-map`** で「指定 Unicode 範囲は問答無用でこのフォント」と宣言できる。CoreText の自動カスケードを**完全にバイパス**する強い指定。

ターミナルは等幅幅の厳格な維持が必要（罫線・表組み・カーソル位置）で、フォント割り当てが暴れると実害が出るため、Ghostty は意図的にこの強制マップ機構を提供している。

### 3.2 Slack（ブラウザ版・Stylus 拡張）

**設定ファイル**: `stylus/slack.css`（Stylus 拡張にコピペ）

```css
:root {
  --slack-font:
    "JetBrainsMono Nerd Font",
    "JetBrainsMono Nerd Font Mono",
    "JetBrainsMonoNL Nerd Font",
    "JetBrains Mono",
    "Hiragino Mincho ProN",
    "HiraMinProN-W3",
    "ヒラギノ明朝 ProN W3",
    "ヒラギノ明朝 ProN",
    "Hiragino Mincho Pro",
    Menlo, Consolas, monospace, serif;
}

* { font-family: var(--slack-font) !important; }
```

#### 仕組み

CSS の `font-family` リストは **per-character fallback**（文字ごとに該当グリフを探す）仕様。`JetBrainsMono Nerd Font` には日本語グリフが無いため、ひらがな・カタカナ・漢字は自動的にリスト内の次フォント（ヒラギノ明朝ProN）にフォールバックする。

Ghostty の `font-codepoint-map` のような明示的範囲指定とは異なるが、結果として同じ「英数字 = JBM、日本語 = 明朝」が実現できる。

#### コードブロックの詳細度勝負（補足）

Slack 内蔵 CSS は `.c-texty_input_unstyled__container .ql-editor .ql-code-block` のような**3クラス連結 `!important`**（詳細度 `(0,0,3,0)`）でフォントを上書きしてくる。

これに勝つため、`slack.css` では同じクラスを4回繰り返した `(0,0,4,0)` のセレクタを使用：

```css
.ql-code-block.ql-code-block.ql-code-block.ql-code-block { ... }
```

CSS 仕様上、同一クラスを複数回書いてもマッチ条件は変わらないが、詳細度カウントだけ上がる仕様を利用したテクニック（CSS-in-JS ライブラリでも使われる定番手法）。

---

## 4. アプリ横断のフォント整合性

| アプリ | 英数字 | 日本語 | 機構 | 状態 |
|---|---|---|---|---|
| **Ghostty** | JetBrainsMono Nerd Font | ヒラギノ明朝ProN W3 | `font-codepoint-map` | 設定済み |
| **Slack (browser)** | JetBrainsMono Nerd Font | ヒラギノ明朝ProN | CSS per-glyph fallback | 設定済み |
| **WezTerm** | （Ghostty移行のため非アクティブ） | — | — | — |
| **Neovim** | ターミナル設定を継承 | ターミナル設定を継承 | Ghostty 経由 | 自動連動 |
| **VS Code** | （未設定） | — | `editor.fontFamily` | 必要なら追加 |

---

## 5. 新しいアプリを追加する時のチェックリスト

新しい開発ツール（IDE、エディタ、ターミナル等）を導入する際は以下を順に確認：

### 5.1 フォント指定の3パターンを見極める

1. **CSS 系（Webアプリ、Electron）**: `font-family` リストで per-glyph fallback
2. **設定ファイル系（ネイティブターミナル、エディタ）**: `font-family` リスト or 明示的 codepoint map
3. **OS 連携系（macOS Cocoa app）**: NSFont API で範囲指定

### 5.2 フォールバックが期待通りか検証

1. アプリ上で「日本語 + 英語混在」のテキストを表示
2. 目視で日本語が**ヒラギノ角ゴ（角張った字面）になっていないか**確認
3. なっていれば明示指定が必要 → 該当アプリの設定機構を調査

### 5.3 設定追加とドキュメント化

- 設定ファイルは `castle/config/<app-name>/` に配置（home symlink される）
- 特殊な指定方法は本ドキュメントの「3. アプリごとの実装」に追記
- 必要フォントが増えた場合は `5.4` に追記

### 5.4 必要フォントの調達

| フォント | 入手方法 | インストール先 |
|---|---|---|
| Hiragino Mincho ProN | macOS 標準 | `/System/Library/Fonts/ヒラギノ明朝 ProN.ttc` |
| JetBrainsMono Nerd Font | [Nerd Fonts 公式](https://www.nerdfonts.com/font-downloads) または Homebrew Cask `font-jetbrains-mono-nerd-font` | `~/Library/Fonts/` |

確認コマンド：

```sh
fc-list | grep -iE "(hira|jetbrains)"
```

---

## 6. 設計判断のメモ

### 6.1 なぜ等幅明朝を採用しなかったか

途中で `BIZ UDMincho`（macOS 標準の等幅明朝）を試したが、**字面が UD 設計で硬く、ヒラギノ明朝の優雅さに及ばない**ため不採用。

長時間チャットを読む用途では「グリッドの整列性」より「字面の美しさ」を優先した。コードと日本語が混在する場合の見た目は、JetBrainsMono と明朝の**コントラスト**で十分視覚的に区別できる。

### 6.2 なぜ Slack に `font-codepoint-map` 相当の機構を求めなかったか

CSS の `font-family` per-glyph fallback で実用上問題ないため。ターミナルと違い、Slack は等幅幅の厳格な維持を要求しない（自由レイアウトの HTML）ため、フォント割り当ての**ピクセル予測性**は不要。

### 6.3 なぜ統一にこだわるか

- **コンテキストスイッチ時の認知負荷低減**: ターミナル ↔ Slack 切り替え時にフォントが変わると微妙に疲れる
- **スクリーンショット時の見栄え統一**: ブログ記事や Issue 上で複数ツールのスクショが混在しても違和感がない
- **設定の予測可能性**: 「全アプリで明朝にする」という単一ルールで運用可能、例外を覚えなくて良い

---

## 7. 関連ファイル

| パス | 内容 |
|---|---|
| `config/ghostty/config` | Ghostty の `font-codepoint-map` 含むフォント設定 |
| `stylus/slack.css` | Slack 用 Stylus CSS（per-glyph fallback） |
| `stylus/README.md` | Stylus 設定手順 |
| `docs/font-strategy.md` | 本ドキュメント |
