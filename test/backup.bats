#!/usr/bin/env bats

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
BACKUP_DIR="$REPO_ROOT/backup"
BORG_BACKUP="$BACKUP_DIR/.local/bin/borg-backup"
BORG_INIT="$BACKUP_DIR/.local/bin/borg-init"
BORG_ENV="$BACKUP_DIR/.config/borg/env"
BORG_EXCLUDE="$BACKUP_DIR/.config/borg/exclude"
UNIT_DIR="$BACKUP_DIR/.config/systemd/user"
INSTALL_UNITS="$REPO_ROOT/bootstrap/install-units.sh"

# The backup package is Linux-only and is not published, so every test that
# reads it skips when the directory is absent (i.e. in the public repo).
setup() {
  [ -d "$BACKUP_DIR" ] || skip "backup/ is a private-source package; covered by the private repo"
}

# ── Package layout ────────────────────────────────────────────────────────────

@test "backup: scripts are executable" {
  [ -x "$BORG_BACKUP" ]
  [ -x "$BORG_INIT" ]
}

@test "backup: every file in the package is tracked by git" {
  # The .gitignore `*.local` pattern matches the XDG .local directory inside a
  # stow package, so borg-backup and borg-init were ignored on first commit:
  # `git add backup` skipped them silently, the worktree kept working because
  # stow had already linked them, and the gap only showed up as a CI failure on
  # a fresh clone. Assert the package is whole from git's point of view, not
  # the filesystem's.
  run git -C "$REPO_ROOT" ls-files --others --ignored --exclude-standard -- backup/
  [ "$status" -eq 0 ]
  [ -z "$output" ] || {
    echo "ignored-but-present files in backup/:"
    echo "$output"
    return 1
  }
}

@test "backup: the executables specifically are tracked" {
  for f in backup/.local/bin/borg-backup backup/.local/bin/borg-init; do
    git -C "$REPO_ROOT" ls-files --error-unmatch "$f" >/dev/null 2>&1 || {
      echo "not tracked: $f"
      return 1
    }
  done
}

@test "backup: config files exist" {
  [ -f "$BORG_ENV" ]
  [ -f "$BORG_EXCLUDE" ]
}

@test "backup: systemd timer and service both exist" {
  [ -f "$UNIT_DIR/borg-backup.timer" ]
  [ -f "$UNIT_DIR/borg-backup.service" ]
}

# ── Safety guards ─────────────────────────────────────────────────────────────
#
# These are the assertions worth having. Each one covers a failure that silently
# produces either no backup or a backup written to the wrong disk.

@test "backup: borg-backup refuses to run unless the NAS is a live mountpoint" {
  # Without this check, an unmounted /mnt/nas is just an empty directory on /,
  # and the backup fills the root filesystem instead.
  run grep -q 'mountpoint -q "\$BORG_MOUNT"' "$BORG_BACKUP"
  [ "$status" -eq 0 ]
}

@test "backup: borg-backup never creates a repo" {
  # Auto-init is the failure mode that turns a dropped mount into a brand new
  # empty repo that looks like a successful backup. Only borg-init may init.
  # Strip comments before matching: the script discusses `borg init` in prose
  # explaining why it must not call it.
  run grep -vE '^\s*#' "$BORG_BACKUP"
  echo "$output" | grep -q 'borg init' && return 1
  true
}

@test "backup: borg-backup verifies the repo exists before writing" {
  run grep -q 'BORG_REPO/config' "$BORG_BACKUP"
  [ "$status" -eq 0 ]
}

@test "backup: prune is scoped to this host's archives" {
  # An unscoped prune in a repo shared by two machines deletes the other
  # machine's archives.
  run grep -q "glob-archives '{hostname}-\*'" "$BORG_BACKUP"
  [ "$status" -eq 0 ]
}

@test "backup: prune only runs after a successful create" {
  # borg create failing must not prune away the last good archive.
  create_line=$(grep -n '^borg create' "$BORG_BACKUP" | cut -d: -f1)
  guard_line=$(grep -n 'skipping prune' "$BORG_BACKUP" | cut -d: -f1)
  prune_line=$(grep -n '^borg prune' "$BORG_BACKUP" | cut -d: -f1)
  [ -n "$create_line" ] && [ -n "$guard_line" ] && [ -n "$prune_line" ]
  [ "$create_line" -lt "$guard_line" ]
  [ "$guard_line" -lt "$prune_line" ]
}

@test "backup: unattended runs cannot block on a borg prompt" {
  run grep -q 'BORG_RELOCATED_REPO_ACCESS_IS_OK=no' "$BORG_BACKUP"
  [ "$status" -eq 0 ]
}

@test "backup: concurrent runs are locked out" {
  run grep -q 'flock -n 9' "$BORG_BACKUP"
  [ "$status" -eq 0 ]
}

# ── Secrets ───────────────────────────────────────────────────────────────────

@test "backup: passphrase is configured outside the stowed repo tree" {
  # ~/.config/borg is a stow symlink INTO this repo, so a passphrase placed
  # there would be a plaintext secret inside a git worktree.
  run grep -q 'BORG_PASSPHRASE_FILE="\${BORG_PASSPHRASE_FILE:-\${XDG_STATE_HOME' "$BORG_ENV"
  [ "$status" -eq 0 ]
  run grep -q 'XDG_CONFIG_HOME.*borg/passphrase' "$BORG_ENV"
  [ "$status" -ne 0 ]
}

@test "backup: no passphrase file is tracked" {
  run git -C "$REPO_ROOT" ls-files --error-unmatch backup/.config/borg/passphrase
  [ "$status" -ne 0 ]
}

@test "backup: a passphrase under a borg config dir is gitignored" {
  run git -C "$REPO_ROOT" check-ignore -q backup/.config/borg/passphrase
  [ "$status" -eq 0 ]
}

@test "backup: borg-init creates the passphrase without a world-readable window" {
  # `openssl rand > file && chmod 600` leaves the secret readable for an
  # instant; the umask subshell closes that window.
  run grep -q 'umask 077' "$BORG_INIT"
  [ "$status" -eq 0 ]
}

# ── No user-specific paths ────────────────────────────────────────────────────

@test "backup: no hardcoded home directory anywhere in the package" {
  run grep -rn '/home/[a-z]' "$BACKUP_DIR"
  [ "$status" -ne 0 ]
}

@test "backup: exclude patterns are relative, not absolute" {
  # borg-backup cds into $HOME and archives '.', which is what lets this file
  # contain no username. An absolute pattern here would silently match nothing.
  run grep -E '^\s*/' "$BORG_EXCLUDE"
  [ "$status" -ne 0 ]
}

@test "backup: the big regenerable trees are excluded" {
  # Only the publishable patterns are named here. This file is synced to the
  # public repo, and the largest excluded tree is under a directory whose name
  # test/private-patterns.local marks as private — spelling it out would make
  # the privacy guard in test/publish.bats fail, which is how this comment
  # came to exist. The count assertion below is what keeps the rest honest.
  for pattern in .cache .local/share/docker .local/share/JetBrains .local/share/pyenv; do
    grep -qxF "$pattern" "$BORG_EXCLUDE" || {
      echo "missing exclude: $pattern"
      return 1
    }
  done
}

@test "backup: exclude file has not been gutted" {
  # Guards against the whole list being emptied or replaced by a stub, which
  # would turn a 30-60G nightly run into a 900G one without failing anything.
  count=$(grep -cvE '^\s*(#|$)' "$BORG_EXCLUDE")
  [ "$count" -ge 25 ]
}

# ── systemd units ─────────────────────────────────────────────────────────────

@test "backup: timer is persistent so missed runs still happen" {
  # The whole reason for choosing a timer over cron.
  run grep -q '^Persistent=true' "$UNIT_DIR/borg-backup.timer"
  [ "$status" -eq 0 ]
}

@test "backup: timer is installed into timers.target" {
  run grep -q '^WantedBy=timers.target' "$UNIT_DIR/borg-backup.timer"
  [ "$status" -eq 0 ]
}

@test "backup: service start timeout exceeds the default 90s" {
  # A oneshot service inherits DefaultTimeoutStartSec=90s, which would SIGTERM
  # the first full backup partway through.
  run grep -qE '^TimeoutStartSec=(6h|infinity)' "$UNIT_DIR/borg-backup.service"
  [ "$status" -eq 0 ]
}

@test "backup: service uses %h rather than a literal home path" {
  run grep -q '^ExecStart=%h/.local/bin/borg-backup' "$UNIT_DIR/borg-backup.service"
  [ "$status" -eq 0 ]
}

@test "backup: units parse cleanly under systemd-analyze" {
  command -v systemd-analyze >/dev/null || skip "systemd-analyze not available"
  run systemd-analyze --user verify "$UNIT_DIR/borg-backup.timer"
  # verify resolves Requires=/After= against units that do not exist in a bare
  # check, so only treat parse-level complaints about our own files as failures.
  [ "$status" -eq 0 ] || ! echo "$output" | grep -qi "borg-backup.*\(syntax\|unknown key\|invalid\)"
}

# ── install-units.sh ──────────────────────────────────────────────────────────

@test "backup: install-units.sh is executable and passes shellcheck" {
  [ -x "$INSTALL_UNITS" ]
  command -v shellcheck >/dev/null || skip "shellcheck not installed in this env"
  run shellcheck "$INSTALL_UNITS"
  [ "$status" -eq 0 ]
}

@test "backup: install-units.sh no-ops without a systemd user bus" {
  # It is called unconditionally from the Makefile, including on macOS and in
  # the CI container, so it must exit 0 when there is nothing to talk to.
  run env -u DBUS_SESSION_BUS_ADDRESS XDG_RUNTIME_DIR=/nonexistent \
    PATH=/usr/bin:/bin "$INSTALL_UNITS"
  [ "$status" -eq 0 ]
}

@test "backup: install-units.sh only manages units stowed from the repo" {
  # A hand-written unit in ~/.config/systemd/user must be left alone.
  run grep -q 'not stowed from' "$INSTALL_UNITS"
  [ "$status" -eq 0 ]
}

@test "backup: Makefile runs install-units.sh after stow, not before" {
  # The units point at ~/.local/bin scripts that do not exist until stow has run.
  stow_line=$(grep -n '^	stow \$\$(ls -d \*/ | grep -Ev .\^(bootstrap|test|macos)' "$REPO_ROOT/Makefile" | cut -d: -f1)
  units_line=$(grep -n '^	./bootstrap/install-units.sh' "$REPO_ROOT/Makefile" | head -1 | cut -d: -f1)
  [ -n "$stow_line" ] && [ -n "$units_line" ]
  [ "$stow_line" -lt "$units_line" ]
}

@test "backup: linux.sh does not call install-units.sh" {
  # It runs before stow, so calling it there would find no units.
  run grep -q '^"\$(dirname "\$0")/install-units.sh"' "$REPO_ROOT/bootstrap/linux.sh"
  [ "$status" -ne 0 ]
}

# ── apt ───────────────────────────────────────────────────────────────────────

@test "backup: apt-pkgs declares borgbackup" {
  run grep -qxF 'borgbackup' "$REPO_ROOT/bootstrap/apt-pkgs"
  [ "$status" -eq 0 ]
}
