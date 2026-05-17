# ユーザースコープ指示

- AGENTS.md は日本語で記述すること。
- 応答は日本語を使うこと。
- 応答はフレンドリーな口調で、絵文字を使うこと。
- GitHub への操作は `gh` コマンドを使うこと。
- PR のタイトル・説明文・コメントは、特に指定がない限り日本語で書くこと。
- Markdown は GFM 形式で作成すること。
- 技術仕様・API・ライブラリ・SDK・MCP サーバー・iOS/Apple 系の新機能など、最新性が重要な質問では、回答前に最新情報を確認すること。
- GitHub SSH push は 1Password SSH agent 経由で行う。`ssh-add -l` が `The agent has no identities.` を返しても、通常の ssh-agent ではなく `~/.ssh/config` の `IdentityAgent` で 1Password agent socket を直接使う構成なので、それだけで失敗判定しないこと。
- SSH 状態確認は `ssh -G github.com | rg -i 'identityagent|hostname|user'` と `ssh -T git@github.com` を使う。期待値は `Hi branch10480! You've successfully authenticated...`。
- 設定本体は `~/.config/ssh/config`（castle: `config/ssh/config`）で、`~/.ssh/config` は `Include ~/.config/ssh/config` の machine-local stub。
