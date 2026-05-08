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

`.env.op` 自体は **追跡対象**（生値が入らない前提）。`.env.op` に万一生値が貼られた瞬間に secret 化するため、castle の `scripts/scan-secrets.sh --staged` を **pre-commit** で走らせる運用を強く推奨する（履歴に生値が入った時点で rotate 必須化するため、検出は push ではなく commit 直前で行う）。

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

`oprun` が `--no-masking` を付けるのに対し、生 `op run` は **マスキング ON がデフォルト**。stdout/stderr に値が偶発的に出力された場合は伏せ字で置換される（現行実装では `<concealed by 1Password>` 相当だが、CLI バージョンで文言が変わる可能性あり）。アプリのデバッグ出力で値そのものが見たいときだけ `--no-masking` を足す。

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
# .env.op を op inject で実値に解決し、direnv の `dotenv` ローダに食わせる。
# `dotenv` は KEY=VALUE を文字列としてパースするため、値に $(...) /
# バックティック / 引用符 / 改行が含まれていても shell injection や
# 値破壊が起きない。`eval "$(op inject ...)"` 形式は値次第で危険なので
# 使わない。
if has op && [[ -f .env.op ]]; then
  watch_file .env.op
  resolved="$(direnv_layout_dir)/op-env"
  mkdir -p "$(dirname "$resolved")"
  op inject -i .env.op > "$resolved"
  dotenv "$resolved"
elif ! has op; then
  log_status "op CLI not found; skipping .env.op resolution"
fi
```

`direnv allow` を 1 度実行すれば、以降は `cd` するだけで環境変数が揃う。1Password GUI のセッションが生きていれば Touch ID プロンプトは出ない。

> ⚠️ **`eval "$(op inject ... | sed 's/^/export /')"` 形式は使わないこと**: 値に `$(...)` / バックティック / 引用符 / 改行が混じった瞬間に shell injection や構文崩壊を起こす。1Password vault には PEM 鍵や複数行 token が入りうるため、必ず `dotenv` 関数経由で値を文字列としてロードする。
>
> 補足: `direnv` 標準の `dotenv` は `op://` URI を解釈しないため、まず `op inject` で **解決済み env-file** を `.direnv/op-env` に書き出してから `dotenv` に渡す。`.direnv/` はプロジェクトの `.gitignore` に必ず追加する（解決済みファイルには生値が含まれる）。

### Docker / Docker Compose

```bash
op run --env-file=.env.op -- docker compose up
```

`op run` は **子プロセス（= `docker compose` 本体）の環境変数**として値を渡すだけで、コンテナ内には自動伝播しない。コンテナへ届けるには compose YAML 側で明示的に渡す必要がある:

```yaml
services:
  web:
    environment:
      OPENAI_API_KEY: ${OPENAI_API_KEY}   # ホスト(=op run)側の値を補間
      ANTHROPIC_API_KEY:                   # 値省略でホスト env から取り込み
```

`env_file:` を使う方法もあるが、その場合は `op inject -i .env.op > .env.compose` のように **解決済み env-file を一時生成**する必要がある（compose の `env_file:` は `op://` URI を解釈しないため）。その一時ファイルは生値を含むので、必ず `.gitignore` し、CI 終了時には削除すること。

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

GitHub Actions 公式 action `1password/load-secrets-action@v2` を使うパターンも実務では一般的（メジャーバージョンは導入時に最新を確認）。castle 自体には CI 用途が無いため詳細は割愛。

## トラブルシュート

| 症状 | 原因 | 対策 |
|---|---|---|
| `op run` が `error: failed to read item` | URI の vault / item / field が typo | `op item list --vault <v>` で実名を、`op item get "<item>" --vault <v>` でフィールド名を確認 |
| Touch ID プロンプトが毎回出る | 1Password GUI が lock されている / GUI 連携 OFF | GUI を起動して unlock。Settings → Developer → "Integrate with 1Password CLI" を ON。auto-lock を緩める設定もあり |
| 値が古いまま | env-file が古い URI を指している、または item を新規作成して field 名がずれた | item 名・field 名と URI が一致しているか確認。1Password は item rename しても URI が古い名前を保持しないので、リネーム後は env-file 側も追従が必要 |
| `oprun` が `command not found` | sh / Makefile / npm scripts から呼んでいる（zsh 関数は子プロセスに継承されない） | 生 `op run --env-file=.env.op -- <cmd>` を使う。`oprun` は zsh 関数のため、対話 zsh 以外からは見えない |
| `op run` の出力が伏せ字（`<concealed by 1Password>` 等）だらけで debug できない | masking が効いている | デバッグ時のみ `--no-masking` を足す。本番運用では masking ON 推奨 |
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
