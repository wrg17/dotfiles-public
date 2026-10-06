#!/usr/bin/env bats

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

# ── Shell ──────────────────────────────────────────────────────────────────

@test "zshenv has no syntax errors" {
  run zsh -n "$REPO_ROOT/zsh/.zshenv"
  [ "$status" -eq 0 ]
}

@test "zshrc has no syntax errors" {
  run zsh -n "$REPO_ROOT/zsh/.config/zsh/.zshrc"
  [ "$status" -eq 0 ]
}

# ── Lua (nvim) ─────────────────────────────────────────────────────────────

@test "nvim lua files have valid syntax" {
  luac=$(command -v luac 2>/dev/null || command -v luac5.4 2>/dev/null || command -v luac5.3 2>/dev/null || echo "")
  [ -n "$luac" ] || skip "luac not installed"
  find "$REPO_ROOT/nvim" -name "*.lua" -print0 | xargs -0 "$luac" -p
}

# ── TOML ───────────────────────────────────────────────────────────────────

@test "starship.toml has valid TOML syntax" {
  run python3 -c "import tomllib, sys; tomllib.load(open(sys.argv[1], 'rb'))" \
    "$REPO_ROOT/starship/.config/starship.toml"
  [ "$status" -eq 0 ]
}

@test "yazi/yazi.toml has valid TOML syntax" {
  run python3 -c "import tomllib, sys; tomllib.load(open(sys.argv[1], 'rb'))" \
    "$REPO_ROOT/yazi/.config/yazi/yazi.toml"
  [ "$status" -eq 0 ]
}

@test "yazi/keymap.toml has valid TOML syntax" {
  run python3 -c "import tomllib, sys; tomllib.load(open(sys.argv[1], 'rb'))" \
    "$REPO_ROOT/yazi/.config/yazi/keymap.toml"
  [ "$status" -eq 0 ]
}

@test "yazi/package.toml has valid TOML syntax" {
  run python3 -c "import tomllib, sys; tomllib.load(open(sys.argv[1], 'rb'))" \
    "$REPO_ROOT/yazi/.config/yazi/package.toml"
  [ "$status" -eq 0 ]
}
