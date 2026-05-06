#!/usr/bin/env bats

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

setup() {
  FAKE_HOME=$(mktemp -d)
  # Stow all packages together — this is the real use case and determines
  # correct folding: .config/ becomes a real dir (multiple packages share it),
  # so each tool's subdirectory becomes the symlink rather than .config itself.
  stow -d "$REPO_ROOT" -t "$FAKE_HOME" nvim starship tmux wezterm yazi zsh
}

teardown() {
  rm -rf "$FAKE_HOME"
}

# ── Conflict-free stow ─────────────────────────────────────────────────────

@test "stow: all public packages stow without conflicts" {
  # Reaching here means setup() succeeded
  true
}

@test "stow: no broken symlinks after stowing all packages" {
  broken=$(find -L "$FAKE_HOME" -type l 2>/dev/null || true)
  [ -z "$broken" ]
}

# ── zsh ────────────────────────────────────────────────────────────────────

@test "stow: .zshenv is a symlink" {
  [ -L "$FAKE_HOME/.zshenv" ]
}

@test "stow: .zshenv target is readable" {
  [ -e "$FAKE_HOME/.zshenv" ]
}

@test "stow: .config/zsh is a symlink" {
  [ -L "$FAKE_HOME/.config/zsh" ]
}

@test "stow: .zshrc is accessible through symlink" {
  [ -e "$FAKE_HOME/.config/zsh/.zshrc" ]
}

@test "stow: clip utility is accessible" {
  # .local is folded to a dir symlink since only zsh uses it
  [ -e "$FAKE_HOME/.local/bin/clip" ]
}

@test "stow: .local is a symlink (only zsh uses it)" {
  [ -L "$FAKE_HOME/.local" ]
}

# ── nvim ───────────────────────────────────────────────────────────────────

@test "stow: .config/nvim is a symlink" {
  [ -L "$FAKE_HOME/.config/nvim" ]
}

@test "stow: nvim init.lua is accessible through symlink" {
  [ -e "$FAKE_HOME/.config/nvim/init.lua" ]
}

@test "stow: nvim keymaps are accessible through symlink" {
  [ -e "$FAKE_HOME/.config/nvim/lua/config/keymaps.lua" ]
}

@test "stow: nvim plugins dir is accessible through symlink" {
  [ -e "$FAKE_HOME/.config/nvim/lua/plugins" ]
}

# ── starship ───────────────────────────────────────────────────────────────

@test "stow: starship.toml is a symlink" {
  [ -L "$FAKE_HOME/.config/starship.toml" ]
}

@test "stow: starship.toml is readable" {
  [ -e "$FAKE_HOME/.config/starship.toml" ]
}

# ── tmux ───────────────────────────────────────────────────────────────────

@test "stow: .config/tmux is a symlink" {
  [ -L "$FAKE_HOME/.config/tmux" ]
}

@test "stow: tmux.conf is accessible through symlink" {
  [ -e "$FAKE_HOME/.config/tmux/tmux.conf" ]
}

# ── wezterm ────────────────────────────────────────────────────────────────

@test "stow: .config/wezterm is a symlink" {
  [ -L "$FAKE_HOME/.config/wezterm" ]
}

@test "stow: wezterm.lua is accessible through symlink" {
  [ -e "$FAKE_HOME/.config/wezterm/wezterm.lua" ]
}

# ── yazi ───────────────────────────────────────────────────────────────────

@test "stow: .config/yazi is a symlink" {
  [ -L "$FAKE_HOME/.config/yazi" ]
}

@test "stow: yazi.toml is accessible through symlink" {
  [ -e "$FAKE_HOME/.config/yazi/yazi.toml" ]
}

@test "stow: yazi keymap.toml is accessible through symlink" {
  [ -e "$FAKE_HOME/.config/yazi/keymap.toml" ]
}
