---
name: learn
description: "「自分が分からなかったこと」を HTML 形式の解説記事として `~/ghq/github.com/branch10480/learnings/` リポジトリに追加する。各 entry は ivory + clay design-system で統一され、メタデータ付きで生成される。`/learn <トピック>` で実行。「これを学習ノートに残して」「learnings に追加して」と言ったときにも使う。"
---

# learn

`~/ghq/github.com/branch10480/learnings/` に新しい explainer HTML を追加し、index.html を再生成するスキル。

## 前提

- リポジトリ: `~/ghq/github.com/branch10480/learnings/`
- design-system: `~/.claude/skills/html-artifact/design-system.html` を参照（html-artifact スキルと同じ流儀）
- entries は単一ファイル完結（外部 CSS/JS なし）

## 手順

### 1. リポジトリの存在確認

`~/ghq/github.com/branch10480/learnings/` が存在しない場合、ユーザーに「learnings リポジトリが見つかりません。先に初期化してください」と伝えて中断する。

### 2. design-system.html を Read する

新しい entry を書き始める前に `~/.claude/skills/html-artifact/design-system.html` を Read してデザイントークンとコンポーネントを確認する。

### 3. ARGUMENTS（トピック）から entry を構想する

ユーザーが渡したトピックについて、以下を決める:

- **slug**: 英数字とハイフンのファイル名用識別子（例: `epub-internals`, `oauth-pkce`, `swift-actor`）
- **title**: 日本語タイトル（カード表示用、30 文字以内推奨）
- **tags**: 3〜6 個のタグ（小文字英単語、複数語はハイフン）
  - 既存タグの再利用を優先（後述「既存タグの確認」を参照）
- **summary**: 1〜2 文のサマリ（カード表示用、120〜180 文字推奨）
- **reading-time**: 推定読了時間（分、整数）

### 4. 既存タグの確認

すでに存在するタグを再利用するため、`~/ghq/github.com/branch10480/learnings/index.html` の `<script id="entries-data">` を読み、過去 entry のタグセットを確認する。新規タグを追加する場合は最小限に。

### 5. entry HTML を生成

`~/ghq/github.com/branch10480/learnings/entries/YYYY-MM-DD-<slug>.html` として生成。日付は今日（CLAUDE.md の `currentDate` を使用）。

**必須要素**:

- `<head>` 内に design-system.html の `:root` トークンブロックを再宣言
- `<head>` 内に以下のメタタグを必ず含める（index 自動生成のソース）:

```html
<meta name="learning:title"   content="…">
<meta name="learning:date"    content="YYYY-MM-DD">
<meta name="learning:tags"    content="tag1, tag2, tag3">
<meta name="learning:summary" content="…">
<meta name="learning:reading-time" content="20">
```

  **属性の書き方ルール**（rebuild_index.py が拾うための契約）:

  - **属性順序**: `name` → `content` の順で書く（逆順は対応していない）
  - **スペル**: `learning:` プレフィクス + 小文字 key（`title`, `date`, `tags`, `summary`, `reading-time`）
  - **クオート**: ダブルクオート `"` 推奨。content 内にダブルクオートが必要な場合は `&quot;` でエスケープするか、外側をシングルクオートに変える
  - **content の値**: 改行を含めない 1 行で書く

- 本文は html-artifact スキルの構造に従う:
  - `header.masthead` + eyebrow + serif h1 + lead + meta + TOC pills
  - 番号付きセクション（`.sec-head` の idx + h2）
  - 適宜 callout / table / code / SVG diagram / list を使う
- 5 セクション以上を目安に、十分な情報量で書く
- **「← All entries」のナビゲーションリンクを必ず含める**。masthead の eyebrow の直前に配置:

```html
<header class="masthead">
  <a href="../index.html" class="back-link"><span aria-hidden="true">←</span> All entries</a>
  <div class="eyebrow">…</div>
  …
</header>
```

対応する CSS（`<style>` 内 `header.masthead` の直後に追加）:

```css
a.back-link {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  font-family: var(--mono);
  font-size: 12px;
  letter-spacing: 0.06em;
  color: var(--g500);
  text-decoration: none;
  margin-bottom: 28px;
  padding: 6px 12px;
  border-radius: var(--r-pill);
  border: var(--b-rule);
  background: var(--paper);
  transition: color 120ms, border-color 120ms;
}
@media (hover: hover) {
  a.back-link:hover { color: var(--slate); border-color: var(--slate); }
}
```

### 6. index.html を再生成

ヘルパースクリプトを実行:

```bash
python3 ~/.claude/skills/learn/rebuild_index.py ~/ghq/github.com/branch10480/learnings
```

このスクリプトは `entries/*.html` を全部 scan し、`learning:*` メタタグを抽出して `index.html` 内の
`<script id="entries-data">…</script>` ブロックを書き換える。手動で index.html を編集する必要はない。

### 7. ローカル確認の案内

```bash
open ~/ghq/github.com/branch10480/learnings/index.html
```

をユーザーに伝える。新しい entry のカードが先頭に表示され、タグフィルタにも反映されているはず。

### 8. git commit（push は手動）

ユーザーが明示的に「push して」と言わない限り、commit までで止める:

```bash
cd ~/ghq/github.com/branch10480/learnings
git add entries/<new-file>.html index.html
git commit -m "Add learning entry: <title>

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

push のタイミングはユーザー判断に委ねる（`git push` か、push スキルを誘導）。

## ガイドライン

- **トーン**: 静かで正確。装飾は最小限、情報密度を優先（html-artifact と同じ）
- **絵文字**: 本文中では使わない。会話メッセージにはユーザー向けに使ってよい
- **長さ**: 短すぎる explainer は HTML 化のメリットが薄い。Markdown で済むなら Markdown で
- **対象読者**: 未来の自分。後から検索 / 読み返したときに迷わない構成を優先
- **コード例**: できるだけ実際に動くスニペットを入れる。`pre.code` クラスでハイライト
- **図解**: 概念図は SVG で。`.cl .oa .ln .da` などの SVG ユーティリティクラスを活用
- **段階的開示**: 最初のセクションで「核心の一文」を提示してから詳細に入る

## 適用しないケース

- ユーザーが Markdown を明示的に指定したとき
- 1〜2 段落で済む短い回答（HTML 化はオーバーキル）
- 機密情報を含むメモ（learnings は public repo）

## トラブルシューティング

- **rebuild_index.py が動かない**: Python 3 が必要。スクリプトは標準ライブラリのみ使用
- **メタタグが拾われない**: `<meta name="learning:*">` のスペルを確認。`learning:` プレフィクス必須
- **index に出てこない**: ファイルが `entries/` 直下にあるか確認。サブディレクトリは scan しない
- **rebuild_index.py が `exit 1` を返した**: **絶対に `index.html` を手動編集しないこと**。エラーメッセージ（stderr）を読んで、欠けているメタタグや壊れた HTML を修正してから再実行する。よくある原因:
  - 必須メタタグ (`title` / `date` / `tags` / `summary`) のいずれかが欠けている
  - メタタグの content 内のクオートが unescape されていて HTML が壊れている
  - すべての entry が skip されて結果がゼロ件になった（既存 index を空配列で潰すのを防ぐため意図的に exit 1）
  - `<head>` タグが見つからない entry が含まれている
- **exit code の意味**:
  - `0`: 成功（変更なし or index.html を更新）
  - `1`: 入力エラー（ディレクトリなし / `<script id="entries-data">` ブロック未検出 / 全 entry skip）
  - `2`: 引数不正（usage を表示）
