---
name: push-all
description: すべての追跡対象ファイル（新規・変更）をadd・commit・pushする。機密情報がある場合は確認を求める。コミットメッセージは英語で自動生成。
disable-model-invocation: false
allowed-tools: Bash
---

# 汎用Git Push All

現在のディレクトリで、すべての追跡対象ファイル（新規ファイルと変更されたファイル）をgit add、commit、pushする。

## 手順

1. `git status --porcelain` で変更状況を確認する。
2. 変更がない場合は「コミット対象なし」と報告して終了する。
3. **機密情報チェック**: 以下をチェックし、該当する場合は確認を求める：
   - パスワード、トークン、APIキー等を含むファイル
   - `.env`、`secret`、`credential`、`key`、`token` などの文字列を含むファイル名
   - 認証情報らしきコミット内容
4. 機密情報チェックをパスした場合、`git add -A` ですべての変更をステージングする。
5. 差分を要約した英語のコミットメッセージを作成する。
6. `git commit -m "<english message>"` を実行する。
7. `git push` でリモートへ反映する。
8. 実行結果として、ブランチ名・コミットハッシュ・コミットメッセージを報告する。

## 機密情報チェック項目

### ファイル名パターン
以下のパターンを含むファイル名は要確認：
- `.env*`, `.*env`
- `*secret*`, `*credential*`, `*password*`
- `*key*`, `*token*`, `*auth*`
- `*.pem`, `*.p12`, `*.pfx`
- `config.json`, `settings.json` (認証情報を含む可能性)

### コミット内容チェック
以下のパターンがdiffに含まれる場合は要確認：
- `password`, `secret`, `token`, `apikey`, `api_key`
- `credentials`, `auth`, `bearer`
- Base64エンコードされた長い文字列
- UUIDやハッシュっぽい長い文字列の追加

## コミットメッセージ規則

- 必ず英語で記述する。
- 変更内容が一目でわかる具体的な文にする。
- 複数の変更がある場合は主要な変更をメインに記述する。
- 可能な限り Conventional Commits 形式を使用する：
  - `feat:` - 新機能
  - `fix:` - バグ修正
  - `chore:` - 設定変更、依存関係更新等
  - `docs:` - ドキュメント更新
  - `refactor:` - リファクタリング
  - `style:` - コードスタイル変更

## エラーハンドリング

- 機密情報が検出された場合は、該当ファイルを明示して確認を求める。
- Gitコマンドが失敗した場合は、エラー内容と推奨される対処法を報告する。
- リモートプッシュに失敗した場合は、プルが必要かなどの対処法を提案する。

## 使用例

```bash
# 基本的な使用
/push-all

# 機密情報検出時の確認例
Found potential sensitive files:
- config/.env.local (contains environment variables)
- scripts/deploy-key.pem (appears to be a private key)

Do you want to proceed with committing these files? (y/N)
```