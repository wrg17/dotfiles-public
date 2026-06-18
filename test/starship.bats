#!/usr/bin/env bats

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
STARSHIP_CFG="$REPO_ROOT/starship/.config/starship.toml"

# ── Prompt format ──────────────────────────────────────────────────────────

@test "starship: format includes git_branch" {
  grep -qF '$git_branch' "$STARSHIP_CFG"
}

@test "starship: format includes git_status" {
  grep -qF '$git_status' "$STARSHIP_CFG"
}

@test "starship: format includes python" {
  grep -qF '$python' "$STARSHIP_CFG"
}

@test "starship: format includes nodejs" {
  grep -qF '$nodejs' "$STARSHIP_CFG"
}

@test "starship: format includes cmd_duration" {
  grep -qF '$cmd_duration' "$STARSHIP_CFG"
}

@test "starship: format includes directory" {
  grep -qF '$directory' "$STARSHIP_CFG"
}

# ── git_status symbols ─────────────────────────────────────────────────────

@test "starship: git_status shows ahead count" {
  grep -q 'ahead' "$STARSHIP_CFG"
}

@test "starship: git_status shows behind count" {
  grep -q 'behind' "$STARSHIP_CFG"
}

@test "starship: git_status shows modified files" {
  grep -q 'modified' "$STARSHIP_CFG"
}

@test "starship: git_status shows staged files" {
  grep -q 'staged' "$STARSHIP_CFG"
}

@test "starship: git_status shows untracked files" {
  grep -q 'untracked' "$STARSHIP_CFG"
}

# ── Command duration ───────────────────────────────────────────────────────

@test "starship: cmd_duration only shows for commands over 2s" {
  grep -qF 'min_time = 2_000' "$STARSHIP_CFG"
}

# ── Character (prompt symbol) ──────────────────────────────────────────────

@test "starship: success prompt symbol is ❯ in dracula green" {
  grep -qF 'success_symbol = "[❯](#50fa7b)"' "$STARSHIP_CFG"
}

@test "starship: error prompt symbol is ❯ in dracula red" {
  grep -qF 'error_symbol = "[❯](#ff5555)"' "$STARSHIP_CFG"
}

# ── Docker ─────────────────────────────────────────────────────────────────

@test "starship: docker context only shows near compose files" {
  grep -qF 'only_with_files = true' "$STARSHIP_CFG"
}

# ── Directory ──────────────────────────────────────────────────────────────

@test "starship: directory truncates to repo root" {
  grep -qF 'truncate_to_repo = true' "$STARSHIP_CFG"
}

# ── Rust ───────────────────────────────────────────────────────────────────

@test "starship: rust module is configured" {
  grep -q '^\[rust\]' "$STARSHIP_CFG"
}
