#!/usr/bin/env bats

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
YAZI_DIR="$REPO_ROOT/yazi/.config/yazi"

# ── Plugins (package.toml) ─────────────────────────────────────────────────

@test "yazi: git plugin is declared" {
  grep -qF 'yazi-rs/plugins:git' "$YAZI_DIR/package.toml"
}

@test "yazi: syntax-highlight plugin is declared" {
  grep -qF 'yazi-rs/plugins:syntax-highlight' "$YAZI_DIR/package.toml"
}

@test "yazi: full-border plugin is declared" {
  grep -qF 'yazi-rs/plugins:full-border' "$YAZI_DIR/package.toml"
}

@test "yazi: starship plugin is declared" {
  grep -qF 'yazi-rs/plugins:starship' "$YAZI_DIR/package.toml"
}

# ── Keymap shortcuts ───────────────────────────────────────────────────────

@test "yazi: . toggles hidden files" {
  grep -qF 'run = "hidden toggle"' "$YAZI_DIR/keymap.toml"
}

@test "yazi: Ctrl+t opens terminal in current dir" {
  grep -qF 'on = "<C-t>"' "$YAZI_DIR/keymap.toml"
}

@test "yazi: terminal shortcut uses wezterm" {
  grep -q 'wezterm' "$YAZI_DIR/keymap.toml"
}

@test "yazi: P opens PyCharm" {
  grep -qF 'on = "P"' "$YAZI_DIR/keymap.toml"
}

@test "yazi: y,p copies path to clipboard" {
  grep -q '"y", "p"' "$YAZI_DIR/keymap.toml"
}

@test "yazi: R bulk-renames with nvim" {
  grep -qF 'run = "bulk-rename"' "$YAZI_DIR/keymap.toml"
}

@test "yazi: A creates a directory" {
  grep -qF 'run = "create --dir"' "$YAZI_DIR/keymap.toml"
}

# ── yazi.toml settings ─────────────────────────────────────────────────────

@test "yazi: directories sort first" {
  grep -qF 'sort_dir_first = true' "$YAZI_DIR/yazi.toml"
}

@test "yazi: hidden files are shown by default" {
  grep -qF 'show_hidden    = true' "$YAZI_DIR/yazi.toml"
}

@test "yazi: symlinks are shown" {
  grep -qF 'show_symlink   = true' "$YAZI_DIR/yazi.toml"
}

@test "yazi: nvim is the default editor" {
  grep -qF "run = 'nvim %s'" "$YAZI_DIR/yazi.toml"
}

@test "yazi: git fetcher is enabled" {
  grep -qF 'id = "git"' "$YAZI_DIR/yazi.toml"
}

@test "yazi: text files open in editor" {
  grep -q 'mime = "text/\*"' "$YAZI_DIR/yazi.toml"
}
