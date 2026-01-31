# Git Add, Commit, Push

すべての変更をadd、commit、pushする。

## 手順

1. `git status` で変更状況を確認する
2. `git diff` と `git diff --cached` で変更内容を確認する
3. 変更内容を分析し、適切なcommitメッセージを生成する
   - 変更の種類（追加/修正/削除）を把握
   - 何を変更したか簡潔に説明
   - 必要であれば詳細を本文に記載
4. `git add -A` ですべての変更をステージング
5. 生成したメッセージでcommit
6. `git push` でリモートにpush

## Commitメッセージのフォーマット

```
<type>: <subject>

<body (optional)>

Co-Authored-By: Claude <noreply@anthropic.com>
```

### Type

- `feat`: 新機能
- `fix`: バグ修正
- `docs`: ドキュメントのみの変更
- `style`: コードの意味に影響しない変更（空白、フォーマット等）
- `refactor`: バグ修正でも機能追加でもないコード変更
- `chore`: ビルドプロセスやツールの変更

## 注意

- 機密ファイル（.env、credentials等）が含まれていないか確認する
- 変更がない場合はその旨を報告して終了する
