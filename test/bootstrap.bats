#!/usr/bin/env bats

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
BREWFILE="$REPO_ROOT/bootstrap/Brewfile"
APT_PKGS="$REPO_ROOT/bootstrap/apt-pkgs"
INSTALL_TOOLS="$REPO_ROOT/bootstrap/install-tools.sh"

# ── bats-core ──────────────────────────────────────────────────────────────────

@test "bootstrap: Brewfile declares bats-core" {
  grep -qF 'bats-core' "$BREWFILE"
}

@test "bootstrap: apt-pkgs declares bats" {
  grep -qF 'bats' "$APT_PKGS"
}

@test "bootstrap: bats is installed" {
  command -v bats >/dev/null || skip "bats not installed in this env"
}

# ── shellcheck ─────────────────────────────────────────────────────────────────

@test "bootstrap: Brewfile declares shellcheck" {
  grep -qF 'shellcheck' "$BREWFILE"
}

@test "bootstrap: apt-pkgs declares shellcheck" {
  grep -qF 'shellcheck' "$APT_PKGS"
}

@test "bootstrap: shellcheck is installed" {
  command -v shellcheck >/dev/null || skip "shellcheck not installed in this env"
}

# ── actionlint (macOS Homebrew only; no apt package) ──────────────────────────

@test "bootstrap: Brewfile declares actionlint" {
  grep -qF 'actionlint' "$BREWFILE"
}

@test "bootstrap: actionlint is installed" {
  command -v actionlint >/dev/null || skip "actionlint not installed in this env"
}

# ── starship (via install-tools.sh) ───────────────────────────────────────────

@test "bootstrap: install-tools.sh installs starship" {
  grep -qF 'install_starship' "$INSTALL_TOOLS"
}

@test "bootstrap: starship is installed" {
  command -v starship >/dev/null || skip "starship not installed in this env (install-tools.sh installs it)"
}

# ── neovim (via install-tools.sh) ─────────────────────────────────────────────

@test "bootstrap: install-tools.sh installs neovim" {
  grep -qF 'install_neovim' "$INSTALL_TOOLS"
}

@test "bootstrap: nvim is installed" {
  command -v nvim >/dev/null || skip "nvim not installed in this env (install-tools.sh installs it)"
}

# ── yazi (via install-tools.sh) ───────────────────────────────────────────────

@test "bootstrap: install-tools.sh installs yazi" {
  grep -qF 'install_yazi' "$INSTALL_TOOLS"
}

@test "bootstrap: yazi is installed" {
  command -v yazi >/dev/null || skip "yazi not installed in this env (install-tools.sh installs it)"
}

# ── nvm (via install-tools.sh) ────────────────────────────────────────────────

@test "bootstrap: install-tools.sh installs nvm" {
  grep -qF 'install_nvm' "$INSTALL_TOOLS"
}

@test "bootstrap: nvm dir exists" {
  [[ -d "${NVM_DIR:-$HOME/.local/share/nvm}" ]] || skip "nvm not installed in this env (install-tools.sh installs it)"
}

# ── rbenv (Brewfile on macOS, install-tools.sh on Linux) ──────────────────────

@test "bootstrap: Brewfile declares rbenv" {
  grep -qF 'brew "rbenv"' "$BREWFILE"
}

@test "bootstrap: install-tools.sh installs rbenv" {
  grep -qF 'install_rbenv' "$INSTALL_TOOLS"
}

@test "bootstrap: rbenv is installed" {
  command -v rbenv >/dev/null || skip "rbenv not installed in this env"
}

# ── rustup (via install-tools.sh) ─────────────────────────────────────────────

@test "bootstrap: install-tools.sh installs rustup" {
  grep -qF 'install_rustup' "$INSTALL_TOOLS"
}

@test "bootstrap: rustup is installed" {
  command -v rustup >/dev/null || skip "rustup not installed in this env (install-tools.sh installs it)"
}

# ── sheldon ───────────────────────────────────────────────────────────────────

@test "bootstrap: Brewfile declares sheldon" {
  grep -qF 'sheldon' "$BREWFILE"
}

@test "bootstrap: sheldon is installed" {
  command -v sheldon >/dev/null || skip "sheldon not installed in this env"
}

# ── tmux ──────────────────────────────────────────────────────────────────────

@test "bootstrap: Brewfile declares tmux" {
  grep -qF 'tmux' "$BREWFILE"
}

@test "bootstrap: apt-pkgs declares tmux" {
  grep -qF 'tmux' "$APT_PKGS"
}

@test "bootstrap: tmux is installed" {
  command -v tmux >/dev/null || skip "tmux not installed in this env"
}

# ── wezterm ───────────────────────────────────────────────────────────────────

@test "bootstrap: Brewfile declares wezterm" {
  grep -qF 'wezterm' "$BREWFILE"
}

@test "bootstrap: apt-pkgs declares wezterm" {
  grep -qF 'wezterm' "$APT_PKGS"
}

# ── watch ─────────────────────────────────────────────────────────────────────

@test "bootstrap: Brewfile declares watch" {
  grep -qF 'watch' "$BREWFILE"
}

@test "bootstrap: apt-pkgs declares watch" {
  grep -qF 'watch' "$APT_PKGS"
}

@test "bootstrap: watch is installed" {
  command -v watch >/dev/null || skip "watch not installed in this env"
}

# ── docker / colima ───────────────────────────────────────────────────────────

@test "bootstrap: Brewfile declares colima" {
  grep -qF 'brew "colima"' "$BREWFILE"
}

@test "bootstrap: Brewfile declares docker CLI" {
  grep -qF 'brew "docker"' "$BREWFILE"
}

@test "bootstrap: Brewfile does not declare Docker Desktop cask" {
  ! grep -qF 'cask "docker"' "$BREWFILE"
}

@test "bootstrap: apt-pkgs declares docker-ce" {
  grep -qF 'docker-ce' "$APT_PKGS"
}

@test "bootstrap: docker is installed" {
  command -v docker >/dev/null || skip "docker not installed in this env"
}

# ── colima-start script ────────────────────────────────────────────────────────

COLIMA_START="$REPO_ROOT/zsh/.local/bin/colima-start"

@test "colima-start: script exists and is executable" {
  [[ -x "$COLIMA_START" ]]
}

@test "colima-start: detects cpu via sysctl" {
  grep -q 'sysctl.*hw.logicalcpu' "$COLIMA_START"
}

@test "colima-start: detects memory via sysctl" {
  grep -q 'sysctl.*hw.memsize' "$COLIMA_START"
}

@test "colima-start: selects vm-type by macOS version" {
  grep -q 'sw_vers' "$COLIMA_START"
  grep -q 'vm_type' "$COLIMA_START"
}

@test "colima-start: enforces minimum cpu of 2" {
  grep -q 'cpu < 2' "$COLIMA_START"
}

@test "colima-start: enforces minimum memory of 2" {
  grep -q 'mem < 2' "$COLIMA_START"
}
