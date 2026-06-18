#!/usr/bin/env bats

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
BIN="$REPO_ROOT/zsh/.local/bin"

# Build a fake HOME with Caches, Logs, JetBrains dirs and PATH shims.
# Usage: _dc_setup <var> <mdfind_body>
#   mdfind_body is shell code for the fake mdfind.
#   A du shim (returns "4.0K\t<path>") is always installed.
_dc_setup() {
  local _var="$1" _mdfind_body="$2" _d
  _d=$(mktemp -d)
  mkdir -p "$_d/Library/Caches" "$_d/Library/Logs" \
           "$_d/Library/Application Support/JetBrains" "$_d/bin"
  printf '#!/bin/sh\n%s\n' "$_mdfind_body" > "$_d/bin/mdfind"
  printf '#!/bin/sh\nprintf "4.0K\\t%s\\n" "${2:-}"\n' > "$_d/bin/du"
  chmod +x "$_d/bin/mdfind" "$_d/bin/du"
  printf -v "$_var" '%s' "$_d"
}

@test "disk-cleanup: script exists and is executable" {
  [ -x "$BIN/disk-cleanup" ]
}

@test "disk-cleanup: exits with error on non-macOS" {
  run env OSTYPE=linux-gnu bash "$BIN/disk-cleanup"
  [ "$status" -ne 0 ]
  [[ "$output" == *"macOS only"* ]]
}

@test "disk-cleanup: reports orphaned bundle-ID cache dirs" {
  _dc_setup td 'exit 0'
  mkdir -p "$td/Library/Caches/com.orphaned.app"
  run env OSTYPE=darwin23 HOME="$td" PATH="$td/bin:$PATH" bash "$BIN/disk-cleanup" --dry-run
  rm -rf "$td"
  [ "$status" -eq 0 ]
  [[ "$output" == *"com.orphaned.app"* ]]
}

@test "disk-cleanup: skips bundle ID whose app is installed" {
  _dc_setup td 'echo "/Applications/Installed.app"'
  mkdir -p "$td/Library/Caches/com.installed.app"
  run env OSTYPE=darwin23 HOME="$td" PATH="$td/bin:$PATH" bash "$BIN/disk-cleanup" --dry-run
  rm -rf "$td"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Nothing to clean up"* ]]
}

@test "disk-cleanup: skips com.apple.* system caches" {
  _dc_setup td 'exit 0'
  mkdir -p "$td/Library/Caches/com.apple.Safari"
  run env OSTYPE=darwin23 HOME="$td" PATH="$td/bin:$PATH" bash "$BIN/disk-cleanup" --dry-run
  rm -rf "$td"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Nothing to clean up"* ]]
}

@test "disk-cleanup: skips non-bundle-ID named dirs" {
  _dc_setup td 'exit 0'
  mkdir -p "$td/Library/Caches/JetBrains" "$td/Library/Caches/Homebrew"
  run env OSTYPE=darwin23 HOME="$td" PATH="$td/bin:$PATH" bash "$BIN/disk-cleanup" --dry-run
  rm -rf "$td"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Nothing to clean up"* ]]
}

@test "disk-cleanup: reports orphaned log dirs" {
  _dc_setup td 'exit 0'
  mkdir -p "$td/Library/Logs/com.orphaned.logger"
  run env OSTYPE=darwin23 HOME="$td" PATH="$td/bin:$PATH" bash "$BIN/disk-cleanup" --dry-run
  rm -rf "$td"
  [ "$status" -eq 0 ]
  [[ "$output" == *"com.orphaned.logger"* ]]
}

@test "disk-cleanup: flags old JetBrains IDE version dirs" {
  _dc_setup td 'exit 0'
  mkdir -p "$td/Library/Application Support/JetBrains/CLion2025.2"
  mkdir -p "$td/Library/Application Support/JetBrains/CLion2026.1"
  run env OSTYPE=darwin23 HOME="$td" PATH="$td/bin:$PATH" bash "$BIN/disk-cleanup" --dry-run
  rm -rf "$td"
  [ "$status" -eq 0 ]
  [[ "$output" == *"CLion2025.2"* ]]
  [[ "$output" != *"CLion2026.1"* ]]
}

@test "disk-cleanup: does not flag the sole JetBrains version" {
  _dc_setup td 'exit 0'
  mkdir -p "$td/Library/Application Support/JetBrains/CLion2026.1"
  run env OSTYPE=darwin23 HOME="$td" PATH="$td/bin:$PATH" bash "$BIN/disk-cleanup" --dry-run
  rm -rf "$td"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Nothing to clean up"* ]]
}

@test "disk-cleanup: flags JetBrains backup dirs" {
  _dc_setup td 'exit 0'
  mkdir -p "$td/Library/Application Support/JetBrains/CLion2026.1"
  mkdir -p "$td/Library/Application Support/JetBrains/CLion2025.2-backup"
  run env OSTYPE=darwin23 HOME="$td" PATH="$td/bin:$PATH" bash "$BIN/disk-cleanup" --dry-run
  rm -rf "$td"
  [ "$status" -eq 0 ]
  [[ "$output" == *"CLion2025.2-backup"* ]]
  [[ "$output" != *"CLion2026.1"* ]]
}

@test "disk-cleanup: dry run does not delete orphaned dirs" {
  _dc_setup td 'exit 0'
  mkdir -p "$td/Library/Caches/com.orphaned.app"
  run env OSTYPE=darwin23 HOME="$td" PATH="$td/bin:$PATH" bash "$BIN/disk-cleanup" --dry-run
  local still_exists=0
  [ -d "$td/Library/Caches/com.orphaned.app" ] && still_exists=1
  rm -rf "$td"
  [ "$status" -eq 0 ]
  [ "$still_exists" -eq 1 ]
}
