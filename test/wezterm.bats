#!/usr/bin/env bats

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
WEZTERM_CFG="$REPO_ROOT/wezterm/.config/wezterm/wezterm.lua"

# Functional tests — each one validates real behavior rather than asserting
# that a particular line exists in the config. UI preferences (cursor style,
# tab bar visibility, scrollback length, color scheme) aren't tested here;
# they catch only "I deleted my own line" which git diff already does.

@test "wezterm: config parses (valid Lua, all keys recognized)" {
  command -v wezterm >/dev/null || skip "wezterm not installed"
  run wezterm --config-file "$WEZTERM_CFG" ls-fonts --text "X"
  [ "$status" -eq 0 ]
}

@test "wezterm: configured font resolves with the expected family" {
  command -v wezterm >/dev/null || skip "wezterm not installed"
  run wezterm --config-file "$WEZTERM_CFG" ls-fonts --text "X"
  [ "$status" -eq 0 ]
  [[ "$output" == *"FiraCode Nerd Font Mono"* ]]
}

@test "wezterm: ligatures render (== maps to equal_equal.liga glyph)" {
  command -v wezterm >/dev/null || skip "wezterm not installed"
  run wezterm --config-file "$WEZTERM_CFG" ls-fonts --text "=="
  [ "$status" -eq 0 ]
  [[ "$output" == *"equal_equal.liga"* ]]
}

@test "wezterm: Homebrew paths are in the configured PATH (GUI launch finds tmux)" {
  # This is the one grep worth keeping — catches the actual bug fix where
  # macOS GUI launches of WezTerm.app inherit a minimal PATH missing brew.
  grep -qF 'PATH = "/opt/homebrew/bin:/usr/local/bin:' "$WEZTERM_CFG"
}
