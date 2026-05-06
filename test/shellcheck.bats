#!/usr/bin/env bats

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

@test "publish.sh passes shellcheck" {
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
