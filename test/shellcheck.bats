#!/usr/bin/env bats

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

@test "publish.sh passes shellcheck" {
  # publish.sh is not synced to the public repo, so only run in the private source repo
  skip "publish.sh is a private dev tool — not published"
  run shellcheck "$REPO_ROOT/publish.sh"
  [ "$status" -eq 0 ]
}

@test "bootstrap/linux.sh passes shellcheck" {
  run shellcheck "$REPO_ROOT/bootstrap/linux.sh"
  [ "$status" -eq 0 ]
}

@test "bootstrap/link-jetbrains.sh passes shellcheck" {
  run shellcheck "$REPO_ROOT/bootstrap/link-jetbrains.sh"
  [ "$status" -eq 0 ]
}
