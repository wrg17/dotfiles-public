#!/usr/bin/env bats

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

@test "README.public.md exists for public repo" {
  [ -f "$REPO_ROOT/README.public.md" ]
}

@test "public packages all exist as directories" {
  for pkg in nvim starship tmux wezterm yazi zsh; do
    [ -d "$REPO_ROOT/$pkg" ]
  done
}

@test ".zshrc.local is gitignored" {
  run git -C "$REPO_ROOT" check-ignore zsh/.config/zsh/.zshrc.local
  [ "$status" -eq 0 ]
}

@test "no private paths in public zsh files" {
  run grep -r "homelab" \
    "$REPO_ROOT/zsh/.zshenv" \
    "$REPO_ROOT/zsh/.config/zsh/.zshrc"
  [ "$status" -ne 0 ]
}

@test "no private paths in other public packages" {
  run grep -r "homelab" \
    "$REPO_ROOT/nvim" \
    "$REPO_ROOT/starship" \
    "$REPO_ROOT/tmux" \
    "$REPO_ROOT/wezterm" \
    "$REPO_ROOT/yazi"
  [ "$status" -ne 0 ]
}
