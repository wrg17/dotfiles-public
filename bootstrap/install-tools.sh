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
RBENV_ROOT="${RBENV_ROOT:-$XDG_DATA_HOME/rbenv}"
CARGO_HOME="${CARGO_HOME:-$XDG_DATA_HOME/cargo}"
RUSTUP_HOME="${RUSTUP_HOME:-$XDG_DATA_HOME/rustup}"

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

# ── Sheldon (zsh plugin manager) ─────────────────────────────────────────────

install_sheldon() {
  if command -v sheldon >/dev/null 2>&1; then
    log "sheldon already installed — skipping"; return
  fi
  log "Installing sheldon"
  curl --proto '=https' -fLsS https://rossmacarthur.github.io/install/crate.sh \
    | bash -s -- --repo rossmacarthur/sheldon --to "$BIN_DIR"
}

# ── zoxide / direnv (shell integrations) ─────────────────────────────────────

# Both are in the Brewfile's natural territory, but Homebrew has no bottles for
# macOS below its support floor, so `brew install zoxide` builds the whole
# dependency tree from source (llvm included). Upstream ships prebuilt binaries.

install_zoxide() {
  if command -v zoxide >/dev/null 2>&1; then
    log "zoxide already installed — skipping"; return
  fi
  log "Installing zoxide"
  curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh \
    | sh -s -- --bin-dir "$BIN_DIR"
}

install_direnv() {
  if command -v direnv >/dev/null 2>&1; then
    log "direnv already installed — skipping"; return
  fi
  log "Installing direnv"
  bin_path="$BIN_DIR" bash -c "$(curl -sfL https://direnv.net/install.sh)"
}

# ── eza / bat / fd (coreutils replacements) ──────────────────────────────────

# These were Brewfile formulae, but all three are Rust, so on a mac below
# Homebrew's bottle floor `brew install` drags in rust and llvm and compiles
# for hours. Upstream binaries (or a single crate build) take seconds.
# On Linux apt already provides them, so the guards below simply skip.

# Latest release tag without the rate-limited API: /releases/latest redirects
# to /releases/tag/<tag>.
gh_latest_tag() {
  curl -fsSLI -o /dev/null -w '%{url_effective}' \
    "https://github.com/$1/releases/latest" | sed 's|.*/tag/||'
}

# bat and fd share a layout: <name>-<tag>-<triple>.tar.gz holding
# <name>-<tag>-<triple>/<name>.
install_sharkdp_binary() {
  local name="$1" repo="$2" triple tag tmpdir
  case "${OS}-${ARCH}" in
    Darwin-x86_64) triple="x86_64-apple-darwin"        ;;
    Darwin-arm64)  triple="aarch64-apple-darwin"       ;;
    Linux-x86_64)  triple="x86_64-unknown-linux-musl"  ;;
    Linux-aarch64) triple="aarch64-unknown-linux-musl" ;;
    *) printf 'Unsupported platform: %s-%s\n' "$OS" "$ARCH" >&2; return 1 ;;
  esac
  tag="$(gh_latest_tag "$repo")"
  [[ -n "$tag" ]] || { printf 'Could not resolve latest %s tag\n' "$name" >&2; return 1; }
  tmpdir="$(mktemp -d)"
  curl -fsSL \
    "https://github.com/${repo}/releases/download/${tag}/${name}-${tag}-${triple}.tar.gz" \
    -o "${tmpdir}/${name}.tar.gz"
  tar -xzf "${tmpdir}/${name}.tar.gz" -C "$tmpdir"
  cp "${tmpdir}/${name}-${tag}-${triple}/${name}" "$BIN_DIR/"
  chmod +x "${BIN_DIR}/${name}"
  rm -rf "$tmpdir"
}

install_bat() {
  if command -v bat >/dev/null 2>&1 || command -v batcat >/dev/null 2>&1; then
    log "bat already installed — skipping"; return
  fi
  log "Installing bat"
  install_sharkdp_binary bat sharkdp/bat
}

install_fd() {
  if command -v fd >/dev/null 2>&1 || command -v fdfind >/dev/null 2>&1; then
    log "fd already installed — skipping"; return
  fi
  log "Installing fd"
  install_sharkdp_binary fd sharkdp/fd
}

install_eza() {
  if command -v eza >/dev/null 2>&1; then
    log "eza already installed — skipping"; return
  fi
  # eza ships no macOS binaries — Linux and Windows only. Build the crate
  # instead: minutes of rustc, versus brew dragging llvm through clang.
  if [[ "$OS" == "Darwin" ]]; then
    local cargo="${CARGO_HOME}/bin/cargo"
    [[ -x "$cargo" ]] || cargo="$(command -v cargo 2>/dev/null || true)"
    if [[ -z "$cargo" || ! -x "$cargo" ]]; then
      log "eza needs cargo on macOS (no upstream binary) — skipping"; return
    fi
    log "Installing eza via cargo (no upstream macOS binary)"
    # Non-fatal: eza is an optional ls replacement and .zshrc falls back to
    # plain ls without it. A failing crate build must not abort the rest of
    # bootstrap — it once took install_bat and install_fd down with it.
    # --locked uses eza's own Cargo.lock. Without it cargo resolves
    # palette_derive independently of palette and the build fails: the 0.7.7
    # macro emits references to crate::lms, absent from palette 0.7.5.
    if ! "$cargo" install eza --locked; then
      log "eza failed to build — skipping (zshrc falls back to ls)"
    fi
    return 0
  fi
  local asset tmpdir
  case "$ARCH" in
    x86_64)  asset="eza_x86_64-unknown-linux-musl.tar.gz" ;;
    aarch64) asset="eza_aarch64-unknown-linux-gnu.tar.gz" ;;
    *) printf 'Unsupported arch: %s\n' "$ARCH" >&2; return 1 ;;
  esac
  log "Installing eza"
  tmpdir="$(mktemp -d)"
  if curl -fsSL \
      "https://github.com/eza-community/eza/releases/latest/download/${asset}" \
      -o "${tmpdir}/eza.tar.gz" \
    && tar -xzf "${tmpdir}/eza.tar.gz" -C "$tmpdir"; then
    cp "${tmpdir}/eza" "$BIN_DIR/"
    chmod +x "${BIN_DIR}/eza"
  else
    log "eza download failed — skipping (zshrc falls back to ls)"
  fi
  rm -rf "$tmpdir"
  return 0
}

# ── TPM (tmux plugin manager) ────────────────────────────────────────────────

install_tpm() {
  if [[ -d "$HOME/.tmux/plugins/tpm" ]]; then
    log "tpm already installed — skipping"; return
  fi
  log "Installing tpm"
  git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
  log "Installing tmux plugins via tpm"
  "$HOME/.tmux/plugins/tpm/bin/install_plugins"
}

# ── Docker CLI plugins (macOS only — apt ships them in the right place) ─────

link_docker_plugin() {
  local formula="$1"
  local src plugin_dir target
  src="$(brew --prefix "$formula" 2>/dev/null)/bin/$formula"
  [[ -x "$src" ]] || { log "$formula not installed via brew — skipping"; return; }
  plugin_dir="${DOCKER_CONFIG:-$HOME/.docker}/cli-plugins"
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

# ── rustup ────────────────────────────────────────────────────────────────────

install_rustup() {
  if command -v rustup >/dev/null 2>&1; then
    log "rustup already installed — skipping"; return
  fi
  log "Installing rustup"
  mkdir -p "$CARGO_HOME" "$RUSTUP_HOME"
  CARGO_HOME="$CARGO_HOME" RUSTUP_HOME="$RUSTUP_HOME" \
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
    | sh -s -- -y --no-modify-path --default-toolchain stable
}

install_starship
install_neovim
install_yazi
install_nvm
install_rustup
install_sheldon
install_zoxide
install_direnv
install_bat
install_fd
install_eza
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
  git clone https://github.com/go-nv/goenv.git "$GOENV_ROOT"
}

install_jenv() {
  if command -v jenv >/dev/null 2>&1 || [[ -d "$HOME/.jenv" ]]; then
    log "jenv already installed — skipping"; return
  fi
  [[ "$OS" != "Linux" ]] && return
  log "Installing jenv"
  git clone https://github.com/jenv/jenv.git "$HOME/.jenv"
}

install_rbenv() {
  if command -v rbenv >/dev/null 2>&1 || [[ -d "$RBENV_ROOT" ]]; then
    log "rbenv already installed — skipping"; return
  fi
  [[ "$OS" != "Linux" ]] && return
  log "Installing rbenv"
  git clone https://github.com/rbenv/rbenv.git "$RBENV_ROOT"
  git clone https://github.com/rbenv/ruby-build.git "$RBENV_ROOT/plugins/ruby-build"
}

install_pyenv
install_goenv
install_jenv
install_rbenv

log "Tool installation complete"
