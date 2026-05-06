#!/usr/bin/env bats

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
NVIM_DIR="$REPO_ROOT/nvim/.config/nvim"

# ── Colorscheme ────────────────────────────────────────────────────────────

@test "nvim: tokyonight is the colorscheme plugin" {
  grep -q 'tokyonight' "$NVIM_DIR/lua/plugins/colorscheme.lua"
}

@test "nvim: colorscheme style is night" {
  grep -qF 'style = "night"' "$NVIM_DIR/lua/plugins/colorscheme.lua"
}

@test "nvim: terminal colors are enabled" {
  grep -qF 'terminal_colors = true' "$NVIM_DIR/lua/plugins/colorscheme.lua"
}

# ── Tmux integration ───────────────────────────────────────────────────────

@test "nvim: vim-tmux-navigator plugin is configured" {
  grep -q 'vim-tmux-navigator' "$NVIM_DIR/lua/plugins/tmux.lua"
}

@test "nvim: Ctrl+h navigates left (tmux/nvim)" {
  grep -qF '"<c-h>"' "$NVIM_DIR/lua/plugins/tmux.lua"
}

@test "nvim: Ctrl+j navigates down (tmux/nvim)" {
  grep -qF '"<c-j>"' "$NVIM_DIR/lua/plugins/tmux.lua"
}

@test "nvim: Ctrl+k navigates up (tmux/nvim)" {
  grep -qF '"<c-k>"' "$NVIM_DIR/lua/plugins/tmux.lua"
}

@test "nvim: Ctrl+l navigates right (tmux/nvim)" {
  grep -qF '"<c-l>"' "$NVIM_DIR/lua/plugins/tmux.lua"
}

# ── Tmux split keymaps ─────────────────────────────────────────────────────

@test "nvim: leader+| splits tmux pane right" {
  grep -qF '"<leader>|"' "$NVIM_DIR/lua/config/keymaps.lua"
}

@test "nvim: leader+_ splits tmux pane down" {
  grep -qF '"<leader>_"' "$NVIM_DIR/lua/config/keymaps.lua"
}

@test "nvim: tmux split-window -h is used for vertical split" {
  grep -qF 'split-window", "-h"' "$NVIM_DIR/lua/config/keymaps.lua"
}

@test "nvim: tmux split-window -v is used for horizontal split" {
  grep -qF 'split-window", "-v"' "$NVIM_DIR/lua/config/keymaps.lua"
}

# ── Options ────────────────────────────────────────────────────────────────

@test "nvim: relative line numbers are enabled" {
  grep -qF 'relativenumber = true' "$NVIM_DIR/lua/config/options.lua"
}

@test "nvim: persistent undo is enabled" {
  grep -qF 'undofile = true' "$NVIM_DIR/lua/config/options.lua"
}

@test "nvim: smartcase search is enabled" {
  grep -qF 'smartcase = true' "$NVIM_DIR/lua/config/options.lua"
}

@test "nvim: scrolloff keeps context visible" {
  grep -q 'scrolloff = 8' "$NVIM_DIR/lua/config/options.lua"
}

@test "nvim: font is FiraCode Nerd Font" {
  grep -q 'FiraCode Nerd Font' "$NVIM_DIR/lua/config/options.lua"
}

@test "nvim: truecolor is enabled" {
  grep -qF 'termguicolors = true' "$NVIM_DIR/lua/config/options.lua"
}

# ── Plugins ────────────────────────────────────────────────────────────────

@test "nvim: treesitter is configured" {
  grep -q 'nvim-treesitter' "$NVIM_DIR/lua/plugins/treesitter.lua"
}

@test "nvim: noice.nvim is configured" {
  grep -q 'noice.nvim' "$NVIM_DIR/lua/plugins/ui.lua"
}

@test "nvim: noice LSP progress is enabled" {
  grep -qF 'progress = { enabled = true }' "$NVIM_DIR/lua/plugins/ui.lua"
}

@test "nvim: lazy.nvim bootstrap is in init.lua" {
  grep -q 'lazy' "$NVIM_DIR/init.lua"
}
