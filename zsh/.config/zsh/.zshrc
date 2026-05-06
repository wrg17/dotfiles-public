# ============================================================================
# .zshrc — interactive shell config
# (env vars live in .zshenv; this file is for shells you actually type into)
# ============================================================================

# ----------------------------------------------------------------------------
# PATH (auto-deduped)
# ----------------------------------------------------------------------------
typeset -U path PATH

path=(
  /home/linuxbrew/.linuxbrew/bin
  /home/linuxbrew/.linuxbrew/sbin
  $HOME/.local/bin
  $HOME/.opencode/bin
  $CARGO_HOME/bin
  $GOBIN
  /usr/local/bin
  /usr/bin
  $path
)

export DOCKER_HOST=unix:///run/user/1000/docker.sock

export VCPKG_ROOT="$HOME/dev/vcpkg"
export XDG_DATA_DIRS="/var/lib/snapd/desktop/applications:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"

# ----------------------------------------------------------------------------
# OH MY ZSH
# ----------------------------------------------------------------------------
ZSH_THEME=""
zstyle ':omz:update' mode auto

plugins=(
  git
  gitignore
  zsh-autosuggestions
  zsh-syntax-highlighting
  history-substring-search
)

source $ZSH/oh-my-zsh.sh

# ----------------------------------------------------------------------------
# HISTORY
# ----------------------------------------------------------------------------
HISTSIZE=50000
SAVEHIST=50000
setopt SHARE_HISTORY HIST_IGNORE_ALL_DUPS HIST_IGNORE_SPACE \
       HIST_REDUCE_BLANKS EXTENDED_HISTORY

# ----------------------------------------------------------------------------
# SHELL OPTIONS
# ----------------------------------------------------------------------------
setopt AUTO_CD AUTO_PUSHD PUSHD_IGNORE_DUPS EXTENDED_GLOB INTERACTIVE_COMMENTS

# ----------------------------------------------------------------------------
# TOOL INTEGRATIONS
# ----------------------------------------------------------------------------
[ -f "$CARGO_HOME/env" ] && source "$CARGO_HOME/env"

# nvm — lazy-loaded (saves ~500ms on shell startup)
_load_nvm() {
  unset -f nvm node npm npx
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
}
nvm()  { _load_nvm; nvm "$@"; }
node() { _load_nvm; node "$@"; }
npm()  { _load_nvm; npm "$@"; }
npx()  { _load_nvm; npx "$@"; }

# Optional tools — load only if installed
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
command -v zoxide >/dev/null && eval "$(zoxide init zsh)"
command -v direnv >/dev/null && eval "$(direnv hook zsh)"

upd() {
  echo "==> apt"
  sudo apt update && sudo apt upgrade -y || return 1
  echo "==> brew"
  brew update && brew upgrade || return 1
  echo "==> rust"
  rustup update || return 1
  echo "==> pipx"
  pipx upgrade-all || return 1
  echo "==> oh-my-zsh"
  zsh "$ZSH/tools/upgrade.sh" || return 1
  echo "✓ all updates complete"
}

# ----------------------------------------------------------------------------
# ALIASES
# ----------------------------------------------------------------------------

# Editor
alias vim='nvim'
alias vi='nvim'

# Modern replacements (only if the tool exists)
if command -v eza >/dev/null; then
  alias ls='eza --group-directories-first'
  alias ll='eza -l --git --group-directories-first'
  alias la='eza -la --git --group-directories-first'
  alias lt='eza --tree --level=2 --git-ignore'
fi
command -v bat >/dev/null && alias cat='bat --paging=never'
command -v fd  >/dev/null || alias fd='fdfind'    # Ubuntu names it fdfind

# Safety nets
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# Config shortcuts
alias zshrc='nvim $ZDOTDIR/.zshrc'
alias zshenv='nvim $HOME/.zshenv'
alias szsh='exec zsh'
alias weztermcfg='nvim $XDG_CONFIG_HOME/wezterm/wezterm.lua'
alias starshipcfg='nvim $XDG_CONFIG_HOME/starship.toml'
alias tmuxcfg='nvim $XDG_CONFIG_HOME/tmux/tmux.conf'

# Clipboard — clip (write) is ~/.local/bin/clip, which handles macOS/Wayland/X11.
# clipout (read) needs a platform alias since there is no equivalent script.
if [[ "$OSTYPE" == darwin* ]]; then
  alias clipout='pbpaste'
elif command -v wl-paste >/dev/null 2>&1; then
  alias clipout='wl-paste'
else
  alias clipout='xclip -selection clipboard -o'
fi

# Git extras (beyond OMZ defaults)
alias gs='git status -sb'
alias glg='git log --graph --oneline --decorate --all'
alias gca='git commit --amend --no-edit'
alias gwip='git add -A && git commit -m "wip"'

# Docker
alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias dex='docker exec -it'
alias dlog='docker logs -f'
alias dstop-all='docker stop $(docker ps -q)'
alias dprune='docker system prune -af --volumes'

# GPU / system
alias gpu='nvidia-smi'
alias gpuwatch='watch -n 1 nvidia-smi'
alias ports='ss -tulpn'
alias myip='curl -s ifconfig.me && echo'

# Dotfiles management
export DOTFILES="$HOME/dotfiles"
alias dot='cd $DOTFILES'
alias dotedit='cd $DOTFILES && $EDITOR .'
dots()    { (cd $DOTFILES && stow -v "$@"); }
dotsoff() { (cd $DOTFILES && stow -Dv "$@"); }
dotsdry() { (cd $DOTFILES && stow -nv "$@"); }
dotsall() { (cd $DOTFILES && stow -v */); }
dotstat() { (cd $DOTFILES && git status); }
dotsync() { (cd $DOTFILES && git add -A && git commit -m "${*:-update}" && git push); }

# ----------------------------------------------------------------------------
# FUNCTIONS
# ----------------------------------------------------------------------------

# Capture stdout+stderr to clipboard while still showing on terminal
clipall() { "$@" 2>&1 | tee /dev/tty | clip; }

# mkdir + cd in one move
mkcd() { mkdir -p "$1" && cd "$1"; }

# Universal extractor
extract() {
  [ -z "$1" ] && { echo "Usage: extract <archive>"; return 1; }
  case "$1" in
    *.tar.bz2|*.tbz2) tar xjf "$1"  ;;
    *.tar.gz|*.tgz)   tar xzf "$1"  ;;
    *.tar.xz)         tar xJf "$1"  ;;
    *.tar)            tar xf "$1"   ;;
    *.bz2)            bunzip2 "$1"  ;;
    *.gz)             gunzip "$1"   ;;
    *.zip)            unzip "$1"    ;;
    *.7z)             7z x "$1"     ;;
    *.rar)            unrar x "$1"  ;;
    *) echo "Cannot extract: $1"; return 1 ;;
  esac
}

# Quick Python venv: creates .venv in cwd and activates it
mkvenv() { python3 -m venv .venv && source .venv/bin/activate; }
alias venv='source .venv/bin/activate'

# ----------------------------------------------------------------------------
# SSH AGENT (interactive shells only)
# ----------------------------------------------------------------------------
if [[ -o interactive ]] && [[ -t 0 ]]; then
  if ! pgrep -u "$USER" ssh-agent > /dev/null; then
    eval "$(ssh-agent -s)" >/dev/null
  fi
  ssh-add -l >/dev/null 2>&1 || ssh-add ~/.ssh/id_ed25519 2>/dev/null
fi

# ----------------------------------------------------------------------------
# TMUX AUTO-START (real terminals only)
# ----------------------------------------------------------------------------
if [[ -o interactive ]] && [[ -t 0 ]] && [[ -t 1 ]] \
   && command -v tmux >/dev/null \
   && [[ -z "$TMUX" ]] && [[ -z "$NO_TMUX" ]] \
   && [[ -z "$VSCODE_INJECTION" ]] && [[ -z "$INSIDE_EMACS" ]] \
   && [[ "$TERMINAL_EMULATOR" != *"JetBrains"* ]] \
   && [[ -z "$INTELLIJ_ENVIRONMENT_READER" ]]; then
  exec tmux
fi

# ----------------------------------------------------------------------------
# PROMPT
# ----------------------------------------------------------------------------
command -v starship >/dev/null && eval "$(starship init zsh)"
setopt NO_BANG_HIST

# ----------------------------------------------------------------------------
# YAZI
# ----------------------------------------------------------------------------
function y() {
  local tmp cwd
  tmp="$(mktemp -t yazi-cwd.XXXXX)"
  yazi "$@" --cwd-file="$tmp"
  cwd="$(cat "$tmp" 2>/dev/null)"
  [ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && cd "$cwd"
  rm -f "$tmp"
}

[[ -f $ZDOTDIR/.zshrc.local ]] && source $ZDOTDIR/.zshrc.local
