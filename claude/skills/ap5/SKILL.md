---
name: ap5
description: >-
  approduce_member_5 ブランチを現在ブランチ基点で作成して強制 push し、元ブランチへ戻って
  ローカルの approduce_member_5 を削除する。ユーザーが「ap5」「approduce_member_5 を作って
  強制 push して戻す」などを依頼したときに使う。
disable-model-invocation: false
allowed-tools: Bash
---

# AP5

`approduce_member_5` を現在ブランチ基点で一時的に作成して `origin` へ `--force` push し、
最後に元ブランチへ戻ってローカルの `approduce_member_5` を削除する。

> **注意**: このワークフローは `origin/approduce_member_5` の履歴を上書きする。

## ワークフロー

### 1. 現在ブランチを取得してバリデーション

- `target_branch="approduce_member_5"` を固定値として使う。
- `git branch --show-current` で開始ブランチを取得する。
- 取得結果が空の場合（detached HEAD など）は停止してユーザーへ確認を求める。
- 現在ブランチが `approduce_member_5` と同じ場合は停止して、別ブランチへ移動後に再実行するよう案内する。

### 2. ローカルに対象ブランチが存在すれば削除

- `git show-ref --verify --quiet "refs/heads/approduce_member_5"` で存在確認する。
- 存在する場合は `git branch -D "approduce_member_5"` で強制削除する。

### 3. 対象ブランチを作成して切り替え

- `git switch -c "approduce_member_5"` で現在ブランチの先頭から作成し、切り替える。

### 4. origin へ強制 push

- `git push -u origin "approduce_member_5" --force` を実行する。
- `--force` がブランチ保護により拒否された場合はエラーを報告して停止する。
- 認証エラー時は `gh auth status` で状態を確認するよう案内する。

### 5. 元ブランチへ戻りローカルを削除

- `git switch <元のブランチ>` でもとのブランチへ戻る。
- `git branch -D "approduce_member_5"` でローカルの `approduce_member_5` を削除する。

### 6. 結果を報告

- 開始ブランチへ復帰できたことと、`origin/approduce_member_5` を強制更新したことを報告する。

## コマンドシーケンス

以下の順序で実行する:

```bash
current_branch="$(git branch --show-current)"
target_branch="approduce_member_5"
if [ -z "$current_branch" ]; then echo "detached HEAD 状態です。ブランチへ移動してから再実行してください。"; exit 1; fi
if [ "$current_branch" = "$target_branch" ]; then echo "すでに $target_branch 上にいます。別ブランチへ移動してから再実行してください。"; exit 1; fi
if git show-ref --verify --quiet "refs/heads/$target_branch"; then git branch -D "$target_branch"; fi
git switch -c "$target_branch"
git push -u origin "$target_branch" --force
git switch "$current_branch"
git branch -D "$target_branch"
```

## エラーハンドリング

- **detached HEAD**: 空の `current_branch` を検出したら停止し、ブランチへの移動を案内する。
- **ブランチ保護**: `--force` が拒否された場合はエラー内容を報告して停止する。
- **認証エラー**: `gh auth status` で認証状態を確認するよう案内する。
