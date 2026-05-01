# Stylus Custom CSS

[Stylus](https://add0n.com/stylus.html) ブラウザ拡張で使うカスタムCSSの保管場所。

## ファイル一覧

| ファイル | 適用先URL | 用途 |
|---|---|---|
| `slack.css` | `slack.com` を含むURL | Slackブラウザ版のフォント差し替え（本文: ヒラギノ明朝ProN / コード: JetBrainsMono Nerd Font） |

## 使い方

1. ブラウザ版Slack（`https://app.slack.com/...`）を開く
2. Stylus拡張のアイコン → 「`app.slack.com`に対応するスタイルを書く」
3. 本ファイルの内容をコピペ
4. 左側「適用先」を **「URL に含まれる」+ `slack.com`** に設定
5. 保存 → Slackをリロード

## 必要なフォント

事前に下記がインストールされていること：

- **ヒラギノ明朝ProN** (macOS標準)
- **JetBrainsMono Nerd Font** ([Nerd Fonts公式](https://www.nerdfonts.com/font-downloads) からDL)

確認コマンド：

```sh
fc-list | grep -iE "(hira|jetbrains)"
```

## 設計メモ（CSSの3層構造）

1. **Layer 1**: `* { JetBrainsMono }` で全画面を等幅で塗りつぶす（土台）
2. **Layer 2**: 本文セレクタで明朝に上書き
3. **Layer 3**: コードブロックは同一クラスを4回重ねた高詳細度セレクタで再度等幅に戻す

Slack内蔵CSSが3クラス連結（詳細度 `(0,0,3,0)`）の `!important` を使うため、
こちらは4回重ね（`(0,0,4,0)`）で詳細度勝負に勝つ設計。
