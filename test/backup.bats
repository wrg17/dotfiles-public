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

@test "backup: borg writes no runtime state into the repo" {
  # ~/.config/borg is a stow symlink into this worktree, so a borg run without
  # BORG_BASE_DIR drops per-repo security records here. They are gitignored as
  # a backstop, but their presence means some code path is still missing the
  # variable — usually a new test or a hand-run command.
  for d in security cache keys; do
    [ ! -d "$BACKUP_DIR/.config/borg/$d" ] || {
      echo "borg runtime state leaked into the repo: backup/.config/borg/$d"
      echo "some borg invocation is missing BORG_BASE_DIR"
      return 1
    }
  done
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

# ── Service dumps ─────────────────────────────────────────────────────────────

@test "backup: dump script exists and is executable" {
  [ -x "$BACKUP_DIR/.local/bin/borg-dump-services" ]
  [ -f "$BACKUP_DIR/.config/borg/sqlite-dbs" ]
}

@test "backup: borg-backup runs the dumps itself, not via ExecStartPre" {
  # If dumping were an ExecStartPre on the unit, a hand-run borg-backup would
  # silently produce a different archive from the timer's — a difference you
  # would only discover during a restore.
  grep -q 'borg-dump-services' "$BORG_BACKUP"
  run grep -q 'ExecStartPre' "$UNIT_DIR/borg-backup.service"
  [ "$status" -ne 0 ]
}

@test "backup: dumps land somewhere the archive actually covers" {
  # A dump written to an excluded path is worse than no dump: it looks like
  # protection and is never archived.
  grep -q 'BORG_DUMP_DIR=.*XDG_STATE_HOME' "$BORG_ENV"
  run grep -qxF '.local/state' "$BORG_EXCLUDE"
  [ "$status" -ne 0 ]
}

@test "backup: Postgres is dumped logically, never copied from its volume" {
  d="$BACKUP_DIR/.local/bin/borg-dump-services"
  # pg_dumpall, not pg_dump: without it a restore has no roles or grants.
  grep -q 'pg_dumpall' "$d"
  # The superuser is read from the container; lexic-db has no `postgres` role,
  # so a hardcoded -U postgres fails.
  grep -q 'printenv POSTGRES_USER' "$d"
}

@test "backup: dumps are written atomically" {
  # Overwriting a good dump with a truncated one is how a backup silently
  # stops being restorable.
  d="$BACKUP_DIR/.local/bin/borg-dump-services"
  grep -q 'mv -f "\$tmp" "\$out"' "$d"
  grep -q 'previous dump left intact' "$d"
}

@test "backup: a missing sqlite3 is reported, not silently skipped" {
  # Without sqlite3 the WAL-mode databases are archived as raw files that may
  # restore corrupt, so it has to reach the exit status.
  d="$BACKUP_DIR/.local/bin/borg-dump-services"
  run awk '/sqlite3 not installed/{found=1} found && /failures=\$\(\(failures \+ 1\)\)/{print "yes"; exit}' "$d"
  [ "$output" = "yes" ]
}

@test "backup: apt-pkgs declares sqlite3" {
  grep -qxF 'sqlite3' "$REPO_ROOT/bootstrap/apt-pkgs"
}

# ── Exclude semantics, exercised rather than eyeballed ────────────────────────

@test "backup: exclude patterns include and skip exactly what is intended" {
  command -v borg >/dev/null || skip "borg not installed in this env"

  # borg's pattern styles are subtle: an unprefixed pattern anchors at the
  # archive root, `sh:**/` matches any depth. Reading them wrong is invisible
  # until a restore comes up short — which is how the live Firefox profile was
  # excluded while a stale ~/.mozilla copy was being backed up. So build a tiny
  # tree with the real shapes and assert on borg's own decisions.
  # The service-state paths live under a directory whose name
  # test/private-patterns.local marks private, and this file is published, so
  # read the prefix out of the exclude file rather than spelling it here.
  venv_pat=$(grep -E 'comfyui/venv$' "$BORG_EXCLUDE" | head -1)
  [ -n "$venv_pat" ] || skip "no comfyui/venv exclude to derive the prefix from"
  svc="${venv_pat%/comfyui/venv}"     # -> <private>/state/services

  work=$(mktemp -d)
  h="$work/home"
  mkdir -p \
    "$h/snap/firefox/common/.mozilla/firefox/prof.default/cache2" \
    "$h/snap/firefox/common/.cache" "$h/snap/firefox/6836" "$h/snap/firefox/current" \
    "$h/snap/postman/360" "$h/snap/postman/360/.cache" \
    "$h/$svc/comfyui/models" "$h/$svc/comfyui/venv" "$h/$svc/comfyui/user" \
    "$h/$svc/openwebui/data" \
    "$h/.minecraft/saves" "$h/.local/state/borg-dumps" \
    "$h/.local/share/docker" "$h/.cache" "$h/projects/app/node_modules"
  for f in \
    snap/firefox/common/.mozilla/firefox/prof.default/places.sqlite \
    snap/firefox/common/.mozilla/firefox/prof.default/cache2/junk \
    snap/firefox/common/.cache/junk snap/firefox/6836/prefs.js \
    snap/postman/360/collections.json snap/postman/360/.cache/junk \
    "$svc/comfyui/models/ckpt" "$svc/comfyui/venv/lib" \
    "$svc/comfyui/user/workflow.json" "$svc/openwebui/data/webui.db" \
    .minecraft/saves/world.dat .local/state/borg-dumps/pg.sql.gz \
    .local/share/docker/layer .cache/junk \
    projects/app/node_modules/dep.js projects/app/main.rs
  do echo x > "$h/$f"; done

  # BORG_BASE_DIR is not optional here. ~/.config/borg is a stow symlink into
  # this repo, so without it borg writes a per-repo security record for each
  # throwaway repo straight into the worktree — this test did exactly that, and
  # a pile of records for /tmp repos ended up committed.
  export BORG_BASE_DIR="$work/borg-base"
  mkdir -p "$BORG_BASE_DIR"

  borg init --encryption=none "$work/repo" >/dev/null 2>&1
  listing=$(cd "$h" && borg create --dry-run --list \
    --exclude-from "$BORG_EXCLUDE" "$work/repo::t" . 2>&1 |
    sed 's|^\(.\) \./|\1 |')
  rm -rf "$work"

  _included() { echo "$listing" | grep -qE "^- $1\$" || { echo "NOT included: $1"; return 1; }; }
  _excluded() { echo "$listing" | grep -qE "^x $1\$" || { echo "NOT excluded: $1"; return 1; }; }

  # The live snap Firefox profile — the gap this test exists for. Firefox keeps
  # it in common/.
  _included 'snap/firefox/common/.mozilla/firefox/prof.default/places.sqlite'

  # ...but which half of a snap holds the real data is up to the app. Postman
  # keeps its collections in the numbered revision directory, so those must be
  # archived too. An earlier exclude of `snap/*/[0-9]*` dropped them silently,
  # and would have left `current` pointing at nothing.
  _included 'snap/postman/360/collections.json'
  _included 'snap/firefox/6836/prefs.js'

  # Caches inside a snap are still skipped, at either level.
  _excluded 'snap/firefox/common/.mozilla/firefox/prof.default/cache2'
  _excluded 'snap/firefox/common/.cache'
  _excluded 'snap/postman/360/.cache'

  # Model weights and authored workflows kept; rebuildable venv dropped.
  _included "$svc/comfyui/models/ckpt"
  _included "$svc/comfyui/user/workflow.json"
  _included "$svc/openwebui/data/webui.db"
  _excluded "$svc/comfyui/venv"

  # The dumps must be archived, or dumping them is pointless.
  _included '.local/state/borg-dumps/pg.sql.gz'

  _included '.minecraft/saves/world.dat'
  _included 'projects/app/main.rs'
  _excluded '.cache'
  _excluded '.local/share/docker'
  _excluded 'projects/app/node_modules'
}

@test "backup: service state and snap are not excluded wholesale" {
  # Both were, and both hid irreplaceable data behind a size-based judgement:
  # chat history, authored workflows, and the live snap Firefox profile.
  # The service-state prefix is derived, not named — see the test above.
  venv_pat=$(grep -E 'comfyui/venv$' "$BORG_EXCLUDE" | head -1)
  [ -n "$venv_pat" ] || skip "no comfyui/venv exclude to derive the prefix from"
  state_root="${venv_pat%/services/comfyui/venv}"

  run grep -qxF "$state_root" "$BORG_EXCLUDE"
  [ "$status" -ne 0 ]
  run grep -qxF 'snap' "$BORG_EXCLUDE"
  [ "$status" -ne 0 ]
}

# ── Root-level system snapshot ────────────────────────────────────────────────

@test "backup: system snapshot script and units exist" {
  [ -x "$REPO_ROOT/bootstrap/system/etc-snapshot" ]
  [ -f "$REPO_ROOT/bootstrap/system/etc-snapshot.service" ]
  [ -f "$REPO_ROOT/bootstrap/system/etc-snapshot.timer" ]
  [ -x "$REPO_ROOT/bootstrap/install-system-units.sh" ]
}

@test "backup: etc-snapshot refuses to run unprivileged" {
  run "$REPO_ROOT/bootstrap/system/etc-snapshot"
  [ "$status" -ne 0 ]
  [[ "$output" == *"must run as root"* ]]
}

@test "backup: etc-snapshot does not put password hashes in a user-readable file" {
  # The tarball has to be readable by the backup user, so shadow stays out —
  # a restored machine just needs its password reset.
  snap="$REPO_ROOT/bootstrap/system/etc-snapshot"
  grep -q -- "--exclude='/etc/shadow\*'" "$snap"
  grep -q -- "--exclude='/etc/gshadow\*'" "$snap"
}

@test "backup: etc-snapshot tars uncompressed so borg can dedup it" {
  snap="$REPO_ROOT/bootstrap/system/etc-snapshot"
  grep -qE '^\s+-cf "\$tmp"' "$snap"
  run grep -qE 'tar .*-c?zf' "$snap"
  [ "$status" -ne 0 ]
}

@test "backup: etc-snapshot captures what a rebuild actually needs" {
  snap="$REPO_ROOT/bootstrap/system/etc-snapshot"
  grep -q 'dpkg --get-selections' "$snap"
  grep -q 'apt-mark showmanual' "$snap"
  grep -q 'lsblk' "$snap"
}

@test "backup: system timer runs before the user backup timer" {
  # Otherwise the tarball the user job archives is always a day stale.
  sys=$(grep -oE 'OnCalendar=\*-\*-\* [0-9]{2}:[0-9]{2}' \
        "$REPO_ROOT/bootstrap/system/etc-snapshot.timer" | grep -oE '[0-9]{2}:[0-9]{2}')
  usr=$(grep -oE 'OnCalendar=\*-\*-\* [0-9]{2}:[0-9]{2}' \
        "$UNIT_DIR/borg-backup.timer" | grep -oE '[0-9]{2}:[0-9]{2}')
  [ -n "$sys" ] && [ -n "$usr" ]
  [[ "$sys" < "$usr" ]]
}

@test "backup: system timer is persistent too" {
  grep -q '^Persistent=true' "$REPO_ROOT/bootstrap/system/etc-snapshot.timer"
}

@test "backup: tracked system files name no specific user" {
  # The username is written to /etc/default at install time precisely so the
  # tracked units stay portable.
  run grep -rnE '(BACKUP_USER=[a-z]|/home/[a-z])' \
    "$REPO_ROOT/bootstrap/system/"
  [ -z "$output" ] || { echo "$output"; return 1; }
}

@test "backup: linux.sh installs the system units" {
  grep -q 'install-system-units.sh' "$REPO_ROOT/bootstrap/linux.sh"
}

# ── doctor ────────────────────────────────────────────────────────────────────

@test "backup: doctor measures staleness from the repo, not from systemd" {
  # systemd only knows about runs it started, so a hand-run backup left
  # ExecMainExitTimestamp empty and doctor reported "has not run yet" with a
  # fresh archive on the NAS — and it could not distinguish that from a timer
  # that has silently stopped firing. The newest archive is ground truth.
  doc="$REPO_ROOT/bootstrap/doctor.sh"
  # Strip comments first: the script names ExecMainExitTimestamp in prose
  # explaining why it is the wrong signal.
  run grep -vE '^\s*#' "$doc"
  echo "$output" | grep -q 'ExecMainExitTimestamp' && return 1
  grep -q "borg list --lock-wait 0 --last 1" "$doc"
}

@test "backup: doctor cannot block on a hung mount or a held lock" {
  # It is an advisory check; a stuck NFS mount must not hang it.
  doc="$REPO_ROOT/bootstrap/doctor.sh"
  grep -q 'timeout 20 borg list' "$doc"
  grep -q -- '--lock-wait 0' "$doc"
}

# ── apt ───────────────────────────────────────────────────────────────────────

@test "backup: apt-pkgs declares borgbackup" {
  run grep -qxF 'borgbackup' "$REPO_ROOT/bootstrap/apt-pkgs"
  [ "$status" -eq 0 ]
}

@test "backup: dumps are verified complete, not merely non-empty" {
  # A dump cut short by a full disk or a container killed mid-write leaves a
  # plausible-looking file that `[ -s ]` waves through. Each kind gets a real
  # integrity check before it replaces the previous good copy.
  d="$BACKUP_DIR/.local/bin/borg-dump-services"
  grep -q 'PostgreSQL database cluster dump complete' "$d"   # pg_dumpall marker
  grep -q 'tar tf "\$tmp"' "$d"                              # tar index reads back
  grep -q "pragma integrity_check" "$d"                      # sqlite opens
}

@test "backup: every listed sqlite database actually exists" {
  # A wrong path is not an error at runtime — the script logs "not present,
  # skipping" and moves on — so a typo means a database silently goes
  # unprotected. One of the original five was guessed wrong this way.
  #
  # Fails only when SOME listed databases exist and others do not. On a fresh
  # machine none of these services are deployed yet, so absence across the
  # board is expected and skips; a partial match means the services are here
  # and a path is wrong.
  [ -r "$BACKUP_DIR/.config/borg/sqlite-dbs" ] || skip "no sqlite list"
  present=0 missing=""
  while IFS= read -r rel; do
    case "$rel" in ''|'#'*) continue ;; esac
    if [ -f "$HOME/$rel" ]; then
      present=$((present + 1))
    else
      missing="$missing $rel"
    fi
  done < "$BACKUP_DIR/.config/borg/sqlite-dbs"

  [ "$present" -gt 0 ] || skip "none of the listed services are deployed here"
  [ -z "$missing" ] || {
    echo "$present listed databases exist, but these paths are wrong:$missing"
    return 1
  }
}

@test "backup: mount guard distinguishes real NFS from an autofs placeholder" {
  # With x-systemd.automount the mountpoint check passes before any NFS traffic
  # has happened, so on its own it would wave through an unreachable NAS. The
  # directory read forces the automount to trigger and findmnt confirms NFS
  # actually landed — otherwise the failure surfaces one check later as
  # "no borg repo", sending you after a missing repo instead of the network.
  grep -q 'findmnt -t nfs,nfs4' "$BORG_BACKUP"
  grep -q 'automount failed to trigger' "$BORG_BACKUP"
  # The order matters: trigger before asserting the filesystem type.
  trigger=$(grep -n 'ls "\$BORG_MOUNT"' "$BORG_BACKUP" | cut -d: -f1)
  confirm=$(grep -n 'findmnt -t nfs,nfs4' "$BORG_BACKUP" | cut -d: -f1)
  repo=$(grep -n 'BORG_REPO/config' "$BORG_BACKUP" | head -1 | cut -d: -f1)
  [ "$trigger" -lt "$confirm" ]
  [ "$confirm" -lt "$repo" ]
}
