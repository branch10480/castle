# 1Password Touch ID プロンプトが tmux ペインごとに発火する件 — 調査記録

## TL;DR

**現象**: tmux のペインを分割し、それぞれで `claude` を起動すると、ペインの数だけ Touch ID が要求される。`op` CLI の cache (`op-daemon`) が機能していないように見える。

**真の原因**: 1Password 8 の **per-terminal-session 認可モデル**。`op` の secret cache とは別レイヤーで、**呼び出し元アプリ（tmux）の "ターミナルセッション" ごとに 10 分間有効な authorization grant を発行する**仕組み。各 tmux ペインは別の pty を持つため、1Password から見て別「ターミナルセッション」として扱われ、毎回プロンプトが出る。

**「常に許可」のオプションは設計上存在しない**。

**さらに**: castle の tmux は Nix-darwin 経由で adhoc 署名されているため、code signature ベースで「同一アプリと認識して認可を持続させる」回路もそもそも 1Password の trust list に乗らない可能性が高い。

**対策方向**: ペイン内で `op` を呼ばないアーキテクチャへ移行する（ghostty 等の Apple-signed アプリで 1 回 `op read` → tmux 環境変数に展開 → 各ペインの claude は env 経由で取得）。または Service Account Token に切り替える。

---

## 1. 観測事実

### 1.1 体感

- `op-warm` (cache 事前 warm) を実行しても、別ペインで `claude` を起動すると Touch ID が出る
- ペインを 3 つ作って各ペインで `claude` 起動 → 3 回 Touch ID
- 同一ペイン内では一度の Touch ID で済む（ことが多い）

### 1.2 Touch ID プロンプトの中身

```
1Password アクセスリクエスト
[exec icon] ─✓─ [1Password icon]
許可 tmux CLI にアクセスするには
v ファミリー  [familyアイコン]
  認証詳細
  1Password CLI を使用して、アカウント「ファミリー」へのフルアクセスを
  「tmux」のターミナルセッションに許可します。
  認証は10分間操作されないか、1Passwordがロックされると失効します。
[キャンセル]    認証 Touch ID
```

**読み解き**:

- 「ファミリー」は **アカウント名**（1Password Families プラン）。vault 名ではない
- 認可単位は **「`tmux` のターミナルセッション」** = pty ベース → ペインごとに別と判定される
- 有効期限は **10 分間の無操作** または **1Password ロック**まで
- 「常に許可」ボタン無し（展開しても詳細表示のみで追加オプション無し）→ 永続認可の口がそもそも無い

### 1.3 op-daemon の cache は実は機能している

実機計測（`time op run --env-file=... -- env`）:

| シナリオ | 1 回目 | 2 回目以降 |
|---|---|---|
| 同シェルで sequential 2x | 7.99s（Touch ID 含む） | 1.45s（silent ✅） |
| **同シェルで parallel 3x（cache 温時）** | — | **3 並列とも 1.45s, 全て silent ✅** |
| `zsh -c` で別 process tree から 2x | 1.4s, silent | 1.4s, silent |

つまり **`op-daemon` の secret cache 自体は process tree を跨いで global に共有される**。`op-warm` で 1 度温めれば、同じ process / 短時間内なら無音で取れる。

→ **cache が問題ではない**。Touch ID プロンプトは別の何かで発火している。

---

## 2. 1Password 8 の認可モデル（推定）

### 2.1 二層構造

| レイヤ | 何を gate するか | TTL | scope |
|---|---|---|---|
| **secret cache** (`op-daemon.sock`) | 復号済み secret 値の再利用 | 短い（数分？） | global（process tree 跨ぎ可） |
| **app authorization grant** | `op` を呼び出した「ターミナルセッション」へのフルアクセス権 | 10 分の無操作 | **terminal session 単位** |

→ secret cache が温かくても、app authorization が新規の場合は Touch ID 必要。

### 2.2 「ターミナルセッション」の境界

プロンプトの文言から推定:
- pty （= tmux ペイン）単位で別セッション扱い
- `op` を直接呼ぶ親 process tree が変わると別セッション扱い
- 同じ tmux server 内でも、別ペイン → 別 pty → 別セッション

これは macOS のセキュリティ要件に準拠した「短時間の transient grant」設計で、ユーザーの明示的な意図確認のための仕組み。

### 2.3 code signature による永続認可（理論）

1Password 8 は呼び出し元アプリの code signature を検証する。安定した signature を持つアプリ（Apple Developer ID 署名）であれば、1Password の "認可済みアプリ" リストに登録され、authorization grant が長期化する余地がある（とドキュメントから推測）。

しかし castle の tmux は:

```
$ codesign -dv --verbose=2 $(which tmux)
Executable=/nix/store/yx9p8ac2rfgpwn8sd7183b97gsimabqx-tmux-3.6a/bin/tmux
Signature=adhoc                ← Apple Developer ID 無し
TeamIdentifier=not set         ← Team ID 無し
Identifier=tmux                 ← 一般的な文字列、ドメイン無し
```

→ **adhoc 署名（Nix がビルド時に動的に生成）+ Team ID 無し** のため、1Password から見て「次に同じ tmux が来ても同一性を保証できない」状態。さらに `/nix/store/<hash>/...` の hash は Nix-darwin rebuild で変わるため、**バージョンアップで物理的にも別 path / 別 binary になる**。

「常に許可」が UI 上存在しない理由は：そもそもこのバイナリ identity を信頼できないため、永続認可を出しようがない、と推測される。

---

## 3. 対策候補

### A. `op` をペイン内で呼ばないアーキテクチャへ（◎ 推奨方向）

**狙い**: ghostty.app は Apple Developer ID 署名 → 1Password は ghostty を「認可済みアプリ」リストに登録できる → ghostty 経由の `op read` 1 回で済む → 結果を tmux global env に流し込み → 各ペインの claude は env 経由で読む。

**実装スケッチ**:

```zsh
# ghostty 起動時 (interactive shell), tmux attach 直後 1 回だけ:
if [[ -n "$TMUX" ]] \
   && ! tmux show-environment -g PERPLEXITY_API_KEY >/dev/null 2>&1; then
  tmux set-environment -g PERPLEXITY_API_KEY \
    "$(op read 'op://Private/Perplexity API/credential')"
fi

# 各ペインの zshrc:
[[ -n "$TMUX" ]] && eval "$(tmux show-environment -g PERPLEXITY_API_KEY 2>/dev/null \
  | sed 's/^/export /')"
```

`~/.claude.json` の perplexity entry を `op run` 経由から **直接 `npx` 呼び出しに変更**。

**コスト**:
- secret が tmux server プロセスメモリと各 zsh の env に存在する（ディスクには無い）
- `~/.claude.json` の手動修正必要（Phase 4 の op:// セットアップ手順の延長）

**リスク**:
- `tmux show-environment -g` で他 pty から見える
- `ps eww <pid>` で env が見える可能性

### B. tmux を再署名（△ 技術的に可能だが運用コスト高）

`codesign --sign <stable-cert>` で安定した identity を付与し、1Password の trust に乗せる。

**コスト**:
- self-signed cert を Keychain に保管
- nix-darwin の `home.activation` で各 rebuild 後に再署名
- 1Password が adhoc + 自前 cert を信頼するか不明

### C. 1Password Service Account Token（◎ Business/Teams 限定）

`OP_SERVICE_ACCOUNT_TOKEN` を環境変数に置く → 全 `op` 呼び出しが biometric バイパス。

**コスト**:
- Business/Teams プラン必要（Family プランでは不可）
- token は長期有効 → 漏洩時の影響範囲大
- 監査ログで「すべて service account からの操作」になり、個人 token と混ざる

### D. 諦めて手動で押す（× UX 悪い）

ペインごとに Touch ID。

### E. ペイン分割を諦めて 1 ペイン内 window 切替で運用（△）

tmux で `prefix c` で windows を増やせば、同じターミナルセッション内で複数 claude を回せる（はず）。pty が変わらないなら同じ authorization grant が効く可能性。要検証。

---

## 4. なぜ `op-warm` は失敗したか

`op-warm` は「op-daemon の secret cache を温める」ことを狙っていた。しかし真の原因は **app authorization grant の per-pty 性** であり、secret cache とは別レイヤー。

`op-warm` を実行したペインでは authorization grant が出るが、その grant は **そのペインの pty に紐付く**。別ペインに分割すると新しい pty が生まれ、また新しい grant が必要になる → Touch ID が出る。

この事実は事前計測で見落とした。`op-warm` を作る前に「別ペイン経由の `op run` でも cache hit するか」を実機テストしていれば気付けた。

**反省**:
- 「process tree を跨いだ silent」を Bash subshell (`zsh -c '...'`) で確認したが、それは tmux ペイン分割と同等ではなかった
- pty 境界の影響を見落とした
- 最初の AskUserQuestion で「ペインごとに Touch ID」と user が回答した時点で、pty/terminal-session 境界の仮説に切り替えるべきだった

---

## 5. 関連リンク

- [`CLAUDE.md`](../CLAUDE.md) — Phase 4 (MCP API キーを op:// で隠匿)
- [`docs/op-env-pattern.md`](op-env-pattern.md) — `op://` env-file パターン
- 1Password 8 Developer Settings の "Connect with 1Password CLI" 設定
- このプロンプト本文の「詳しく見る」リンク先（1Password 公式ドキュメント）
