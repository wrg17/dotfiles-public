#!/usr/bin/env bash
# Installs tools not reliably available via brew/apt as pre-built binaries.
# Idempotent: skips tools already present in PATH.
set -euo pipefail

INSTALL_DIR="${HOME}/.local"
BIN_DIR="${INSTALL_DIR}/bin"
mkdir -p "$BIN_DIR"

OS="$(uname -s)"
ARCH="$(uname -m)"

XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
PYENV_ROOT="${PYENV_ROOT:-$XDG_DATA_HOME/pyenv}"
GOENV_ROOT="${GOENV_ROOT:-$XDG_DATA_HOME/goenv}"

log() { printf '\n==> %s\n' "$*"; }

# ── Starship ──────────────────────────────────────────────────────────────────

install_starship() {
  if command -v starship >/dev/null 2>&1; then
    log "starship already installed — skipping"; return
  fi
  log "Installing starship"
  curl -sS https://starship.rs/install.sh | sh -s -- --yes --bin-dir "$BIN_DIR"
}

# ── Neovim ────────────────────────────────────────────────────────────────────

install_neovim() {
  if command -v nvim >/dev/null 2>&1; then
    log "neovim already installed — skipping"; return
  fi
  log "Installing neovim"
  local asset
  case "${OS}-${ARCH}" in
    Darwin-x86_64)  asset="nvim-macos-x86_64.tar.gz" ;;
    Darwin-arm64)   asset="nvim-macos-arm64.tar.gz"   ;;
    Linux-x86_64)   asset="nvim-linux-x86_64.tar.gz"  ;;
    Linux-aarch64)  asset="nvim-linux-arm64.tar.gz"   ;;
    *) printf 'Unsupported platform: %s-%s\n' "$OS" "$ARCH" >&2; return 1 ;;
  esac
  curl -fsSL "https://github.com/neovim/neovim/releases/latest/download/${asset}" \
    | tar -xz -C "$INSTALL_DIR" --strip-components=1
}

# ── Yazi ──────────────────────────────────────────────────────────────────────

install_yazi() {
  if command -v yazi >/dev/null 2>&1; then
    log "yazi already installed — skipping"; return
  fi
  log "Installing yazi"
  local asset
  case "${OS}-${ARCH}" in
    Darwin-x86_64)  asset="yazi-x86_64-apple-darwin.zip"        ;;
    Darwin-arm64)   asset="yazi-aarch64-apple-darwin.zip"       ;;
    Linux-x86_64)   asset="yazi-x86_64-unknown-linux-musl.zip"  ;;
    Linux-aarch64)  asset="yazi-aarch64-unknown-linux-musl.zip" ;;
    *) printf 'Unsupported platform: %s-%s\n' "$OS" "$ARCH" >&2; return 1 ;;
  esac
  local tmpdir
  tmpdir="$(mktemp -d)"
  curl -fsSL "https://github.com/sxyazi/yazi/releases/latest/download/${asset}" \
    -o "${tmpdir}/yazi.zip"
  unzip -q "${tmpdir}/yazi.zip" -d "${tmpdir}"
  local inner_dir
  inner_dir="$(find "${tmpdir}" -maxdepth 1 -mindepth 1 -type d | head -n 1)"
  cp "${inner_dir}/yazi" "${inner_dir}/ya" "$BIN_DIR/"
  chmod +x "${BIN_DIR}/yazi" "${BIN_DIR}/ya"
  rm -rf "${tmpdir}"
}

# ── nvm ───────────────────────────────────────────────────────────────────────

install_nvm() {
  local nvm_dir="${NVM_DIR:-${XDG_DATA_HOME}/nvm}"
  if [[ -d "$nvm_dir" ]]; then
    log "nvm already installed — skipping"; return
  fi
  log "Installing nvm"
  mkdir -p "$nvm_dir"
  PROFILE=/dev/null NVM_DIR="$nvm_dir" \
    bash -c "$(curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/HEAD/install.sh)"
}

# ── TPM (tmux plugin manager) ────────────────────────────────────────────────

install_tpm() {
  if [[ -d "$HOME/.tmux/plugins/tpm" ]]; then
    log "tpm already installed — skipping"; return
  fi
  log "Installing tpm"
  git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
}

# ── Docker CLI plugins (macOS only — apt ships them in the right place) ─────

link_docker_plugin() {
  local formula="$1"
  local src plugin_dir target
  src="$(brew --prefix "$formula" 2>/dev/null)/bin/$formula"
  [[ -x "$src" ]] || { log "$formula not installed via brew — skipping"; return; }
  plugin_dir="$HOME/.docker/cli-plugins"
  target="$plugin_dir/$formula"
  if [[ -L "$target" && "$(readlink "$target")" == "$src" ]]; then
    log "$formula plugin already linked — skipping"; return
  fi
  log "Linking $formula plugin"
  mkdir -p "$plugin_dir"
  ln -sfn "$src" "$target"
}

install_docker_plugins() {
  [[ "$OS" != "Darwin" ]] && return
  link_docker_plugin docker-compose
  link_docker_plugin docker-buildx
}

install_starship
install_neovim
install_yazi
install_nvm
install_tpm
install_docker_plugins

# ── Language version managers (Linux only — macOS uses brew) ─────────────────

install_pyenv() {
  if command -v pyenv >/dev/null 2>&1 || [[ -d "$PYENV_ROOT" ]]; then
    log "pyenv already installed — skipping"; return
  fi
  [[ "$OS" != "Linux" ]] && return
  log "Installing pyenv"
  git clone https://github.com/pyenv/pyenv.git "$PYENV_ROOT"
  # Compile dynamic bash extension for faster version switching (optional)
  (cd "$PYENV_ROOT" && src/configure && make -C src 2>/dev/null) || true
}

install_goenv() {
  if command -v goenv >/dev/null 2>&1 || [[ -d "$GOENV_ROOT" ]]; then
    log "goenv already installed — skipping"; return
  fi
  [[ "$OS" != "Linux" ]] && return
  log "Installing goenv"
  git clone https://github.com/go-env/goenv.git "$GOENV_ROOT"
}

install_jenv() {
  if command -v jenv >/dev/null 2>&1 || [[ -d "$HOME/.jenv" ]]; then
    log "jenv already installed — skipping"; return
  fi
  [[ "$OS" != "Linux" ]] && return
  log "Installing jenv"
  git clone https://github.com/jenv/jenv.git "$HOME/.jenv"
}

install_pyenv
install_goenv
install_jenv

log "Tool installation complete"
