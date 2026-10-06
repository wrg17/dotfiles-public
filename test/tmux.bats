#!/usr/bin/env bats

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
TMUX_CONF="$REPO_ROOT/tmux/.config/tmux/tmux.conf"
# Socket name needs to be stable across setup_file + tests (which run in
# separate subshells with different $$). Derive from BATS_RUN_TMPDIR which
# is the same value throughout one bats invocation.
TMUX_SOCK="bats-tmux-$(printf '%s' "${BATS_RUN_TMPDIR:-/tmp/bats-fallback}" | shasum | cut -c1-8)"

# Functional tests for the tmux config. A real tmux server is spawned with
# this config and queried via show-options / list-keys — far stronger than
# greps, which only catch "I deleted a line in my own config." UI prefs
# (cursor style, status format, border colors) aren't tested.

setup_file() {
  command -v tmux >/dev/null || return 0
  tmux -L "$TMUX_SOCK" -f "$TMUX_CONF" new-session -d -s bats 2>/dev/null || true
}

teardown_file() {
  command -v tmux >/dev/null || return 0
  tmux -L "$TMUX_SOCK" kill-server 2>/dev/null || true
}

_tmux() {
  tmux -L "$TMUX_SOCK" "$@"
}

@test "tmux: config sources without errors (server starts)" {
  command -v tmux >/dev/null || skip "tmux not installed"
  run _tmux list-sessions
  [ "$status" -eq 0 ]
  [[ "$output" == *"bats"* ]]
}

@test "tmux: prefix is C-a" {
  command -v tmux >/dev/null || skip "tmux not installed"
  run _tmux show-options -g prefix
  [ "$status" -eq 0 ]
  [[ "$output" == *"C-a"* ]]
}

@test "tmux: core options take effect (mouse, history, base-index, renumber)" {
  command -v tmux >/dev/null || skip "tmux not installed"
  [[ "$(_tmux show-options -gv mouse)"               == "on"    ]]
  [[ "$(_tmux show-options -gv history-limit)"       == "50000" ]]
  [[ "$(_tmux show-options -gv base-index)"          == "1"     ]]
  [[ "$(_tmux show-options -gwv pane-base-index)"    == "1"     ]]
  [[ "$(_tmux show-options -gv renumber-windows)"    == "on"    ]]
}

@test "tmux: escape-time is a sane integer (>=0, <=500)" {
  command -v tmux >/dev/null || skip "tmux not installed"
  local val
  val=$(_tmux show-options -sgv escape-time)
  [[ "$val" =~ ^[0-9]+$ ]]
  [ "$val" -le 500 ]
}

@test "tmux: vim-style pane navigation (h/j/k/l → select-pane)" {
  command -v tmux >/dev/null || skip "tmux not installed"
  for key_dir in 'h L' 'j D' 'k U' 'l R'; do
    set -- $key_dir
    local key="$1" want="$2"
    local out
    out=$(_tmux list-keys -T prefix "$key")
    [[ "$out" == *"select-pane -$want"* ]] || { echo "expected select-pane -$want for '$key', got: $out"; return 1; }
  done
}

@test "tmux: vim-style pane resize (H/J/K/L → resize-pane)" {
  command -v tmux >/dev/null || skip "tmux not installed"
  for key_dir in 'H L' 'J D' 'K U' 'L R'; do
    set -- $key_dir
    local key="$1" want="$2"
    local out
    out=$(_tmux list-keys -T prefix "$key")
    [[ "$out" == *"resize-pane -$want"* ]] || { echo "expected resize-pane -$want for '$key', got: $out"; return 1; }
  done
}

@test "tmux: splits inherit current pane's working directory" {
  command -v tmux >/dev/null || skip "tmux not installed"
  local out
  out=$(_tmux list-keys -T prefix '|')
  [[ "$out" == *"pane_current_path"* ]]
  out=$(_tmux list-keys -T prefix '-')
  [[ "$out" == *"pane_current_path"* ]]
}

@test "tmux: copy mode uses vi keys and v starts selection" {
  command -v tmux >/dev/null || skip "tmux not installed"
  [[ "$(_tmux show-options -gwv mode-keys)" == "vi" ]]
  local out
  out=$(_tmux list-keys -T copy-mode-vi v)
  [[ "$out" == *"begin-selection"* ]]
}

@test "tmux: copy mode yank routes to OS clipboard" {
  command -v tmux >/dev/null || skip "tmux not installed"
  local out
  out=$(_tmux list-keys -T copy-mode-vi y)
  if [[ "$(uname)" == "Darwin" ]]; then
    [[ "$out" == *"pbcopy"* ]]
  else
    [[ "$out" == *"xclip -selection clipboard"* ]]
  fi
}

@test "tmux: default-terminal exists in this system's terminfo" {
  command -v tmux >/dev/null || skip "tmux not installed"
  local term
  term=$(_tmux show-options -gv default-terminal)
  [ -n "$term" ]
  infocmp "$term" >/dev/null 2>&1
}

@test "tmux: TPM-installed plugins are bound (resurrect save key registered)" {
  command -v tmux >/dev/null || skip "tmux not installed"
  # resurrect binds prefix+Ctrl-s for save; presence of that binding
  # proves TPM successfully loaded the plugins listed in tmux.conf.
  # Skip if plugins haven't been installed yet (CI's clean checkout
  # would have to clone from GitHub during setup_file — flaky).
  local plugin_dir="${TMUX_PLUGIN_MANAGER_PATH:-$HOME/.config/tmux/plugins}"
  [[ -d "$plugin_dir/tmux-resurrect" ]] || [[ -d "$HOME/.tmux/plugins/tmux-resurrect" ]] \
    || skip "tmux-resurrect plugin not installed on this system"
  local out
  out=$(_tmux list-keys -T prefix C-s 2>&1)
  [[ "$out" == *"resurrect"* ]]
}
