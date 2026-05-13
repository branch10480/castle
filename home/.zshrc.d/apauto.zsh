# Hammerspoon の時刻ベース appearance 自動切替を ON/OFF するヘルパ。
#
# hammerspoon/init.lua は ~/.hammerspoon/appearance-auto.disabled が存在
# する間、時刻トリガー (07:00 Light / 14:00 Dark) と cold-start 同期を
# 早期 return で無効化する。`apauto` はその flag file の作成/削除と
# Hammerspoon の reload をまとめたフロントエンド。
#
# Ghostty font-size 連動 (AppleInterfaceThemeChangedNotification 購読) は
# 別系統なので、OFF 中でも手動 appearance 切替には font-size がそのまま
# 追従する。
#
# 詳細: castle CLAUDE.md「Hammerspoon による時刻ベース appearance 自動切替」

apauto() {
  local flag="$HOME/.hammerspoon/appearance-auto.disabled"
  local cmd="${1:-status}"

  # Hammerspoon を即時 reload。hs CLI 未導入 (= 新 Mac で hs.ipc.cliInstall
  # がまだ走っていない) なら警告だけ出して flag 更新は通す。次の Hammerspoon
  # 起動 / Reload Config で反映される。
  _apauto_reload() {
    if command -v hs >/dev/null 2>&1; then
      hs -c 'hs.reload()' >/dev/null 2>&1
    else
      print -u2 "apauto: hs CLI が見つかりません (Hammerspoon メニュー → Reload Config で反映してください)"
    fi
  }

  case "$cmd" in
    on)
      if [[ ! -e $flag ]]; then
        print "apauto: 既に ON です"
      else
        rm -f -- "$flag" && print "apauto: ON (時刻ベース自動切替を再開しました)"
        _apauto_reload
      fi
      ;;
    off)
      if [[ -e $flag ]]; then
        print "apauto: 既に OFF です"
      else
        mkdir -p -- "${flag:h}" && : > "$flag" \
          && print "apauto: OFF (時刻ベース自動切替を停止しました / Ghostty font-size 連動は維持)"
        _apauto_reload
      fi
      ;;
    toggle)
      if [[ -e $flag ]]; then
        apauto on
      else
        apauto off
      fi
      ;;
    status|"")
      if [[ -e $flag ]]; then
        print "apauto: OFF"
        print "  flag: $flag"
      else
        print "apauto: ON (07:00 Light / 14:00 Dark)"
      fi
      ;;
    -h|--help|help)
      cat <<'USAGE'
Usage: apauto [on|off|toggle|status]

  on      時刻ベース appearance 自動切替 (07:00 Light / 14:00 Dark) を再開
  off     一時停止 (Ghostty font-size 連動は生かしたまま)
  toggle  ON/OFF を反転
  status  現在の状態を表示 (引数なしと同じ)

flag file: ~/.hammerspoon/appearance-auto.disabled
詳細: castle CLAUDE.md「Hammerspoon による時刻ベース appearance 自動切替」
USAGE
      ;;
    *)
      print -u2 "apauto: 未知のサブコマンド: $cmd"
      print -u2 "apauto: 'apauto help' で使い方を表示します"
      return 1
      ;;
  esac
}
