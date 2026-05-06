# ============================================================================
# .zshenv — sourced for ALL zsh invocations (including scripts)
# Keep this minimal: env vars only, no interactive-shell logic
# Cross-platform: detects Mac/Linux paths via existence checks
# ============================================================================

# ----------------------------------------------------------------------------
# XDG BASE DIRECTORIES
# ----------------------------------------------------------------------------
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

# ----------------------------------------------------------------------------
# REDIRECT TOOLS THAT POLLUTE $HOME INTO XDG DIRS
# ----------------------------------------------------------------------------
export ZDOTDIR="$XDG_CONFIG_HOME/zsh"
export HISTFILE="$XDG_STATE_HOME/zsh/history"

export ZSH="$XDG_DATA_HOME/oh-my-zsh"
export CARGO_HOME="$XDG_DATA_HOME/cargo"
export RUSTUP_HOME="$XDG_DATA_HOME/rustup"
export GOPATH="$XDG_DATA_HOME/go"
export GOBIN="$GOPATH/bin"
export NVM_DIR="$XDG_DATA_HOME/nvm"
export BUN_INSTALL="$XDG_DATA_HOME/bun"
export NUGET_PACKAGES="$XDG_DATA_HOME/NuGet"

export NPM_CONFIG_USERCONFIG="$XDG_CONFIG_HOME/npm/npmrc"
export NPM_CONFIG_CACHE="$XDG_CACHE_HOME/npm"
export DOCKER_CONFIG="$XDG_CONFIG_HOME/docker"
export LESSHISTFILE="$XDG_STATE_HOME/less/history"
export PYTHONSTARTUP="$XDG_CONFIG_HOME/python/pythonrc"
export WGETRC="$XDG_CONFIG_HOME/wgetrc"

export ZSH_COMPDUMP="$XDG_CACHE_HOME/zsh/zcompdump"

# Ensure state dirs exist (otherwise zsh history etc. fail silently)
mkdir -p "$XDG_STATE_HOME/zsh" "$XDG_STATE_HOME/less"

# ----------------------------------------------------------------------------
# EDITOR & LOCALE
# ----------------------------------------------------------------------------
export EDITOR='nvim'
export VISUAL='nvim'
export LANG=en_US.UTF-8

# ----------------------------------------------------------------------------
# HOMEBREW
# Apple Silicon Mac · Intel Mac · Linuxbrew — first existing path wins.
# brew shellenv sets HOMEBREW_PREFIX, prepends bin/sbin to PATH, etc.
# ----------------------------------------------------------------------------
for brew_path in \
    /opt/homebrew/bin/brew \
    /usr/local/bin/brew \
    /home/linuxbrew/.linuxbrew/bin/brew; do
  if [[ -x "$brew_path" ]]; then
    eval "$("$brew_path" shellenv)"
    break
  fi
done
unset brew_path

# ----------------------------------------------------------------------------
# JETBRAINS TOOLBOX SHELL SCRIPTS
# Adds the Toolbox-managed `idea`, `pycharm`, `webstorm`, etc. CLI launchers
# to PATH if Toolbox is installed.
# ----------------------------------------------------------------------------
for tbx_scripts in \
    "$HOME/Library/Application Support/JetBrains/Toolbox/scripts" \
    "$HOME/.local/share/JetBrains/Toolbox/scripts"; do
  [[ -d "$tbx_scripts" ]] && export PATH="$PATH:$tbx_scripts"
done
unset tbx_scripts
