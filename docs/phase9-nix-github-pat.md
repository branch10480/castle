# Phase 9: `nru` で flake update を認証付き fetch にする

`nix flake update`（castle では `nru` エイリアス）の実行時、Nix は `api.github.com` を `NixOS/nixpkgs` / `LnL7/nix-darwin` / `nix-community/home-manager` の 3 input 分連続で叩く。匿名アクセスは IP 単位で 60 req/hr のレートリミットがあり、共有 IP では `HTTP error 403: API rate limit exceeded` で `using cached version` フォールバックに落ちる挙動になる。

これを回避するため、`op run` で 1Password から GitHub Public PAT を `op://` 解決して `GITHUB_TOKEN` に展開 → `NIX_CONFIG="access-tokens = github.com=$GITHUB_TOKEN"` 経由で Nix に注入する。認証ユーザーあたり 5000 req/hr へ引き上がる。

関連: [`op-cli-setup.md`](op-cli-setup.md)（Phase 2 / Phase 4 の `op run` 基盤）, [`work-mac-setup.md`](work-mac-setup.md)

## 構成

- `home/.zshrc` の `nru` zsh 関数（旧 alias を関数に置換）— `~/.config/op/github.env.local`（machine-local override、gitignored）があればそれを優先、無ければ castle 追跡側の `~/.config/op/github.env` を使う。両方無い / `op` 未起動なら匿名 fetch にフォールバック
- `config/op/github.env` — castle 追跡テンプレ。`GITHUB_TOKEN=op://Private/GitHub Public PAT/credential`（個人 Mac default）
- `~/.config/op/github.env.local` — 仕事 Mac 等で `op://Employee/GitHub Public PAT/credential` のように上書き
- 1Password 側: API Credential テンプレで `<vault>/GitHub Public PAT/credential` フィールドに PAT を保管

## 初回セットアップ手順（新規 Mac で 1 度だけ）

1. **public github.com** で Fine-grained PAT を発行（個人 Mac なら個人アカウント、仕事 Mac なら仕事用個人アカウント。GHE 用 token は使えない）
   - Resource owner: 自分 / Expiration: 90 days / Repository access: "Public Repositories (read-only)" / Permissions: デフォルト
2. 1Password に保管:
   - Item template: **API Credential**
   - Item name: **`GitHub Public PAT`**（vault 横断で同じ名前に揃える）
   - `credential` フィールドに PAT
3. 個人 Mac の Private vault に保管した場合は追加設定不要（`config/op/github.env` がそのまま参照される）
4. 仕事 Mac で Employer 1Password の `Employee` vault などに置く場合は machine-local override を作成:
   ```bash
   cat > ~/.config/op/github.env.local <<'EOF'
   GITHUB_TOKEN=op://Employee/GitHub Public PAT/credential
   EOF
   chmod 600 ~/.config/op/github.env.local
   ```
5. 動作確認:
   ```bash
   op read 'op://Employee/GitHub Public PAT/credential' >/dev/null && echo OK
   nru   # 403 が出ずに lock 更新が走ること
   ```

## ポイント

- **Nix は `GITHUB_TOKEN` を直接読まない**: `NIX_CONFIG="access-tokens = github.com=..."` 経由で渡す必要がある。`nru` 関数の中で組み立てている
- **Fine-grained PAT を選ぶ**: Classic PAT より blast radius が小さい。Public read-only スコープなら漏洩時被害は最小限。Phase 5 の ASC API キー rotation と同じ思想で 90 日 expiration が無難
- **GHE 用 token は使えない**: `ghe.corp.yahoo.co.jp` 等の GHE で発行した PAT は `api.github.com` には通用しない（host が独立）。public github.com で個別に発行する必要がある
- **Touch ID は `nru` 実行毎に 1 回**: Phase 4 の MCP per-pane と違い対話 1 回限りなので許容範囲。常駐プロセスではないので warm-cache 戦略は採らない
- **匿名フォールバック**: `op` 未起動 / env-file 未設置の Mac でも `nru` は anonymous な `nix flake update` を実行する。fresh Mac で Phase 9 を未設定でもエラーにならない設計
