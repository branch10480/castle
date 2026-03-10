---
name: castle-dotfiles
description: "homeshick管理のdotfilesリポジトリ castle（~/.homesick/repos/castle）を扱う。/castle の依頼で、ローカルのcastleに移動し、変更のステージ、差分に基づくコミットメッセージ作成、コミット、プッシュを行うときに使う。"
---

# Castle Dotfiles

## Overview

homeshick管理のdotfilesリポジトリ「castle」を、ステージ・文脈に合ったメッセージでのコミット・プッシュまで一連で扱う。

## Workflow

1) Locate and enter the repo  
`~/.homesick/repos/castle` を使う。存在しない場合は報告し、正しいパスを確認する。

2) Inspect status  
`git status -sb` を実行して要約する。クリーンなら「変更なし」と報告し、no-opコミットの指示がない限り停止する（確認する）。

3) Review diffs and decide commit message  
`git diff --stat` と `git diff` を確認し、簡潔で説明的な英語コミットメッセージを作る。

4) Stage changes  
`git add -A` を使い、`git status -sb` で再確認する。

5) Commit  
`git commit -m "<message>"` を使う。コミット対象がなければ報告して停止する。

6) Push  
`git push` でプッシュする。このワークフローでは `gh` は使わない。

## Notes

- このワークフローでは `gh` を使わない。  
- 変更に合った簡潔なコミットメッセージを優先する（例: "Update zsh settings", "Refine git aliases"）。  
- 独立した変更が複数ある場合は、コミット分割を提案する。
