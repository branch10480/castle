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
export CLAUDE_CODE_NO_FLICKER=1

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
if command -v cmux &>/dev/null; then
  alias cc='cmux claude-teams --dangerously-skip-permissions --model opus'
  alias ccc='cmux claude-teams --continue --model opus'
  alias cch='cmux claude-teams --dangerously-skip-permissions --model haiku'
  alias ccs='cmux claude-teams --dangerously-skip-permissions --model sonnet'
  alias ccp='cmux claude-teams --dangerously-skip-permissions --print --model opus'
  alias cchp='cmux claude-teams --dangerously-skip-permissions --print --model haiku'
  alias ccsp='cmux claude-teams --dangerously-skip-permissions --print --model sonnet'
else
  alias cc='claude --dangerously-skip-permissions --model opus'
  alias ccc='claude --dangerously-skip-permissions --continue --model opus'
  alias cch='claude --dangerously-skip-permissions --model haiku'
  alias ccs='claude --dangerously-skip-permissions --model sonnet'
  alias ccp='claude --dangerously-skip-permissions --print --model opus'
  alias cchp='claude --dangerously-skip-permissions --print --model haiku'
  alias ccsp='claude --dangerously-skip-permissions --print --model sonnet'
fi
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

# Ghostty split CWD復元（先頭で保存した_SHELL_INIT_PWDを使用）
if [[ -n "$_SHELL_INIT_PWD" && "$PWD" == "$HOME/.homesick/"* && "$PWD" != "$_SHELL_INIT_PWD" ]]; then
  cd "$_SHELL_INIT_PWD"
fi
unset _SHELL_INIT_PWD
