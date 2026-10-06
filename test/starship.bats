#!/usr/bin/env bats

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
STARSHIP_CFG="$REPO_ROOT/starship/.config/starship.toml"

# Functional tests for the starship config. Each catches real behavior;
# preference-asserting greps (cmd_duration min_time, character colors,
# truncation length, etc.) aren't tested — they only catch "I deleted
# my own line" which git diff already does.

@test "starship: config parses (valid TOML, no invalid module references)" {
  command -v starship >/dev/null || skip "starship not installed"
  STARSHIP_CONFIG="$STARSHIP_CFG" run starship explain
  [ "$status" -eq 0 ]
}

@test "starship: prompt renders without error" {
  command -v starship >/dev/null || skip "starship not installed"
  STARSHIP_CONFIG="$STARSHIP_CFG" run starship prompt --status=0
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}

@test "starship: format includes the language/tool modules we want shown" {
  # Single grep — losing a module from the format silently removes it
  # from the prompt forever. Worth catching, but not 6 separate tests.
  local fmt
  fmt="$(awk '/^format = """$/,/^"""$/' "$STARSHIP_CFG")"
  for module in '$directory' '$git_branch' '$git_status' '$python' '$nodejs' '$rust' '$golang' '$java' '$ruby' '$docker_context' '$cmd_duration' '$character'; do
    [[ "$fmt" == *"$module"* ]] || { echo "missing from format: $module"; return 1; }
  done
}
