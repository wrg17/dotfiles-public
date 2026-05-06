#!/usr/bin/env bash
# bootstrap/linux.sh
# Idempotent bootstrap for a fresh Ubuntu 24.04 (noble) install.
# Run after cloning ~/dotfiles; safe to re-run.

set -euo pipefail

# -----------------------------------------------------------------------------
# Sanity checks
# -----------------------------------------------------------------------------

if ! grep -qi 'ubuntu' /etc/os-release; then
  echo "Error: this script targets Ubuntu. Detected:" >&2
  grep -E '^(NAME|VERSION)=' /etc/os-release >&2
  exit 1
fi

# shellcheck disable=SC1091
. /etc/os-release
CODENAME="${VERSION_CODENAME:-noble}"
ARCH="$(dpkg --print-architecture)"

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
PKG_FILE="$DOTFILES_DIR/bootstrap/apt-pkgs"

if [ ! -f "$PKG_FILE" ]; then
  echo "Error: package list not found at $PKG_FILE" >&2
  exit 1
fi

# Make all apt operations non-interactive
export DEBIAN_FRONTEND=noninteractive

log() { printf '\n==> %s\n' "$*"; }

# -----------------------------------------------------------------------------
# 1. Prerequisites needed to add other repos
# -----------------------------------------------------------------------------

log "Installing repo prerequisites"
sudo apt-get update -qq
sudo apt-get install -y --no-install-recommends \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg2 \
  software-properties-common \
  wget

# -----------------------------------------------------------------------------
# 2. Third-party repositories
# -----------------------------------------------------------------------------

log "Adding Docker official repo"
sudo install -m 0755 -d /etc/apt/keyrings
if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg |
    sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg
fi
if [ ! -f /etc/apt/sources.list.d/docker.list ]; then
  echo "deb [arch=$ARCH signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $CODENAME stable" |
    sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
fi

log "Adding NVIDIA Container Toolkit repo"
if [ ! -f /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg ]; then
  curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey |
    sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
fi
if [ ! -f /etc/apt/sources.list.d/nvidia-container-toolkit.list ]; then
  curl -fsSL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list |
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' |
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list >/dev/null
fi

log "Adding WezTerm repo"
if [ ! -f /usr/share/keyrings/wezterm-fury.gpg ]; then
  curl -fsSL https://apt.fury.io/wez/gpg.key |
    sudo gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg
fi
if [ ! -f /etc/apt/sources.list.d/wezterm.list ]; then
  echo "deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *" |
    sudo tee /etc/apt/sources.list.d/wezterm.list >/dev/null
fi

# -----------------------------------------------------------------------------
# 3. Install everything from the package list
# -----------------------------------------------------------------------------

log "Refreshing apt with new repos"
sudo apt-get update -qq

log "Installing packages from $PKG_FILE"
# Strip comments and blank lines, feed the rest to apt-get install
mapfile -t PKGS < <(grep -vE '^\s*(#|$)' "$PKG_FILE")
sudo apt-get install -y --no-install-recommends "${PKGS[@]}"

# -----------------------------------------------------------------------------
# 4. Post-install configuration
# -----------------------------------------------------------------------------

log "Post-install configuration"

# Docker: add user to docker group so `docker` works without sudo
if ! id -nG "$USER" | grep -qw docker; then
  sudo usermod -aG docker "$USER"
  echo "    Added $USER to docker group (logout/login required)."
fi

# zsh: make it the login shell
ZSH_PATH="$(command -v zsh || true)"
if [ -n "$ZSH_PATH" ] && [ "$SHELL" != "$ZSH_PATH" ]; then
  if ! grep -qx "$ZSH_PATH" /etc/shells; then
    echo "$ZSH_PATH" | sudo tee -a /etc/shells >/dev/null
  fi
  chsh -s "$ZSH_PATH"
  echo "    Default shell set to zsh (logout/login required)."
fi

# Refresh font cache (picks up fonts-jetbrains-mono and anything stowed)
if command -v fc-cache &>/dev/null; then
  fc-cache -f >/dev/null 2>&1 || true
fi

# Enable syncthing as a user service if you use it
if command -v syncthing &>/dev/null; then
  systemctl --user enable --now syncthing.service 2>/dev/null || true
fi

# -----------------------------------------------------------------------------
# Done
# -----------------------------------------------------------------------------

log "Bootstrap complete"
cat <<EOF

Next steps:
  - Log out and back in for docker group / zsh changes to take effect
  - cd $DOTFILES_DIR && make install-linux   (or stow packages individually)
  - bootstrap/link-jetbrains.sh after installing any JetBrains IDEs

Not handled by this script — install manually if you want them:
  - JetBrains Toolbox       https://www.jetbrains.com/toolbox-app/
  - Stacher7                https://stacher.io/
  - Rust toolchain          https://rustup.rs/  (curl ... | sh)
  - Claude CLI              https://github.com/anthropics/claude-cli
  - pipx packages           pipx install huggingface-hub  (etc.)

EOF
