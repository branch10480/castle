---
name: git-commit-push-all
description: Gitの全変更をステージし、差分全体から英語のコミットメッセージを作成してコミットし、現在のブランチをoriginへプッシュする。ユーザーが全変更の追加（git add -A / git add .）と、推測したメッセージでのコミットおよび同名リモートブランチへのプッシュを求めたときに使う。
---

# Git Commit Push All

## Overview

全変更をステージし、差分全体から英語のコミットメッセージを作成してコミットし、現在のブランチをoriginへプッシュする。

## Workflow

### 1) Validate preconditions

- `git status -sb` で作業ツリーの状態を確認する。
- 変更が一切ない場合は、次にどうするかユーザーへ確認する。
- `git branch --show-current` で現在のブランチを確認する。

### 2) Stage all changes

- `git add -A` で全てをステージする（適切なら `git add .`）。
- `git status -sb` で再確認し、ステージ済みの変更があることを確認する。

### 3) Inspect full diff and craft message

- `git diff --staged` でステージ済み差分全体を確認する（必要なら `git diff --staged --stat`）。
- 変更意図と範囲を英語の命令形タイトルで要約する。
- タイトルは約50文字に抑え、必要なら短い本文を付ける。

### 4) Commit all staged changes

- `git commit -m "<title>"` でコミットする。
- 本文が必要なら複数行メッセージで `git commit` を使う。

### 5) Push to origin same-name branch

- `git push origin <current-branch>` で `origin` にプッシュする。
- GitHub関連の確認（認証/ステータス/リポジトリ情報）は `gh` を使う（例: `gh auth status`, `gh repo view`）。

## Notes

- ブランチ名が取得できない場合は、進める前にユーザーへ確認する。
- 認証エラーでプッシュに失敗したら `gh auth status` を使って案内する。
