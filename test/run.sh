#!/usr/bin/env bash
# Run bats test files, skipping any whose dependency files haven't changed
# since the last successful run. Markers live under .cache/tests/passed/.
#
# Flags:
#   --no-cache   Run everything; rewrite markers on success.
#   --clean      Delete the marker directory, then process remaining args.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CACHE_DIR="$REPO_ROOT/.cache/tests/passed"

if command -v sha256sum >/dev/null 2>&1; then
  _sha256() { sha256sum | awk '{print $1}'; }
elif command -v shasum >/dev/null 2>&1; then
  _sha256() { shasum -a 256 | awk '{print $1}'; }
else
  echo "run.sh: need sha256sum or shasum" >&2
  exit 1
fi

clean=0
no_cache=0
files=()
for arg in "$@"; do
  case "$arg" in
    --clean)    clean=1 ;;
    --no-cache) no_cache=1 ;;
    *)          files+=("$arg") ;;
  esac
done

if (( clean )); then
  rm -rf "$CACHE_DIR"
  echo "cleared $CACHE_DIR"
fi

(( ${#files[@]} )) || exit 0

mkdir -p "$CACHE_DIR"

# Stable per (bats/shellcheck/actionlint versions, OS). Bumping any tool
# invalidates every marker so old passes can't mask new lint rules.
tool_hash=$(
  {
    bats --version       2>&1 || true
    shellcheck --version 2>&1 || true
    actionlint -version  2>&1 || true
    uname -s
  } | _sha256
)

# Echo dep roots (paths relative to REPO_ROOT) for a given .bats basename.
# Empty output means "fall back to all tracked + unignored files".
deps_for() {
  local name="$1" stem rest
  stem="${name%.bats}"
  case "$stem" in
    scripts-*)
      rest="${stem#scripts-}"
      echo "zsh/.local/bin/$rest"
      ;;
    *)
      if [ -d "$REPO_ROOT/$stem" ]; then
        echo "$stem"
      fi
      ;;
  esac
}

# Hash a sorted, deduped list of file contents under the given roots.
# Walks directories; silently skips missing paths.
hash_paths() {
  local p
  (
    cd "$REPO_ROOT"
    for p in "$@"; do
      if [ -d "$p" ]; then
        find "$p" -type f
      elif [ -e "$p" ]; then
        echo "$p"
      fi
    done | LC_ALL=C sort -u | git hash-object --stdin-paths
  ) | _sha256
}

hash_all() {
  (
    cd "$REPO_ROOT"
    {
      git ls-files
      git ls-files --others --exclude-standard
    } | LC_ALL=C sort -u | while IFS= read -r p; do
      [ -e "$p" ] && printf '%s\n' "$p"
    done | git hash-object --stdin-paths
  ) | _sha256
}

status=0
for f in "${files[@]}"; do
  name="$(basename "$f")"
  bats_hash=$(git hash-object "$f")

  deps=()
  while IFS= read -r dep; do
    [ -n "$dep" ] && deps+=("$dep")
  done < <(deps_for "$name")

  if (( ${#deps[@]} )); then
    dep_hash=$(hash_paths "${deps[@]}")
  else
    dep_hash=$(hash_all)
  fi

  key=$(printf '%s|%s|%s\n' "$tool_hash" "$bats_hash" "$dep_hash" | _sha256)
  marker="$CACHE_DIR/$name.$key"

  if (( ! no_cache )) && [ -e "$marker" ]; then
    echo "SKIP $name (cached)"
    continue
  fi

  if bats "$f"; then
    : > "$marker"
  else
    status=1
  fi
done

exit "$status"
