# Stylus Custom CSS

[Stylus](https://add0n.com/stylus.html) ブラウザ拡張で使うカスタムCSSの保管場所。

## ファイル一覧

| ファイル | 適用先URL | 用途 |
|---|---|---|
| `slack.css` | `slack.com` を含むURL | Slackブラウザ版のフォント差し替え（英数字: JetBrainsMono Nerd Font / 日本語フォールバック: ヒラギノ角ゴ ProN W3） |

## 使い方

1. ブラウザ版Slack（`https://app.slack.com/...`）を開く
2. Stylus拡張のアイコン → 「`app.slack.com`に対応するスタイルを書く」
3. 本ファイルの内容をコピペ
4. 左側「適用先」を **「URL に含まれる」+ `slack.com`** に設定
5. 保存 → Slackをリロード

## 必要なフォント

事前に下記がインストールされていること：

- **ヒラギノ角ゴ ProN** (macOS標準。`Hiragino Sans W3` 以上)
- **JetBrainsMono Nerd Font** ([Nerd Fonts公式](https://www.nerdfonts.com/font-downloads) からDL、または castle の nix-darwin 経由で `nerd-fonts.jetbrains-mono` をインストール)

確認コマンド：

```sh
fc-list | grep -iE "(hira|jetbrains)"
```

## 設計メモ（per-glyph fallback 戦略）

CSSの `font-family` リストは **「文字ごとにフォント探索」** する仕様で、
最初のフォントに該当グリフが無ければ自動で次のフォントへフォールバックする。
この仕様を活かして以下の設計：

```
font-family:
  "JetBrainsMono Nerd Font",   /* 英数字・記号・コード合字 */
  "Hiragino Sans W3",          /* 日本語（JBMにグリフが無いので自動フォールバック） */
  ...
```

結果として：

- **Hello world** → JetBrainsMono Nerd Font
- **こんにちは** → ヒラギノ角ゴ ProN W3（自動フォールバック）
- **PRレビューOK** → 「PR」「OK」JBM ＋ 「レビュー」角ゴのハイブリッド表示

> 当初は「ヒラギノ明朝 ProN」を採用していたが、castle 全体の方針転換に合わせて Sans 化済み（commit `199ac95`）。背景は [`docs/font-strategy.md`](../docs/font-strategy.md) §6.1 を参照。

### コードブロックの詳細度勝負

Slack内蔵CSSは `.c-texty_input_unstyled__container .ql-editor .ql-code-block` のような
**3クラス連結 `!important`**（詳細度 `(0,0,3,0)`）でコードブロックの font-family を上書きしてくる。
これに勝つため、こちらは **同一クラスを4回重ねた `(0,0,4,0)` セレクタ** を使って詳細度バトルに勝つ設計：

```css
.ql-code-block.ql-code-block.ql-code-block.ql-code-block { ... }
```

CSS仕様上、同じクラスを複数回書いてもマッチ条件は変わらないが、**詳細度カウントだけ上がる**ため、
他要件への影響を最小化しつつ確実に上書きできる。
