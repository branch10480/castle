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

# Serena/Claude Code トークン最適化
export ENABLE_TOOL_SEARCH=true

