#!/usr/bin/env bash
# bootstrap/install-system-units.sh
# Install the root-level pieces of the backup: the /etc snapshot script and its
# systemd system timer.
#
# Separate from install-units.sh because these need root and live outside
# $HOME, so they cannot be stowed. Everything that can be a user unit is one —
# this exists only for the handful of files no unprivileged job can read, which
# in practice means /etc/netplan and the NetworkManager connections holding
# WiFi credentials.
#
# Needs sudo. Idempotent; safe to re-run.

set -euo pipefail

SRC_DIR="$(cd "$(dirname "$0")/system" && pwd)"
SBIN=/usr/local/sbin
UNIT_DIR=/etc/systemd/system
CONF=/etc/default/etc-snapshot

log() { printf '==> %s\n' "$*"; }

if [ "$(uname -s)" != Linux ]; then
  log "not Linux — nothing to install"
  exit 0
fi

if ! command -v systemctl >/dev/null 2>&1; then
  log "systemctl not found — skipping system units"
  exit 0
fi

# The script writes into this user's dump directory, so record who that is at
# install time. Deriving it here keeps the username out of the tracked unit
# files, which must stay portable between machines.
TARGET_USER="${SUDO_USER:-$USER}"
if [ "$TARGET_USER" = root ]; then
  echo "Error: run this as your normal user (via sudo), not as root directly," >&2
  echo "       otherwise the snapshot would be written to root's home." >&2
  exit 1
fi

log "installing etc-snapshot for user $TARGET_USER"

# Create the target directory rather than assuming it. A minimal Ubuntu install
# ships neither /usr/local/sbin nor /usr/local/bin — both are on root's PATH via
# ENV_SUPATH in /etc/login.defs, but the directories themselves are absent until
# something makes them, and `install` does not create a missing parent.
sudo install -d -m 0755 "$SBIN"
sudo install -m 0755 "$SRC_DIR/etc-snapshot" "$SBIN/etc-snapshot"

# Not tracked in the repo: it names a specific user, which tracked files must
# not do. Written here so the unit stays machine-independent.
printf '# Written by bootstrap/install-system-units.sh — not tracked in the repo.\nBACKUP_USER=%s\n' \
  "$TARGET_USER" | sudo tee "$CONF" >/dev/null
sudo chmod 0644 "$CONF"

sudo install -d -m 0755 "$UNIT_DIR"
sudo install -m 0644 "$SRC_DIR/etc-snapshot.service" "$UNIT_DIR/etc-snapshot.service"
sudo install -m 0644 "$SRC_DIR/etc-snapshot.timer"   "$UNIT_DIR/etc-snapshot.timer"

sudo systemctl daemon-reload
sudo systemctl enable --now etc-snapshot.timer

log "running it once now, so the first user backup has something to archive"
if sudo systemctl start etc-snapshot.service; then
  sudo systemctl status etc-snapshot.service --no-pager -n 12 2>/dev/null | sed 's/^/    /' || true
else
  echo "    WARN: first run failed — journalctl -u etc-snapshot -n 50" >&2
fi

log "done"
echo
echo "    timer:  systemctl list-timers etc-snapshot.timer"
echo "    logs:   journalctl -u etc-snapshot -n 50"
