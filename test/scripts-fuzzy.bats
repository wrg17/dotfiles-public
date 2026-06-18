#!/usr/bin/env bats

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
BIN="$REPO_ROOT/zsh/.local/bin"

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
