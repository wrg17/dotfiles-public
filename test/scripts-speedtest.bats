#!/usr/bin/env bats

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
BIN="$REPO_ROOT/zsh/.local/bin"

@test "speedtest: script exists and is executable" {
  [ -x "$BIN/speedtest" ]
}

@test "speedtest: handles macOS (networkQuality)" {
  grep -q 'networkQuality' "$BIN/speedtest"
}

@test "speedtest: handles Linux (speedtest-cli)" {
  grep -q 'speedtest-cli' "$BIN/speedtest"
}

@test "speedtest: error message shown when tool not found" {
  grep -q 'Install' "$BIN/speedtest"
}
