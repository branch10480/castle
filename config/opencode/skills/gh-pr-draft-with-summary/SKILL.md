---
name: gh-pr-draft-with-summary
description: GitHub PRテンプレートの「概要」セクションに変更点の箇条書きを差し込み、Draft PRを作成する。ユーザーが「draftでPR作成」「概要を追加してPRを作る」「テンプレに概要を入れる」などを依頼したときに使う。
---

# Gh Pr Draft With Summary

## Overview

GitHub PRテンプレートを使いつつ、概要セクションに今回の変更点を自動で追記してDraft PRを作成する。

## Workflow

### 1) 事前確認

- `git status -sb` で現在のブランチとコミット状況を確認する。
- PRに使うタイトルを決める（原則 `git log -1 --pretty=%s` を使う）。
- GitHub操作は必ず `gh` を使う。

### 2) 概要の箇条書きを用意

- ユーザーから概要の箇条書きを受け取る。
- 受け取れない場合は差分から仮案を作り、ユーザーに確認する。

### 3) PR本文をテンプレから生成

- `.github/PULL_REQUEST_TEMPLATE.md` を読み込む。
- 「## 概要」直下に概要の箇条書きを挿入する。
- 生成は `scripts/prepare_pr_body.py` を使う。

実行例:

```
python /path/to/prepare_pr_body.py \
  --template .github/PULL_REQUEST_TEMPLATE.md \
  --summary "- 変更点A\n- 変更点B" \
  --out /tmp/pr_body.md
```

### 4) Draft PRを作成

- タイトルは最新コミットから取得するのが基本。
- `gh pr create --draft --title "$(git log -1 --pretty=%s)" --body-file /tmp/pr_body.md` を使う。
- 作成後、PR URLを返す。

### 5) 例外対応

- テンプレが存在しない場合は、`--fill` で作成し概要は手動追記を提案する。
- `gh` の認証問題がある場合は `gh auth status` で案内する。

## Resources

### scripts/prepare_pr_body.py

PRテンプレに概要を差し込むためのスクリプト。

