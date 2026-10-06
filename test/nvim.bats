#!/usr/bin/env bats

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
NVIM_DIR="$REPO_ROOT/nvim/.config/nvim"

# Functional tests for the nvim config. UI preferences (italic comments,
# specific keymaps, scrollback positions) aren't grep-tested — the headless
# load below catches the realistic failure modes (syntax errors, broken
# requires, missing plugin specs).

@test "nvim: all authored .lua files have valid Lua syntax" {
  command -v luac >/dev/null || skip "luac not installed"
  while IFS= read -r f; do
    luac -p "$f" || { echo "syntax error in: $f"; return 1; }
  done < <(find "$NVIM_DIR" -name '*.lua' -type f)
}

@test "nvim: headless launch loads init.lua without errors" {
  command -v nvim >/dev/null || skip "nvim not installed"
  # Run from a temp HOME so the test doesn't fight a real lazy install state
  local out
  out="$(XDG_CONFIG_HOME="$REPO_ROOT/nvim/.config" nvim --headless -c 'qa!' 2>&1)" || true
  # Allow expected "lazy.nvim setup complete" type messages; fail on E5113/E5108 lua errors
  [[ "$out" != *"E5113"* && "$out" != *"E5108"* && "$out" != *"E5104"* ]] || { echo "$out"; return 1; }
}

@test "nvim: lazy-lock.json contains the plugins this config explicitly adds" {
  local lock="$NVIM_DIR/lazy-lock.json"
  [[ -f "$lock" ]] || skip "lazy-lock.json not yet generated (run nvim once to install)"
  for plugin in 'dracula.nvim' 'vim-tmux-navigator' 'nvim-treesitter' 'noice.nvim' 'lazy.nvim'; do
    grep -qF "\"$plugin\"" "$lock" || { echo "missing from lockfile: $plugin"; return 1; }
  done
}

@test "nvim: configured options take effect after init.lua loads" {
  command -v nvim >/dev/null || skip "nvim not installed"
  # Query a few representative options we explicitly set in options.lua
  local out
  out="$(XDG_CONFIG_HOME="$REPO_ROOT/nvim/.config" nvim --headless \
    -c 'lua io.write(string.format("scrolloff=%d relativenumber=%s smartcase=%s undofile=%s\n", vim.opt.scrolloff:get(), tostring(vim.opt.relativenumber:get()), tostring(vim.opt.smartcase:get()), tostring(vim.opt.undofile:get())))' \
    -c 'qa!' 2>&1 | grep -E '^scrolloff=')"
  [[ "$out" == *"scrolloff=8"* ]] || { echo "scrolloff wrong: $out"; return 1; }
  [[ "$out" == *"relativenumber=true"* ]] || { echo "relativenumber wrong: $out"; return 1; }
  [[ "$out" == *"smartcase=true"* ]] || { echo "smartcase wrong: $out"; return 1; }
  [[ "$out" == *"undofile=true"* ]] || { echo "undofile wrong: $out"; return 1; }
}
