---
name: commit-staged
description: ステージング済みファイルのみをcommit・pushする。機密情報がある場合は確認を求める。コミットメッセージは英語で自動生成。
disable-model-invocation: false
allowed-tools: Bash
---

# ステージング済みファイル Git Commit & Push

現在のディレクトリで、既にステージングエリアに追加されているファイルのみをcommit・pushする。

## 手順

1. `git status --cached --porcelain` でステージング済みファイルを確認する。
2. ステージング済みファイルがない場合は「ステージング対象なし」と報告して終了する。
3. **機密情報チェック**: 以下をチェックし、該当する場合は確認を求める：
   - パスワード、トークン、APIキー等を含むファイル
   - `.env`、`secret`、`credential`、`key`、`token` などの文字列を含むファイル名
   - 認証情報らしきコミット内容
4. 機密情報チェックをパスした場合、ステージング済み内容を確認する。
5. 差分を要約した英語のコミットメッセージを作成する。
6. `git commit -m "<english message>"` を実行する。
7. `git push` でリモートへ反映する。
8. 実行結果として、ブランチ名・コミットハッシュ・コミットメッセージを報告する。

## 機密情報チェック項目

### ステージング済みファイル名パターン
以下のパターンを含むファイル名は要確認：
- `.env*`, `.*env`
- `*secret*`, `*credential*`, `*password*`
- `*key*`, `*token*`, `*auth*`
- `*.pem`, `*.p12`, `*.pfx`
- `config.json`, `settings.json` (認証情報を含む可能性)

### ステージング済み内容チェック
以下のパターンが `git diff --cached` に含まれる場合は要確認：
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
- ステージング済みファイルがない場合は、適切なメッセージで終了する。
- Gitコマンドが失敗した場合は、エラー内容と推奨される対処法を報告する。
- リモートプッシュに失敗した場合は、プルが必要かなどの対処法を提案する。

## 使用例

```bash
# 基本的な使用（事前に git add で必要なファイルをステージング）
git add specific-file.js
/commit-staged

# 機密情報検出時の確認例
Found potential sensitive files in staging:
- config/.env.local (contains environment variables)
- scripts/deploy-key.pem (appears to be a private key)

Do you want to proceed with committing these staged files? (y/N)
```

## push-allスキルとの使い分け

- **commit-staged**: ファイルを選別してステージングした後、そのファイルのみをコミット
- **push-all**: 作業ディレクトリのすべての変更を一括でコミット

```bash
# 選択的コミットの例
git add file1.js file2.css  # 特定ファイルのみステージング
/commit-staged              # ステージング済みファイルのみコミット

# 一括コミットの例
/push-all                   # すべての変更を一括コミット
```