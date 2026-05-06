#!/usr/bin/env bats

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
WEZTERM_CFG="$REPO_ROOT/wezterm/.config/wezterm/wezterm.lua"

# ── Font ───────────────────────────────────────────────────────────────────

@test "wezterm: font is FiraCode Nerd Font Mono" {
  grep -qF 'family = "FiraCode Nerd Font Mono"' "$WEZTERM_CFG"
}

@test "wezterm: font size is 12" {
  grep -qF 'font_size = 12.0' "$WEZTERM_CFG"
}

@test "wezterm: ligatures are enabled via harfbuzz" {
  grep -q 'harfbuzz_features' "$WEZTERM_CFG"
}

# ── Color scheme ───────────────────────────────────────────────────────────

@test "wezterm: color scheme is Tokyo Night" {
  grep -qF 'color_scheme = "Tokyo Night"' "$WEZTERM_CFG"
}

# ── Default program (tmux) ─────────────────────────────────────────────────

@test "wezterm: default program launches tmux" {
  grep -qF '"tmux"' "$WEZTERM_CFG"
}

@test "wezterm: tmux attaches to or creates session named main" {
  grep -qF '"-s", "main"' "$WEZTERM_CFG"
}

@test "wezterm: tmux new-session uses -A flag to attach if exists" {
  grep -qF '"-A"' "$WEZTERM_CFG"
}

# ── Keyboard ───────────────────────────────────────────────────────────────

@test "wezterm: Kitty keyboard protocol is enabled" {
  grep -qF 'enable_kitty_keyboard = true' "$WEZTERM_CFG"
}

# ── Rendering ──────────────────────────────────────────────────────────────

@test "wezterm: OpenGL frontend is used" {
  grep -qF 'front_end = "OpenGL"' "$WEZTERM_CFG"
}

@test "wezterm: Wayland is disabled (X11 preferred)" {
  grep -qF 'enable_wayland = false' "$WEZTERM_CFG"
}

# ── UI behavior ────────────────────────────────────────────────────────────

@test "wezterm: tab bar hides with single tab" {
  grep -qF 'hide_tab_bar_if_only_one_tab = true' "$WEZTERM_CFG"
}

@test "wezterm: scrollback is 10000 lines" {
  grep -qF 'scrollback_lines = 10000' "$WEZTERM_CFG"
}

@test "wezterm: auto-update is disabled" {
  grep -qF 'check_for_updates = false' "$WEZTERM_CFG"
}

@test "wezterm: cursor style is blinking bar" {
  grep -qF 'default_cursor_style = "BlinkingBar"' "$WEZTERM_CFG"
}

@test "wezterm: window decorations are resize only" {
  grep -qF 'window_decorations = "RESIZE"' "$WEZTERM_CFG"
}
