# Ghostty splitでsymlink経由のdotfiles読み込みによりCWDがcastleに変わる問題の回避
# 初期化前のCWDを保存し、末尾で復元する（ref: ghostty-org/ghostty#647）
_SHELL_INIT_PWD="$PWD"

# ── Environment ──────────────────────────────────────────
export PATH="$HOME/.local/bin:$PATH"

if [[ -n "${WEZTERM_PANE:-}" ]]; then
  export TMUX="wezterm-shim/${WEZTERM_PANE}/0"
fi
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

# zsh plugins
[[ -f "$_brew/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]] && \
  source "$_brew/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
[[ -f "$_brew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]] && \
  source "$_brew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

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

# ── Claude Code ──────────────────────────────────────────
export CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING=1
export CLAUDE_CODE_EFFORT_LEVEL=max

alias c='claude'
: ${CLAUDE_MODEL_OPUS:='claude-opus-4-6[1m]'}
: ${CLAUDE_MODEL_SONNET:='sonnet'}
: ${CLAUDE_MODEL_HAIKU:='haiku'}

_cc()  { claude --dangerously-skip-permissions "$@"; }
_ccp() { claude --print "$@"; }

cc()   { _cc --model "$CLAUDE_MODEL_OPUS" "$@"; }
ccc()  { _cc --continue --model "$CLAUDE_MODEL_OPUS" "$@"; }
cch()  { _cc --model "$CLAUDE_MODEL_HAIKU" "$@"; }
ccs()  { _cc --effort medium --model "$CLAUDE_MODEL_SONNET" "$@"; }
ccp()  { _ccp --model "$CLAUDE_MODEL_OPUS" "$@"; }
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
bindkey '^]' fzf-src

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
