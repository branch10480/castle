# App Store Connect API キー (`.p8`) を 1Password 管理にする（Phase 5）

App Store Connect (ASC) の API キー（`AuthKey_<KEY_ID>.p8` ファイル + Key ID + Issuer ID）を 1Password に集約し、`xcrun altool --upload-app` の都度だけディスクに展開する運用パターン。Phase 4 の MCP サーバ向け運用と並ぶ位置づけで、**TestFlight / App Store への iOS / macOS アプリ配信時の認証情報** を扱う。

## なぜ Phase 3 の `oprun` / `.env.op` 経路ではダメか

`xcrun altool` は API キーの値を環境変数からも `--apiKeyPath` のようなオプションからも受け取らない。**実体ファイルが `~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8` というパスに存在することを前提に、自前でディレクトリを scan する**（公式ドキュメントには明示されないが、altool / Transporter ツール群で共通の規約）。

加えて `.p8` は PKCS#8 形式の PEM 鍵で、改行・空白・引用符を含む複数行テキスト。[`docs/op-env-pattern.md`](op-env-pattern.md) の注意書きにある通り、こういう値は dotenv パーサで取り込めず direnv 経路には載せられない。

したがって ASC の `.p8` は次の流儀になる：

- **保管**: 1Password に「Key ID / Issuer ID / Team ID / `.p8` 全文」を 1 つの API Credential item にまとめる
- **使用**: 配信時だけ `op read` で `.p8` を `~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8` に書き出し、`altool` 実行後に **EXIT トラップで即削除**
- **永続化しない**: 配信が終わればディスク上の `.p8` は消える（バックアップは 1Password 側のみ）

## 1Password 側の構成

| フィールド | 値の例 | 備考 |
|---|---|---|
| Title | `App Store Connect API Key` | 複数アプリで共通鍵を使うなら 1 つの item で OK。鍵をアプリごとに分けている場合は item を分けて環境変数 `ASC_OP_ITEM` で切り替える |
| Vault | `Private` | 個人 Mac は `Private`、仕事 Mac は別 vault → `ASC_OP_VAULT` で切替 |
| Category | API Credential | `username` フィールドに Key ID、`credential` に `.p8` 全文を保管できるテンプレ |
| `username` | `<KEY_ID>` (例: `56A235P5WM`) | API Credential テンプレの規定フィールド |
| `credential` | `.p8` の中身（`-----BEGIN PRIVATE KEY-----` 行から `-----END PRIVATE KEY-----` 行まで） | `op item create` の引数で `credential[password]=$(cat AuthKey_*.p8)` で投入 |
| `key id` (text) | `<KEY_ID>` | 取り出し側で `username` ではなく専用フィールドから読むことで一貫性を保つ |
| `issuer id` (text) | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` | UUID。ASC の Users and Access → Integrations → App Store Connect API ページ上部に表示 |
| `team id` (text) | `<TEAM_ID>` (例: `67NJZVUMG3`) | プロジェクト側 build settings の `DEVELOPMENT_TEAM` と一致させる |

### 初回登録（既に `.p8` がローカルにある場合）

```bash
op item create \
  --category="api credential" \
  --title="App Store Connect API Key" \
  --vault="Private" \
  "username=<KEY_ID>" \
  "credential[password]=$(cat ~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8)" \
  "key id[text]=<KEY_ID>" \
  "issuer id[text]=<ISSUER_ID>" \
  "team id[text]=<TEAM_ID>"
```

登録できたら `op read 'op://Private/App Store Connect API Key/credential'` で `.p8` 全文が引けることを確認し、ローカルの `~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8` を削除する。

## ヘルパ

### `asc-upload <path-to-ipa>` （対話 zsh から）

`home/.zshrc.d/asc.zsh` で定義。実体は `scripts/asc-upload.sh` を呼ぶだけのラッパ。

```zsh
asc-upload ./build/export/EpubReader.ipa
```

挙動：

1. `op item get` で Key ID / Issuer ID を取得（fail-fast — 値が空ならファイル展開前に終了）
2. `~/.appstoreconnect/private_keys/` を `chmod 700` で確保
3. `umask 077` のサブシェル内で `op read` を `AuthKey_<KEY_ID>.p8` に書き出し（最初から 0600 で作る）
4. `trap cleanup EXIT INT TERM` で正常終了でも中断でも `.p8` を削除
5. `xcrun altool --upload-app --apiKey <KEY_ID> --apiIssuer <ISSUER>` を実行（altool が固定パスから `.p8` を読む）

### Makefile / CI / Fastfile から呼ぶ

zsh 関数は子プロセスに継承されないため、必ず **スクリプトを直接呼ぶ**：

```makefile
.PHONY: testflight
testflight: build/export/$(SCHEME).ipa
	~/.homesick/repos/castle/scripts/asc-upload.sh $<
```

CI では Service Account Token (`OP_SERVICE_ACCOUNT_TOKEN` 環境変数) を使えば対話 Touch ID なしで走る ([`op-env-pattern.md` の "CI で使う場合"](op-env-pattern.md) 参照)。

## 環境変数による切替

| 変数 | 既定値 | 用途 |
|---|---|---|
| `ASC_OP_ITEM` | `App Store Connect API Key` | 複数の Apple ID / 複数アプリを分けて運用する場合に item 名を切替 |
| `ASC_OP_VAULT` | `Private` | 仕事 Mac で別 vault を使う場合（[`op-env-pattern.md` の machine-local override](op-env-pattern.md) と同じ思想） |

例：仕事用の鍵を呼ぶ場合

```bash
ASC_OP_VAULT="Employer" ASC_OP_ITEM="ASC API Key (WorkApp)" \
  asc-upload ./build/export/WorkApp.ipa
```

## ローカルファイルを残さない運用ポリシー

- `.p8` の **永続コピーは 1Password のみ**。ローカル `~/.appstoreconnect/private_keys/` は実行中の数十秒〜数分だけ存在する状態にする
- 配信失敗 / Ctrl-C / kill のいずれでも `trap` によりクリーンアップ
- macOS の `rm -f` で十分（APFS は full-disk encryption 前提なので `shred` 等は不要）
- `scan-secrets.sh` の検出パターンに `AuthKey_[A-Z0-9]{8,}\.p8` を含めているので、誤って `.p8` のファイル名やパスをスクリプトに hardcode した場合に commit 前に拾われる（中身の PEM ヘッダは既存の `Private key block` パターンが拾う）

## トラブルシュート

| 症状 | 原因 | 対策 |
|---|---|---|
| `asc-upload: missing "key id" or "issuer id" field` | 1Password item にフィールドが無い / 名前が違う | `op item get "App Store Connect API Key" --vault Private --format json | jq '.fields[].label'` で実際のラベル名を確認。`asc-upload.sh` は `key id` / `issuer id` (lower-case + 半角空白) を期待 |
| `op read` が無言で空を返す | `op` が locked / GUI integration が切れた | `op-status` で確認 → `op signin` で再取得（[`op.zsh`](../home/.zshrc.d/op.zsh) のヘルパ参照） |
| altool が `Could not find auth key file` | `.p8` が `~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8` に書き出されていない | スクリプトの `op read` 行のみを切り出して手動実行 → 出力が空でないか確認。`KEY_ID` と item の `username` が一致しているか確認 |
| TestFlight 上で「Invalid Signature」 | これは API キーの問題ではなく codesign 設定 | `ExportOptions.plist` の `signingStyle: automatic`、Xcode 側 build settings の `DEVELOPMENT_TEAM` を確認 |
| altool が `App Store Connect API key not configured` | `--apiKey` / `--apiIssuer` が空 or 不一致 | `ASC_OP_ITEM` / `ASC_OP_VAULT` の上書きが効いて違う item を読んでいないか確認 |

## 関連

- Phase 2: `oprun` ヘルパ → [`home/.zshrc.d/op.zsh`](../home/.zshrc.d/op.zsh)
- Phase 3: プロジェクト `.env.op` 規約 → [`docs/op-env-pattern.md`](op-env-pattern.md)
- Phase 4: MCP サーバ API キーの op 化 → [`CLAUDE.md` の Phase 4](../CLAUDE.md)
- ASC API キー発行: ASC Web の Users and Access → Integrations → App Store Connect API
