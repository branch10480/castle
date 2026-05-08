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
| MCP API キー | `op://Private/...` | 同 URI を Employer 側にも揃える（vault 名共通化が推奨） | `~/.config/op/<server>.env` は **castle 配下の実ファイル** で個別 symlink ではないため、書き換えると castle 追跡対象を直接編集してしまう。1Password 側で同名 vault / item を用意するのが安全 |
| プロジェクト `.env.op` | 値は `op://Private/...` | `.env.op.local` で `op://Employer/...` に上書き | Phase 3 docs の machine-local override |
| Touch ID 認証 | Personal アカウントのみで Touch ID | アカウントごとに Touch ID（最初の数回ペアリング必要） | 1Password 8 GUI で各アカウントの Developer settings を ON |

「**castle 内の追跡ファイルは仕事 Mac で書き換えない**」が大原則。違いは全部 machine-local 側（`~/.gitconfig.local` / `~/.zshrc.local` / `.env.op.local`）に逃がし、1Password 側の vault / item 名は仕事 / 個人で **共通化**することで castle 追跡ファイルを変えずに済ませる。共通化できない MCP API キーだけは `--assume-unchanged` で castle 配下を上書きする最終手段が残っている（後述セクション 6 参照）。

## bootstrap チェックリスト

新規仕事 Mac で castle を動かすまでの手順。**順番厳守**（特に SSH と Git signing の依存関係）。

### 1. 前提のインストール（個人 Mac と共通）

CLAUDE.md の `nix-darwin / Home Manager` セクションを参照。homeshick → Nix → 1Password 8 GUI まで。
1Password 8 GUI で **個人アカウント・仕事アカウントの両方を sign in** しておく（GUI integration 経由の sign-in は `op account list` の出力には現れない場合があるため、CLI 側でも別途確認する）。

### 2. 1Password アカウントの追加と既定切替

```bash
# Personal は GUI で sign in 済みの想定。Employer 用 sign-in を CLI 側にも登録:
# --address は 1Password Business / Enterprise 契約だとテナント固有 URL になる
# （例: <team>.1password.com / <team>.1password.eu / <team>.1password.ca）。
# 個人 1Password の場合は my.1password.com で OK。
op account add --address <your-team-domain>.1password.com --email <work email>
# 対話で Secret Key を要求される（1Password emergency kit 参照）

# 利用可能なアカウントを確認
op account list

# 仕事 Mac での既定アカウントを Employer にする
echo 'export OP_ACCOUNT=<value>' >> ~/.zshrc.local
```

`OP_ACCOUNT` には次のいずれを設定してもよい（`op --help` の `--account` 説明より）:

- account shorthand — `op account list` で確認可。`op account add --shorthand <name>` で固定もできる。CLI で手動 sign-in したアカウントなら安定して取れる
- sign-in address — 例: `my.1password.com` / `<team>.1password.com`。**GUI integration だけで sign-in したアカウントはこれで指定するのが堅い**
- account UUID / user UUID — `op account list --format=json` の `account_uuid` / `user_uuid`

GUI integration 経由のみで sign-in している場合、`op account list` が空配列を返すことがあるので、その際は sign-in address を `OP_ACCOUNT` に設定する。

> 補足: `~/.zshrc.local` は castle 管理外（machine-local）。castle の `home/.zshrc` の **上部**（`~/.zshrc.d/*.zsh` の source より前）で読み込まれる設計で、`OP_ACCOUNT` は `op.zsh` が初期化される前に export されるため安全に効く。未設定でも壊れない。

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

`IdentityFile` は **公開鍵**ファイル（OpenSSH 公式仕様では本来は秘密鍵を指すが、1Password agent と組み合わせる場合の慣習として、agent 内の秘密鍵を選ばせるヒントに対応する公開鍵パスを渡す。秘密鍵をディスクに置かない設計と組み合わせるための運用）。1Password GUI から各鍵の「Copy public key」で `~/.ssh/<name>_pubkey.pub` に書き出して `chmod 644` する（公開鍵は慣例的に `0644`）。

clone するときは `git@github-work:org/repo.git` のように `Host` を指定すれば仕事鍵が選ばれる。

### 5. Git identity（仕事用）

`~/.gitconfig.local` を **仕事用 email + 仕事用 signing key** で作る。`signingkey` の値先頭の `key::` プレフィックスは git の SSH signing で「鍵をファイルパスではなく公開鍵リテラルで指定する」記法（[`git-config(1)` `gpg.ssh.defaultKeyCommand`](https://git-scm.com/docs/git-config) 周辺の仕様）。これは 1Password agent 経由で秘密鍵をディスクに置かない設計と組み合わせるために必要。

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

> 注意: 個人と仕事の両方の repo を同じ Mac で扱うなら、`includeIf` で directory ベースに自動切替する運用も可。`~/.gitconfig` 自体は **`castle/home/.gitconfig` への symlink なので絶対に書き込まない**。代わりに `~/.gitconfig.local` 側に `[includeIf]` を追記する（git の include は ["The contents of the included file are inserted immediately, as if they had been found at the location of the include directive."](https://git-scm.com/docs/git-config) という仕様で、include 先のファイル内に書かれた `[includeIf]` も同じ位置に展開されるため再帰的に有効）:
>
> ```ini
> # ~/.gitconfig.local（machine-local、castle 管理外）
> [user]
>     email = <personal email>                  # 既定（個人 repo 用）
>     signingkey = key::<personal ssh public key>
>
> # 仕事 repo ディレクトリでは追加で work identity を読み込む
> [includeIf "gitdir:~/ghq/github.com/<work-org>/"]
>     path = ~/.gitconfig.work
> ```
>
> `~/.gitconfig.work` 側に仕事用 `[user]` ブロック（仕事 email / signingkey）を書く。`gitdir:` の値は **末尾スラッシュ付き** でディレクトリ配下マッチを意味する。castle 共通 `home/.gitconfig` には一切触らない。

### 6. MCP API キー（Phase 4 の vault 名違い）

castle が追跡している `config/op/perplexity.env` の `op://` URI は **個人 Mac 想定**:

```
PERPLEXITY_API_KEY=op://Private/Perplexity API/credential
```

homeshick が張る symlink は `~/.config -> ~/.homesick/repos/castle/home/.config`（= `castle/config`）の **トップレベル dir symlink** だけで、`~/.config/op/perplexity.env` は **castle 配下の実ファイルそのもの**を指す（`readlink ~/.config` で確認できる）。したがって `~/.config/op/perplexity.env` を `rm` したり書き換えたりすると、**castle 配下の追跡ファイルを直接編集している**ことになる。これは「castle 内のファイルは編集しない」原則と真逆になるので避ける。

仕事 Mac で別 vault のキーを使いたい場合は、次のいずれかで対応する:

#### 推奨: 1Password 側で vault / item 名を揃える

Employer アカウント側に **`Private` という名前で vault を作る**（既存 vault のリネームでも可）、もしくは Personal / Employer 双方に `Perplexity API` という同名アイテムを置く。castle が追跡している URI (`op://Private/Perplexity API/credential`) を仕事 / 個人で共通化することで、castle 配下を一切編集しなくて済む。`OP_ACCOUNT` で実行アカウントを切り替えるだけで vault 内容が切り替わる。

#### 代替: `--assume-unchanged` で castle 配下を上書き

vault 名がどうしても揃えられない場合のみ、castle 内のファイルを書き換えて git に「変更を無視させる」運用にする:

```bash
# castle 内のファイルを書き換え、git の追跡から除外したことにする
sed -i.bak 's|op://Private/|op://Employer/|' \
  ~/.homesick/repos/castle/config/op/perplexity.env
git -C ~/.homesick/repos/castle update-index --assume-unchanged \
  config/op/perplexity.env
```

> ⚠️ `--assume-unchanged` は **ローカル変更を index に反映しないように git に伝えるフラグ**で、git 公式仕様では当該ファイルを更新する必要が出た merge / pull 操作は **graceful に fail する**（公式: "Git will fail (gracefully) in case it needs to modify this file in the index"）。pull が黙って通るわけではなく、当該ファイルが upstream で更新されたときに pull が止まる挙動。upstream に変更が入ったら `git update-index --no-assume-unchanged config/op/perplexity.env` で一旦解除し、手動 merge → 再度 assume-unchanged をかける運用になる。極力 **vault 名共通化（推奨案）** で済ませること。

### 7. プロジェクト `.env.op` の上書き（Phase 3 連携）

castle 外の自分のプロジェクトでは Phase 3（[`op-env-pattern.md`](op-env-pattern.md)）で定義した `.env.op.local` を使って vault 名を上書きする:

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
| 1Password CLI signin | `op-status` | `URL` / `Email` 行に仕事アカウントの値が出ること（`op whoami` の出力フォーマットは CLI バージョンで列構成が変わる可能性あり） |
| 1Password 複数アカウント | `op account list`（or `op whoami --account <shorthand>`） | Personal + Employer の両方が確認できること。GUI integration 経由の sign-in は `op account list` に出ない場合があり、その場合は `op whoami --account <shorthand>` で個別確認 |
| 仕事用 SSH 認証 | `ssh -T git@github-work` | `Hi <work username>!` |
| Git signing | `git -C <work repo> commit --allow-empty -m "test signing"` → `git log --show-signature -1` | `Good "git" signature for <work email>` |
| MCP（Claude Code） | `claude mcp list` | `perplexity ✓ Connected`（仕事側 vault でも） |
| プロジェクト env | プロジェクトディレクトリで `oprun --env-file=.env.op.local -- env \| grep OPENAI_API_KEY` | `OPENAI_API_KEY=<値>` が **生で表示される**（`oprun` は常に `--no-masking` 付きで `op run` を呼ぶため）。マスキングを効かせて確認したいときは生 `op run --env-file=.env.op.local -- env \| grep OPENAI_API_KEY` を直接呼ぶ |

## トラブルシュート（仕事 Mac 特有）

| 症状 | 原因 | 対策 |
|---|---|---|
| `op` がいつも個人アカウントを引いてしまう | `OP_ACCOUNT` が未設定 or 個人を指している | `~/.zshrc.local` の `OP_ACCOUNT` を仕事 short name に。`exec zsh` で再読込 |
| `op item get ... --vault Employer` が `not found` | 仕事アカウントに sign in できていない / vault 名違い | `op account list` で Employer が出るか確認。`op vault list` で vault 名一覧を確認 |
| Touch ID プロンプトが個人鍵を要求してくる | SSH config の `Host` を指定せず `git@github.com` で clone した | clone URL を `git@github-work:...` に変更。既存 remote は `git remote set-url origin git@github-work:org/repo.git` |
| commit が Personal の email で署名されてしまう | `~/.gitconfig.local` を作っていない or `includeIf` の directory パスがズレている | `git -C <repo> config user.email` で確認。期待値と違えば `~/.gitconfig.local` / `~/.gitconfig.work` 経路を見直す |
| 仕事 GitHub 上で commit が Verified にならない | 仕事 GitHub アカウントの **Signing keys** に公開鍵を登録していない（Authentication keys だけ登録した） | GitHub Settings → SSH and GPG keys → Signing keys に登録（同じ鍵でも別管理が必要） |
| `op-status` が `1Password CLI is locked` を返す（GUI は起動しているのに） | OS / 1Password アプリのアップデート後に "Integrate with 1Password CLI" トグルが OFF に戻った / GUI と `op` daemon の握手が切れた | 下の「1Password CLI integration の復旧」節を参照 |

### 1Password CLI integration の復旧

OS / 1Password アプリのアップデート後など、`op-status` が `1Password CLI is locked` を返す状態に陥ったときの復旧手順。**初手で GUI 側のトグルを目視確認**するのが最重要（出力文言だけでは原因が判別できない）。

#### 切り分け

```bash
op-status         # 期待: URL/Email/User ID 3 行。"locked" が出れば異常
op account list   # アカウントが 1 件以上見えるか（GUI integration の最低限の通信確認）
```

| `op-status` | `op account list` | 状態 |
|---|---|---|
| ✓ | ✓ | 正常 |
| ✗ locked | ✓ アカウント可視 | **アカウントは見えるが session 無し**（最頻パターン）— GUI integration が中途半端に切れている |
| ✗ locked | ✗ 空（"No accounts configured"） | GUI integration が完全に切れている / トグル OFF |

#### 復旧手順（順に実行）

1. **GUI 側のトグル目視確認**（多くはこれだけで直る）:
   - 1Password 8 GUI → `Settings` (`⌘,`) → **Developer** → **"Integrate with 1Password CLI" が ON か**
   - OFF だったら ON にする
   - **既に ON でも、一度 OFF → ON にトグル**して握手を再発動させる

2. それでも `op-status` が `locked` のまま:
   ```bash
   # 古い socket と op daemon を片付ける
   pkill -f "op-daemon" 2>/dev/null
   rm -f ~/.config/op/op-daemon.sock

   # 1Password GUI を強制終了 → 再起動（osascript の quit は効かないことがあるので killall を使う）
   killall 1Password 2>/dev/null
   killall "1Password Helper" 2>/dev/null
   killall "1Password Helper (GPU)" 2>/dev/null
   killall "1Password Helper (Renderer)" 2>/dev/null
   killall "1Password-BrowserSupport" 2>/dev/null
   sleep 3

   # GUI が完全停止したか確認
   pgrep -lf "1Password" | head

   # 起動し直す
   open -a "1Password"
   ```
   → GUI を **Touch ID で unlock** → トグルが ON のままか再確認 → `op-status` 確認

3. アカウントは見えるが session が無い（中間状態）の場合は **`op signin` で握手をやり直す**:
   ```bash
   op signin
   # → Touch ID プロンプトが出るので承認
   ```
   その後 `op-status` が通れば成功。`claude mcp list` で `perplexity ✓ Connected` も確認。

#### 仕組み（次に詰まったときのために）

- `op-status` (= 内部で `op whoami` を呼ぶ) は **session token を必要とする**ため、GUI から daemon への握手が切れていると `locked` を返す
- `op account list` は **アカウントレジストリの読み出しだけ**で session を必要としない。両者の差で「整合度合い」が分かる
- `~/.config/op/op-daemon.sock` は `op` 側の自前 socket。`lsof | grep op-daemon` で実プロセスが listening しているかが分かる
- 1Password 8 のメジャーアップデートや macOS 系のセキュリティ強化で **"Integrate with 1Password CLI" トグルが暗黙にリセットされる**ことがある（運用上の最頻原因）

## 設計上の注意

1. **castle 内のファイルは編集しない**: 仕事 Mac だけの差分はすべて `~/.zshrc.local` / `~/.gitconfig.local`（必要に応じて派生する `~/.gitconfig.work`）/ `.env.op.local` に逃がす。MCP API キーは 1Password 側で vault / item 名を仕事 / 個人で共通化して castle 追跡ファイルを変えずに済ませる（共通化できない場合のみ最終手段として `--assume-unchanged`、セクション 6 参照）。castle に commit する瞬間に「仕事固有の値」が入っていたら個人 Mac 側で壊れる
2. **`OP_ACCOUNT` を `~/.zshrc.local` で固定する**: 都度 `op --account=...` を打つよりミス耐性が高い
3. **GitHub の Authentication と Signing は別管理**: 同じ公開鍵でも GitHub 上で別の枠に登録しないと、push は通るが Verified バッジが付かない
4. **`includeIf` でディレクトリベース切替も検討**: `ghq` で個人と仕事を別 root に置いている場合、`~/.gitconfig.local` 内に `[includeIf "gitdir:..."]` を書いて identity を自動切替できる（git の include は再帰的に有効。詳細はセクション 5 参照）。castle 共通 `home/.gitconfig` および `~/.gitconfig`（symlink）には触らない

## 関連

- 個人 Mac 用の汎用手順: `CLAUDE.md` の各セクション（SSH / Git / 1Password / Phase 2 / Phase 4）
- プロジェクト `.env.op` 運用パターン: [`op-env-pattern.md`](op-env-pattern.md)
- nix-darwin / Home Manager: [`config/nix-darwin/README.md`](../config/nix-darwin/README.md)
