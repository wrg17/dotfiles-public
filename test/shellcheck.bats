#!/usr/bin/env bats

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

# Assert a file is clean AND print shellcheck's diagnosis when it is not.
#
# Every test here used to be a bare `[ "$status" -eq 0 ]`, which told you a
# file failed but not why — and because the CI runner's shellcheck is older
# than a typical dev machine's (0.9.0 on noble vs 0.11.0 locally), the checks
# they disagree on are exactly the ones you can only see in the CI log. One of
# those cost a round trip through CI to identify, so print the output.
_shellcheck() {
  local target="$1"
  run shellcheck "$target"
  if [ "$status" -ne 0 ]; then
    echo "shellcheck $(shellcheck --version | awk '/^version:/{print $2}') on ${target#"$REPO_ROOT"/}:"
    echo "$output"
    return 1
  fi
}

@test "publish.sh passes shellcheck" {
  # publish.sh is not synced to the public repo, so only run in the private source repo
  skip "publish.sh is a private dev tool — not published"
  _shellcheck "$REPO_ROOT/publish.sh"
}

@test "bootstrap/macos.sh passes shellcheck" {
  _shellcheck "$REPO_ROOT/bootstrap/macos.sh"
}

@test "bootstrap/linux.sh passes shellcheck" {
  _shellcheck "$REPO_ROOT/bootstrap/linux.sh"
}

@test "bootstrap/install-tools.sh passes shellcheck" {
  _shellcheck "$REPO_ROOT/bootstrap/install-tools.sh"
}

@test "bootstrap/install-langs.sh passes shellcheck" {
  run shellcheck "$REPO_ROOT/bootstrap/install-langs.sh"
  [ "$status" -eq 0 ]
}

@test "bootstrap/kde-settings.sh passes shellcheck" {
  run shellcheck "$REPO_ROOT/bootstrap/kde-settings.sh"
  [ "$status" -eq 0 ]
}

@test "bootstrap/link-jetbrains.sh passes shellcheck" {
  _shellcheck "$REPO_ROOT/bootstrap/link-jetbrains.sh"
}

@test "bootstrap/brew-bottles.sh passes shellcheck" {
  run shellcheck "$REPO_ROOT/bootstrap/brew-bottles.sh"
  [ "$status" -eq 0 ]
}

@test "bootstrap/doctor.sh passes shellcheck" {
  _shellcheck "$REPO_ROOT/bootstrap/doctor.sh"
}

@test "bootstrap/install-units.sh passes shellcheck" {
  _shellcheck "$REPO_ROOT/bootstrap/install-units.sh"
}

@test "backup/.local/bin/borg-backup passes shellcheck" {
  [ -f "$REPO_ROOT/backup/.local/bin/borg-backup" ] || skip "backup/ is a private-source package"
  _shellcheck "$REPO_ROOT/backup/.local/bin/borg-backup"
}

@test "backup/.local/bin/borg-init passes shellcheck" {
  [ -f "$REPO_ROOT/backup/.local/bin/borg-init" ] || skip "backup/ is a private-source package"
  _shellcheck "$REPO_ROOT/backup/.local/bin/borg-init"
}

@test "backup/.config/borg/env passes shellcheck" {
  [ -f "$REPO_ROOT/backup/.config/borg/env" ] || skip "backup/ is a private-source package"
  _shellcheck "$REPO_ROOT/backup/.config/borg/env"
}

@test "zsh/.local/bin/speedtest passes shellcheck" {
  _shellcheck "$REPO_ROOT/zsh/.local/bin/speedtest"
}

@test "zsh/.local/bin/epoch passes shellcheck" {
  _shellcheck "$REPO_ROOT/zsh/.local/bin/epoch"
}

@test "zsh/.local/bin/fuzzy passes shellcheck" {
  _shellcheck "$REPO_ROOT/zsh/.local/bin/fuzzy"
}

@test "backup/.local/bin/borg-dump-services passes shellcheck" {
  [ -f "$REPO_ROOT/backup/.local/bin/borg-dump-services" ] || skip "backup/ is a private-source package"
  _shellcheck "$REPO_ROOT/backup/.local/bin/borg-dump-services"
}

@test "bootstrap/install-system-units.sh passes shellcheck" {
  _shellcheck "$REPO_ROOT/bootstrap/install-system-units.sh"
}

@test "bootstrap/system/etc-snapshot passes shellcheck" {
  _shellcheck "$REPO_ROOT/bootstrap/system/etc-snapshot"
}

@test "shellcheck: every bootstrap script is covered by a test above" {
  # The list above is hand-maintained, so a new script defaults to unlinted —
  # install-langs.sh and kde-settings.sh both shipped that way. Fail when a
  # script exists with no test naming it.
  local script missing=()
  for script in "$REPO_ROOT"/bootstrap/*.sh; do
    grep -qF "bootstrap/$(basename "$script")" "$BATS_TEST_FILENAME" \
      || missing+=("$(basename "$script")")
  done
  [ "${#missing[@]}" -eq 0 ] || {
    echo "no shellcheck test for: ${missing[*]}"
    return 1
  }
}
