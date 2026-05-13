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
| 日本語 **見出し** (読み物系: MarkdownObserver / htmla のみ例外的に採用) | ヒラギノ明朝 ProN W6 (`--c-serif` / `--serif` 経由) |

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
font-style = Medium
font-size = 13  # config.local 未生成時の fallback (Light 側に倒す)

# Force JP code points to Hiragino Sans (gothic) so CJK fallback is explicit
font-codepoint-map = U+3000-U+303F=Hiragino Sans W3   # 全角記号
font-codepoint-map = U+3040-U+309F=Hiragino Sans W3   # ひらがな
font-codepoint-map = U+30A0-U+30FF=Hiragino Sans W3   # カタカナ
font-codepoint-map = U+3400-U+4DBF=Hiragino Sans W3   # CJK統合漢字拡張A
font-codepoint-map = U+4E00-U+9FFF=Hiragino Sans W3   # CJK統合漢字（基本）
font-codepoint-map = U+FF00-U+FFEF=Hiragino Sans W3   # 半角・全角形

# Hammerspoon が OS appearance を watch して font-size を上書きする
config-file = ?config.local
```

#### 仕組み

Ghostty は **`font-codepoint-map`** で「指定 Unicode 範囲は問答無用でこのフォント」と宣言できる。CoreText の自動カスケードを**完全にバイパス**する強い指定。

ターミナルは等幅幅の厳格な維持が必要（罫線・表組み・カーソル位置）で、フォント割り当てが暴れると実害が出るため、Ghostty は意図的にこの強制マップ機構を提供している。

**1 番手に NFM を置く理由**: Nerd Font glyph (Powerline アイコン等) を等幅で扱えるのは Mono variant だけ。通常の NF (variable width) を 1 番手にするとカーソル位置がズレる。NF を 2 番手に残しているのは、NFM 未導入環境での graceful degradation 用。

#### Light/Dark で `font-size` を 1pt 差にする（Hammerspoon hook 方式）

castle 共通の「Light vs Dark = 1pt 差」運用（[CLAUDE.md「テーマ運用ルール」](../CLAUDE.md)）を Ghostty でも貫くため、本体 config 末尾の `config-file = ?config.local` で **machine-local の動的ファイル** をオプショナル include する設計を採っている。

`config.local` は `hammerspoon/init.lua` が以下のタイミングで生成 / 上書きする:

1. Hammerspoon 起動時 (cold start / `hs.reload()`) に 1 度
2. `AppleInterfaceThemeChangedNotification` を `hs.distributednotifications` で購読し、OS appearance 変更のたびに

書き出される内容は `font-size = 13` (Light) または `font-size = 14` (Dark) のみ含む最小ファイル。本体 config の `font-size = 13` (fallback) の後に読まれるため、include があるときは override される。

書き出し直後に **`hs.application.get("com.mitchellh.ghostty"):selectMenuItem({"Ghostty", "Reload Config.*"}, true)`** で Ghostty のメニューバー「Reload Configuration」を自動 click する。これにより config.local の値が Ghostty 内部の "current config" に即座に取り込まれ、ユーザーは手動で `Cmd+Shift+,` を叩く必要が無い。Ghostty 未起動時は best-effort で skip し、log にだけ残す。

##### なぜ theme file 内で `font-size` を書けないか

Ghostty 公式 docs では「A theme can set any valid configuration option」（`theme` / `config-file` 以外は何でも設定可）と書かれているが、**実装上は theme file 内の `font-size` などフォント系オプションは silently ignore される** ことが `+show-config` で検証済み。これは theme 切替のたびに glyph atlas (GPU 上のフォントテクスチャ) を再構築するコストを避けるための暗黙仕様と推定される。

そのため、Ghostty のテーマファイル (`config/ghostty/themes/Claude Day` / `Claude Day Dark`) は **color のみ** を定義し、`font-size` は本体 config + Hammerspoon hook 経由で実現するという責務分割になっている。

##### 反映の挙動

| 設定カテゴリ | 既存ウィンドウ | 新ウィンドウ |
|---|---|---|
| color / palette / keybinding | ✓ 即時反映 | ✓ 反映 |
| **font-size** | ✓ 即時反映（Hammerspoon の Reload Configuration 自動発火経由） | ✓ 反映 |

実機確認（2026-05、`auto-update-channel = tip` の Ghostty）で、Hammerspoon が `selectMenuItem` で発火する Reload Configuration により **既存ウィンドウの色も font-size も即時反映** される。font 系設定の live reload は glyph atlas 再構築を伴うコストの大きい操作だが、Ghostty の最近のバージョンは追従するようになっている。

##### 必須条件

- **Hammerspoon に Accessibility 権限が必要** (System Settings → Privacy & Security → Accessibility)。無いと `selectMenuItem` は silently fail し、`config.local` だけ書き換わって Ghostty が再読込しないため見た目に何も起こらない
- Ghostty が起動している必要がある (`hs.application.get` で nil の場合は best-effort skip)
- `config.local` を書き換えただけでは Ghostty は再読込しないため、Hammerspoon が menu click を自動化する経路は必須 (= 設計の中核)

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

MarkdownObserver は **本文 = Hiragino Sans / 見出し = ヒラギノ明朝 ProN** のハイブリッド設計を例外的に採用している。Markdown ビューアという "読み物" 用途では、見出しの字面の美しさを優先する判断（書籍・新聞の見出し慣行に倣う）。castle 全体で見ると **読み物系サーフェス（MarkdownObserver と htmla 出力 HTML、§3.5 参照）の見出しのみが明朝**で、それ以外のサーフェス（ターミナル / Slack / 通知）は本文・見出しともに Sans。これは「設計の一貫性 < 用途別の最適化」を採った意図的な例外。

> Xcode はそもそも castle のユースケースで日本語見出しを描画しない（ソースコード表示が主）。日本語が混入した場合は CoreText フォールバックで結果的に Sans になるが、これは設計判断ではなく副作用なので上記の整合性議論からは外している。

x-height 補正として `code, pre` には `font-weight: 300` + `font-size: 0.92em` を当てている（JetBrainsMono は x-height が高めで、同じ em でも本文 (Hiragino Sans) より大きく見える現象の相殺）。詳細は CSS 内コメント参照。

### 3.4 Xcode（iOS / Swift IDE）

**設定ファイル**:

- `config/nix-darwin/files/xcode/ClaudeDay.xccolortheme` — Light テーマ（基準サイズ）
- `config/nix-darwin/files/xcode/ClaudeDayDark.xccolortheme` — Dark テーマ（Light より一律 +1pt）

それぞれ home.activation で `~/Library/Developer/Xcode/UserData/FontAndColorThemes/Claude Day.xccolortheme` および `Claude Day Dark.xccolortheme` に**実ファイルとして**配布する。Xcode は symlink を辿らないため、`home.file` ではなく `home.activation` で `install -m 0644` する。詳細は [`docs/nix-darwin-manual.md`](nix-darwin-manual.md) §5.10。

Xcode の `.xccolortheme` (plist) はフォントを **用途別に複数キーで分けて指定**する。Claude Day / Claude Day Dark テーマでは「コード描画系のキーだけ JBM 化、Markdown / Heading 系の描画は Xcode 既定 (macOS システムフォント) を踏襲」という方針を採っている。Light / Dark のサイズ差は castle 共通の「Light vs Dark = 1pt 差」運用（[CLAUDE.md「テーマ運用ルール」](../CLAUDE.md)）に従い、Dark 側を一律 +1pt にしている:

| plist キー | 用途 | Light サイズ | Dark サイズ |
|---|---|---|---|
| `DVTSourceTextSyntaxFonts` | ソースコード本体（dict 形式で各 syntax トークンごとに指定。全トークンに同じ値を入れることで結果的に統一） | `JetBrainsMonoNF-Regular - 13.0` | `JetBrainsMonoNF-Regular - 14.0` |
| `DVTConsoleDebuggerInputTextFont` 等 (`DVTConsole*Font` 系 5 キー) | デバッガコンソールの入出力 | `JetBrainsMonoNF-Regular - 13.0` | `JetBrainsMonoNF-Regular - 14.0` |
| `DVTMarkupTextCodeFont` | DocC / inline doc 内の **コードブロック** | `JetBrainsMonoNF-Regular - 10.0` | `JetBrainsMonoNF-Regular - 11.0` |
| `DVTMarkupText{Emphasis,Link,Normal,Strong}Font` (4 キー、本文・強調・リンク) | DocC / inline doc の本文系 | `.AppleSystemUIFont - 10.0` | `.AppleSystemUIFont - 11.0` |
| `DVTMarkupTextOtherHeadingFont` | DocC の小見出し | `.AppleSystemUIFont - 14.0` | `.AppleSystemUIFont - 15.0` |
| `DVTMarkupTextSecondaryHeadingFont` | DocC の中見出し | `.AppleSystemUIFont - 18.0` | `.AppleSystemUIFont - 19.0` |
| `DVTMarkupTextPrimaryHeadingFont` | DocC の大見出し | `.AppleSystemUIFont - 24.0` | `.AppleSystemUIFont - 25.0` |

`DVTMarkupText*Font` 7 キー (Code 以外) を JBM 化していないのは意図的で、**DocC 描画時の見出し階層を Xcode 既定の見え方に揃える**ため (Xcode 標準 theme と同じ階層感を保ちつつ、コードブロックだけ JBM に置き換える、という最小侵襲設計)。読者が自分の theme を作る際は、**Markdown 系の見出しまで JBM 化すると 10pt 等幅で読みづらくなる**点に注意。

NF variant を選んでいるのは、Xcode のソース表示で Powerline 系 glyph を使わない（= Mono variant の利点が薄い）ため。`.xccolortheme` は font 名の解決を **PostScript 命名規則** ベース（`-NF` / `-NFM` などの variant サフィックス込みのフルネーム）で行う。本テーマでは NF (Regular) のみ採用しており、NFM (Mono variant) は使っていない。

#### Light / Dark テーマファイルの保守 tips

- フォントサイズを一律 ±1pt するときは **大きいサイズから降順で sed/Edit する**（`13→14, 14→15` の順で実行すると元 13 のものが二重シフトされて 15 になる事故が起きる、Dark 版作成時に踏んだ罠）
- ヘッダコメント内の `JetBrainsMonoNF-Regular - 14.0` のような数値は **plist の `<string>` 値の置換と同じ正規表現に巻き込まれる**ので、降順置換中の中間状態でコメントだけが先行して書き換わる事故にも注意。`plutil -lint` + `grep -oE '\- [0-9]+\.0' | sort | uniq -c` のヒストグラム比較で Light / Dark がきっちり +1 シフトしているか検証できる

### 3.5 htmla（Claude Code が生成する HTML 成果物）

**設定ファイル**: `claude/skills/htmla/design-system.html`（`/htmla` スキルで生成される HTML が参照するデザイントークン定義）

```css
/* 概形。実際の font-family は Win/Linux 系含む長い fallback リストを持つ。
   完全な定義は claude/skills/htmla/design-system.html:31-36 を参照。 */
:root {
  --serif: ui-serif, Georgia, "Hiragino Mincho ProN", ..., serif;
  --sans:  system-ui, -apple-system, "Hiragino Sans", ..., sans-serif;
  --mono:  "JetBrainsMono Nerd Font Mono", ..., monospace;
}
```

MarkdownObserver と同じく **本文 = Sans / 見出し = 明朝** のハイブリッド設計。これは「Claude Code が生成する HTML 成果物 (spec / report / mockup 等) は Markdown ビューア相当の "読み物" として消費される」想定に基づく。詳細は [`docs/htmla-usage.html`](htmla-usage.html) を参照。

---

## 4. アプリ横断のフォント整合性

| アプリ | 英数字 | 日本語 | 機構 | Light/Dark サイズ差 | 状態 |
|---|---|---|---|---|---|
| **Ghostty** | JetBrainsMono Nerd Font Mono | ヒラギノ角ゴ ProN W3 | `font-codepoint-map` (強制) | Light 13pt / Dark 14pt（Hammerspoon が `config.local` を書換 + Reload Configuration を自動発火、§3.1 参照） | 設定済み |
| **Slack (browser)** | JetBrainsMono Nerd Font | ヒラギノ角ゴ ProN W3 | CSS per-glyph fallback | – | 設定済み (`stylus/slack.css`) |
| **MarkdownObserver** | JetBrainsMono Nerd Font Mono | 本文: ヒラギノ角ゴ ProN W3 / **見出し: ヒラギノ明朝 ProN** (例外) | CSS 変数 (`--c-mono` / `--c-sans` / `--c-serif`) | – (CSS の `prefers-color-scheme` で色のみ追従) | 設定済み (Claude Day テーマ) |
| **htmla** | JetBrainsMono Nerd Font Mono | 本文: ヒラギノ角ゴ ProN / **見出し: ヒラギノ明朝 ProN** (例外) | CSS 変数 (`--mono` / `--sans` / `--serif`) | – | 設定済み (`design-system.html`) |
| **Xcode** | **コード系**: JBM Nerd Font Regular（ソース・Console・DocC コードブロック を §3.4 参照） / **Markup 系**: `.AppleSystemUIFont` 系（Xcode 既定踏襲、§3.4 参照） | – (ソース表示中心) | xccolortheme `DVTSourceTextSyntaxFonts` ほか | Light 13/10/14/18/24pt / Dark 14/11/15/19/25pt（テーマファイル別、§3.4 参照） | 設定済み (Claude Day / Claude Day Dark テーマ) |
| **Neovim** | ターミナル設定を継承 | ターミナル設定を継承 | Ghostty 経由 | Ghostty 経由で自動連動 | 自動連動 |
| **VS Code** | （未設定） | — | `editor.fontFamily` | – | 必要なら追加 |

「Light/Dark サイズ差」列は castle 共通の「Light vs Dark = 1pt 差」運用（[CLAUDE.md「テーマ運用ルール」](../CLAUDE.md)）の各アプリ実装状況。color に限らず font-size まで appearance に追従させているのは **Ghostty (Hammerspoon hook 経由)** と **Xcode (テーマファイル別配布)** の 2 つ。読み物系 (MarkdownObserver / htmla) は CSS の `prefers-color-scheme` で色だけ追従し、font-size は記事の読みやすさを優先して固定。

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

**ただし読み物系サーフェス (MarkdownObserver / htmla) の見出しだけは明朝を維持**。Markdown ビューアと HTML 成果物という "読み物" 用途では、見出しの字面の美しさが用途上重要なため (書籍・新聞でも見出しと本文でフォントを変える慣行がある)。これにより castle 全体は「本文は Sans 統一 / 見出しは用途次第」という運用になっている (§3.3 / §3.5 参照)。

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
| `config/nix-darwin/files/xcode/ClaudeDay.xccolortheme` | Xcode テーマのフォント指定 (`DVTSourceTextSyntaxFonts` / `DVTConsole*Font` / `DVTMarkupTextCodeFont` ほか、§3.4 参照) |
| `stylus/slack.css` | Slack 用 Stylus CSS（per-glyph fallback） |
| `stylus/README.md` | Stylus 設定手順 |
| `docs/nix-darwin-manual.md` §5.10 | Xcode が symlink を辿らない罠と `home.activation` での回避策 |
| `docs/font-strategy.md` | 本ドキュメント |
