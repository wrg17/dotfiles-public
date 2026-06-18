#!/usr/bin/env bats
# Language EOL checks — run by upd() after package updates.
# Uses endoflife.date API; all tests skip gracefully when offline or no versions installed.

NVM_DIR="${NVM_DIR:-$HOME/.local/share/nvm}"
PYENV_ROOT="${PYENV_ROOT:-$HOME/.local/share/pyenv}"
GOENV_ROOT="${GOENV_ROOT:-$HOME/.local/share/goenv}"
RBENV_ROOT="${RBENV_ROOT:-$HOME/.local/share/rbenv}"
JENV_ROOT="$HOME/.jenv"

_eol_date() {
  local product="$1" cycle="$2"
  local response
  response="$(curl -sf --max-time 5 "https://endoflife.date/api/${product}/${cycle}.json" 2>/dev/null)" || {
    echo "unreachable"; return
  }
  python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('eol',''))" 2>/dev/null <<< "$response" || echo ""
}

# ── Python ────────────────────────────────────────────────────────────────────

@test "lang: all installed Python versions are supported" {
  [[ -d "$PYENV_ROOT/versions" ]] || skip "no pyenv versions installed"
  local today failed
  today="$(date +%Y-%m-%d)"
  failed=0
  for vdir in "$PYENV_ROOT/versions"/*/; do
    [[ -d "$vdir" ]] || continue
    v="$(basename "$vdir")"
    cycle="$(printf '%s' "$v" | grep -oE '^[0-9]+\.[0-9]+')"
    [[ -n "$cycle" ]] || continue
    eol="$(_eol_date "python" "$cycle")"
    [[ "$eol" == "unreachable" ]] && skip "endoflife.date unreachable"
    if [[ "$eol" != "false" && -n "$eol" && "$eol" < "$today" ]]; then
      echo "EOL: python $v (since $eol)" >&3
      failed=1
    fi
  done
  [[ $failed -eq 0 ]]
}

# ── Node ──────────────────────────────────────────────────────────────────────

@test "lang: all installed Node versions are supported" {
  [[ -d "$NVM_DIR/versions/node" ]] || skip "no nvm versions installed"
  local today failed
  today="$(date +%Y-%m-%d)"
  failed=0
  for vdir in "$NVM_DIR/versions/node"/*/; do
    [[ -d "$vdir" ]] || continue
    v="$(basename "$vdir")"; v="${v#v}"
    cycle="$(printf '%s' "$v" | grep -oE '^[0-9]+\.[0-9]+')"
    [[ -n "$cycle" ]] || continue
    eol="$(_eol_date "nodejs" "$cycle")"
    [[ "$eol" == "unreachable" ]] && skip "endoflife.date unreachable"
    if [[ "$eol" != "false" && -n "$eol" && "$eol" < "$today" ]]; then
      echo "EOL: node $v (since $eol)" >&3
      failed=1
    fi
  done
  [[ $failed -eq 0 ]]
}

# ── Go ────────────────────────────────────────────────────────────────────────

@test "lang: all installed Go versions are supported" {
  [[ -d "$GOENV_ROOT/versions" ]] || skip "no goenv versions installed"
  local today failed
  today="$(date +%Y-%m-%d)"
  failed=0
  for vdir in "$GOENV_ROOT/versions"/*/; do
    [[ -d "$vdir" ]] || continue
    v="$(basename "$vdir")"
    cycle="$(printf '%s' "$v" | grep -oE '^[0-9]+\.[0-9]+')"
    [[ -n "$cycle" ]] || continue
    eol="$(_eol_date "go" "$cycle")"
    [[ "$eol" == "unreachable" ]] && skip "endoflife.date unreachable"
    if [[ "$eol" != "false" && -n "$eol" && "$eol" < "$today" ]]; then
      echo "EOL: go $v (since $eol)" >&3
      failed=1
    fi
  done
  [[ $failed -eq 0 ]]
}

# ── Ruby ──────────────────────────────────────────────────────────────────────

@test "lang: all installed Ruby versions are supported" {
  [[ -d "$RBENV_ROOT/versions" ]] || skip "no rbenv versions installed"
  local today failed
  today="$(date +%Y-%m-%d)"
  failed=0
  for vdir in "$RBENV_ROOT/versions"/*/; do
    [[ -d "$vdir" ]] || continue
    v="$(basename "$vdir")"
    cycle="$(printf '%s' "$v" | grep -oE '^[0-9]+\.[0-9]+')"
    [[ -n "$cycle" ]] || continue
    eol="$(_eol_date "ruby" "$cycle")"
    [[ "$eol" == "unreachable" ]] && skip "endoflife.date unreachable"
    if [[ "$eol" != "false" && -n "$eol" && "$eol" < "$today" ]]; then
      echo "EOL: ruby $v (since $eol)" >&3
      failed=1
    fi
  done
  [[ $failed -eq 0 ]]
}

# ── Java ──────────────────────────────────────────────────────────────────────

@test "lang: all installed Java versions are supported" {
  [[ -d "$JENV_ROOT/versions" ]] || skip "no jenv versions installed"
  local today failed major seen
  today="$(date +%Y-%m-%d)"
  failed=0
  seen=""
  for vdir in "$JENV_ROOT/versions"/*/; do
    [[ -L "$vdir" ]] || continue
    v="$(basename "$vdir")"
    major="$(printf '%s' "$v" | grep -oE '^[0-9]+')"
    [[ -z "$major" ]] && continue
    case " $seen " in *" $major "*) continue ;; esac
    seen="$seen $major"
    eol="$(_eol_date "java" "$major")"
    [[ "$eol" == "unreachable" ]] && skip "endoflife.date unreachable"
    if [[ "$eol" != "false" && -n "$eol" && "$eol" < "$today" ]]; then
      echo "EOL: java $v (since $eol)" >&3
      failed=1
    fi
  done
  [[ $failed -eq 0 ]]
}
