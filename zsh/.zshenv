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

export CARGO_HOME="$XDG_DATA_HOME/cargo"
export RUSTUP_HOME="$XDG_DATA_HOME/rustup"
export GOPATH="$XDG_DATA_HOME/go"
export GOBIN="$GOPATH/bin"
export PYENV_ROOT="$XDG_DATA_HOME/pyenv"
export GOENV_ROOT="$XDG_DATA_HOME/goenv"
export RBENV_ROOT="$XDG_DATA_HOME/rbenv"
export NVM_DIR="$XDG_DATA_HOME/nvm"

# Expose nvm's default node to non-interactive shells (zsh -c, automation).
# Avoids sourcing nvm.sh — that's left lazy-loaded in .zshrc for ~500ms savings.
# Follow alias chain: default -> lts/* -> lts/krypton -> v24.16.0
if [[ -d "$NVM_DIR/versions/node" ]]; then
  _nvm_ver="$(<"$NVM_DIR/alias/default" 2>/dev/null)"
  while [[ -n "$_nvm_ver" && -f "$NVM_DIR/alias/$_nvm_ver" ]]; do
    _nvm_ver="$(<"$NVM_DIR/alias/$_nvm_ver")"
  done
  [[ -d "$NVM_DIR/versions/node/$_nvm_ver/bin" ]] && \
    export PATH="$NVM_DIR/versions/node/$_nvm_ver/bin:$PATH"
  unset _nvm_ver
fi

export SOPS_AGE_KEY_FILE="${XDG_CONFIG_HOME}/sops/age/keys.txt"

export NPM_CONFIG_USERCONFIG="$XDG_CONFIG_HOME/npm/npmrc"
export NPM_CONFIG_CACHE="$XDG_CACHE_HOME/npm"
export DOCKER_CONFIG="$XDG_CONFIG_HOME/docker"
export LESSHISTFILE="$XDG_STATE_HOME/less/history"

export ZSH_COMPDUMP="$XDG_CACHE_HOME/zsh/zcompdump"

# Ensure state dirs exist (otherwise zsh history etc. fail silently)
mkdir -p "$XDG_STATE_HOME/zsh" "$XDG_STATE_HOME/less" "$XDG_CACHE_HOME/zsh"

# ----------------------------------------------------------------------------
# EDITOR & LOCALE
# ----------------------------------------------------------------------------
export EDITOR='nvim'
export VISUAL='nvim'
export LANG=en_US.UTF-8

# ----------------------------------------------------------------------------
# HOMEBREW
# Apple Silicon Mac · Intel Mac · Linuxbrew — first existing path wins.
# Cache shellenv output so the Ruby subprocess (~190ms) only runs when brew
# itself changes (the binary's mtime advances on every brew upgrade).
# ----------------------------------------------------------------------------
export HOMEBREW_NO_ENV_HINTS=1

_brew_cache="$XDG_CACHE_HOME/brew_shellenv.zsh"
for brew_path in \
    /opt/homebrew/bin/brew \
    /usr/local/bin/brew \
    /home/linuxbrew/.linuxbrew/bin/brew; do
  if [[ -x "$brew_path" ]]; then
    if [[ ! -f "$_brew_cache" || "$brew_path" -nt "$_brew_cache" ]]; then
      "$brew_path" shellenv >| "$_brew_cache"
    fi
    source "$_brew_cache"
    break
  fi
done
unset _brew_cache brew_path

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
