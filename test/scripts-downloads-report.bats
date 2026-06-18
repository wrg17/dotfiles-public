#!/usr/bin/env bats

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
BIN="$REPO_ROOT/zsh/.local/bin"

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
