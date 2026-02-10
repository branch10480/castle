---
name: castle
description: homeshick管理のcastleリポジトリへ移動し、全変更をadd・commit・pushする。コミットメッセージは差分を見て英語で自動生成する。
---

# Castle Update

homeshickで管理しているcastleリポジトリ（dotfiles）に移動し、変更をコミットしてプッシュする。

## 手順

1. `homeshick cd castle` を実行して castle ディレクトリへ移動する。
2. `git status --short` と `git diff` で変更内容を確認する。
3. 変更がない場合は「コミット対象なし」と報告して終了する。
4. `git add -A` ですべての変更をステージングする。
5. 差分を要約した英語のコミットメッセージを作成する。
6. `git commit -m "<english message>"` を実行する。
7. `git push` でリモートへ反映する。
8. 実行結果として、ブランチ名・コミットハッシュ・コミットメッセージを報告する。

## コミットメッセージ規則

- 必ず英語で記述する。
- 変更内容が一目でわかる具体的な文にする。
- 必要に応じて Conventional Commits 形式（`feat: ...`, `fix: ...`, `chore: ...`）を使う。

## 注意事項

- 機密情報（認証情報、秘密鍵、トークン）が含まれていないか確認する。
- 失敗時はエラー内容と次に必要な操作を報告する。
