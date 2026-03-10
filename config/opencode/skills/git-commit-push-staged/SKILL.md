---
name: git-commit-push-staged
description: ステージ済みのGit変更を差分から作成した英語メッセージでコミットし、現在のローカルブランチと同名のoriginブランチへプッシュする。ユーザーがステージ済み変更のコミットと同名リモートブランチへのプッシュを求め、コミットメッセージを差分から推測すべき場合に使う。
---

# Git Commit Push Staged

## Overview

ステージ済み差分から作成した簡潔な英語コミットメッセージでコミットし、同名ブランチの `origin` へプッシュする。

## Workflow

### 1) Validate preconditions

- `git status -sb` でステージ状況を確認し、ステージ済み変更があることを確認する。
- 何もステージされていなければ、ステージするか次の対応をユーザーに確認する。
- `git branch --show-current` で現在のブランチを確認する。

### 2) Inspect staged diff and craft message

- `git diff --staged` でステージ済み変更を確認する（必要なら `git diff --staged --stat`）。
- 変更意図と範囲を英語の命令形タイトルで要約する。
- タイトルは約50文字に抑え、必要なら短い本文を付ける。

### 3) Commit staged changes

- `git commit -m "<title>"` でステージ済み変更のみをコミットする。
- 本文が必要なら複数行メッセージで `git commit` を使う。

### 4) Push to origin same-name branch

- `git push origin <current-branch>` で `origin` にプッシュする。
- GitHub関連の確認（認証/ステータス/リポジトリ情報）は `gh` を使う（例: `gh auth status`, `gh repo view`）。

## Notes

- 明示的な指示がない限り、新規ステージやindex変更は行わない。
- ブランチ名が取得できない場合は、進める前にユーザーへ確認する。
- 認証エラーでプッシュに失敗したら `gh auth status` を使って案内する。
