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
# Remove conflicting Docker apt entries (e.g. deb822 docker.sources written by
# Docker's own installer, which pins signed-by to docker.asc and clashes with
# the docker.list we manage here).
for f in /etc/apt/sources.list.d/docker.sources /etc/apt/keyrings/docker.asc; do
  if [ -e "$f" ]; then
    sudo rm -f "$f"
    echo "    Removed conflicting $f"
  fi
done
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
# 4. Binary tools (not in apt)
# -----------------------------------------------------------------------------

log "Installing binary tools"
"$DOTFILES_DIR/bootstrap/install-tools.sh"

# -----------------------------------------------------------------------------
# 4b. Language versions
# -----------------------------------------------------------------------------

log "Installing language versions"
"$DOTFILES_DIR/bootstrap/install-langs.sh"

# -----------------------------------------------------------------------------
# 5. Post-install configuration
# -----------------------------------------------------------------------------

log "Post-install configuration"

# Docker: add user to docker group so the system daemon works without sudo.
# Harmless under rootless Docker, which does not use the socket this grants
# access to — kept because the group is also what lets you talk to a system
# daemon if you ever switch back.
if ! id -nG "$USER" | grep -qw docker; then
  sudo usermod -aG docker "$USER"
  echo "    Added $USER to docker group (logout/login required)."
fi

# Rootless Docker.
#
# This machine runs the daemon as a systemd user service with its data-root
# under ~/.local/share/docker. Without this step a rebuilt machine comes up on
# the system daemon instead, which changes where volumes live and breaks the
# container-based volume dumps in borg-dump-services.
#
# Non-fatal: it needs a user session bus, which a container or a plain ssh
# invocation may not have, and bootstrap should not die over it.
if command -v dockerd-rootless-setuptool.sh >/dev/null 2>&1; then
  if systemctl --user is-active docker >/dev/null 2>&1; then
    echo "    Rootless Docker already running."
  elif systemctl --user show-environment >/dev/null 2>&1; then
    # The system daemon and the rootless one cannot both own the socket.
    sudo systemctl disable --now docker.service docker.socket 2>/dev/null || true
    if dockerd-rootless-setuptool.sh install; then
      systemctl --user enable --now docker 2>/dev/null || true
      # Needed for the user daemon to keep running with no login session.
      sudo loginctl enable-linger "$USER" 2>/dev/null || true
      echo "    Rootless Docker installed and enabled."
    else
      echo "    WARN: rootless Docker setup failed — see dockerd-rootless-setuptool.sh output" >&2
    fi
  else
    echo "    No systemd user bus — skipping rootless Docker setup."
  fi
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

# SSH key: generate ed25519 key if none exists
if [[ ! -f "$HOME/.ssh/id_ed25519" ]]; then
  mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
  ssh-keygen -t ed25519 -C "$USER@$(hostname)" -f "$HOME/.ssh/id_ed25519" -N ""
  echo "    Generated SSH key at ~/.ssh/id_ed25519"
  echo "    Add the public key to GitHub/GitLab: ~/.ssh/id_ed25519.pub"
fi

# Refresh font cache (picks up fonts-jetbrains-mono and anything stowed)
if command -v fc-cache &>/dev/null; then
  fc-cache -f >/dev/null 2>&1 || true
fi

# KDE/Plasma settings (no-op on non-Plasma systems)
"$(dirname "$0")/kde-settings.sh"

# Enable syncthing as a user service if you use it
if command -v syncthing &>/dev/null; then
  systemctl --user enable --now syncthing.service 2>/dev/null || true
fi

# Root-level backup pieces: the /etc snapshot script and its system timer.
# These do not depend on stow (nothing is symlinked into $HOME), so unlike the
# user timers they can be installed from here.
"$(dirname "$0")/install-system-units.sh"

# Note: the systemd user timers this repo ships are NOT registered here.
# bootstrap/install-units.sh has to run after `stow`, because the units point at
# scripts under ~/.local/bin that do not exist until the packages are linked.
# The Makefile's install-linux target calls it in the right order.

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
  - Claude CLI              https://github.com/anthropics/claude-cli
  - pipx packages           pipx install huggingface-hub  (etc.)

EOF
