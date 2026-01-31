---
name: castle
description: castleリポジトリ（dotfiles）の変更をcommitしてpushする
disable-model-invocation: false
argument-hint: [コミットメッセージ]
allowed-tools: Bash
---

# castle更新

homeshickで管理しているcastleリポジトリ（dotfiles）に変更をコミットしてプッシュしてください。

## 手順

1. リポジトリに移動: `~/.homesick/repos/castle`
2. `git status` で変更を確認
3. `git diff` で差分を確認
4. **ドキュメント更新チェック**:
   - 変更内容が README.md や CLAUDE.md の記述に影響するか確認
   - 影響がある場合は該当箇所を更新（例: ツール追加/削除、設定変更など）
5. 変更があれば:
   - 変更ファイルを `git add`（ドキュメント更新を含む）
   - コミットメッセージ: $ARGUMENTS（指定がなければ変更内容から自動生成）
   - `git push` でリモートにプッシュ
6. 結果を報告

## ドキュメント更新が必要なケース

- シェル設定の変更（プロンプト、ツール追加/削除）→ CLAUDE.md の「シェル設定」、README.md の「シェル」セクション
- Neovim プラグイン追加/削除 → README.md の「エディタ」セクション
- 新規スキル/コマンド追加 → CLAUDE.md の「主要コマンド・スキル」
- ディレクトリ構造変更 → CLAUDE.md の「リポジトリ構造」

## 注意事項
- Co-Authored-By を含める
- untrackedファイルは確認してから追加
- ドキュメント更新もコミットに含める
