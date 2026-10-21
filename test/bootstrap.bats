#!/usr/bin/env bats

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
BREWFILE="$REPO_ROOT/bootstrap/Brewfile"
APT_PKGS="$REPO_ROOT/bootstrap/apt-pkgs"
INSTALL_TOOLS="$REPO_ROOT/bootstrap/install-tools.sh"
INSTALL_LANGS="$REPO_ROOT/bootstrap/install-langs.sh"
ZSHRC="$REPO_ROOT/zsh/.config/zsh/.zshrc"
MAKEFILE="$REPO_ROOT/Makefile"
DOCTOR="$REPO_ROOT/bootstrap/doctor.sh"
BREW_BOTTLES="$REPO_ROOT/bootstrap/brew-bottles.sh"

# These tests read the manifests and bootstrap scripts as text. They never
# invoke a package manager and never inspect host state: a package this repo
# forgets to declare has to be visible in the repo itself, not in whichever
# machine happens to run the suite. The earlier `command -v X || skip "..."`
# pairs reported green both when X was installed and when nothing installed
# it, which is how zoxide and direnv stayed missing from every manifest.

# ── manifest lookups (exact, never substring) ─────────────────────────────────

# Anchored: a bare `grep -F watch` on the Brewfile would also accept a future
# brew "watchexec", and `grep -F bats` matches any line containing it.
brewfile_has() {
  grep -qE "^(brew|cask) \"$1\"\$" "$BREWFILE"
}

aptpkgs_has() {
  sed 's/#.*//' "$APT_PKGS" | tr -d '[:blank:]' | grep -qxF "$1"
}

install_tools_has() {
  grep -qE "^install_$1\(\) \{" "$INSTALL_TOOLS"
}

# ── test tooling ──────────────────────────────────────────────────────────────

@test "bootstrap: Brewfile declares the make test toolchain" {
  brewfile_has bats-core
  brewfile_has shellcheck
  brewfile_has actionlint
  brewfile_has expect
}

@test "bootstrap: apt-pkgs declares the make test toolchain" {
  aptpkgs_has bats
  aptpkgs_has shellcheck
  aptpkgs_has expect
  # actionlint has no apt package; apt-pkgs documents the go install instead.
  grep -qF 'actionlint' "$APT_PKGS"
}

# ── tools installed from upstream by install-tools.sh ─────────────────────────

@test "bootstrap: install-tools.sh owns the non-packaged tools" {
  install_tools_has starship
  install_tools_has neovim
  install_tools_has yazi
  install_tools_has nvm
  install_tools_has rustup
  install_tools_has sheldon
  install_tools_has tpm
}

# ── language version managers ─────────────────────────────────────────────────

@test "bootstrap: Brewfile declares the version managers" {
  brewfile_has pyenv
  brewfile_has goenv
  brewfile_has jenv
  brewfile_has rbenv
}

@test "bootstrap: install-tools.sh installs the version managers on Linux" {
  install_tools_has pyenv
  install_tools_has goenv
  install_tools_has jenv
  install_tools_has rbenv
}

@test "bootstrap: goenv clones from go-nv, not the dead go-env org" {
  grep -qF 'go-nv/goenv' "$INSTALL_TOOLS"
  ! grep -qF 'go-env/goenv' "$INSTALL_TOOLS"
}

# ── core tools ────────────────────────────────────────────────────────────────

@test "bootstrap: Brewfile declares the core tools" {
  brewfile_has tmux
  brewfile_has sheldon
  brewfile_has watch
  brewfile_has gh
}

@test "bootstrap: apt-pkgs declares the core tools" {
  aptpkgs_has tmux
  aptpkgs_has wezterm
  aptpkgs_has watch
}

@test "bootstrap: Brewfile declares the wezterm cask" {
  grep -qE '^cask "wezterm"$' "$BREWFILE"
}

# ── coreutils replacements ────────────────────────────────────────────────────

@test "bootstrap: install-tools.sh owns the ls/cat/find replacements" {
  # Moved out of the Brewfile: all three are Rust, so on a mac below
  # Homebrew's bottle floor `brew install eza` builds rust and llvm first.
  install_tools_has eza
  install_tools_has bat
  install_tools_has fd
}

@test "bootstrap: Brewfile does not declare the Rust coreutils replacements" {
  ! brewfile_has eza
  ! brewfile_has bat
  ! brewfile_has fd
}

@test "bootstrap: apt-pkgs declares the ls/cat/find replacements" {
  aptpkgs_has eza
  aptpkgs_has bat
  # Ubuntu ships fd as fd-find; .zshrc aliases around the rename.
  aptpkgs_has fd-find
  grep -qF "alias fd='fdfind'" "$ZSHRC"
}

# ── docker / colima ───────────────────────────────────────────────────────────

@test "bootstrap: Brewfile declares the docker CLI and colima" {
  brewfile_has colima
  brewfile_has docker
  brewfile_has docker-compose
  brewfile_has docker-buildx
}

@test "bootstrap: Brewfile does not declare Docker Desktop cask" {
  ! grep -qE '^cask "docker"$' "$BREWFILE"
}

@test "bootstrap: apt-pkgs declares the docker packages" {
  aptpkgs_has docker-ce
  aptpkgs_has docker-ce-cli
  aptpkgs_has docker-compose-plugin
}

# ── optional tools must not abort bootstrap ───────────────────────────────────

@test "install_eza: cannot abort bootstrap when the build fails" {
  # eza publishes no macOS binary, so Darwin builds the crate — and that build
  # does fail (palette does not compile on the pinned rustc). Under
  # set -euo pipefail an unguarded failure took install_bat and install_fd
  # down with it, leaving all three missing.
  run awk '/^install_eza\(\)/{fn=1} fn{print} fn && /^}/{fn=0}' "$INSTALL_TOOLS"
  echo "$output" | grep -qE 'if ! "\$cargo" install eza --locked'
  echo "$output" | grep -qF 'return 0'
  # no unguarded invocation at statement level
  ! echo "$output" | grep -qE '^  +"\$cargo" install eza$'
}

@test "install-tools.sh: the fragile crate build runs after the reliable binaries" {
  # Defence in depth behind the non-fatal guard: ordering alone would have
  # spared bat and fd.
  run awk '/^install_bat$/{b=NR} /^install_fd$/{f=NR} /^install_eza$/{e=NR} END{print (b && f && e && b<e && f<e) ? "ok" : "bad"}' "$INSTALL_TOOLS"
  [ "$output" = "ok" ]
}

# ── shell-integration coverage, derived from .zshrc ───────────────────────────

# Tools .zshrc hooks into shell startup, via the two forms it uses:
#   _initcache <tool> ...   and   eval "$(<tool> init ...)"
# Derived rather than hardcoded so adding a hook to .zshrc without declaring
# the tool anywhere fails here instead of at someone's next shell start.
zshrc_shell_integrations() {
  {
    grep -oE '_initcache [a-z0-9_-]+' "$ZSHRC" | awk '{print $2}'
    grep -oE 'eval "\$\([a-z0-9_-]+ init' "$ZSHRC" | sed -E 's/^eval "\$\(//; s/ init$//'
  } | sort -u
}

@test "bootstrap: the .zshrc shell-integration list is not vacuous" {
  # Without this, a .zshrc refactor that breaks the greps above would make the
  # two coverage tests pass over an empty set.
  run zshrc_shell_integrations
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | wc -w)" -ge 6 ]
  echo "$output" | grep -qx starship
  echo "$output" | grep -qx pyenv
  echo "$output" | grep -qx zoxide
}

@test "bootstrap: every tool .zshrc initializes is declared for macOS" {
  local tool missing=()
  for tool in $(zshrc_shell_integrations); do
    brewfile_has "$tool" || install_tools_has "$tool" || missing+=("$tool")
  done
  [ "${#missing[@]}" -eq 0 ] || {
    echo "hooked in .zshrc, declared in neither Brewfile nor install-tools.sh:"
    echo "  ${missing[*]}"
    return 1
  }
}

@test "bootstrap: every tool .zshrc initializes is declared for Linux" {
  local tool missing=()
  for tool in $(zshrc_shell_integrations); do
    aptpkgs_has "$tool" || install_tools_has "$tool" || missing+=("$tool")
  done
  [ "${#missing[@]}" -eq 0 ] || {
    echo "hooked in .zshrc, declared in neither apt-pkgs nor install-tools.sh:"
    echo "  ${missing[*]}"
    return 1
  }
}

# ── Homebrew source-build guard ───────────────────────────────────────────────

# Homebrew bottles only macOS versions at or above its support floor. Below it,
# brew builds from source — the whole dependency tree. Three call sites used to
# walk straight into that: `make upgrade`, `upd()`, and doctor.sh's advice.

@test "brew-bottles.sh: exists and is executable" {
  [[ -x "$BREW_BOTTLES" ]]
}

@test "brew-bottles.sh: reads the floor from Homebrew rather than hardcoding it" {
  grep -qF 'HOMEBREW_MACOS_OLDEST_SUPPORTED' "$BREW_BOTTLES"
  grep -qF 'brew --repository' "$BREW_BOTTLES"
}

@test "brew-bottles.sh: exits cleanly with a definite yes/no" {
  # Never crash and never hang: callers branch on the exit status, so a third
  # outcome would silently take the wrong branch.
  run "$BREW_BOTTLES"
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "brew-bottles.sh: non-macOS is always bottled" {
  # The cliff is macOS-only; apt and Linuxbrew have no equivalent.
  grep -qE '\[\[ "\$\(uname -s\)" == Darwin \]\] \|\| exit 0' "$BREW_BOTTLES"
}

@test "make upgrade: installs nothing via brew when bottles are unavailable" {
  # --no-upgrade was not enough: `brew bundle --no-upgrade` still INSTALLS
  # missing formulae, and on an unbottled mac installing eza/bat/fd pulled
  # rust and llvm and ran for an hour. The unbottled branch must only report.
  grep -qF 'bootstrap/brew-bottles.sh' "$MAKEFILE"
  ! grep -qF -- '--no-upgrade' "$MAKEFILE"
  grep -qF 'brew bundle check' "$MAKEFILE"
  # Exactly one unguarded `brew bundle` install, inside the bottled branch.
  run grep -cE 'brew bundle --file' "$MAKEFILE"
  [ "$output" = "1" ]
}

@test "install_java: does not brew-install a JDK when bottles are unavailable" {
  # Every mention of `brew install openjdk` must sit after the guard — the
  # hint text names the command too, so assert on absence of "bare" rather
  # than on a single line.
  run awk '/^install_java\(\)/{fn=1} fn && /brew-bottles\.sh/{guard=1} fn && /brew install openjdk/{print guard?"guarded":"bare"} fn && /^}/{fn=0}' "$INSTALL_LANGS"
  [ -n "$output" ]
  ! echo "$output" | grep -qx bare
}

@test "doctor.sh: does not recommend brew upgrade unconditionally" {
  grep -qF 'brew-bottles.sh' "$DOCTOR"
  # The bare recommendation must sit inside the bottled branch.
  run awk '/brew-bottles\.sh/{guard=1} /run: brew upgrade/{print guard?"guarded":"bare"}' "$DOCTOR"
  [ "$output" = "guarded" ]
}

@test "upd(): skips brew upgrade when bottles are unavailable" {
  run awk '/^upd\(\)/{fn=1} fn && /brew-bottles\.sh/{guard=1} fn && /brew update && brew upgrade/{print guard?"guarded":"bare"} fn && /^}/{fn=0}' "$ZSHRC"
  [ "$output" = "guarded" ]
}

# ── install-langs.sh portability ──────────────────────────────────────────────

@test "install-langs.sh: every apt-get call sits behind an OS branch" {
  # install_java ran `sudo apt-get` unconditionally, so `make upgrade` aborted
  # on macOS under set -e before it reached stow. Any function reaching for
  # apt-get has to consult $OS first.
  run awk '
    /^[a-z_]+\(\) \{/  { fn = $1; apt = 0; os = 0 }
    fn && /apt-get/    { apt = 1 }
    fn && /\$OS|uname/ { os = 1 }
    fn && /^\}/        { if (apt && !os) print fn; fn = "" }
  ' "$INSTALL_LANGS"
  [ "$status" -eq 0 ]
  [ -z "$output" ] || {
    echo "apt-get reachable on macOS in: $output"
    return 1
  }
}

@test "install-langs.sh: detects the OS" {
  grep -qE '^OS="\$\(uname -s\)"$' "$INSTALL_LANGS"
}

# ── colima-start script ────────────────────────────────────────────────────────

COLIMA_START="$REPO_ROOT/zsh/.local/bin/colima-start"

@test "colima-start: script exists and is executable" {
  [[ -x "$COLIMA_START" ]]
}

@test "colima-start: detects cpu via sysctl" {
  grep -q 'sysctl.*hw.logicalcpu' "$COLIMA_START"
}

@test "colima-start: detects memory via sysctl" {
  grep -q 'sysctl.*hw.memsize' "$COLIMA_START"
}

@test "colima-start: selects vm-type by macOS version" {
  grep -q 'sw_vers' "$COLIMA_START"
  grep -q 'vm_type' "$COLIMA_START"
}

@test "colima-start: enforces minimum cpu of 2" {
  grep -q 'cpu < 2' "$COLIMA_START"
}

@test "colima-start: enforces minimum memory of 2" {
  grep -q 'mem < 2' "$COLIMA_START"
}

# ── Fresh-machine prerequisites ───────────────────────────────────────────────
#
# Everything below went undeclared until a fresh-machine audit. The first two
# are the ones that actually broke a rebuild: `make install-linux` runs linux.sh
# and then calls `stow` directly, so an undeclared stow killed the install at
# that line, and linux.sh's chsh step is guarded on zsh existing, so a missing
# zsh silently left the login shell as bash.

@test "bootstrap: apt-pkgs declares stow — the Makefile calls it directly" {
  grep -qxF 'stow' "$APT_PKGS"
}

@test "bootstrap: apt-pkgs declares zsh — linux.sh chsh's to it" {
  grep -qxF 'zsh' "$APT_PKGS"
}

@test "bootstrap: apt-pkgs declares git" {
  grep -qxF 'git' "$APT_PKGS"
}

@test "bootstrap: apt-pkgs declares xclip, which the clip helper needs" {
  grep -qxF 'xclip' "$APT_PKGS"
}

@test "bootstrap: apt-pkgs declares the rootless Docker packages" {
  # Without these a rebuilt machine comes up on the system daemon, which moves
  # where volumes live and breaks the container-based volume dumps.
  for p in docker-ce-rootless-extras uidmap dbus-user-session; do
    grep -qxF "$p" "$APT_PKGS" || { echo "missing: $p"; return 1; }
  done
}

@test "bootstrap: linux.sh enables rootless Docker" {
  grep -q 'dockerd-rootless-setuptool.sh' "$REPO_ROOT/bootstrap/linux.sh"
  grep -q 'loginctl enable-linger' "$REPO_ROOT/bootstrap/linux.sh"
}

@test "bootstrap: apt-pkgs declares the NVIDIA toolkit whose repo linux.sh adds" {
  # The repo was being added and then never used.
  grep -q 'nvidia-container-toolkit' "$REPO_ROOT/bootstrap/linux.sh"
  grep -qxF 'nvidia-container-toolkit' "$APT_PKGS"
}

@test "bootstrap: apt-pkgs names no transitional ncurses package" {
  # libncursesw5-dev resolves on noble only as a virtual package.
  run grep -qxF 'libncursesw5-dev' "$APT_PKGS"
  [ "$status" -ne 0 ]
  grep -qxF 'libncurses-dev' "$APT_PKGS"
}

# Packages that come from the third-party repos linux.sh adds, so they are not
# resolvable until it has run. Checking them against a bare CI runner's apt
# fails for the wrong reason — the first version of the test below did exactly
# that. The test under it asserts linux.sh really does add a repo for each.
_third_party_pkgs() {
  cat <<'PKGS'
wezterm
docker-ce
docker-ce-cli
docker-ce-rootless-extras
containerd.io
docker-buildx-plugin
docker-compose-plugin
nvidia-container-toolkit
PKGS
}

@test "bootstrap: every base-archive package exists in apt" {
  command -v apt-cache >/dev/null || skip "not a Debian/Ubuntu system"
  # A stale or misspelt name here aborts `apt-get install` partway through a
  # fresh bootstrap, after some packages are already in.
  missing=""
  while read -r p; do
    _third_party_pkgs | grep -qxF "$p" && continue
    apt-cache show "$p" >/dev/null 2>&1 || missing="$missing $p"
  done < <(grep -vE '^\s*(#|$)' "$APT_PKGS")
  [ -z "$missing" ] || { echo "not resolvable from the base archive:$missing"; return 1; }
}

@test "bootstrap: linux.sh adds a repo for every third-party package" {
  # Otherwise the package is declared and simply never installable — which was
  # the case for nvidia-container-toolkit in reverse: repo added, never used.
  linux="$REPO_ROOT/bootstrap/linux.sh"
  declared=$(grep -vE '^\s*(#|$)' "$APT_PKGS")

  # Only check the ones actually declared, so dropping a package does not
  # require editing the helper list above.
  for p in $(_third_party_pkgs); do
    printf '%s\n' "$declared" | grep -qxF "$p" || continue
    case "$p" in
      wezterm)                  grep -q 'apt.fury.io/wez' "$linux" ;;
      nvidia-container-toolkit) grep -q 'libnvidia-container' "$linux" ;;
      *)                        grep -q 'download.docker.com' "$linux" ;;
    esac || { echo "$p is declared but linux.sh adds no repo providing it"; return 1; }
  done
}
