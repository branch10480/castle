# 仕事 Mac セットアップ手順（Phase 8）

castle は **個人 Mac で動くこと**を前提に整備されている。仕事 Mac（別の 1Password アカウント・別の GitHub identity・別の SSH 鍵）で同じ castle を運用する際の **差分手順だけ** をここに集約する。

個人 Mac 用の汎用手順は `CLAUDE.md` 本体に書いてあるので、本書は **「個人 Mac との差分」だけ** を取り扱う。共通部分は CLAUDE.md を参照のこと。

## 個人 Mac との差分マトリクス

| 領域 | 個人 Mac | 仕事 Mac | 仕組み |
|---|---|---|---|
| 1Password アカウント | Personal（1 アカウント） | Personal + Employer（2 アカウント並走） | `op account add` で追加。`OP_ACCOUNT` で切替 |
| 1Password vault 名 | `Private` | 仕事用は組織が決めた名前（例: `Employer`） | `.env.op.local` などの machine-local override で吸収 |
| GitHub identity | 個人アカウント | 仕事アカウント（同じ github.com 上の別ユーザー） | `~/.gitconfig.local` を仕事用 email に書く |
| SSH 鍵 | 1Password 内に 1 本（Personal 用） | 1Password 内に 2 本（Personal + Employer 用、別アイテム） | SSH config の `Host` 別エントリで使い分け |
| commit signing key | Personal SSH 鍵 | Employer SSH 鍵 | `~/.gitconfig.local` の `signingkey` を仕事用に |
| MCP API キー | `op://Private/...` | `op://Employer/...`（仕事独自キー） / `op://Private/...`（個人と同じキーで OK） | `~/.config/op/<server>.env` を仕事 Mac だけ別 URI に書き換え |
| プロジェクト `.env.op` | 値は `op://Private/...` | `.env.op.local` で `op://Employer/...` に上書き | Phase 3 docs の machine-local override |
| Touch ID 認証 | Personal アカウントのみで Touch ID | アカウントごとに Touch ID（最初の数回ペアリング必要） | 1Password 8 GUI で各アカウントの Developer settings を ON |

「**castle 内の追跡ファイルは仕事 Mac で書き換えない**」が大原則。違いは全部 machine-local（`~/.gitconfig.local` / `~/.zshrc.local` / `.env.op.local` / `~/.config/op/<server>.env` の URI）に逃がす。

## bootstrap チェックリスト

新規仕事 Mac で castle を動かすまでの手順。**順番厳守**（特に SSH と Git signing の依存関係）。

### 1. 前提のインストール（個人 Mac と共通）

CLAUDE.md の `nix-darwin / Home Manager` セクションを参照。homeshick → Nix → 1Password 8 GUI まで。
1Password 8 GUI で **個人アカウント・仕事アカウントの両方を sign in** しておく（後で `op account list` に出る）。

### 2. 1Password アカウントの追加と既定切替

```bash
# Personal は GUI で sign in 済みの想定。Employer 用 sign-in を CLI 側にも登録:
op account add --address my.1password.com --email <work email>
# 対話で Secret Key を要求される（1Password emergency kit 参照）

# 利用可能なアカウントを確認
op account list

# 仕事 Mac での既定アカウントを Employer にする
echo 'export OP_ACCOUNT=<employer_short_name>' >> ~/.zshrc.local
```

`OP_ACCOUNT` の short name は `op account list --format=json | jq -r '.[].shorthand'` で確認できる。

> 補足: `~/.zshrc.local` は castle 管理外（machine-local）。castle の `home/.zshrc` 末尾で source される設計だが、未設定の場合の挙動も壊れない。

### 3. SSH 鍵の準備（仕事用）

仕事 Mac は **新規に仕事用 SSH 鍵を 1Password 内で生成**する（個人鍵は使い回さない）:

1. 1Password 8 GUI → Employer アカウントを選択 → 新規 SSH Key アイテム生成（`Ed25519` 推奨）
2. 公開鍵をコピー → 仕事の GitHub アカウントの **Authentication keys** に登録
3. 同じ公開鍵を仕事の GitHub アカウントの **Signing keys** にも登録（authentication と signing は GitHub 上で別管理）
4. 1Password 8 GUI → Settings → Developer → **Use the SSH agent** が ON か確認（Personal Mac と同じ要領）

### 4. SSH config の確認（castle 共通設定で動く）

`config/ssh/config` は仕事 Mac でもそのまま使える。1Password agent socket パス (`~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock`) は **AgileBits Team ID 由来でアカウント横断共通**のため、変更不要。

複数の GitHub identity を使い分けるなら `Host` 別エントリで明示する:

```ssh-config
# ~/.ssh/config 末尾（machine-local stub の Include の後）に追記
# ※ castle 管理外のため ~/.ssh/config を直接編集する

Host github-personal
  HostName github.com
  User git
  IdentityAgent ~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock
  IdentityFile ~/.ssh/personal_pubkey.pub
  IdentitiesOnly yes

Host github-work
  HostName github.com
  User git
  IdentityAgent ~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock
  IdentityFile ~/.ssh/work_pubkey.pub
  IdentitiesOnly yes
```

`IdentityFile` は **公開鍵**ファイル（agent から該当する秘密鍵を選ばせるためのヒント）。1Password GUI から各鍵の「Copy public key」で `~/.ssh/<name>_pubkey.pub` に書き出して `chmod 600` する。

clone するときは `git@github-work:org/repo.git` のように `Host` を指定すれば仕事鍵が選ばれる。

### 5. Git identity（仕事用）

`~/.gitconfig.local` を **仕事用 email + 仕事用 signing key** で作る:

```bash
cat > ~/.gitconfig.local <<EOF
[user]
	email = <work email>
	signingkey = key::<work ssh public key, e.g. ssh-ed25519 AAAA...>
EOF
chmod 600 ~/.gitconfig.local
```

`allowed_signers` も仕事の鍵に置き換え:

```bash
mkdir -p ~/.config/git && chmod 700 ~/.config/git
echo "<work email> <work ssh public key>" > ~/.config/git/allowed_signers
chmod 600 ~/.config/git/allowed_signers
```

> 注意: 個人と仕事の両方の repo を同じ Mac で扱うなら、`includeIf` で directory ベースに切り替える運用も可。
> 例: `~/.gitconfig` に `[includeIf "gitdir:~/ghq/github.com/<work-org>/"] path = ~/.gitconfig.work` を追加し、`~/.gitconfig.local` を Personal、`~/.gitconfig.work` を Employer にする。castle 共通 `home/.gitconfig` は変えずに、machine-local 側で対応する。

### 6. MCP API キー（Phase 4 の vault 名違い）

castle が追跡している `config/op/perplexity.env` の `op://` URI は **個人 Mac 想定**:

```
PERPLEXITY_API_KEY=op://Private/Perplexity API/credential
```

仕事 Mac で別 vault に同じキーがあるなら、**castle 配下を編集せず** `~/.config/op/perplexity.env` を直接書き換える運用が安全:

```bash
# castle の symlink を解除して machine-local 版に差し替え（仕事 Mac だけの操作）
rm ~/.config/op/perplexity.env
cat > ~/.config/op/perplexity.env <<EOF
PERPLEXITY_API_KEY=op://Employer/Perplexity API/credential
EOF
chmod 600 ~/.config/op/perplexity.env
```

> 注意: この方式だと castle の追跡対象から外れるため、castle を `homeshick refresh` しても上書きされない。**復元したいときに castle 側を pull するだけでは戻らない**点に留意。仕事 Mac の `.gitignore` 様の意図的退避として運用する。
>
> あるいは仕事 Mac でも castle の URI を共通にしたいなら、1Password の Employer 側に `Private` という名前の vault を作る or vault 名を `Private` に揃える運用も検討可。

### 7. プロジェクト `.env.op` の上書き（Phase 3 連携）

castle 外の自分のプロジェクトでは Phase 3（[`docs/op-env-pattern.md`](op-env-pattern.md)）で定義した `.env.op.local` を使って vault 名を上書きする:

```
# .env.op.local（仕事 Mac、コミットしない）
OPENAI_API_KEY=op://Employer/OpenAI API/credential
```

実行時に明示的に切り替える:

```bash
oprun --env-file=.env.op.local -- npm run dev
```

`.env.op` 自体は個人と共通で commit されたまま。仕事 Mac だけ `.env.op.local` を使う、という機械別差分。

### 8. 動作確認

| 確認項目 | コマンド | 期待結果 |
|---|---|---|
| 1Password CLI signin | `op-status` | `my.1password.com / <work email>` |
| 1Password 複数アカウント | `op account list` | Personal + Employer の 2 行 |
| 仕事用 SSH 認証 | `ssh -T git@github-work` | `Hi <work username>!` |
| Git signing | `git -C <work repo> commit --allow-empty -m "test signing"` → `git log --show-signature -1` | `Good "git" signature for <work email>` |
| MCP（Claude Code） | `claude mcp list` | `perplexity ✓ Connected`（仕事側 vault でも） |
| プロジェクト env | プロジェクトディレクトリで `oprun --env-file=.env.op.local -- env \| grep OPENAI_API_KEY` | 値が伏せ字で出る（`--no-masking` 無しだと `<concealed by 1Password>` 相当） |

## トラブルシュート（仕事 Mac 特有）

| 症状 | 原因 | 対策 |
|---|---|---|
| `op` がいつも個人アカウントを引いてしまう | `OP_ACCOUNT` が未設定 or 個人を指している | `~/.zshrc.local` の `OP_ACCOUNT` を仕事 short name に。`exec zsh` で再読込 |
| `op item get ... --vault Employer` が `not found` | 仕事アカウントに sign in できていない / vault 名違い | `op account list` で Employer が出るか確認。`op vault list` で vault 名一覧を確認 |
| Touch ID プロンプトが個人鍵を要求してくる | SSH config の `Host` を指定せず `git@github.com` で clone した | clone URL を `git@github-work:...` に変更。既存 remote は `git remote set-url origin git@github-work:org/repo.git` |
| commit が Personal の email で署名されてしまう | `~/.gitconfig.local` を作っていない or `includeIf` の directory パスがズレている | `git -C <repo> config user.email` で確認。期待値と違えば `~/.gitconfig.local` / `~/.gitconfig.work` 経路を見直す |
| 仕事 GitHub 上で commit が Verified にならない | 仕事 GitHub アカウントの **Signing keys** に公開鍵を登録していない（Authentication keys だけ登録した） | GitHub Settings → SSH and GPG keys → Signing keys に登録（同じ鍵でも別管理が必要） |

## 設計上の注意

1. **castle 内のファイルは編集しない**: 仕事 Mac だけの差分はすべて `~/.zshrc.local` / `~/.gitconfig.local` / `~/.gitconfig.work` / `~/.config/op/<server>.env`（symlink を解除した実体）/ `.env.op.local` に逃がす。castle に commit する瞬間に「仕事固有の値」が入っていたら個人 Mac 側で壊れる
2. **`OP_ACCOUNT` を `~/.zshrc.local` で固定する**: 都度 `op --account=...` を打つよりミス耐性が高い
3. **GitHub の Authentication と Signing は別管理**: 同じ公開鍵でも GitHub 上で別の枠に登録しないと、push は通るが Verified バッジが付かない
4. **`includeIf` でディレクトリベース切替も検討**: `ghq` で個人と仕事を別 root に置いている場合、`~/.gitconfig` の `includeIf "gitdir:..."` で identity を自動切替できる。castle 共通 `home/.gitconfig` は変えず、machine-local 側で `[includeIf]` を組む

## 関連

- 個人 Mac 用の汎用手順: `CLAUDE.md` の各セクション（SSH / Git / 1Password / Phase 2 / Phase 4）
- プロジェクト `.env.op` 運用パターン: [`docs/op-env-pattern.md`](op-env-pattern.md)
- nix-darwin / Home Manager: [`config/nix-darwin/README.md`](../config/nix-darwin/README.md)
