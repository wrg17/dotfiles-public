#!/usr/bin/env bats

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

@test "README.public.md exists for public repo" {
  # In the public repo the README was renamed to README.md during publish.
  # The test verifies the private source has it.
  skip "README.public.md is a private-source file; covered by the private repo"
}

@test "public packages all exist as directories" {
  for pkg in nvim sheldon starship tmux wezterm yazi zsh; do
    [ -d "$REPO_ROOT/$pkg" ]
  done
}

@test "AGENTS.public.md exists and publish.sh ships it as AGENTS.md" {
  [ -f "$REPO_ROOT/AGENTS.public.md" ]
  run grep -q 'AGENTS.public.md.*AGENTS.md' "$REPO_ROOT/publish.sh"
  [ "$status" -eq 0 ]
}

# Everything publish.sh copies into the public repo. Keep in sync with publish.sh.
_published_paths() {
  local p
  for p in nvim sheldon starship tmux wezterm yazi zsh bootstrap test \
           Makefile .gitignore README.public.md AGENTS.public.md \
           .github/workflows/ci.yml; do
    [ -e "$REPO_ROOT/$p" ] && printf '%s\n' "$REPO_ROOT/$p"
  done
}

# Only tracked files reach the public repo: publish.sh rsyncs each package, then
# `git add -A` honours the copied .gitignore. So scan git's view, not the worktree —
# otherwise gitignored local files (.zsh_history, .zcompdump) raise false alarms.
_published_tracked_files() {
  git -C "$REPO_ROOT" ls-files -- $(_published_paths | sed "s|$REPO_ROOT/||")
}

# Patterns are derived at runtime rather than written literally, so this test does
# not itself leak the values it guards against (test/ is published too).
@test "published files leak no absolute home paths, hostname, or git email" {
  local found="" hits
  cd "$REPO_ROOT"

  # Absolute home directories of any user, either platform.
  # /home/linuxbrew is a real shared Homebrew prefix, not user-specific.
  hits="$(_published_tracked_files | xargs grep -In -E \
          '(/home/|/Users/)[a-z_][a-z0-9_-]*/' 2>/dev/null \
          | grep -v 'linuxbrew' || true)"
  [ -z "$hits" ] || found="${found}absolute home paths:\n${hits}\n"

  # This machine's hostname
  local shorthost; shorthost="$(hostname 2>/dev/null | cut -d. -f1)"
  if [ -n "$shorthost" ]; then
    hits="$(_published_tracked_files | xargs grep -In -F "$shorthost" 2>/dev/null || true)"
    [ -z "$hits" ] || found="${found}hostname:\n${hits}\n"
  fi

  # The committing user's real git email
  local email; email="$(git config user.email 2>/dev/null || true)"
  if [ -n "$email" ]; then
    hits="$(_published_tracked_files | xargs grep -In -F "$email" 2>/dev/null || true)"
    [ -z "$hits" ] || found="${found}git email:\n${hits}\n"
  fi

  if [ -n "$found" ]; then
    printf 'private data would be published:\n%b' "$found" >&2
    return 1
  fi
}

@test "publish.sh excludes shell history and compdumps from the rsync" {
  # Defence in depth: rsync ignores .gitignore, so these must be excluded
  # explicitly rather than relying solely on the copied ignore file.
  for pat in .zsh_history '.zcompdump\*' '\*.zwc'; do
    run grep -qE -- "--exclude=.?$pat" "$REPO_ROOT/publish.sh"
    [ "$status" -eq 0 ]
  done
}

@test ".zshrc.local is gitignored" {
  run git -C "$REPO_ROOT" check-ignore zsh/.config/zsh/.zshrc.local
  [ "$status" -eq 0 ]
}

# Host-specific terms are kept in test/private-patterns.local — gitignored and
# excluded from publish.sh — so this file does not itself disclose the strings it
# guards against. Earlier versions grepped the literal word, which meant the test
# published the very term it was protecting.
@test "no private terms from private-patterns.local in published files" {
  local list="$REPO_ROOT/test/private-patterns.local"
  [ -f "$list" ] || skip "no test/private-patterns.local on this machine"

  cd "$REPO_ROOT"
  local pat found=""
  while IFS= read -r pat; do
    case "$pat" in ''|'#'*) continue ;; esac
    local hits
    hits="$(_published_tracked_files | xargs grep -Iln -E -- "$pat" 2>/dev/null || true)"
    [ -z "$hits" ] || found="${found}pattern #$(( ++n )) matched: ${hits}\n"
  done < "$list"

  if [ -n "$found" ]; then
    printf 'private terms would be published:\n%b' "$found" >&2
    return 1
  fi
}
