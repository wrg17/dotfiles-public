#!/usr/bin/env bats

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
YAZI_DIR="$REPO_ROOT/yazi/.config/yazi"

# yazi doesn't expose a "config check" CLI mode (it silently starts with
# bad config), so functional testing collapses to: do the TOML files
# parse? Combined with daily use, that's the realistic failure mode.

@test "yazi: all TOML config files parse as valid TOML" {
  command -v python3 >/dev/null || skip "python3 not installed (need tomllib)"
  for f in yazi.toml keymap.toml theme.toml package.toml; do
    python3 -c "import tomllib,sys; tomllib.load(open('$YAZI_DIR/$f','rb'))" \
      || { echo "TOML parse error in: $f"; return 1; }
  done
}

@test "yazi: package.toml plugins are pinned to specific revisions (reproducible installs)" {
  # Each [[plugin.deps]] entry should have a rev and a hash — catches
  # someone adding a plugin without pinning, which would break reproducibility.
  command -v python3 >/dev/null || skip "python3 not installed"
  python3 - <<EOF || return 1
import tomllib
with open("$YAZI_DIR/package.toml", "rb") as f:
    pkg = tomllib.load(f)
deps = pkg.get("plugin", {}).get("deps", [])
assert deps, "no plugin.deps entries"
for d in deps:
    assert "use" in d, f"missing 'use' in {d}"
    assert "rev" in d, f"missing 'rev' in {d.get('use')}"
    assert "hash" in d, f"missing 'hash' in {d.get('use')}"
EOF
}
