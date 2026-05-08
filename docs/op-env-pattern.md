# プロジェクトの `.env` を `op://` で運用する（Phase 3）

任意のプロジェクト（Web app、CLI、インフラ管理リポジトリ等）で API キーや認証情報を扱うとき、生値を `.env` に書かず **1Password を起点に実行時注入する** 運用パターン。castle 自体ではなく **castle 外のプロジェクト側で採用するスタイル**を定める文書。

仕組みの土台は Phase 2 で導入した zsh ヘルパ `oprun`（`home/.zshrc.d/op.zsh`）と、`op run --env-file=` の組み合わせ。

```zsh
oprun [--env-file=<path>] -- <command...>
# 内部: op run --env-file=<path> --no-masking -- <command...>
# env-file の既定値は ./.env.op
```

## なぜプロジェクト `.env` を 1Password 化するか

- **生値が history / backup / IDE インデックスに散らばる**: ローカル `.env` はバージョン管理外でも、tarball、Time Machine、エディタの search index、ビルドアーティファクト等に容易に流出する
- **キーローテーション時に "どの開発者がどの値を持っているか" が追えない**: 中央 (1Password vault) で管理すると一斉ローテートが効く
- **CI / 同僚の環境に persist しない**: env-file には `op://` URI のみが残るため、リポジトリを clone した側が自分の vault item を作れば動く（同名・同フィールドの規約だけ揃える）

## ファイル命名規約

| ファイル | 役割 | git 追跡 |
|---|---|---|
| `.env.op` | プロジェクト共通の `op://` URI テンプレ | **コミット可**（生値が無いことが大前提） |
| `.env.op.local` | machine-local override（仕事 Mac 用 vault 名違い等） | **必ず ignore** |
| `.env` | 通常の dotenv（dev デフォルト値、non-secret 設定） | プロジェクト方針に従う（多くは ignore） |

`.env.op` は **`KEY=op://<vault>/<item>/<field>` のみ**を含む。`oprun` 経由で展開された値は子プロセスの環境変数として存在し、ディスクには書かれない。

## プロジェクト `.gitignore` への追記

```gitignore
# 1Password CLI 経由で実行する場合の machine-local override
.env.op.local
```

`.env.op` 自体は **追跡対象**（生値が入らない前提）。`.env.op` に万一生値が貼られた瞬間に secret 化するため、castle の `scripts/scan-secrets.sh` を pre-push で走らせる運用を強く推奨する。

## `.env.op` の中身

```
# 1 行 = 1 環境変数。値は必ず op:// URI。
OPENAI_API_KEY=op://Private/OpenAI API/credential
ANTHROPIC_API_KEY=op://Private/Anthropic API/credential
DATABASE_URL=op://Private/Staging DB/connection_string
```

`op run` は env-file の各行を独立に処理するので、種類の違うキーを 1 ファイルにまとめても問題ない。複数のサービスを使うアプリでも env-file 1 本で済む。

## 実行例

### 単発コマンド

```bash
# .env.op を参照（デフォルト）
oprun -- node ./scripts/embed.js

# 別の env-file を明示
oprun --env-file=./infra/.env.op -- terraform plan
```

### npm / yarn / pnpm scripts

`npm run` / `yarn run` / `pnpm run` は **sh 経由でスクリプトを起動する**ため、zsh 関数の `oprun` は呼べない。**`op run` を直接書く**こと。

```json
{
  "scripts": {
    "dev": "op run --env-file=.env.op -- vite",
    "build": "op run --env-file=.env.op -- vite build",
    "test": "op run --env-file=.env.op -- vitest"
  }
}
```

`oprun` が `--no-masking` を付けるのに対し、生 `op run` は **マスキング ON がデフォルト**。stdout/stderr に値が偶発的に出力された場合 `<concealed by 1Password>` で伏せられる。アプリのデバッグ出力で値そのものが見たいときだけ `--no-masking` を足す。

### Makefile

```makefile
.PHONY: dev
dev:
	op run --env-file=.env.op -- python manage.py runserver
```

Makefile は sh 経由なので npm 同様に `op run` を直接呼ぶ。

### direnv 連携（cd しただけで env が揃う運用）

`.envrc`:

```bash
# direnv を使ってディレクトリに入った瞬間に op が値を inject する設定。
# .env.op の op:// URI を実値に展開し export する。

if has op; then
  # `op inject` は「テンプレファイル → 解決済みテキスト」変換を行う。
  # env-file 形式（KEY=URI）をそのまま渡すと、解決後に KEY=<value> の
  # 行が出力される。eval ... に流して環境変数化する。
  eval "$(op inject -i .env.op | sed 's/^/export /')"
else
  log_status "op CLI not found; skipping .env.op resolution"
fi
```

`direnv allow` を 1 度実行すれば、以降は `cd` するだけで環境変数が揃う。1Password GUI のセッションが生きていれば Touch ID プロンプトは出ない。

> 注意: `direnv` の `dotenv` 関数は `op://` URI を解釈しない。`op inject` を経由する必要がある。

### Docker / Docker Compose

```bash
op run --env-file=.env.op -- docker compose up
```

`op run` は子プロセスにのみ env を渡すので、`docker compose up` の下で動くコンテナにも各 `KEY=<value>` が引き継がれる（compose の `environment:` が `${KEY}` 参照を含んでいる場合）。

## machine-local override（仕事 Mac での vault 名違い）

仕事 Mac は別の 1Password アカウント・別 vault 構造を持つ可能性がある。その場合は `.env.op.local`（ignore 対象）を作って vault 名を上書きする運用にする。

```
# .env.op.local（machine-local、コミットしない）
OPENAI_API_KEY=op://Employer/OpenAI API/credential
```

実行側はそのファイルを env-file として渡す:

```bash
oprun --env-file=.env.op.local -- node ./scripts/embed.js
```

`oprun` 自体に「`.env.op.local` があればそれを優先」のような挙動は無い。**呼び出し側で明示する**ことで、machine-local 設定が unintentional に他環境に効くのを防いでいる（透過 fallback は事故の温床）。

## CI で使う場合

対話 Touch ID 前提の `op` は CI には向かない。代わりに **Service Account Token** を使う:

1. 1Password 管理画面で Service Account を作成し、必要な vault に read 権限を付与
2. CI 環境変数 `OP_SERVICE_ACCOUNT_TOKEN` に token を保管
3. `op run --env-file=.env.op -- <cmd>` がそのまま動く（Service Account モードは GUI を介さない）

GitHub Actions 公式 action `1password/load-secrets-action` を使うパターンも実務では一般的。castle 自体には CI 用途が無いため詳細は割愛。

## トラブルシュート

| 症状 | 原因 | 対策 |
|---|---|---|
| `op run` が `error: failed to read item` | URI の vault / item / field が typo | `op item list --vault <v>` で実名を、`op item get "<item>" --vault <v>` でフィールド名を確認 |
| Touch ID プロンプトが毎回出る | 1Password GUI が lock されている / GUI 連携 OFF | GUI を起動して unlock。Settings → Developer → "Integrate with 1Password CLI" を ON。auto-lock を緩める設定もあり |
| 値が古いまま | env-file が古い URI を指している、または item を新規作成して field 名がずれた | item 名・field 名と URI が一致しているか確認。1Password は item rename しても URI が古い名前を保持しないので、リネーム後は env-file 側も追従が必要 |
| `oprun` が `command not found` | sh / Makefile / npm scripts から呼んでいる | 生 `op run --env-file=.env.op -- <cmd>` を使う。`oprun` は zsh 関数 |
| `op run` の出力が `<concealed by 1Password>` だらけで debug できない | masking が効いている | デバッグ時のみ `--no-masking` を足す。本番運用では masking ON 推奨 |
| `direnv` 経由で env が反映されない | `.envrc` を `direnv allow` していない / `op inject` が失敗している | `direnv reload` してログを見る。`op inject -i .env.op` を手動実行して原因切り分け |

## 設計上の注意

1. **`.env.op` は生値を入れた瞬間に secret 化する**: 普段はコミット対象だが、誤って生値を貼ったら `scripts/scan-secrets.sh` が検出する。検出したら即 rotate（生値の混入は履歴にも残るため）
2. **`.env` を捨てて `.env.op` 一本にする必要は無い**: ローカル dev 用の dummy 値や non-secret 設定（ポート番号、フィーチャフラグ等）は通常の `.env` のままで良い。1Password に入れる価値があるのは **実環境で使う実キー** のみ
3. **チームメンバーに同じ vault 構造を強制しない**: 各開発者が自分の Private vault に同名 item を作る運用が現実的。`.env.op` の URI が共通の規約として機能する
4. **`OP_ACCOUNT` の machine-local 切り替え**: 個人 / 仕事 Mac でアカウントを変える場合、`~/.zshrc.local` で `export OP_ACCOUNT=<short_name>` を設定（castle 共通設定からは分離）

## 関連

- castle 側の Phase 2（`oprun` ヘルパ実装）: `home/.zshrc.d/op.zsh`
- castle 側の Phase 4（MCP API キーの op 化）: `config/op/perplexity.env`、`CLAUDE.md` の Phase 4 セクション
- secret スキャナ: `scripts/scan-secrets.sh`
