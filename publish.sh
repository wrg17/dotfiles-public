#!/usr/bin/env bash
set -euo pipefail

PUBLIC_PACKAGES=(nvim starship tmux wezterm yazi zsh)
REPO_ROOT=$(git rev-parse --show-toplevel)

PUBLIC_URL=$(git remote get-url public 2>/dev/null) || {
  echo "Error: no 'public' remote. Run: git remote add public <url>"
  exit 1
}

command -v gh >/dev/null || {
  echo "Error: gh CLI not found — needed to open the PR. brew install gh"
  exit 1
}

GH_REPO=$(echo "$PUBLIC_URL" | sed 's|.*github\.com[:/]||; s|\.git$||')
BRANCH="publish/$(date -u +%Y%m%d-%H%M%S)"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

git -C "$tmpdir" init -b master
git -C "$tmpdir" remote add origin "$PUBLIC_URL"

# Detect whether master already exists in the public repo.
# No --depth: shallow clones break GitHub's PR diff computation.
if git -C "$tmpdir" fetch origin master 2>/dev/null; then
  HAS_MASTER=true
  git -C "$tmpdir" checkout -b "$BRANCH" origin/master
else
  # First publish — bootstrap master directly; no base branch to PR into yet.
  HAS_MASTER=false
  git -C "$tmpdir" checkout -b master
fi

# Wipe tracked files so deleted packages/files don't linger across publishes
git -C "$tmpdir" rm -rf . >/dev/null 2>&1 || true

# Sync public packages
for pkg in "${PUBLIC_PACKAGES[@]}"; do
  rsync -a --exclude='.zshrc.local' "$REPO_ROOT/$pkg/" "$tmpdir/$pkg/"
done

# Public-facing README (as the repo's main README)
cp "$REPO_ROOT/README.public.md" "$tmpdir/README.md" 2>/dev/null || true

# .gitignore needed for .zshrc.local ignore pattern tests
cp "$REPO_ROOT/.gitignore" "$tmpdir/" 2>/dev/null || true

# CI so the public repo can gate its own merges
mkdir -p "$tmpdir/.github/workflows"
cp "$REPO_ROOT/.github/workflows/ci.yml" "$tmpdir/.github/workflows/"

# Test framework and Makefile needed for public CI
cp "$REPO_ROOT/Makefile" "$tmpdir/" 2>/dev/null || true
rsync -a "$REPO_ROOT/test/" "$tmpdir/test/" 2>/dev/null || true

# Validation scripts used by CI shellcheck tests
cp "$REPO_ROOT/publish.sh" "$tmpdir/" 2>/dev/null || true
rsync -a "$REPO_ROOT/bootstrap/" "$tmpdir/bootstrap/" 2>/dev/null || true

git -C "$tmpdir" add -A

# Nothing to do if the sync produced no diff
if git -C "$tmpdir" diff --cached --quiet 2>/dev/null; then
  echo "Nothing to publish — public repo is already up to date."
  exit 0
fi

git -C "$tmpdir" \
  -c user.name="$(git config user.name)" \
  -c user.email="$(git config user.email)" \
  commit -m "publish: sync $(date -u +%Y-%m-%dT%H:%M:%SZ)"

if $HAS_MASTER; then
  git -C "$tmpdir" push origin "$BRANCH"

  PR_URL=$(cd "$tmpdir" && gh pr create \
    --repo "$GH_REPO" \
    --base master \
    --title "publish: sync $(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --body "Automated publish from private dotfiles.")

  if gh pr merge --auto --merge "$PR_URL" 2>/dev/null; then
    echo ""
    echo "PR opened with auto-merge enabled: $PR_URL"
    echo "Will merge to master once CI passes."
  else
    echo ""
    echo "PR opened: $PR_URL"
    echo "Auto-merge unavailable — enable branch protection on master, then future runs will auto-merge."
  fi
else
  git -C "$tmpdir" push origin master

  echo ""
  echo "First publish: bootstrapped master directly (no existing base branch)."
  echo "Future publishes will go through a PR."
fi
