export PATH="$HOME/.local/bin:$PATH"

eval "$(anyenv init -)"

function powerline_precmd() {
	PS1="$(powerline-shell --shell zsh $?)"$'\n%f%k%F{green}❯%f '
}

function install_powerline_precmd() {
  for s in "${precmd_functions[@]}"; do
    if [ "$s" = "powerline_precmd" ]; then
      return
    fi
  done
  precmd_functions+=(powerline_precmd)
}

if [ "$TERM" != "linux" -a -x "$(command -v powerline-shell)" ]; then
    install_powerline_precmd
fi

source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh

# homeshick
export HOMESHICK_DIR=/opt/homebrew/opt/homeshick
source "/opt/homebrew/opt/homeshick/homeshick.sh"
fpath=(/opt/homebrew/opt/homeshick/share/zsh/site-functions $fpath)

# Alias
alias cc='claude'
alias ccc='claude -- continue'
alias t='tig status'

# fzf + nvim
v() {
  local file
  file=$(fzf --height=40% --reverse)
  [[ -n "$file" ]] && nvim "$file"
}

# Zoxide
eval "$(zoxide init zsh --cmd j)"

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
