#!/usr/bin/env bash
# bootstrap/install-units.sh
# Load and reconcile the systemd --user units stowed from this repo.
#
# This is the scheduled-job half of the bootstrap: anything this repo wants run
# on a schedule ships as a .timer/.service pair under a stow package's
# .config/systemd/user/, and this script registers whatever is there. Adding a
# new scheduled job means adding two files and re-running install-linux — there
# is no list here to keep in sync.
#
# "Reconcile" means both directions:
#   - every dotfiles-owned .timer present gets enabled and started
#   - every enabled timer whose unit file has gone away gets disabled
#
# The second half is what makes this re-runnable after a unit is renamed or
# deleted. Without it, `systemctl --user` keeps a dangling want forever and
# prints a failure on every daemon-reload.
#
# Idempotent; safe to re-run. No-op on systems without a systemd user instance
# (macOS, most containers), so bootstrap/linux.sh can call it unconditionally.

set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"

log() { printf '    %s\n' "$*"; }

# -----------------------------------------------------------------------------
# Is there anything to talk to?
# -----------------------------------------------------------------------------

if ! command -v systemctl >/dev/null 2>&1; then
  log "systemctl not found — skipping user units"
  exit 0
fi

# A systemd user instance needs a session bus. In a container or over a bare
# `docker exec` there is none, and every systemctl --user call fails with
# "Failed to connect to bus" — which is not an error worth failing bootstrap for.
if ! systemctl --user show-environment >/dev/null 2>&1; then
  log "no systemd user instance (no session bus) — skipping user units"
  exit 0
fi

if [ ! -d "$UNIT_DIR" ]; then
  log "no unit directory at $UNIT_DIR — nothing to load"
  exit 0
fi

# -----------------------------------------------------------------------------
# Pick up newly stowed unit files
# -----------------------------------------------------------------------------

systemctl --user daemon-reload

# -----------------------------------------------------------------------------
# Disable timers whose unit file no longer exists
#
# `systemctl --user enable` records a symlink under timers.target.wants. If the
# unit it points at is later renamed or unstowed, that symlink dangles. Clean
# those first, so the enable pass below starts from a consistent state.
# -----------------------------------------------------------------------------

for wants_dir in "$UNIT_DIR"/timers.target.wants "$UNIT_DIR"/default.target.wants; do
  [ -d "$wants_dir" ] || continue
  for link in "$wants_dir"/*; do
    # The glob itself when the directory is empty.
    [ -e "$link" ] || [ -L "$link" ] || continue
    # -L true and -e false means a symlink to something that is not there.
    if [ -L "$link" ] && [ ! -e "$link" ]; then
      unit="$(basename "$link")"
      log "disabling $unit (unit file is gone)"
      systemctl --user disable "$unit" >/dev/null 2>&1 || rm -f "$link"
    fi
  done
done

# -----------------------------------------------------------------------------
# Enable and start every timer this repo owns
#
# Ownership is decided by where the symlink points, not by filename: a unit the
# user wrote by hand into ~/.config/systemd/user is left completely alone, and
# only units resolving back into the dotfiles checkout are managed here.
# -----------------------------------------------------------------------------

found=0
for unit_path in "$UNIT_DIR"/*.timer; do
  [ -e "$unit_path" ] || continue

  target="$(readlink -f "$unit_path" 2>/dev/null || true)"
  case "$target" in
    "$DOTFILES_DIR"/*) ;;
    *)
      log "skipping $(basename "$unit_path") (not stowed from $DOTFILES_DIR)"
      continue
      ;;
  esac

  unit="$(basename "$unit_path")"
  found=$((found + 1))

  # --now covers both the fresh install and the already-enabled case: enable is
  # idempotent, and start on an already-running timer is a no-op.
  if systemctl --user enable --now "$unit" >/dev/null 2>&1; then
    next="$(systemctl --user show -p NextElapseUSecRealtime --value "$unit" 2>/dev/null || true)"
    if [ -n "$next" ] && [ "$next" != "0" ]; then
      log "enabled $unit (next run: $next)"
    else
      log "enabled $unit"
    fi
  else
    # Don't abort bootstrap for one bad unit — report it and carry on, so the
    # remaining timers still get installed.
    log "FAILED to enable $unit — systemctl --user status $unit"
  fi
done

if [ "$found" -eq 0 ]; then
  log "no dotfiles-owned timers found in $UNIT_DIR"
fi
