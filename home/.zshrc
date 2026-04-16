# Ghostty splitでsymlink経由のdotfiles読み込みによりCWDがcastleに変わる問題の回避
# 初期化前のCWDを保存し、末尾で復元する（ref: ghostty-org/ghostty#647）
_SHELL_INIT_PWD="$PWD"

export PATH="$HOME/.local/bin:$PATH"

# WezTerm内でClaude Codeのチーム機能を使えるようにtmux環境変数を偽装
if [[ -n "${WEZTERM_PANE:-}" ]]; then
  export TMUX="wezterm-shim/${WEZTERM_PANE}/0"
fi
export EDITOR="nvim"
export VISUAL="nvim"

# マシン固有設定の読み込み（モデル名等を上書き可能）
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local

eval "$(anyenv init -)"

source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# starship
eval "$(starship init zsh)"

# homeshick
export HOMESHICK_DIR=/opt/homebrew/opt/homeshick
source "/opt/homebrew/opt/homeshick/homeshick.sh"
fpath=(/opt/homebrew/opt/homeshick/share/zsh/site-functions $fpath)

# Alias
alias c='claude'
# Claude Codeモデル設定（~/.zshrc.local で上書き可能）
: ${CLAUDE_MODEL_OPUS:='claude-opus-4-6[1M]'}
: ${CLAUDE_MODEL_SONNET:='claude-sonnet-4-6[1M]'}
: ${CLAUDE_MODEL_HAIKU:=haiku}

cc()   { claude --dangerously-skip-permissions --effort high --model "$CLAUDE_MODEL_OPUS" "$@"; }
ccc()  { claude --dangerously-skip-permissions --continue --effort high --model "$CLAUDE_MODEL_OPUS" "$@"; }
cch()  { claude --dangerously-skip-permissions --model "$CLAUDE_MODEL_HAIKU" "$@"; }
ccs()  { claude --dangerously-skip-permissions --effort high --model "$CLAUDE_MODEL_SONNET" "$@"; }
ccp()  { claude --dangerously-skip-permissions --effort high --print --model "$CLAUDE_MODEL_OPUS" "$@"; }
ccsp() { claude --dangerously-skip-permissions --effort high --print --model "$CLAUDE_MODEL_SONNET" "$@"; }
cchp() { claude --dangerously-skip-permissions --print --model "$CLAUDE_MODEL_HAIKU" --bare "$@"; }
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

# Claude Code
export CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING=1

# fzf + nvim
v() {
  local file
  file=$(fzf --height=40% --reverse)
  [[ -n "$file" ]] && nvim "$file"
}

# Zoxide
eval "$(zoxide init zsh --cmd j)"

# direnv
eval "$(direnv hook zsh)"

# emacs key bind
bindkey -e

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

# Ghostty CWD復元（先頭で保存した_SHELL_INIT_PWDを使用）
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
