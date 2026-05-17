# テーマ自動切替の実装詳細（Hammerspoon hook / 時刻トリガー / apauto）

castle の Light/Dark 共通契約（1pt 差ルール、Dark = warm-lifted layered gray）は [`../CLAUDE.md`](../CLAUDE.md#テーマ運用ルールlightdark--1pt-差--dark--warm-lifted-layered-gray) に **判断ルールとして**残してあり、本ドキュメントはその**実装側の詳細**（Ghostty 連動の仕組み・時刻ベース自動切替・一時 OFF 運用）を集約する。

## Ghostty の制約と Hammerspoon hook 方式

Ghostty 公式 docs では「A theme can set any valid configuration option」と書かれているが、**実装上は theme file 内の `font-size` などフォント系オプションは silently ignored** される（`+show-config | grep font-size` を Light/Dark 両モードで実行すると、本体 config の値しか返らないことで検証可能）。これは glyph atlas の再構築コストを避けるための暗黙仕様と推定される。

そのため castle では **Hammerspoon を appearance watcher として用いる方式**を採用:

1. 本体 `config/ghostty/config` 末尾に `config-file = ?config.local` (optional include) を置く
2. `hammerspoon/init.lua` が `AppleInterfaceThemeChangedNotification` を `hs.distributednotifications` で購読
3. appearance 変更を検知したら `~/.config/ghostty/config.local` を `font-size = 12` (Light) / `font-size = 13` (Dark) だけ含む最小ファイルとして上書き
4. 続けて Ghostty の **メニューバー → Reload Configuration を `hs.application:selectMenuItem` で自動 click** （Ghostty 未起動なら best-effort で skip）。これにより config.local の値が即座に Ghostty 内部の "current config" に取り込まれる
5. Hammerspoon 起動時 (cold start / `hs.reload()`) にも 1 度同期して cold start でも正しい値に揃える

`config.local` は **gitignored** (`.gitignore` 末尾に登録) の machine-local 動的ファイル。Hammerspoon が起動していない別 Mac でも `?` (optional include) のおかげで Ghostty config は壊れない (font-size は本体 config の fallback = 13pt にフォールバックする)。

## Ghostty 側の反映の挙動

| 設定カテゴリ | 既存ウィンドウ | 新ウィンドウ |
|---|---|---|
| color / palette / keybinding | ✓ 即時反映 | ✓ 反映 |
| **font-size** | ✓ 即時反映 (Hammerspoon が Reload Configuration を自動発火するため) | ✓ 反映 |

実機確認 (2026-05) で、Hammerspoon が `selectMenuItem` で発火する Reload Configuration により **既存ウィンドウの色も font-size も即時反映** される。`auto-update-channel = tip` を採用している castle の Ghostty では、font 系設定も live reload に追従する挙動になっている。

ただし **reload 発火は必須**: `config.local` を書き換えただけでは Ghostty は再読込しない。Hammerspoon の `selectMenuItem` が menu click を自動化することでこのループを閉じている。Hammerspoon に **Accessibility 権限が必要** (System Settings → Privacy & Security → Accessibility) で、無いと selectMenuItem が silently fail する。

### cmux 内ターミナルへの自動追従（reload 発火すら不要）

cmux (`/Applications/cmux.app`, bundle id `com.cmuxterm.app`) は libghostty を内蔵した Mac ネイティブアプリで、`~/.config/ghostty/config` を自身のターミナル surface 描画用にそのまま読む（公式 docs にも `cmux config paths` 出力にも明記。`cmux themes list` で `Source: ~/.config/ghostty/config` と表示される）。**さらに `config-file = ?config.local` の include directive を解釈し、`config.local` の変更を自動 watch して即時適用する**。

実機検証 (2026-05-17): config.local を一時的に `font-size = 18` に書き換えただけで、`cmux reload-config` を叩かずに cmux 内ターミナルのフォントが大きくなった。つまり cmux 側は Hammerspoon の `selectMenuItem` 経路に依存せず、ファイル更新のみで追従する（libghostty 内のファイルウォッチャーか cmux 側のフォールバックかは未確認だが、castle の運用上は「動く」が分かれば十分）。

結論として **castle の Light/Dark font-size 1pt 差ルールは cmux 内ターミナルでも自動適用される**。cmux 専用の hook は不要で、`config.local` を真実の源として維持する限り Ghostty 本体と cmux が同期する。

注意点:
- `~/Library/Application Support/com.cmuxterm.app/config.synced-preview` は **初回起動時の snapshot 仕様**らしく、その後の config 変更は反映されない (検証時に 4 月の旧設定が残っていた)。デバッグ時に preview が古いのは正常で、cmux 内ターミナルの実挙動が真実
- cmux GUI Settings で外観切替すると、cmux 自身が管理する `~/Library/Application Support/com.cmuxterm.app/config.ghostty` に書き込む設計 (cmux issue #3523)。castle の `~/.config/ghostty/config` は直接書き換えられない方向だが、混乱を避けるため **cmux GUI のテーマセレクタは触らず、OS appearance に追従させる運用**を取る
- cmux 本体は nix-darwin から brew cask 経由で宣言的に install (`config/nix-darwin/darwin.nix` の `casks = [ "cmux" ]`)。旧 NIGHTLY ビルド (`/Applications/cmux NIGHTLY.app`) は手動 DMG なので zap 対象外、移行時は手動削除

### Accessibility 権限の自己チェック（新 Mac セットアップ時の safeguard）

`hammerspoon/init.lua` の冒頭で `hs.accessibilityState()` を呼び、権限が無ければ次の 2 経路で自己申告する:

1. **通知センター**: 「Hammerspoon: Accessibility 権限が必要」というタイトルの通知を `autoWithdraw = false` で滞留させる
2. **画面中央アラート**: `hs.alert.show` で 10 秒表示。通知センターを見ない癖の人にも届く

新 Mac で `homeshick link castle` 直後に Hammerspoon を起動すると、この通知が出る → ユーザーは System Settings → Privacy & Security → Accessibility で Hammerspoon を許可 → Hammerspoon メニュー → Reload Config で反映、というフローになる。

> ドキュメントに「権限が必要」と書くだけだと「ドキュメントを読まずに動かない → 原因不明」になりがち。実装が自己診断するほうが届く範囲が広い。

## Hammerspoon による時刻ベース appearance 自動切替

macOS 純正の「自動」appearance は日の出 / 日の入り固定で時刻指定ができないため、Hammerspoon 側で時刻トリガーを持ち OS appearance を切り替えている。切替に伴って `AppleInterfaceThemeChangedNotification` が飛び、上記の Ghostty `config.local` 書換えが自動追従する（= 時刻層と font-size 層を疎結合にしている）。

- 既定スケジュール: **07:00 に Light / 14:00 に Dark**（境界は `hammerspoon/init.lua` の `APPEARANCE_LIGHT_HOUR` / `APPEARANCE_DARK_HOUR`）
- cold start（Hammerspoon 起動 / `hs.reload()` / 再ログイン）時にも、現在時刻に対する期待状態へ強制同期する（= 手動 override より時刻ルールを優先する設計判断）
- 必須権限: `hs.osascript.applescript` で System Events を呼ぶため **Automation 権限**（System Settings → Privacy & Security → Automation → Hammerspoon → System Events を ON）が必要。Accessibility 権限とは別枠で、初回実行時に macOS のダイアログが出る

### 一時 OFF 運用（`apauto` コマンド / flag file）

「今日はずっと Dark で作業したい」「プレゼン中なので勝手に切り替わってほしくない」など、時刻ベースの自動切替を一時的に止めたい場合は `apauto` zsh 関数（`home/.zshrc.d/apauto.zsh`）を使う:

```bash
apauto off       # 時刻トリガー & cold-start 同期を停止 (Hammerspoon 自動 reload)
apauto on        # ON に戻す
apauto toggle    # ON/OFF を反転
apauto status    # 現在の状態を表示 (引数なしと同じ)
apauto help      # 使い方を表示
```

内部的には `~/.hammerspoon/appearance-auto.disabled` という flag file の作成/削除と `hs -c 'hs.reload()'` の自動発火をまとめている。`hs` CLI が無い環境では flag だけ書き換えて警告を出すので、Hammerspoon メニュー → Reload Configuration で手動反映すれば良い。

flag が存在する間は `hammerspoon/init.lua` の `isAppearanceAutoDisabled()` が true を返し、各 timer コールバックと `applyExpectedAppearance()`（cold-start 同期）が早期 return する。cold start 時には `hs.alert` で `⏸ appearance auto-switch is OFF` を 4 秒表示し、OFF 中であることを自己申告する（黙って効かなくなる事故を防ぐため）。

zsh が無い環境（CI / 一時 sh / 他シェル）から直接叩きたい場合は flag ファイルを直接操作することもできる:

```bash
touch ~/.hammerspoon/appearance-auto.disabled   # OFF
rm    ~/.hammerspoon/appearance-auto.disabled   # ON
hs -c 'hs.reload()'                             # 即時反映 (任意)
```

### 設計上のポイント

- **Ghostty font-size 連動は止めない**: flag は時刻トリガーだけを無効化し、`AppleInterfaceThemeChangedNotification` の購読は生かす。OFF 中でも手動で OS appearance を切り替えれば font-size はそのまま追従する（= "手動操作の体験は壊さない"）
- **machine-local 扱い**: `~/.hammerspoon` は homeshick の symlink 越しに `castle/hammerspoon/` を指すため flag は castle 配下に着地するが、`.gitignore` で `hammerspoon/*.disabled` を無視して追跡しない（[`../config/ghostty/config.local`](../config/ghostty/config.local) と同じ machine-local override パターン）
- **永続 OFF にしたい場合は flag を残したまま運用**: reload や macOS 再ログインも貫通する。`rm` するまで OFF
- **常時 OFF にしたいわけではなく "境界時刻を変えたい" だけなら**, `hammerspoon/init.lua` の `APPEARANCE_LIGHT_HOUR` / `APPEARANCE_DARK_HOUR` を直接書き換えるほうが筋が良い（flag は "一時退避" 用、定数は "通常運用の境界" を担う）

## 新規テーマを追加するときの指針（How to apply）

- Xcode 系のように **theme file で font-size が effective なアプリ**は、Light/Dark 両方の theme file 内に直接 `font-size` を明示する (self-contained な定義)
- Ghostty のように **theme file で font-size が ignored なアプリ**は、Hammerspoon hook 側に分岐を追加するか、castle 側で `config-file` の optional include 機構を仕掛ける
- フォントサイズを 1pt 変えるときは **大きいサイズから降順で置換** すること。`13→14, 14→15` の順で実行すると元 13 のものが二重シフトされて 15 になる事故が起きる (Xcode テーマ作成時に踏んだ罠)
- 本体 config に `font-size` を残す場合は **Dark と同値 (13pt)** にして、override 未適用時に小さい側に倒れない設計にする (= 戸惑わせない方の挙動にフォールバック)
