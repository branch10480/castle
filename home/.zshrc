# Ghostty splitでsymlink経由のdotfiles読み込みによりCWDがcastleに変わる問題の回避
# 初期化前のCWDを保存し、末尾で復元する（ref: ghostty-org/ghostty#647）
_SHELL_INIT_PWD="$PWD"

# ── Environment ──────────────────────────────────────────
export PATH="$HOME/.local/bin:$PATH"

# Nix (nix-darwin + Home Manager) を Homebrew より優先させる。
# /etc/zprofile の path_helper が /opt/homebrew/bin を先頭に挿入し直すため、
# .zshrc 側で再度 Nix プロファイルを prepend する必要がある。
for _nix_dir in \
  "/etc/profiles/per-user/$USER/bin" \
  /run/current-system/sw/bin \
  /nix/var/nix/profiles/default/bin; do
  [[ -d "$_nix_dir" ]] && PATH="$_nix_dir:${PATH//$_nix_dir:/}"
done
unset _nix_dir
export PATH

export EDITOR="nvim"
export VISUAL="nvim"

# ── Machine-local overrides ──────────────────────────────
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local

# ── Tool initialization ──────────────────────────────────
_brew="${HOMEBREW_PREFIX:-/opt/homebrew}"

# anyenv
# `anyenv init -` は管理下の全*envのシェル初期化コードを動的生成するが、
# 毎回サブプロセスを起こすため遅い（~100-200ms）。
# 生成結果をキャッシュファイルに保存し、次回以降は source で読み込む。
# anyenv本体が更新された場合（バイナリのタイムスタンプが新しい場合）は自動で再生成する。
# 手動で再生成したい場合: rm ~/.cache/anyenv-init.zsh
if (( $+commands[anyenv] )); then
  _anyenv_cache="$HOME/.cache/anyenv-init.zsh"
  if [[ ! -f "$_anyenv_cache" ]] || [[ "$(command -v anyenv)" -nt "$_anyenv_cache" ]]; then
    mkdir -p "${_anyenv_cache:h}"          # ~/.cache がなければ作成
    anyenv init - > "$_anyenv_cache"       # 初期化コードをファイルに保存
  fi
  source "$_anyenv_cache"                  # キャッシュから読み込み（高速）
  unset _anyenv_cache
fi

# zsh plugins (Nix を優先、brew にフォールバック)
# 注意: nixpkgs ではプラグイン毎に share/ 配下のパスが揺れるため明示する。
_nix_share="/etc/profiles/per-user/$USER/share"
_zsh_plugin_paths=(
  "$_nix_share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
  "$_brew/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
  "$HOME/.local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
  "$_brew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
)
# autosuggestions と syntax-highlighting をそれぞれ最初に見つかった方だけ source。
for _name in zsh-autosuggestions zsh-syntax-highlighting; do
  for _p in $_zsh_plugin_paths; do
    [[ "$_p" == *"/$_name/"* && -f "$_p" ]] && { source "$_p"; break; }
  done
done
unset _nix_share _zsh_plugin_paths _name _p

# starship
(( $+commands[starship] )) && eval "$(starship init zsh)"

# homeshick
if [[ -f "$_brew/opt/homeshick/homeshick.sh" ]]; then
  export HOMESHICK_DIR="$_brew/opt/homeshick"
  source "$HOMESHICK_DIR/homeshick.sh"
  fpath=("$HOMESHICK_DIR/share/zsh/site-functions" $fpath)
fi

# zoxide
(( $+commands[zoxide] )) && eval "$(zoxide init zsh --cmd j)"

# direnv
(( $+commands[direnv] )) && eval "$(direnv hook zsh)"

unset _brew

# ── ~/.zshrc.d/ snippets (castle-managed) ────────────────
# 機能ごとの初期化スクリプトを小さく分割して置く場所。
# Phase 2 (1Password CLI 統合) で導入。homeshick が ~/.zshrc.d を
# castle/home/.zshrc.d への symlink として張る。
# (N) は zsh glob qualifier: マッチ 0 件でもエラーにしない指定。
if [[ -d ~/.zshrc.d ]]; then
  for _f in ~/.zshrc.d/*.zsh(N); do
    source "$_f"
  done
  unset _f
fi

# ── Key bindings ─────────────────────────────────────────
bindkey -e

# ── Aliases ──────────────────────────────────────────────
alias t='tig status'
alias co='codex --ask-for-approval never --sandbox danger-full-access'
alias ll='ls -al'
alias o='open'
alias n='nvim'
alias oc='opencode'
alias gd='git difftool'
alias cl='clear'
alias xc='xclean'
alias xcd='xclean -d'
alias mdo='open -a "/opt/homebrew/opt/markdownobserver-fork/MarkdownObserver.app"'
alias nixman='nvim ~/.homesick/repos/castle/docs/nix-darwin-manual.md'
# nix-darwin: switch / rollback / generation list
alias nrs='sudo darwin-rebuild switch --flake ~/.config/nix-darwin'
alias nrb='darwin-rebuild --rollback'
alias nrl='darwin-rebuild --list-generations'
# nix flake: update inputs (nixpkgs 等を最新化) → switch で反映
alias nru='nix flake update --flake ~/.config/nix-darwin'
# nrgc: system / user 両 profile の "14日より古い" 世代を削除（rollback 余地を保つ）
nrgc() {
  sudo nix-collect-garbage --delete-older-than 14d
  nix-collect-garbage --delete-older-than 14d
}

# ── Claude Code ──────────────────────────────────────────

alias c='claude'
: ${CLAUDE_MODEL_SONNET:='sonnet'}
: ${CLAUDE_MODEL_HAIKU:='haiku'}

_cc()  { claude --dangerously-skip-permissions "$@"; }
_ccp() { claude --print "$@"; }

cc()   { claude "$@"; }
ccc()  { claude --continue "$@"; }
cch()  { _cc --model "$CLAUDE_MODEL_HAIKU" "$@"; }
ccs()  { _cc --effort medium --model "$CLAUDE_MODEL_SONNET" "$@"; }
ccp()  { _ccp "$@"; }
ccsp() { _ccp --effort medium --model "$CLAUDE_MODEL_SONNET" "$@"; }
cchp() { _ccp --model "$CLAUDE_MODEL_HAIKU" --bare "$@"; }

# ── Utility functions ────────────────────────────────────
# fzf + nvim
v() {
  local file
  file=$(fzf --height=40% --reverse)
  [[ -n "$file" ]] && nvim "$file"
}

# ghq + fzf
fzf-src () {
  local repo
  repo=$(ghq list | fzf --query "$LBUFFER" --prompt="ghq> " --height=40% --reverse)

  if [[ -n "$repo" ]]; then
    repo=$(ghq list --full-path --exact "$repo")
    BUFFER="cd ${repo}"
    zle accept-line
  fi

  zle clear-screen
}
zle -N fzf-src
bindkey '^G' fzf-src

# wtp + fzf
fzf-src-wtp () {
  local wt_name wt_path list

  list="$(wtp list -q 2>/dev/null)"
  [[ -z "$list" ]] && { zle clear-screen; zle -M "wtp list: no entries"; return 0; }

  wt_name="$(print -r -- "$list" | fzf --query "$LBUFFER" --prompt="wtp> " --height=40% --reverse)"
  [[ -z "$wt_name" ]] && { zle clear-screen; return 0; }

  wt_path="$(wtp cd "$wt_name" 2>/dev/null)"
  [[ -z "$wt_path" ]] && { zle clear-screen; zle -M "wtp cp failed: $wt_name"; return 0; }

  BUFFER="cd ${wt_path}"
  zle accept-line
  zle clear-screen
}
zle -N fzf-src-wtp
bindkey '^w' fzf-src-wtp

# ── Ghostty CWD restore ─────────────────────────────────
# homeshickのsymlink解決によりCWDがcastle配下に移動した場合のみ復元する。
# cmuxワークスペース間のCWD継承は意図的に対処しない（誤検知による$HOME飛ばし防止）。
# （ref: ghostty-org/ghostty#647）
#
# 注意: .zshrc内のcdではGhosttyのOSC 7フック（_ghostty_report_pwd）が未登録のため、
# cmuxのサーフェスCWDが更新されない。cdした場合は明示的にOSC 7を発行する。
_zshrc_cd_and_report() {
  cd "$1" && printf '\e]7;kitty-shell-cwd://%s%s\a' "${HOST}" "${PWD}" 2>/dev/null
}
if [[ -n "${GHOSTTY_RESOURCES_DIR:-}" && "$PWD" == "$HOME/.homesick/"* ]]; then
  if [[ -n "$_SHELL_INIT_PWD" && "$_SHELL_INIT_PWD" != "$HOME/.homesick/"* ]]; then
    _zshrc_cd_and_report "$_SHELL_INIT_PWD"
  else
    _zshrc_cd_and_report "$HOME"
  fi
fi
unfunction _zshrc_cd_and_report 2>/dev/null
unset _SHELL_INIT_PWD

# ── Ghostty: auto-attach tmux (session group 方式) ──────────
# Ghostty で新規ペイン/タブ/ウィンドウを開いたら自動で tmux に入る。
# - `main` セッションが既にあれば session group として join し、独立 client を
#   `ghostty-<pid>` 名で作る → 各 ghostty タブで見ている window が独立。
#   prefix s で同一 session group の window 一覧が見える。
# - 無ければ `main` を新規作成。
# - 既に tmux 内 / 非 interactive / NO_AUTO_TMUX が設定されている場合はスキップ
# - tmux 未インストール時はスキップ（シェルがロックされないように防御）
# - 一時的に無効化したいときは `NO_AUTO_TMUX=1 exec zsh -l`
# - has-session の `-t =main` は前方一致ではなく完全一致 (先頭の `=` が必要)
# - `=main` はシングルクォート必須: zsh の EQUALS オプション (デフォルト ON) が
#   `=word` を「word コマンドの絶対パス展開」と解釈し、`main` が見つからず
#   展開エラーで if 全体が abort する (`zsh: main not found`)
if [[ -z "$TMUX" && -z "$NO_AUTO_TMUX" && -n "${GHOSTTY_RESOURCES_DIR:-}" && $- == *i* ]] \
  && (( $+commands[tmux] )); then
  if tmux has-session -t '=main' 2>/dev/null; then
    exec tmux new-session -t main -s "ghostty-$$"
  else
    exec tmux new-session -s main
  fi
fi
