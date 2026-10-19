#!/usr/bin/env bats

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

setup() {
  FAKE_HOME=$(mktemp -d)
  # Stow all packages together — this is the real use case and determines
  # correct folding: .config/ becomes a real dir (multiple packages share it),
  # so each tool's subdirectory becomes the symlink rather than .config itself.
  stow -d "$REPO_ROOT" -t "$FAKE_HOME" nvim sheldon starship tmux wezterm yazi zsh
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
  # .local folds to a dir symlink here because zsh is the only package in the
  # public set that ships one. The Linux set has two — see the test below.
  [ -e "$FAKE_HOME/.local/bin/clip" ]
}

@test "stow: .local is a symlink (zsh is the only public package using it)" {
  [ -L "$FAKE_HOME/.local" ]
}

# ── .gitignore patterns actually match ─────────────────────────────────────

@test "stow: no .gitignore pattern carries an inline comment" {
  # `#` only starts a comment at the beginning of a line, so `path  # why` is a
  # single literal pattern containing spaces and a hash — it matches nothing.
  # Five KDE entries were written that way and protected nothing for months.
  run grep -nE '^[^#[:space:]].*[[:space:]]#' "$REPO_ROOT/.gitignore"
  [ -z "$output" ] || {
    echo "inline comments make these patterns inert:"
    echo "$output"
    return 1
  }
}

@test "stow: every churning KDE rc file is genuinely ignored" {
  # --no-index because these files deliberately do not exist in the repo; the
  # patterns are a backstop for the day one gets copied back in.
  for f in kdeglobals konsolerc dolphinrc kglobalshortcutsrc kwinrc \
           khotkeysrc kwinrulesrc kxkbrc spectaclerc; do
    git -C "$REPO_ROOT" check-ignore -q --no-index "linux/.config/$f" || {
      echo "not ignored: linux/.config/$f"
      return 1
    }
  done
}

@test "stow: kdeglobals is not tracked" {
  # It was a stowed symlink, so Plasma wrote dialog geometry straight into the
  # worktree every session. Its intent now lives in bootstrap/kde-settings.sh.
  run git -C "$REPO_ROOT" ls-files --error-unmatch linux/.config/kdeglobals
  [ "$status" -ne 0 ]
}

@test "stow: kde-settings.sh carries the settings kdeglobals used to hold" {
  kde="$REPO_ROOT/bootstrap/kde-settings.sh"
  grep -q 'Icons Theme Yaru-magenta' "$kde"
  grep -q 'KDE LookAndFeelPackage org.kde.breezedark.desktop' "$kde"
  grep -q 'KDE widgetStyle Oxygen' "$kde"
  grep -q 'plasma-apply-colorscheme BreezeDark' "$kde"
}

# ── Full Linux package set ─────────────────────────────────────────────────
#
# The tests above stow only the public packages, which is not what a Linux
# machine installs. Two packages now ship a .local directory (zsh and backup),
# so stow has to unfold .local from a directory symlink into a real directory
# with per-file links. That transition is exactly where stow conflicts appear,
# and getting it wrong on a fresh machine breaks the five-minute recovery this
# repo is built around — so exercise the real set in its own fake home.

@test "stow: full Linux package set stows without conflicts" {
  [ -d "$REPO_ROOT/backup" ] || skip "backup/ is a private-source package"
  linux_home=$(mktemp -d)
  pkgs=$(ls -d "$REPO_ROOT"/*/ | xargs -n1 basename | grep -Ev '^(bootstrap|test|macos)$')
  run stow -d "$REPO_ROOT" -t "$linux_home" $pkgs
  status_saved="$status"
  output_saved="$output"
  rm -rf "$linux_home"
  [ "$status_saved" -eq 0 ] || {
    echo "$output_saved"
    return 1
  }
}

@test "stow: both .local-shipping packages land together on Linux" {
  [ -d "$REPO_ROOT/backup" ] || skip "backup/ is a private-source package"
  linux_home=$(mktemp -d)
  stow -d "$REPO_ROOT" -t "$linux_home" zsh backup

  # One script from each package, proving the unfold kept both.
  [ -e "$linux_home/.local/bin/clip" ]
  [ -e "$linux_home/.local/bin/borg-backup" ]
  [ -e "$linux_home/.config/borg/env" ]
  [ -e "$linux_home/.config/systemd/user/borg-backup.timer" ]

  # .local must be a real directory now, not a symlink into one package.
  [ -d "$linux_home/.local" ] && [ ! -L "$linux_home/.local" ]

  broken=$(find -L "$linux_home" -type l 2>/dev/null || true)
  rm -rf "$linux_home"
  [ -z "$broken" ]
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

# ── sheldon ────────────────────────────────────────────────────────────────

@test "stow: .config/sheldon is a symlink" {
  [ -L "$FAKE_HOME/.config/sheldon" ]
}

@test "stow: plugins.toml is accessible through symlink" {
  [ -e "$FAKE_HOME/.config/sheldon/plugins.toml" ]
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
