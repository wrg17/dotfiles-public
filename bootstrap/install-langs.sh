#!/usr/bin/env bash
# Installs the latest stable version of each managed language and sets it as
# the global default. All managers run in parallel. Idempotent.
set -euo pipefail

LOG_DIR="$(mktemp -d)"
PIDS=()
NAMES=()

run_bg() {
  local name="$1"; shift
  NAMES+=("$name")
  ("$@" >"$LOG_DIR/$name.log" 2>&1) &
  PIDS+=("$!")
}

# ── Node (nvm) ────────────────────────────────────────────────────────────────

install_node() {
  export NVM_DIR="${NVM_DIR:-$HOME/.local/share/nvm}"
  [[ -s "$NVM_DIR/nvm.sh" ]] || { echo "nvm not installed — skipping"; return; }
  # shellcheck source=/dev/null
  source "$NVM_DIR/nvm.sh"
  if nvm current | grep -qvE 'none|system'; then
    echo "already active ($(nvm current)) — skipping"; return
  fi
  echo "Installing latest LTS node"
  nvm install --lts
  nvm alias default node
}

# ── Python (pyenv) ────────────────────────────────────────────────────────────

install_python() {
  command -v pyenv >/dev/null || { echo "pyenv not found — skipping"; return; }
  if [[ "$(pyenv global)" != "system" && -n "$(pyenv global)" ]]; then
    echo "already set to $(pyenv global) — skipping"; return
  fi
  local version
  version="$(pyenv install --list | grep -E '^\s+3\.[0-9]+\.[0-9]+$' | tail -1 | tr -d ' ')"
  echo "Installing python $version"
  pyenv install "$version"
  pyenv global "$version"
}

# ── Go (goenv) ────────────────────────────────────────────────────────────────

install_go() {
  command -v goenv >/dev/null || { echo "goenv not found — skipping"; return; }
  if goenv global 2>/dev/null | grep -qE '^[0-9]'; then
    echo "already set to $(goenv global) — skipping"; return
  fi
  local version
  version="$(goenv install --list | grep -E '^\s+[0-9]+\.[0-9]+\.[0-9]+$' | tail -1 | tr -d ' ')"
  echo "Installing go $version"
  goenv install "$version"
  goenv global "$version"
}

# ── Ruby (rbenv) ──────────────────────────────────────────────────────────────

install_ruby() {
  command -v rbenv >/dev/null || { echo "rbenv not found — skipping"; return; }
  if rbenv global 2>/dev/null | grep -qE '^[0-9]'; then
    echo "already set to $(rbenv global) — skipping"; return
  fi
  local version
  version="$(rbenv install --list | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | tail -1)"
  echo "Installing ruby $version"
  rbenv install "$version"
  rbenv global "$version"
}

# ── Java (jenv) ───────────────────────────────────────────────────────────────

install_java() {
  command -v jenv >/dev/null || { echo "jenv not found — skipping"; return; }
  if jenv global 2>/dev/null | grep -qE '^[0-9]'; then
    echo "already set to $(jenv global) — skipping"; return
  fi
  echo "Installing OpenJDK 21 (LTS)"
  sudo apt-get install -y --no-install-recommends openjdk-21-jdk
  local jdk_path
  jdk_path="$(update-java-alternatives -l 2>/dev/null | awk '/java-21/{print $3}' | head -1)"
  if [[ -z "$jdk_path" && -d /usr/lib/jvm/java-21-openjdk-amd64 ]]; then
    jdk_path=/usr/lib/jvm/java-21-openjdk-amd64
  fi
  if [[ -n "$jdk_path" ]]; then
    jenv add "$jdk_path" || true
    local jenv_version
    jenv_version="$(jenv versions --bare 2>/dev/null | awk '/^21\./' | head -1 || true)"
    [[ -n "$jenv_version" ]] && jenv global "$jenv_version"
  else
    echo "Could not locate JDK 21 path — add manually with: jenv add <path>"
  fi
}

# ── Run all in parallel ───────────────────────────────────────────────────────

run_bg node    install_node
run_bg python  install_python
run_bg go      install_go
run_bg ruby    install_ruby
run_bg java    install_java

echo "Installing languages in parallel (node, python, go, ruby, java)..."

failed=0
for i in "${!PIDS[@]}"; do
  name="${NAMES[$i]}"
  pid="${PIDS[$i]}"
  if wait "$pid"; then
    printf '  OK  %s\n' "$name"
  else
    printf ' ERR  %s\n' "$name"
    failed=1
  fi
  cat "$LOG_DIR/$name.log"
done

rm -rf "$LOG_DIR"

if [[ "$failed" -ne 0 ]]; then
  echo "One or more language installs failed." >&2
  exit 1
fi

echo "Language installation complete"
