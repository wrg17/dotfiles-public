#!/usr/bin/env bats

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
BIN="$REPO_ROOT/zsh/.local/bin"

# ── speedtest ──────────────────────────────────────────────────────────────

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

# ── epoch ──────────────────────────────────────────────────────────────────

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

# ── fuzzy ──────────────────────────────────────────────────────────────────

@test "fuzzy: script exists and is executable" {
  [ -x "$BIN/fuzzy" ]
}

@test "fuzzy: returns matching items from colon-delimited list" {
  run bash "$BIN/fuzzy" git "github:gitignore:grep:gzip"
  [ "$status" -eq 0 ]
  [[ "$output" == *"github"* ]]
  [[ "$output" == *"gitignore"* ]]
}

@test "fuzzy: does not return non-matching items" {
  run bash "$BIN/fuzzy" git "github:gitignore:grep:gzip"
  [ "$status" -eq 0 ]
  [[ "$output" != *"grep"* ]]
  [[ "$output" != *"gzip"* ]]
}

@test "fuzzy: ranks earlier/consecutive match above later match" {
  run bash "$BIN/fuzzy" git "agit:git"
  [ "$status" -eq 0 ]
  first=$(printf '%s\n' "$output" | head -1)
  [ "$first" = "git" ]
}

@test "fuzzy: ranks match at start of string higher than mid-string" {
  run bash "$BIN/fuzzy" hub "github:hubspot"
  [ "$status" -eq 0 ]
  first=$(printf '%s\n' "$output" | head -1)
  [ "$first" = "hubspot" ]
}

@test "fuzzy: custom delimiter via -d flag" {
  run bash "$BIN/fuzzy" -d, hub "github,gitlab,bitbucket"
  [ "$status" -eq 0 ]
  [ "$output" = "github" ]
}

@test "fuzzy: reads items from stdin when no list arg given" {
  run bash -c "printf 'github\ngitlab\ngrep\n' | bash '$BIN/fuzzy' git"
  [ "$status" -eq 0 ]
  [[ "$output" == *"github"* ]]
  [[ "$output" == *"gitlab"* ]]
  [[ "$output" != *"grep"* ]]
}

@test "fuzzy: no matches produces empty output with exit 0" {
  run bash "$BIN/fuzzy" zzz "github:gitlab"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "fuzzy: missing needle argument exits with error" {
  run bash "$BIN/fuzzy"
  [ "$status" -ne 0 ]
}

@test "fuzzy: empty needle argument exits with error" {
  run bash "$BIN/fuzzy" "" "github:gitlab"
  [ "$status" -ne 0 ]
}

@test "fuzzy: match is case-insensitive" {
  run bash "$BIN/fuzzy" GIT "github:gitignore:grep"
  [ "$status" -eq 0 ]
  [[ "$output" == *"github"* ]]
}

# ── disk-cleanup ───────────────────────────────────────────────────────────────

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
  run env HOME="$td" PATH="$td/bin:$PATH" bash "$BIN/disk-cleanup" --dry-run
  rm -rf "$td"
  [ "$status" -eq 0 ]
  [[ "$output" == *"com.orphaned.app"* ]]
}

@test "disk-cleanup: skips bundle ID whose app is installed" {
  _dc_setup td 'echo "/Applications/Installed.app"'
  mkdir -p "$td/Library/Caches/com.installed.app"
  run env HOME="$td" PATH="$td/bin:$PATH" bash "$BIN/disk-cleanup" --dry-run
  rm -rf "$td"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Nothing to clean up"* ]]
}

@test "disk-cleanup: skips com.apple.* system caches" {
  _dc_setup td 'exit 0'
  mkdir -p "$td/Library/Caches/com.apple.Safari"
  run env HOME="$td" PATH="$td/bin:$PATH" bash "$BIN/disk-cleanup" --dry-run
  rm -rf "$td"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Nothing to clean up"* ]]
}

@test "disk-cleanup: skips non-bundle-ID named dirs" {
  _dc_setup td 'exit 0'
  mkdir -p "$td/Library/Caches/JetBrains" "$td/Library/Caches/Homebrew"
  run env HOME="$td" PATH="$td/bin:$PATH" bash "$BIN/disk-cleanup" --dry-run
  rm -rf "$td"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Nothing to clean up"* ]]
}

@test "disk-cleanup: reports orphaned log dirs" {
  _dc_setup td 'exit 0'
  mkdir -p "$td/Library/Logs/com.orphaned.logger"
  run env HOME="$td" PATH="$td/bin:$PATH" bash "$BIN/disk-cleanup" --dry-run
  rm -rf "$td"
  [ "$status" -eq 0 ]
  [[ "$output" == *"com.orphaned.logger"* ]]
}

@test "disk-cleanup: flags old JetBrains IDE version dirs" {
  _dc_setup td 'exit 0'
  mkdir -p "$td/Library/Application Support/JetBrains/CLion2025.2"
  mkdir -p "$td/Library/Application Support/JetBrains/CLion2026.1"
  run env HOME="$td" PATH="$td/bin:$PATH" bash "$BIN/disk-cleanup" --dry-run
  rm -rf "$td"
  [ "$status" -eq 0 ]
  [[ "$output" == *"CLion2025.2"* ]]
  [[ "$output" != *"CLion2026.1"* ]]
}

@test "disk-cleanup: does not flag the sole JetBrains version" {
  _dc_setup td 'exit 0'
  mkdir -p "$td/Library/Application Support/JetBrains/CLion2026.1"
  run env HOME="$td" PATH="$td/bin:$PATH" bash "$BIN/disk-cleanup" --dry-run
  rm -rf "$td"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Nothing to clean up"* ]]
}

@test "disk-cleanup: flags JetBrains backup dirs" {
  _dc_setup td 'exit 0'
  mkdir -p "$td/Library/Application Support/JetBrains/CLion2026.1"
  mkdir -p "$td/Library/Application Support/JetBrains/CLion2025.2-backup"
  run env HOME="$td" PATH="$td/bin:$PATH" bash "$BIN/disk-cleanup" --dry-run
  rm -rf "$td"
  [ "$status" -eq 0 ]
  [[ "$output" == *"CLion2025.2-backup"* ]]
  [[ "$output" != *"CLion2026.1"* ]]
}

@test "disk-cleanup: dry run does not delete orphaned dirs" {
  _dc_setup td 'exit 0'
  mkdir -p "$td/Library/Caches/com.orphaned.app"
  run env HOME="$td" PATH="$td/bin:$PATH" bash "$BIN/disk-cleanup" --dry-run
  local still_exists=0
  [ -d "$td/Library/Caches/com.orphaned.app" ] && still_exists=1
  rm -rf "$td"
  [ "$status" -eq 0 ]
  [ "$still_exists" -eq 1 ]
}

# ── downloads-report ──────────────────────────────────────────────────────────

# Build a fake Downloads dir with files. Sets DL var to the dir path.
_dr_setup() {
  local _var="$1" _d
  _d=$(mktemp -d)
  mkdir -p "$_d/Downloads"
  printf -v "$_var" '%s/Downloads' "$_d"
}

@test "downloads-report: script exists and is executable" {
  [ -x "$BIN/downloads-report" ]
}

@test "downloads-report: groups files by type in human-readable output" {
  _dr_setup dl
  touch "$dl/photo.jpg" "$dl/song.mp3" "$dl/report.pdf"
  run env DOWNLOADS_DIR="$dl" bash "$BIN/downloads-report"
  rm -rf "$(dirname "$dl")"
  [ "$status" -eq 0 ]
  [[ "$output" == *"images"* ]]
  [[ "$output" == *"audio"* ]]
  [[ "$output" == *"documents"* ]]
}

@test "downloads-report: --paths outputs one path per line" {
  _dr_setup dl
  touch "$dl/photo.jpg" "$dl/song.mp3"
  run env DOWNLOADS_DIR="$dl" bash "$BIN/downloads-report" --paths
  rm -rf "$(dirname "$dl")"
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | wc -l | tr -d ' ')" -eq 2 ]
  [[ "$output" == *"photo.jpg"* ]]
  [[ "$output" == *"song.mp3"* ]]
}

@test "downloads-report: --type filters to one category" {
  _dr_setup dl
  touch "$dl/photo.jpg" "$dl/archive.zip" "$dl/song.mp3"
  run env DOWNLOADS_DIR="$dl" bash "$BIN/downloads-report" --type=archives
  rm -rf "$(dirname "$dl")"
  [ "$status" -eq 0 ]
  [[ "$output" == *"archives"* ]]
  [[ "$output" != *"images"* ]]
  [[ "$output" != *"audio"* ]]
}

@test "downloads-report: --type accepts raw extension" {
  _dr_setup dl
  touch "$dl/photo.jpg" "$dl/photo.png" "$dl/doc.pdf"
  run env DOWNLOADS_DIR="$dl" bash "$BIN/downloads-report" --paths --type=jpg
  rm -rf "$(dirname "$dl")"
  [ "$status" -eq 0 ]
  [[ "$output" == *"photo.jpg"* ]]
  [[ "$output" != *"photo.png"* ]]
  [[ "$output" != *"doc.pdf"* ]]
}

@test "downloads-report: --paths --type outputs only matching paths" {
  _dr_setup dl
  touch "$dl/file.zip" "$dl/photo.jpg"
  run env DOWNLOADS_DIR="$dl" bash "$BIN/downloads-report" --paths --type=archives
  rm -rf "$(dirname "$dl")"
  [ "$status" -eq 0 ]
  [[ "$output" == *"file.zip"* ]]
  [[ "$output" != *"photo.jpg"* ]]
}

@test "downloads-report: --older-than excludes recent files" {
  _dr_setup dl
  touch -t 202001010000 "$dl/old.dmg"   # Jan 2020 — old
  touch "$dl/new.pdf"                    # now — recent
  run env DOWNLOADS_DIR="$dl" bash "$BIN/downloads-report" --paths --older-than=30
  rm -rf "$(dirname "$dl")"
  [ "$status" -eq 0 ]
  [[ "$output" == *"old.dmg"* ]]
  [[ "$output" != *"new.pdf"* ]]
}

@test "downloads-report: empty dir prints no-files message" {
  _dr_setup dl
  run env DOWNLOADS_DIR="$dl" bash "$BIN/downloads-report"
  rm -rf "$(dirname "$dl")"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No files found"* ]]
}

@test "downloads-report: unknown option exits with error" {
  run bash "$BIN/downloads-report" --bogus
  [ "$status" -ne 0 ]
}
