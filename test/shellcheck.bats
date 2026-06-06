#!/usr/bin/env bats

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

@test "publish.sh passes shellcheck" {
  # publish.sh is not synced to the public repo, so only run in the private source repo
  skip "publish.sh is a private dev tool — not published"
  run shellcheck "$REPO_ROOT/publish.sh"
  [ "$status" -eq 0 ]
}

@test "bootstrap/macos.sh passes shellcheck" {
  run shellcheck "$REPO_ROOT/bootstrap/macos.sh"
  [ "$status" -eq 0 ]
}

@test "bootstrap/linux.sh passes shellcheck" {
  run shellcheck "$REPO_ROOT/bootstrap/linux.sh"
  [ "$status" -eq 0 ]
}

@test "bootstrap/install-tools.sh passes shellcheck" {
  run shellcheck "$REPO_ROOT/bootstrap/install-tools.sh"
  [ "$status" -eq 0 ]
}

@test "bootstrap/link-jetbrains.sh passes shellcheck" {
  run shellcheck "$REPO_ROOT/bootstrap/link-jetbrains.sh"
  [ "$status" -eq 0 ]
}

@test "bootstrap/doctor.sh passes shellcheck" {
  run shellcheck "$REPO_ROOT/bootstrap/doctor.sh"
  [ "$status" -eq 0 ]
}

@test "zsh/.local/bin/speedtest passes shellcheck" {
  run shellcheck "$REPO_ROOT/zsh/.local/bin/speedtest"
  [ "$status" -eq 0 ]
}

@test "zsh/.local/bin/epoch passes shellcheck" {
  run shellcheck "$REPO_ROOT/zsh/.local/bin/epoch"
  [ "$status" -eq 0 ]
}

@test "zsh/.local/bin/fuzzy passes shellcheck" {
  run shellcheck "$REPO_ROOT/zsh/.local/bin/fuzzy"
  [ "$status" -eq 0 ]
}
