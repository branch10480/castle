# SSH / Git 初回セットアップ（1Password agent + commit signing）

castle の SSH/Git 統合は「秘密鍵をディスクに置かず、auth と commit signing 双方を 1Password agent に集約する」設計。本ドキュメントは新規 Mac で動かすまでの初回手順を扱う。CLAUDE.md には方針サマリのみ残す。

関連: [`work-mac-setup.md`](work-mac-setup.md)（仕事 Mac での差分）

---

## SSH 設定（1Password agent 連携）

`config/ssh/config` に SSH client 設定本体を集約。`home/.config -> ../config` 経由で `~/.config/ssh/config` に自動 symlink される。

`~/.ssh/` には秘密鍵があり homeshick で扱わないため、`~/.ssh/config` は **machine-local** の最小ファイル（`Include ~/.config/ssh/config` の 1 行）として運用する。

### 初回セットアップ手順（新規 Mac で 1 度だけ）

1. `homeshick link castle` を実行（`config/ssh/config` が `~/.config/ssh/config` に symlink される）
2. **permissions を当てる**（git はディレクトリ mode を追跡せず、ファイルも新規 clone 後は 644 で展開されるため。nix-darwin 適用済み Mac では `home.activation.fixSensitiveConfigPermissions` が自動で当て直すので step 2 自体を skip して良い）:
   ```bash
   chmod 700 ~/.config/ssh
   chmod 600 ~/.config/ssh/config
   ```
3. `~/.ssh/config` を machine-local の Include stub として作成:
   ```bash
   printf 'Include ~/.config/ssh/config\n' > ~/.ssh/config
   chmod 600 ~/.ssh/config
   ```
4. 1Password 8 を起動 → Settings → Developer → **Use the SSH agent** を ON
5. 動作確認: `ssh -T git@github.com` で `Hi <username>! You've successfully authenticated...` が返ることを確認

### ポイント

- 1Password の SSH agent socket パス (`~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock`) は AgileBits Team ID に依存し、**個人/ビジネスを問わずアカウント横断で同一**。複数 Mac（個人 / 仕事）で同じ config が機能する
- `Host github.com` ブロックには `IdentityFile` を置かず、認証は 1Password agent 経由のみ（秘密鍵をディスクに置かない設計）
- **秘密鍵はディスクに置かない**。auth / signing 双方が `op-ssh-sign` + 1Password agent 経由で完結し、Touch ID で都度承認される。新規 Mac では「1Password 内で SSH 鍵を新規生成」もしくは「既存鍵を import 後にローカルファイルを退避（`mkdir -p -m 700 ~/.ssh-keys-backup && mv ~/.ssh/id_* ~/.ssh-keys-backup/`）→ `ssh -T git@github.com` と test commit で動作確認 → バックアップは緊急復旧用に保持」の流れで運用する

---

## Git 設定（commit signing 含む）

`home/.gitconfig` に共通の Git 設定（commit signing、diff/merge tool、`user.name`）を集約し、`~/.gitconfig` は `castle/home/.gitconfig` への symlink で運用する。

identity（`user.email` / `user.signingkey`）と credential helper は **machine-local** の `~/.gitconfig.local` に分離し、`[include] path = ~/.gitconfig.local` 経由で読み込む。これにより個人 Mac と仕事 Mac で異なる identity を保持できる。テンプレは `home/.gitconfig.local.example`。

`gh auth setup-git` は `credential.helper` を `~/.gitconfig` に追記することがあるが、castle では `~/.gitconfig` が共通管理ファイルへの symlink なので、そのまま commit しない。Nix store 由来の `gh` wrapper path などホスト固有の helper は `~/.gitconfig.local` 側へ置く。

commit signing は **1Password SSH agent + `op-ssh-sign`** で行い、SSH 鍵そのもので commit を署名する（GPG 不要）。Touch ID で都度承認される。

> ⚠️ **新規 Mac で `homeshick link castle` 直後は `~/.gitconfig.local` が未作成**のため、`commit.gpgsign = true` が castle 側で有効でも署名ができず commit が失敗する（`error: gpg failed to sign the data`）。**castle 配下で commit する前に必ず以下の手順 1〜4 を完了**させてから commit すること（5・6 は GitHub 側 Verified バッジ用なので後回し可）。

### 初回セットアップ手順（新規 Mac で 1 度だけ）

1. `homeshick link castle` を実行。`~/.gitconfig` の symlink が自動で作られない場合は手動で:
   ```bash
   if [ ! -L ~/.gitconfig ]; then
     ln -s ~/.homesick/repos/castle/home/.gitconfig ~/.gitconfig
   fi
   ```
2. 1Password に SSH 鍵を import（既存鍵を import するか、1Password 内で新規生成）
3. machine-local identity ファイルを作成（`<...>` を実際の値に置換）:
   ```bash
   cat > ~/.gitconfig.local <<EOF
   [user]
   	email = <your email>
   	signingkey = key::<ssh public key, e.g. ssh-ed25519 AAAA...>
   EOF
   chmod 600 ~/.gitconfig.local
   ```
4. 自分の commit を verify するための allowed_signers を作成（`~/.config/git/` は homeshick 経由で生まれるが、castle 未使用の Mac でも動くよう `mkdir -p` で防御）:
   ```bash
   mkdir -p ~/.config/git && chmod 700 ~/.config/git
   echo "<your email> <ssh public key>" > ~/.config/git/allowed_signers
   chmod 600 ~/.config/git/allowed_signers
   ```
5. GitHub に同じ公開鍵を **signing key** として登録（authentication key とは別管理）。1Password のアイテム詳細から「公開鍵をコピー」してから次を実行:
   ```bash
   gh auth refresh -h github.com -s admin:ssh_signing_key   # 初回のみスコープ追加
   pbpaste > /tmp/op-pubkey.pub                             # クリップボードからファイル化
   gh ssh-key add /tmp/op-pubkey.pub --title "<machine name> (1Password signing)" --type signing
   rm /tmp/op-pubkey.pub
   ```
6. 動作確認: 任意の git リポジトリで `git commit --allow-empty -m "test signing"` を実行。1Password の Touch ID プロンプトが出て、`git log --show-signature -1` に `Good "git" signature` が表示されれば成功
