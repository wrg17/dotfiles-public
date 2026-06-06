#!/usr/bin/env bash
# Advisory health check for your dotfiles environment.
# Prints warnings but always exits 0 — nothing is fatal here.

NVM_DIR="${NVM_DIR:-$HOME/.local/share/nvm}"
PYENV_ROOT="${PYENV_ROOT:-$HOME/.local/share/pyenv}"
GOENV_ROOT="${GOENV_ROOT:-$HOME/.local/share/goenv}"
JENV_ROOT="$HOME/.jenv"

WARNS=0
CHECKS=0
today="$(date +%Y-%m-%d)"

_warn()    { printf '  WARN  %s\n' "$*"; WARNS=$((WARNS + 1)); CHECKS=$((CHECKS + 1)); }
_ok()      { printf '    OK  %s\n' "$*"; CHECKS=$((CHECKS + 1)); }
_info()    { printf '  INFO  %s\n' "$*"; }
_section() { printf '\n── %s\n' "$*"; }

# ── Tool presence ──────────────────────────────────────────────────────────────

_section "Tool presence"
for tool in starship nvim yazi tmux zsh git stow watch docker; do
  if command -v "$tool" >/dev/null 2>&1; then
    _ok "$tool"
  else
    _warn "$tool not found in PATH"
  fi
done
if [[ -s "$NVM_DIR/nvm.sh" ]]; then
  _ok "nvm"
else
  _warn "nvm not found (expected at $NVM_DIR)"
fi

# ── Stow symlinks ──────────────────────────────────────────────────────────────

_section "Stow symlinks"
dangling=0
while IFS= read -r link; do
  _warn "dangling symlink: $link"
  dangling=$((dangling + 1))
done < <(find "$HOME/.config" "$HOME/.local" -maxdepth 4 -type l ! -exec test -e {} \; -print 2>/dev/null)
if [[ $dangling -eq 0 ]]; then
  _ok "no dangling symlinks"
fi

# ── Homebrew (macOS only) ──────────────────────────────────────────────────────

if [[ "$(uname -s)" == Darwin ]]; then
  _section "Colima"
  if ! command -v colima >/dev/null 2>&1; then
    _warn "colima not found — run: brew install colima docker"
  else
    _ok "colima"
    status="$(colima status 2>&1)" || true
    if printf '%s' "$status" | grep -q 'running'; then
      _ok "colima running"
    else
      _info "colima installed but not running — start with: colima start"
    fi
    if ! command -v colima-start >/dev/null 2>&1; then
      _warn "colima-start script not in PATH — re-run: stow zsh"
    else
      _ok "colima-start script available"
    fi
  fi
fi

if [[ "$(uname -s)" == Darwin ]]; then
  _section "Homebrew"
  if ! command -v brew >/dev/null 2>&1; then
    _warn "brew not found"
  else
    outdated="$(brew outdated 2>/dev/null)"
    if [[ -n "$outdated" ]]; then
      while IFS= read -r pkg; do _info "  outdated: $pkg"; done <<< "$outdated"
      count="$(printf '%s\n' "$outdated" | wc -l | tr -d ' ')"
      _warn "${count} outdated package(s) — run: brew upgrade"
    else
      _ok "all brew packages up to date"
    fi
    if brew doctor 2>&1 | grep -q 'Your system is ready to brew'; then
      _ok "brew doctor clean"
    else
      _warn "brew doctor reported issues — run: brew doctor"
    fi
  fi
fi

# ── Language version managers ──────────────────────────────────────────────────

_section "Language version managers"
if command -v pyenv >/dev/null 2>&1; then _ok "pyenv"; else _warn "pyenv not found"; fi
if command -v goenv >/dev/null 2>&1; then _ok "goenv"; else _warn "goenv not found"; fi
if command -v jenv  >/dev/null 2>&1; then _ok "jenv";  else _warn "jenv not found"; fi
if command -v rustup >/dev/null 2>&1; then
  rust_check="$(rustup check 2>/dev/null)" || rust_check=""
  if printf '%s' "$rust_check" | grep -q "Update available"; then
    _warn "rustup — update available, run: rustup update"
  else
    _ok "rustup"
  fi
else
  _info "rustup not found (optional)"
fi

# ── Language EOL ───────────────────────────────────────────────────────────────

_section "Language EOL"

if ! command -v python3 >/dev/null 2>&1; then
  _info "python3 not found — skipping EOL checks (needed for JSON parsing)"
else

  _eol_check() {
    local product="$1" label="$2" cycle="$3"
    local response eol
    response="$(curl -sf --max-time 5 "https://endoflife.date/api/${product}/${cycle}.json" 2>/dev/null)" || {
      _info "${label} — could not reach endoflife.date"
      return
    }
    eol="$(python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('eol',''))" 2>/dev/null <<< "$response")" || return
    if [[ "$eol" == "false" || -z "$eol" ]]; then
      _ok "${label} — supported"
    elif [[ "$eol" < "$today" ]]; then
      _warn "${label} — EOL since ${eol}"
    else
      _ok "${label} — supported until ${eol}"
    fi
  }

  # Python (pyenv)
  found=0
  if [[ -d "$PYENV_ROOT/versions" ]]; then
    for vdir in "$PYENV_ROOT/versions"/*/; do
      [[ -d "$vdir" ]] || continue
      v="$(basename "$vdir")"
      cycle="$(printf '%s' "$v" | grep -oE '^[0-9]+\.[0-9]+')"
      [[ -n "$cycle" ]] || continue
      _eol_check "python" "python $v" "$cycle"
      found=1
    done
  fi
  [[ $found -eq 0 ]] && _info "python — no pyenv versions installed"

  # Node (nvm)
  found=0
  if [[ -d "$NVM_DIR/versions/node" ]]; then
    for vdir in "$NVM_DIR/versions/node"/*/; do
      [[ -d "$vdir" ]] || continue
      v="$(basename "$vdir")"; v="${v#v}"
      cycle="$(printf '%s' "$v" | grep -oE '^[0-9]+\.[0-9]+')"
      [[ -n "$cycle" ]] || continue
      _eol_check "nodejs" "node $v" "$cycle"
      found=1
    done
  fi
  [[ $found -eq 0 ]] && _info "node — no nvm versions installed"

  # Go (goenv)
  found=0
  if [[ -d "$GOENV_ROOT/versions" ]]; then
    for vdir in "$GOENV_ROOT/versions"/*/; do
      [[ -d "$vdir" ]] || continue
      v="$(basename "$vdir")"
      cycle="$(printf '%s' "$v" | grep -oE '^[0-9]+\.[0-9]+')"
      [[ -n "$cycle" ]] || continue
      _eol_check "go" "go $v" "$cycle"
      found=1
    done
  fi
  [[ $found -eq 0 ]] && _info "go — no goenv versions installed"

  # Java (jenv) — deduplicate by major version
  found=0
  seen_java=""
  if [[ -d "$JENV_ROOT/versions" ]]; then
    for vdir in "$JENV_ROOT/versions"/*/; do
      [[ -L "$vdir" ]] || continue
      v="$(basename "$vdir")"
      major="$(printf '%s' "$v" | grep -oE '^[0-9]+')"
      [[ -z "$major" ]] && continue
      case " $seen_java " in *" $major "*) continue ;; esac
      seen_java="$seen_java $major"
      _eol_check "java" "java $v" "$major"
      found=1
    done
  fi
  [[ $found -eq 0 ]] && _info "java — no jenv versions installed"

fi  # end python3 check

# ── JetBrains ──────────────────────────────────────────────────────────────────

_section "JetBrains"

tbx_scripts=""
for d in \
    "$HOME/Library/Application Support/JetBrains/Toolbox/scripts" \
    "$HOME/.local/share/JetBrains/Toolbox/scripts"; do
  [[ -d "$d" ]] && tbx_scripts="$d" && break
done

case "$(uname -s)" in
  Darwin) jb_root="$HOME/Library/Application Support/JetBrains" ;;
  *)      jb_root="$HOME/.config/JetBrains" ;;
esac

if [[ -z "$tbx_scripts" ]]; then
  _info "Toolbox not found — skipping JetBrains checks"
else
  _ok "Toolbox installed"

  # List IDEs installed via Toolbox
  ide_count=0
  for script in "$tbx_scripts"/*; do
    [[ -f "$script" ]] || continue
    _ok "IDE: $(basename "$script")"
    ide_count=$((ide_count + 1))
  done
  [[ $ide_count -eq 0 ]] && _info "no IDEs installed via Toolbox"

  # Check shared config symlinks are not dangling
  if [[ -d "$jb_root" ]]; then
    broken=0
    for product_dir in "$jb_root"/*/; do
      [[ -d "$product_dir" ]] || continue
      pname="$(basename "$product_dir")"
      [[ "$pname" == "Toolbox" || "$pname" == "consentOptions" ]] && continue
      for check in keymaps colors codestyles; do
        if [[ -L "${product_dir}${check}" ]] && ! [[ -e "${product_dir}${check}" ]]; then
          _warn "broken config symlink in ${pname}/${check} — run: bootstrap/link-jetbrains.sh"
          broken=$((broken + 1))
        fi
      done
    done
    [[ $broken -eq 0 ]] && _ok "JetBrains config symlinks valid"
  fi
fi

# ── Summary ────────────────────────────────────────────────────────────────────

printf '\n── Summary ──────────────────────────────────────────────────────────────────\n'
printf '%d check(s), %d warning(s)\n' "$CHECKS" "$WARNS"

# Send a macOS notification when running non-interactively (e.g. launchd) and warnings exist
if [[ $WARNS -gt 0 && "$(uname -s)" == Darwin ]] && ! [[ -t 1 ]] && command -v osascript >/dev/null 2>&1; then
  osascript -e "display notification \"${WARNS} warning(s) found — run: make doctor\" with title \"dotfiles health check\""
fi

exit 0
