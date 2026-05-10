# フォント戦略：アプリ横断で「JBM + ヒラギノ角ゴ」を貫く設計

開発作業の中心となる **ターミナル / エディタ / Markdown ビューア / チャット** で、英数字・記号は等幅 Nerd Font、日本語は macOS 標準のヒラギノ角ゴシックに統一するための設計指針。各アプリのフォント指定機構が異なるため、本ドキュメントでは**意図と実装の対応**を整理する。

> [!NOTE]
> 当初は「日本語=ヒラギノ明朝 ProN W3」採用だったが、commit `199ac95`（`chore: switch JP fallback fonts from Mincho to Hiragino Sans`）で Ghostty / Slack 等のフォールバックを **角ゴ (Hiragino Sans W3) に統一**した。Mincho 時代の議論 (BIZ UDMincho 比較含む) を読みたい場合は `git show 09eb250 -- docs/font-strategy.md` (= 当 docs を初版追加した commit、つまり Mincho narrative の最終版) で当時の本文を参照可能。

---

## 1. 設計方針

### 1.1 採用するフォント

| 用途 | フォント |
|---|---|
| 英数字・記号・コード合字・Nerd Font アイコン (等幅必須の場面) | **JetBrainsMono Nerd Font Mono** (NFM) |
| 英数字・記号・コード合字・Nerd Font アイコン (等幅不要の場面) | **JetBrainsMono Nerd Font** (NF) |
| 日本語 **本文** (ひらがな・カタカナ・漢字・全角記号) | **ヒラギノ角ゴシック ProN W3** (Hiragino Sans W3) |
| 日本語 **見出し** (読み物系: MarkdownObserver / html-artifact のみ例外的に採用) | ヒラギノ明朝 ProN W6 (`--c-serif` / `--serif` 経由) |

### 1.2 採用理由

- **JetBrainsMono Nerd Font Mono (NFM)**: ターミナル / エディタなど **等幅整列が必要**な場面で 1 番手にする。`Mono` variant は **Nerd Font glyph (`` 等の Powerline / file-type アイコン) も等幅化される**ため、アイコンを混ぜてもカーソル位置や罫線・テーブルがズレない。通常の NF (variable width) を 1 番手にすると glyph 幅が暴れる
- **JetBrainsMono Nerd Font (NF)**: Slack / Xcode など **等幅整列が緩く、glyph 幅の予測性が要らない**場面では NF で十分。NFM 環境を要求するより導入の手数が少ない
- **ヒラギノ角ゴシック ProN W3 (Hiragino Sans W3)**:
  - macOS 標準で追加インストール不要
  - macOS の他アプリ (Finder / 通知 / Safari / メッセージ等) と同じ系統で**コンテキストスイッチの "フォント差" が出にくい**
  - JetBrainsMono と humanist sans 系の雰囲気が近く、英数 ↔ 日本語の文字色（重さ）が揃いやすい
  - W3 (Light) なので、コードフォントを `font-style = Light` 運用にしているケース（Ghostty）と視覚的バランスが取れる

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
                      Hiragino Sans (角ゴシック) ← デフォルトでここ
```

つまり**現行の Sans 採用方針はデフォルト挙動と同じ方向**であり、明示指定が無くても "それっぽく" 動く。

ただし以下の理由で、castle では**全アプリで明示的に `Hiragino Sans W3` を指定**する：

- アプリによっては別フォント (Helvetica / 中華系フォント等) にフォールバックする実装もあり、CoreText のデフォルト挙動だけに依存できない
- weight (W3 / W6) や variant が選ばれる順序は CoreText 内部の言語タグ判定に依存して不安定。明示しないと太く出ることがある
- 設計を docs / 設定ファイル上で明示することで「他人 / 未来の自分」が読んだとき意図が分かる

---

## 3. アプリごとの実装

### 3.1 Ghostty（ターミナル）

**設定ファイル**: `~/.config/ghostty/config`（実体は `config/ghostty/config`）

```ini
font-family = JetBrainsMono Nerd Font Mono
font-family = JetBrainsMono Nerd Font
font-family = Hiragino Sans W3
font-style = Light
font-size = 14

# Force JP code points to Hiragino Sans (gothic) so CJK fallback is explicit
font-codepoint-map = U+3000-U+303F=Hiragino Sans W3   # 全角記号
font-codepoint-map = U+3040-U+309F=Hiragino Sans W3   # ひらがな
font-codepoint-map = U+30A0-U+30FF=Hiragino Sans W3   # カタカナ
font-codepoint-map = U+3400-U+4DBF=Hiragino Sans W3   # CJK統合漢字拡張A
font-codepoint-map = U+4E00-U+9FFF=Hiragino Sans W3   # CJK統合漢字（基本）
font-codepoint-map = U+FF00-U+FFEF=Hiragino Sans W3   # 半角・全角形
```

#### 仕組み

Ghostty は **`font-codepoint-map`** で「指定 Unicode 範囲は問答無用でこのフォント」と宣言できる。CoreText の自動カスケードを**完全にバイパス**する強い指定。

ターミナルは等幅幅の厳格な維持が必要（罫線・表組み・カーソル位置）で、フォント割り当てが暴れると実害が出るため、Ghostty は意図的にこの強制マップ機構を提供している。

**1 番手に NFM を置く理由**: Nerd Font glyph (Powerline アイコン等) を等幅で扱えるのは Mono variant だけ。通常の NF (variable width) を 1 番手にするとカーソル位置がズレる。NF を 2 番手に残しているのは、NFM 未導入環境での graceful degradation 用。

### 3.2 Slack（ブラウザ版・Stylus 拡張）

**設定ファイル**: `stylus/slack.css`（Stylus 拡張にコピペ）

```css
:root {
  --slack-font:
    "JetBrainsMono Nerd Font",
    "JetBrainsMono Nerd Font Mono",
    "JetBrainsMonoNL Nerd Font",
    "JetBrains Mono",
    "Hiragino Sans W3",
    "HiraginoSans-W3",
    "ヒラギノ角ゴシック W3",
    "Hiragino Kaku Gothic ProN",
    "Hiragino Kaku Gothic Pro",
    Menlo, Consolas, monospace, sans-serif;
}

* { font-family: var(--slack-font) !important; }
```

#### 仕組み

CSS の `font-family` リストは **per-character fallback**（文字ごとに該当グリフを探す）仕様。`JetBrainsMono Nerd Font` には日本語グリフが無いため、ひらがな・カタカナ・漢字は自動的にリスト内の次フォント（ヒラギノ角ゴ ProN W3）にフォールバックする。

Ghostty の `font-codepoint-map` のような明示的範囲指定とは異なるが、結果として同じ「英数字 = JBM、日本語 = 角ゴ」が実現できる。

#### コードブロックの詳細度勝負（補足）

Slack 内蔵 CSS は `.c-texty_input_unstyled__container .ql-editor .ql-code-block` のような**3クラス連結 `!important`**（詳細度 `(0,0,3,0)`）でフォントを上書きしてくる。

これに勝つため、`slack.css` では同じクラスを4回繰り返した `(0,0,4,0)` のセレクタを使用：

```css
.ql-code-block.ql-code-block.ql-code-block.ql-code-block { ... }
```

CSS 仕様上、同一クラスを複数回書いてもマッチ条件は変わらないが、詳細度カウントだけ上がる仕様を利用したテクニック（CSS-in-JS ライブラリでも使われる定番手法）。

### 3.3 MarkdownObserver（Markdown ビューア）

**設定ファイル**: `config/nix-darwin/files/markdownobserver/user.css`（Home Manager の `home.file` で `~/Library/Application Support/MarkdownObserver/themes/user.css` に symlink 配布）

```css
:root {
  --c-mono:  "JetBrainsMono Nerd Font Mono", "JetBrainsMono Nerd Font",
             "JetBrains Mono", ui-monospace, "SF Mono", Menlo, Monaco, Consolas, monospace;
  --c-sans:  system-ui, -apple-system, "Hiragino Sans",
             "Hiragino Kaku Gothic ProN", "YuGothic", "Yu Gothic", sans-serif;
  --c-serif: ui-serif, Georgia, "Hiragino Mincho ProN", "Hiragino Mincho Pro",
             "YuMincho", "Yu Mincho", "Times New Roman", Times, serif;
}

/* 本文 = Sans / 見出しのみ Serif (明朝) のハイブリッド設計 */
.markdown-body :is(h1, h2, h3, h4, h5, h6) {
  font-family: var(--c-serif);
  font-weight: 600;
}
```

MarkdownObserver は **本文 = Hiragino Sans / 見出し = ヒラギノ明朝 ProN** のハイブリッド設計を例外的に採用している。Markdown ビューアという "読み物" 用途では、見出しの字面の美しさを優先する判断（書籍・新聞の見出し慣行に倣う）。castle 全体で見ると **読み物系サーフェス（MarkdownObserver と html-artifact 出力 HTML、§3.5 参照）の見出しのみが明朝**で、それ以外（ターミナル / Slack / Xcode / 通知）は本文・見出しともに Sans。これは「設計の一貫性 < 用途別の最適化」を採った意図的な例外。

x-height 補正として `code, pre` には `font-weight: 300` + `font-size: 0.92em` を当てている（JetBrainsMono は x-height が高めで、同じ em でも本文 (Hiragino Sans) より大きく見える現象の相殺）。詳細は CSS 内コメント参照。

### 3.4 Xcode（iOS / Swift IDE）

**設定ファイル**: `config/nix-darwin/files/xcode/ClaudeDay.xccolortheme`（home.activation で `~/Library/Developer/Xcode/UserData/FontAndColorThemes/Claude Day.xccolortheme` に**実ファイルとして**配布。Xcode は symlink を辿らないため、`home.file` ではなく `home.activation` で `install -m 0644` する。詳細は [`docs/nix-darwin-manual.md`](nix-darwin-manual.md) §5.10）

Xcode の `.xccolortheme` (plist) はフォントを **用途別に複数キーで分けて指定**する。Claude Day テーマでは全キーを `JetBrainsMonoNF-Regular` で統一し、サイズだけ用途別に変えている：

| plist キー | 用途 | サイズ |
|---|---|---|
| `DVTSourceTextSyntaxFonts` | ソースコード本体（dict 形式で各 syntax トークンごとに指定。全トークンに同じ値を入れることで結果的に統一） | 13.0 |
| `DVTConsoleDebuggerInputTextFont` 等 (`DVTConsole*Font` 系 5 キー) | デバッガコンソールの入出力 | 12.0 |
| `DVTMarkupTextCodeFont` 等 (`DVTMarkupText*Font` 系 8 キー) | DocC / inline doc の Markdown レンダリング | 10.0 |

NF variant を選んでいるのは、Xcode のソース表示で Powerline 系 glyph を使わない（= Mono variant の利点が薄い）ため。`.xccolortheme` は font 名の解決を **PostScript 名** ベースで行うため、`JetBrainsMonoNF-Regular` のような `-NF` / `-NFM` サフィックス付きの名前で variant を直接指定する。

### 3.5 html-artifact（Claude Code が生成する HTML 成果物）

**設定ファイル**: `claude/skills/html-artifact/design-system.html`（`/html-artifact` スキルで生成される HTML が参照するデザイントークン定義）

```css
:root {
  --mono:  "JetBrainsMono Nerd Font Mono", ui-monospace, "SF Mono", Menlo, monospace;
  --sans:  system-ui, -apple-system, "Hiragino Sans", "Hiragino Kaku Gothic ProN",
           "YuGothic", "Yu Gothic", sans-serif;
  --serif: ui-serif, Georgia, "Hiragino Mincho ProN", "Hiragino Mincho Pro",
           "YuMincho", "Yu Mincho", "Times New Roman", Times, serif;
}
```

MarkdownObserver と同じく **本文 = Sans / 見出し = 明朝** のハイブリッド設計。これは「Claude Code が生成する HTML 成果物 (spec / report / mockup 等) は Markdown ビューア相当の "読み物" として消費される」想定に基づく。詳細は [`docs/html-artifact-usage.html`](html-artifact-usage.html) を参照。

---

## 4. アプリ横断のフォント整合性

| アプリ | 英数字 | 日本語 | 機構 | 状態 |
|---|---|---|---|---|
| **Ghostty** | JetBrainsMono Nerd Font Mono | ヒラギノ角ゴ ProN W3 | `font-codepoint-map` (強制) | 設定済み |
| **Slack (browser)** | JetBrainsMono Nerd Font | ヒラギノ角ゴ ProN W3 | CSS per-glyph fallback | 設定済み (`stylus/slack.css`) |
| **MarkdownObserver** | JetBrainsMono Nerd Font Mono | 本文: ヒラギノ角ゴ ProN W3 / **見出し: ヒラギノ明朝 ProN** (例外) | CSS 変数 (`--c-mono` / `--c-sans` / `--c-serif`) | 設定済み (Claude Day テーマ) |
| **html-artifact** | JetBrainsMono Nerd Font Mono | 本文: ヒラギノ角ゴ ProN / **見出し: ヒラギノ明朝 ProN** (例外) | CSS 変数 (`--mono` / `--sans` / `--serif`) | 設定済み (`design-system.html`) |
| **Xcode** | JetBrainsMono Nerd Font (Regular 13.0 / 12.0 / 10.0 を用途別) | – (ソース表示中心) | xccolortheme `DVTSourceTextSyntaxFonts` ほか | 設定済み (Claude Day テーマ) |
| **Neovim** | ターミナル設定を継承 | ターミナル設定を継承 | Ghostty 経由 | 自動連動 |
| **VS Code** | （未設定） | — | `editor.fontFamily` | 必要なら追加 |

---

## 5. 新しいアプリを追加する時のチェックリスト

新しい開発ツール（IDE、エディタ、ターミナル等）を導入する際は以下を順に確認：

### 5.1 フォント指定の3パターンを見極める

1. **CSS 系（Webアプリ、Electron）**: `font-family` リストで per-glyph fallback
2. **設定ファイル系（ネイティブターミナル、エディタ）**: `font-family` リスト or 明示的 codepoint map
3. **OS 連携系（macOS Cocoa app）**: NSFont API で範囲指定（plist / xccolortheme 等のアプリ独自フォーマットで指定するパターンが多い）

### 5.2 フォールバックが期待通りか検証

1. アプリ上で「日本語 + 英語混在」のテキストを表示
2. 目視で日本語が**ヒラギノ角ゴ ProN W3 になっているか**確認（W6 で太く出ていたら weight 指定漏れ、明朝になっていたら設計から外れている）
3. なっていなければ明示指定が必要 → 該当アプリの設定機構を調査

### 5.3 設定追加とドキュメント化

- 設定ファイルは `castle/config/<app-name>/` に配置（home symlink される）
- nix-darwin 経由で配布する場合は `config/nix-darwin/files/<app-name>/` 配下 + `home.nix` で `home.file` または `home.activation` を追加
- 特殊な指定方法は本ドキュメントの「3. アプリごとの実装」に追記

### 5.4 必要フォントの調達

| フォント | 入手方法 | インストール先 |
|---|---|---|
| Hiragino Sans (角ゴ) | macOS 標準 | `/System/Library/Fonts/ヒラギノ角ゴシック W*.ttc` |
| JetBrainsMono Nerd Font (NF / NFM) | nix-darwin の `nerd-fonts.jetbrains-mono` パッケージ（`config/nix-darwin/darwin.nix` 経由）/ 手動なら [Nerd Fonts 公式](https://www.nerdfonts.com/font-downloads) | Nix 経由なら `/etc/profiles/per-user/$USER/share/fonts/`、手動なら `~/Library/Fonts/` |

確認コマンド：

```sh
fc-list | grep -iE "(hira|jetbrains)"
```

---

## 6. 設計判断のメモ

### 6.1 Mincho → Sans への方針転換 (2025)

当初は「コードのゴシック感とのコントラスト」「明朝の字面の美しさ」を理由に **ヒラギノ明朝 ProN W3** を採用していた。commit `199ac95` で **本文 (ターミナル / Slack / MarkdownObserver 本文 / 通知系) を Sans に統一**。Sans 化で得られた利点（観察ベース）：

- **macOS 他アプリと視覚的に連続する**: Finder / 通知 / システム UI が Sans 系のため、コンテキストスイッチ時の "フォント感" が揃う
- **小さい文字サイズでの可読性向上**: Slack のサイドバー、通知バナー等で明朝のセリフが潰れる現象が解消
- **JBM とのカスケードでベースライン揃いが綺麗**: humanist sans 系同士の方が x-height / ベースラインが揃いやすい

「字面の美しさ」を優先するか「本文の一貫性 + 実用上の可読性」を優先するかのトレードオフ判断で、後者を選んだ形。

**ただし読み物系サーフェス (MarkdownObserver / html-artifact) の見出しだけは明朝を維持**。Markdown ビューアと HTML 成果物という "読み物" 用途では、見出しの字面の美しさが用途上重要なため (書籍・新聞でも見出しと本文でフォントを変える慣行がある)。これにより castle 全体は「本文は Sans 統一 / 見出しは用途次第」という運用になっている (§3.3 / §3.5 参照)。

### 6.2 NFM vs NF の使い分け基準

| 用途 | 1 番手 | 理由 |
|---|---|---|
| ターミナル (Ghostty) | **NFM** | Powerline glyph を等幅で扱う必要がある (starship のセグメント区切り等) |
| MarkdownObserver | **NFM** | コードブロック内の整列維持 |
| Xcode | **NF** (Regular 13.0) | ソース表示で Powerline glyph 不使用、NF で十分 |
| Slack | **NF** | コードブロックは存在するが整列要求は緩い、glyph も基本不使用 |

### 6.3 なぜ Slack に `font-codepoint-map` 相当の機構を求めなかったか

CSS の `font-family` per-glyph fallback で実用上問題ないため。ターミナルと違い、Slack は等幅幅の厳格な維持を要求しない（自由レイアウトの HTML）ため、フォント割り当ての**ピクセル予測性**は不要。

### 6.4 なぜ統一にこだわるか

- **コンテキストスイッチ時の認知負荷低減**: ターミナル ↔ Slack ↔ MarkdownObserver ↔ Xcode を頻繁に往復するワークフローで、フォントが変わると微妙に疲れる
- **スクリーンショット時の見栄え統一**: ブログ記事や Issue 上で複数ツールのスクショが混在しても違和感がない
- **設定の予測可能性**: 「全アプリで角ゴ + JBM にする」という単一ルールで運用可能、例外を覚えなくて良い

---

## 7. 関連ファイル

| パス | 内容 |
|---|---|
| `config/ghostty/config` | Ghostty の `font-codepoint-map` 含むフォント設定 |
| `config/nix-darwin/files/markdownobserver/user.css` | MarkdownObserver の `--c-mono` / `--c-sans` 変数 |
| `config/nix-darwin/files/xcode/ClaudeDay.xccolortheme` | Xcode テーマのフォント指定 (`DVTSourceTextFont`) |
| `stylus/slack.css` | Slack 用 Stylus CSS（per-glyph fallback） |
| `stylus/README.md` | Stylus 設定手順 |
| `docs/nix-darwin-manual.md` §5.10 | Xcode が symlink を辿らない罠と `home.activation` での回避策 |
| `docs/font-strategy.md` | 本ドキュメント |
