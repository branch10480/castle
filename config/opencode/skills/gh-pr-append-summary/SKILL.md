---
name: gh-pr-append-summary
description: "GitHub PRの本文に変更概要の箇条書きを追記する。既存文言は削除せず、PRのファイル変更から概要を生成して `## 概要` 直下に追加する依頼で使う。"
---

# Gh Pr Append Summary

## Overview

GitHub PRの本文に、変更内容の要約を追記する。既存の本文は保持したまま `## 概要` 直下に箇条書きを追加する。

## Workflow

### 1. PR情報を取得する（ghのみ使用）

```bash
gh pr view <PR番号> --json title,body,files,url
```

### 2. 追記する要約の箇条書きを作る

- 変更ファイルのディレクトリや目的別にまとめて簡潔に書く（1〜4行程度）
- 例（`.codex` 同期系の変更）:
  - `.claude` の rules/docs/agents を `.codex` にミラーし、Codex 側の運用ルールを最新化
  - `.codex/skills` を同期し、`create-snapshot-test` を SKILL 化
  - `pr-review.md` の自動生成クレジットを Codex CLI 表記に更新（`.codex` 側のみ）

### 3. PR本文へ追記する（既存文言は削除しない）

#### ルール
- `## 概要` があれば、その直下に箇条書きを追加
- なければ `## 概要` を新規作成して末尾に追加
- 既存文言は削除・改変しない

```bash
gh pr edit <PR番号> --body "<更新後の本文>"
```

### 4. 反映後の確認

```bash
gh pr view <PR番号> --json body,url
```
