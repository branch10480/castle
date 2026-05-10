---
name: html-artifact
description: "HTML ファイルとして成果物（spec / report / mockup / プロトタイプ / リサーチ / 解説 / ダッシュボード / カスタムエディタ）を生成する。`HTMLで作って` `HTML artifact` `HTMLファイルにまとめて` `デザインを揃えて` と言われたとき、また Markdown では伝わりにくいリッチな表現（カラーパレット、SVG ダイアグラム、KPI、テーブル、対話 UI）が必要なときに使用する。`design-system.html` を参照してトークンとコンポーネントを再利用する。"
disable-model-invocation: false
---

# html-artifact

Claude が HTML 形式で artifact を生成するときに参照するスキル。`design-system.html` に集約された ivory + clay デザイントークンとコンポーネントパターンを使い、**単一ファイルで完結する HTML** を出力する。

参照元: [thariqs/html-effectiveness](https://thariqs.github.io/html-effectiveness/) のデザイン言語をベースにしている。

## 手順

### 1. design-system.html を必ず Read する

artifact を書き始める前に、このスキルディレクトリの `design-system.html` を Read する。`:root` ブロックのトークン定義と、各セクションのコンポーネント実装を参照元として扱う。

### 2. 単一ファイル完結で書く

- **外部 CSS / JS をリンクしない**。`<link rel="stylesheet">` や CDN 参照は使わない
- `:root` の CSS 変数ブロックを HTML の `<style>` 内に毎回再宣言する（design-system.html の冒頭をコピーするのが最短）
- フォントは system font stack で完結（Web フォント読み込みなし）
- 画像は SVG inline か data-URI 推奨（外部ファイルに依存させない）

### 3. デザイントークンに従う

色は CSS 変数経由でのみ参照する。リテラル hex を直書きしない。

| 用途 | トークン |
|---|---|
| ページ背景 | `--ivory` |
| カード・パネル | `--paper` |
| 本文・見出し | `--slate` / `--g700` |
| アクセント | `--clay`（一画面に 1〜2 箇所まで） |
| セカンダリ・成功表示 | `--olive`（赤緑を避ける） |
| 罫線・ボーダー | `--g200`（細）/ `--g300`（標準） |
| コードブロック背景 | `--g100`（純グレーではなく warm tint） |

### 4. タイポグラフィの役割分担

- **見出し**: `--serif` + `font-weight: 500` + `letter-spacing: -0.01em`
- **本文**: `--sans` + 15px + `line-height: 1.55`
- **eyebrow / メタ / コード**: `--mono` + 12px + `letter-spacing: 0.12em` + 大文字（eyebrow の場合）

#### `--mono` は JetBrainsMono Nerd Font Mono を採用

`--mono` の 1 番手は `"JetBrainsMono Nerd Font Mono"`（Nerd glyphs も等幅化された版）。`config/nix-darwin/darwin.nix` で `nerd-fonts.jetbrains-mono` が宣言されているため、castle が適用された Mac には常にインストールされている前提。フォルバックチェーンは `JetBrainsMono Nerd Font` → `JetBrains Mono` → `ui-monospace` → `SF Mono` → … なので、未導入環境でも破綻しない。新規 artifact を書くときも同じチェーンをコピーすること。

### 5. コンポーネントを使い回す

design-system.html の以下のセクションをそのまま流用する:

1. **Masthead** — eyebrow + serif h1 + lead + meta + TOC pills
2. **Section head** — mono の idx 番号 + serif h2 + count badge
3. **Cards** — thumb (SVG) + body + `.file` mono フッター
4. **Buttons & Pills** — `.btn-primary` / `.btn-outline` / `.pill` 系
5. **Code** — `pre.code` ブロック + `code.inline`
6. **Callouts** — `.callout-note` / `.callout-success` / `.callout-warn`
7. **Tables** — `table.t`（`.num` で数字列を mono 整列）
8. **Tabs** — CSS + 10 行 JS のステートレス実装
9. **Lists** — `ol.serif-list`（手順用）/ `ul.dot-list`（スキャン用）
10. **KPI** — serif の数値 + mono のラベル
11. **SVG toolkit** — `.st .fl .cl .ol .oa .sl .wh .ln .lc .da` のユーティリティクラス

### 6. レイアウトの基本

- コンテナ: `max-width: 1120px; margin: 0 auto; padding: 0 32px 140px;`
- セクション間: `margin-top: 72px;`
- セクション内本文の左マージン: `margin-left: 50px;`（idx 番号と本文を揃えるため）。`@media (max-width: 640px)` で 0 に解除

### 7. 出力先と確認

- artifact を書き出す先は会話ごとに決める（プロジェクト直下の `artifacts/` や `tmp/` など、ユーザーに確認するか文脈で判断）
- 書き出したら `open <file>` でブラウザで開けることを伝える
- 共有用なら S3 / GitHub Pages / Gist にアップロードする方法を提案できる

## 適用しないケース

- ユーザーが明示的に Markdown を指定したとき
- README / CHANGELOG / リリースノートなど、Markdown が標準フォーマットの成果物
- バージョン管理で diff を頻繁にレビューする想定のドキュメント（HTML diff はノイジー）
- 1 行〜数行の短い回答（HTML 化はオーバーキル）

## トーンのガイド

- **静かで正確** が基本。装飾は最小限、情報密度を優先
- アクセント（clay）は loud な要素なので、画面全体で 1〜2 箇所に絞る
- 絵文字は本文中では使わない（記事のトーンに揃える）。一方、ユーザー向けの会話メッセージには絵文字を使ってよい（`~/.claude/CLAUDE.md` の方針に従う）

## 注意事項

- design-system.html は **コピペ元** として機能させる設計。各 artifact が独立して動くよう、共通 CSS 化はしない
- トークン名を勝手に変えない（`--g100` を `--gray-100` に書き換えない、など。揺れると参照しづらくなる）
- 機密情報（API キー / トークン / 個人情報）が artifact に紛れ込まないよう、書き出し前に確認する

## ユーザー向けの使い方ドキュメント

人間（ユーザー）が読むためのプロンプト集と運用ガイドは `docs/html-artifact-usage.html` にある。SKILL.md は Claude が読む設計仕様、`docs/html-artifact-usage.html` は人間が読むチュートリアル、という役割分担。新しいプロンプト例や運用 tips が増えたら `docs/html-artifact-usage.html` 側に追記する。

### 閲覧方法

- **ローカル（推奨）**: `open ~/.homesick/repos/castle/docs/html-artifact-usage.html`
  - JetBrainsMono Nerd Font 込みでデザインが完璧に再現される
- **GitHub Web から rendered で見る**: 以下の htmlpreview リンクを使う
  - `https://htmlpreview.github.io/?https://github.com/branch10480/castle/blob/main/docs/html-artifact-usage.html`
  - GitHub Web で `.html` を直接クリックすると view-source 表示になるため、共有相手にはこの URL を渡す
- **将来オプション**: HTML doc が複数に増えた場合は GitHub Pages 化（`branch10480.github.io/castle/...`）で短い URL にできる
