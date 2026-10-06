# ============================================================================
# .zshrc — interactive shell config
# (env vars live in .zshenv; this file is for shells you actually type into)
# ============================================================================

# ----------------------------------------------------------------------------
# PATH (auto-deduped)
# ----------------------------------------------------------------------------
typeset -U path PATH

path=(
  $PYENV_ROOT/bin
  $PYENV_ROOT/shims
  $GOENV_ROOT/bin
  $GOENV_ROOT/shims
  $RBENV_ROOT/bin
  $RBENV_ROOT/shims
  $HOME/.jenv/bin
  $HOME/.jenv/shims
  /home/linuxbrew/.linuxbrew/bin
  /home/linuxbrew/.linuxbrew/sbin
  $HOME/.local/bin
  $CARGO_HOME/bin
  $GOBIN
  $path
)

if [[ "$OSTYPE" == linux-gnu* ]]; then
  export XDG_DATA_DIRS="/var/lib/snapd/desktop/applications:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
fi

# ----------------------------------------------------------------------------
# INIT CACHE HELPER
# Sources cached output of a command; regenerates only when trigger-file is
# newer than the cache (e.g. after brew upgrade or editing plugins.toml).
# ----------------------------------------------------------------------------
_initcache() {
  local name=$1 trigger=$2; shift 2
  local cache="$XDG_CACHE_HOME/zsh/${name}.zsh"
  if [[ ! -f $cache || $trigger -nt $cache ]]; then
    "$@" >| "$cache"
  fi
  source "$cache"
}

# ----------------------------------------------------------------------------
# PLUGINS (sheldon)
# ----------------------------------------------------------------------------
HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_FOUND='fg=#50fa7b,bold'
HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_NOT_FOUND='fg=#ff5555,bold'

# zsh-syntax-highlighting palette is supplied upstream by dracula/zsh-syntax-highlighting
# (loaded via sheldon after the main highlighter)
ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets pattern)
if command -v sheldon >/dev/null; then
  _sheldon_trigger="${XDG_CONFIG_HOME}/sheldon/plugins.lock"
  [[ -f "$_sheldon_trigger" ]] || _sheldon_trigger="${XDG_CONFIG_HOME}/sheldon/plugins.toml"
  _initcache sheldon "$_sheldon_trigger" sheldon source
  unset _sheldon_trigger
fi

typeset -A ZSH_HIGHLIGHT_STYLES
ZSH_HIGHLIGHT_PATTERNS+=('rm -rf *' 'fg=#ff5555,bold')
ZSH_HIGHLIGHT_PATTERNS+=('rm -r *'  'fg=#ff5555,bold')

# ----------------------------------------------------------------------------
# COMPLETIONS
# ----------------------------------------------------------------------------
autoload -Uz compinit
() {
  if [[ $# -gt 0 || ! -f "$ZSH_COMPDUMP" ]]; then
    compinit -u -d "$ZSH_COMPDUMP"
  else
    compinit -C -d "$ZSH_COMPDUMP"
  fi
} ${ZSH_COMPDUMP}(N.mh+24)

zstyle ':completion:*' menu select
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' use-cache yes
zstyle ':completion:*' cache-path "$XDG_CACHE_HOME/zsh/compcache"

# ----------------------------------------------------------------------------
# KEY BINDINGS
# ----------------------------------------------------------------------------
bindkey -v
export KEYTIMEOUT=1          # snap mode-switch (default 0.4s)

# Preserve emacs-style shortcuts in vi insert mode — muscle memory
bindkey -M viins '^a' beginning-of-line
bindkey -M viins '^e' end-of-line
bindkey -M viins '^k' kill-line
bindkey -M viins '^w' backward-kill-word

zmodload zsh/terminfo

(( ${+terminfo[smkx]} )) && (( ${+terminfo[rmkx]} )) && {
  function zle-line-init()   { echoti smkx }
  function zle-line-finish() { echoti rmkx }
  zle -N zle-line-init
  zle -N zle-line-finish
}

# Arrow keys — history-substring-search (loaded via sheldon)
bindkey "${terminfo[kcuu1]:-$'\e[A'}" history-substring-search-up
bindkey "${terminfo[kcud1]:-$'\e[B'}" history-substring-search-down
bindkey $'\eOA' history-substring-search-up
bindkey $'\eOB' history-substring-search-down

# Home / End / Delete
[[ -n "${terminfo[khome]}" ]] && bindkey "${terminfo[khome]}" beginning-of-line
[[ -n "${terminfo[kend]}"  ]] && bindkey "${terminfo[kend]}"  end-of-line
bindkey '\033[4~' end-of-line    # fn+right in WezTerm
bindkey '\033[1~' beginning-of-line  # fn+left in WezTerm
bindkey '^?' backward-delete-char
[[ -n "${terminfo[kdch1]}" ]] && bindkey "${terminfo[kdch1]}" delete-char || bindkey '^[[3~' delete-char

# Ctrl+arrows — word movement; Ctrl+Delete — kill word
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word
bindkey '^[[3;5~' kill-word

# Shift+Tab — reverse completion menu
[[ -n "${terminfo[kcbt]}" ]] && bindkey "${terminfo[kcbt]}" reverse-menu-complete

# Ctrl+R — incremental history search; Space — history expansion
bindkey '^r' history-incremental-search-backward
bindkey ' '  magic-space

# Ctrl+X Ctrl+E (or `v` in vi normal mode) — edit command line in $EDITOR
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey '^x^e' edit-command-line
bindkey -M vicmd 'v' edit-command-line

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

## Language version managers
command -v pyenv >/dev/null && eval "$(pyenv init -)"
command -v goenv >/dev/null && eval "$(goenv init -)"
command -v rbenv >/dev/null && eval "$(rbenv init - zsh)"
command -v jenv  >/dev/null && eval "$(jenv init -)"

## LLVM (brew keg-only on macOS — not auto-linked, must be explicit)
[[ -n "${HOMEBREW_PREFIX:-}" && -d "$HOMEBREW_PREFIX/opt/llvm/bin" ]] && \
  path=("$HOMEBREW_PREFIX/opt/llvm/bin" $path)

## Optional tools — load only if installed
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
command -v zoxide >/dev/null && _initcache zoxide "$(command -v zoxide)" zoxide init zsh
command -v direnv >/dev/null && _initcache direnv "$(command -v direnv)" direnv hook zsh

upd() {
  if command -v apt >/dev/null 2>&1; then
    echo "==> apt"
    sudo apt update && sudo apt upgrade -y || return 1
  fi
  if command -v brew >/dev/null 2>&1; then
    echo "==> brew"
    brew update && brew upgrade || return 1
  fi
  if command -v rustup >/dev/null 2>&1; then
    echo "==> rust"
    rustup update || return 1
  fi
  if command -v pipx >/dev/null 2>&1; then
    echo "==> pipx"
    pipx upgrade-all || return 1
  fi
  if command -v sheldon >/dev/null 2>&1; then
    echo "==> sheldon"
    sheldon lock --update || return 1
  fi
  # Update git-cloned managers (nvm always; *envs only on Linux — brew handles macOS)
  for _vm_dir in "$NVM_DIR" "$PYENV_ROOT" "$GOENV_ROOT" "$RBENV_ROOT" "$HOME/.jenv"; do
    [[ -d "$_vm_dir/.git" ]] || continue
    echo "==> $(basename $_vm_dir)"
    git -C "$_vm_dir" pull --ff-only || return 1
  done
  unset _vm_dir
  # Audit language EOL status after updating
  if command -v bats >/dev/null 2>&1 && [[ -f "${DOTFILES}/test/langs.bats" ]]; then
    echo "==> lang audit"
    bats "${DOTFILES}/test/langs.bats" || true
  fi
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

# Clipboard
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

# GPU / system (gpu/ports skip cleanly on machines without the underlying tool)
if command -v nvidia-smi >/dev/null; then
  alias gpu='nvidia-smi'
  alias gpuwatch='watch -n 1 nvidia-smi'
fi
command -v ss >/dev/null && alias ports='ss -tulpn'
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
# macOS launchd provides SSH_AUTH_SOCK automatically; only start an agent on
# Linux (or any system where launchd isn't managing it).
# ----------------------------------------------------------------------------
if [[ -o interactive ]] && [[ -t 0 ]]; then
  if [[ -z "$SSH_AUTH_SOCK" ]]; then
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
command -v starship >/dev/null && _initcache starship "$(command -v starship)" starship init zsh
unset -f _initcache
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
