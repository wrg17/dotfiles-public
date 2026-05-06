#!/usr/bin/env bats

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
TMUX_CONF="$REPO_ROOT/tmux/.config/tmux/tmux.conf"

# ── Prefix ─────────────────────────────────────────────────────────────────

@test "tmux: prefix is Ctrl+a" {
  grep -qF 'set -g prefix C-a' "$TMUX_CONF"
}

@test "tmux: default Ctrl+b prefix is unbound" {
  grep -qF 'unbind C-b' "$TMUX_CONF"
}

# ── Pane navigation (vim-style) ────────────────────────────────────────────

@test "tmux: h selects left pane" {
  grep -qF 'bind h select-pane -L' "$TMUX_CONF"
}

@test "tmux: j selects down pane" {
  grep -qF 'bind j select-pane -D' "$TMUX_CONF"
}

@test "tmux: k selects up pane" {
  grep -qF 'bind k select-pane -U' "$TMUX_CONF"
}

@test "tmux: l selects right pane" {
  grep -qF 'bind l select-pane -R' "$TMUX_CONF"
}

# ── Pane splits ────────────────────────────────────────────────────────────

@test "tmux: | splits horizontally" {
  grep -qF 'bind | split-window -h' "$TMUX_CONF"
}

@test "tmux: - splits vertically" {
  grep -qF 'bind - split-window -v' "$TMUX_CONF"
}

@test "tmux: splits open in current directory" {
  grep -q 'pane_current_path' "$TMUX_CONF"
}

@test "tmux: default split bindings are unbound" {
  grep -qF 'unbind %' "$TMUX_CONF"
}

# ── Window navigation ──────────────────────────────────────────────────────

@test "tmux: Alt+h goes to previous window" {
  grep -qF 'bind -n M-h previous-window' "$TMUX_CONF"
}

@test "tmux: Alt+l goes to next window" {
  grep -qF 'bind -n M-l next-window' "$TMUX_CONF"
}

# ── Pane resizing ──────────────────────────────────────────────────────────

@test "tmux: H resizes pane left" {
  grep -qF 'bind -r H resize-pane -L' "$TMUX_CONF"
}

@test "tmux: L resizes pane right" {
  grep -qF 'bind -r L resize-pane -R' "$TMUX_CONF"
}

# ── Copy mode ──────────────────────────────────────────────────────────────

@test "tmux: copy mode uses vi keys" {
  grep -qF 'setw -g mode-keys vi' "$TMUX_CONF"
}

@test "tmux: v begins selection in copy mode" {
  grep -q 'begin-selection' "$TMUX_CONF"
}

@test "tmux: y yanks to system clipboard via xclip" {
  grep -q 'xclip -selection clipboard' "$TMUX_CONF"
}

@test "tmux: mouse drag copies to clipboard" {
  grep -q 'MouseDragEnd1Pane' "$TMUX_CONF"
}

# ── General settings ───────────────────────────────────────────────────────

@test "tmux: mouse is enabled" {
  grep -qF 'set  -g  mouse on' "$TMUX_CONF"
}

@test "tmux: history limit is 50000" {
  grep -qF 'history-limit 50000' "$TMUX_CONF"
}

@test "tmux: window indexing starts at 1" {
  grep -qF 'set  -g  base-index 1' "$TMUX_CONF"
}

@test "tmux: pane indexing starts at 1" {
  grep -qF 'setw -g  pane-base-index 1' "$TMUX_CONF"
}

@test "tmux: windows renumber after close" {
  grep -qF 'renumber-windows on' "$TMUX_CONF"
}

@test "tmux: escape time is 0ms" {
  grep -qF 'escape-time 0' "$TMUX_CONF"
}

@test "tmux: reload bind is r" {
  grep -q 'bind r source-file' "$TMUX_CONF"
}
