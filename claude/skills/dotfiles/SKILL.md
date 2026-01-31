---
name: dotfiles
description: homeshickで管理しているdotfilesをcommitしてpushする
disable-model-invocation: false
argument-hint: [コミットメッセージ]
allowed-tools: Bash
---

# dotfiles更新

homeshickで管理しているdotfilesリポジトリに変更をコミットしてプッシュしてください。

## 手順

1. リポジトリに移動: `~/.homesick/repos/castle`
2. `git status` で変更を確認
3. `git diff` で差分を確認
4. 変更があれば:
   - 変更ファイルを `git add`
   - コミットメッセージ: $ARGUMENTS（指定がなければ変更内容から自動生成）
   - `git push` でリモートにプッシュ
5. 結果を報告

## 注意事項
- Co-Authored-By を含める
- untrackedファイルは確認してから追加
