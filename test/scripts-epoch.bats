#!/usr/bin/env bats

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
BIN="$REPO_ROOT/zsh/.local/bin"

@test "epoch: script exists and is executable" {
  [ -x "$BIN/epoch" ]
}

@test "epoch: no args prints current unix timestamp" {
  run bash "$BIN/epoch"
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^[0-9]{10}$ ]]
}

@test "epoch: converts epoch to human-readable date" {
  run bash "$BIN/epoch" 1000000000
  [ "$status" -eq 0 ]
  [[ "$output" =~ 2001 ]]
}

@test "epoch: millisecond input is truncated to seconds" {
  run bash "$BIN/epoch" 1000000000000
  [ "$status" -eq 0 ]
  [[ "$output" =~ "milliseconds truncated" ]]
  [[ "$output" =~ 2001 ]]
}

@test "epoch: date string to epoch returns digits" {
  run bash "$BIN/epoch" "2024-01-15"
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^[0-9]+$ ]]
}

@test "epoch: unix epoch zero converts to 1970 (UTC)" {
  run env TZ=UTC bash "$BIN/epoch" 0
  [ "$status" -eq 0 ]
  [[ "$output" =~ 1970 ]]
}

@test "epoch: handles cross-platform date (darwin vs linux)" {
  grep -q 'darwin' "$BIN/epoch"
}
