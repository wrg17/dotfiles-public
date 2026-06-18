#!/usr/bin/env bats

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
ZSHENV="$REPO_ROOT/zsh/.zshenv"
ZSHRC="$REPO_ROOT/zsh/.config/zsh/.zshrc"
BIN="$REPO_ROOT/zsh/.local/bin"
PLUGINS_TOML="$REPO_ROOT/sheldon/.config/sheldon/plugins.toml"

# ── Helpers ────────────────────────────────────────────────────────────────────

setup() {
  BATS_TMPDIR="$(mktemp -d)"
  CACHE_DIR="$BATS_TMPDIR/cache"
  mkdir -p "$CACHE_DIR/zsh"
  # Pre-touch compdump so compinit uses the fast path and doesn't rescan every test
  touch "$CACHE_DIR/zsh/zcompdump"
}

teardown() {
  rm -rf "$BATS_TMPDIR"
}

# Run cmd in a non-interactive zsh with both dotfiles loaded.
# Commands are written to a temp file and sourced so that zsh reads the file
# line-by-line — this is the only way aliases defined by the sourced dotfiles
# are visible to commands that follow in the same zsh session.
_zsh() {
  local tmp rc
  tmp="$(mktemp "$BATS_TMPDIR/zsh-XXXXXX.zsh")"
  {
    printf "source '%s'\n" "$ZSHENV"
    printf "{ source '%s'; } 2>/dev/null\n" "$ZSHRC"
    printf '%s\n' "$*"
  } > "$tmp"
  env TMUX=t XDG_CACHE_HOME="$CACHE_DIR" zsh -c "source '$tmp'"
  rc=$?
  rm -f "$tmp"
  return $rc
}

# Run cmd with only .zshenv sourced.
_zshenv() {
  zsh -c "source '${ZSHENV}'; $*"
}

# Spawn an interactive zsh via expect (provides a real PTY so the
# [[ -o interactive ]] && [[ -t 0 ]] && [[ -t 1 ]] guard can fire).
# $1 — extra KEY=VALUE env pairs passed to spawn
# Side-effect: writes $BATS_TMPDIR/tmux (fake) and checks $BATS_TMPDIR/.tmux_launched.
_guard_test() {
  local extra_env="$1"
  local zdotdir="$BATS_TMPDIR/zdotdir"
  mkdir -p "$zdotdir"

  # Fake tmux: just marks itself called, then exits cleanly
  printf '#!/bin/sh\ntouch "%s/.tmux_launched"\n' "$BATS_TMPDIR" \
    > "$BATS_TMPDIR/tmux"
  chmod +x "$BATS_TMPDIR/tmux"

  # Stub slow-starting tools so shell init completes within the expect timeout
  local stub
  for stub in pyenv goenv jenv rbenv starship; do
    printf '#!/bin/sh\n' > "$BATS_TMPDIR/$stub"
    chmod +x "$BATS_TMPDIR/$stub"
  done

  # Startup file: load real config, clear precmd hooks, set a known prompt
  cat > "$zdotdir/.zshrc" <<RCEOF
{ source '${ZSHENV}'; source '${ZSHRC}'; } 2>/dev/null
precmd_functions=()
PROMPT='ZSHTEST\$ '
RCEOF

  expect -c "
    set timeout 30
    spawn env PATH=\"${BATS_TMPDIR}:\$env(PATH)\" \
               XDG_CACHE_HOME=\"${CACHE_DIR}\" \
               ZDOTDIR=\"${zdotdir}\" \
               ${extra_env} \
               zsh -i
    expect {
      \"ZSHTEST\"  { send \"exit\r\"; expect eof; exit 0 }
      \" % \"      { send \"exit\r\"; expect eof; exit 0 }
      \" \\\$ \"   { send \"exit\r\"; expect eof; exit 0 }
      eof          { exit 2 }
      timeout      { exit 3 }
    }
  " >/dev/null 2>&1
}

# ── .zshenv: XDG base directories — verify values in a live shell ──────────────

@test "zshenv: XDG_CONFIG_HOME resolves to ~/.config" {
  run _zshenv 'printf "%s" "$XDG_CONFIG_HOME"'
  [ "$status" -eq 0 ]
  [[ "$output" == "$HOME/.config" ]]
}

@test "zshenv: XDG_DATA_HOME resolves to ~/.local/share" {
  run _zshenv 'printf "%s" "$XDG_DATA_HOME"'
  [ "$status" -eq 0 ]
  [[ "$output" == "$HOME/.local/share" ]]
}

@test "zshenv: XDG_CACHE_HOME resolves to ~/.cache" {
  run _zshenv 'printf "%s" "$XDG_CACHE_HOME"'
  [ "$status" -eq 0 ]
  [[ "$output" == "$HOME/.cache" ]]
}

@test "zshenv: XDG_STATE_HOME resolves to ~/.local/state" {
  run _zshenv 'printf "%s" "$XDG_STATE_HOME"'
  [ "$status" -eq 0 ]
  [[ "$output" == "$HOME/.local/state" ]]
}

@test "zshenv: ZDOTDIR is inside XDG_CONFIG_HOME" {
  run _zshenv 'printf "%s" "$ZDOTDIR"'
  [ "$status" -eq 0 ]
  [[ "$output" == *"/.config/zsh" ]]
}

@test "zshenv: HISTFILE is inside XDG_STATE_HOME" {
  run _zshenv 'printf "%s" "$HISTFILE"'
  [ "$status" -eq 0 ]
  [[ "$output" == *"/.local/state/"* ]]
}

@test "zshenv: CARGO_HOME is inside XDG_DATA_HOME" {
  run _zshenv 'printf "%s" "$CARGO_HOME"'
  [ "$status" -eq 0 ]
  [[ "$output" == *"/.local/share/"* ]]
}

@test "zshenv: NVM_DIR is inside XDG_DATA_HOME" {
  run _zshenv 'printf "%s" "$NVM_DIR"'
  [ "$status" -eq 0 ]
  [[ "$output" == *"/.local/share/"* ]]
}

@test "zshenv: non-interactive shell finds nvm's default node/npm" {
  local nvm_dir="${NVM_DIR:-$HOME/.local/share/nvm}"
  [[ -d "$nvm_dir/versions/node" ]] || skip "no nvm versions installed"
  [[ -f "$nvm_dir/alias/default" ]] || skip "no nvm default alias set"
  run _zshenv 'command -v npm'
  [ "$status" -eq 0 ]
  [[ "$output" == *"nvm/versions/node"* ]]
}

@test "zshenv: RBENV_ROOT is inside XDG_DATA_HOME" {
  run _zshenv 'printf "%s" "$RBENV_ROOT"'
  [ "$status" -eq 0 ]
  [[ "$output" == *"/.local/share/"* ]]
}

@test "zshenv: RUSTUP_HOME is inside XDG_DATA_HOME" {
  run _zshenv 'printf "%s" "$RUSTUP_HOME"'
  [ "$status" -eq 0 ]
  [[ "$output" == *"/.local/share/"* ]]
}

@test "zshenv: EDITOR is nvim" {
  run _zshenv 'printf "%s" "$EDITOR"'
  [ "$status" -eq 0 ]
  [[ "$output" == "nvim" ]]
}

@test "zshenv: VISUAL is nvim" {
  run _zshenv 'printf "%s" "$VISUAL"'
  [ "$status" -eq 0 ]
  [[ "$output" == "nvim" ]]
}

@test "zshenv: HOMEBREW_PREFIX is set when brew is installed" {
  command -v brew >/dev/null || skip "brew not installed"
  run _zshenv '[[ -n "$HOMEBREW_PREFIX" ]] && echo ok'
  [ "$status" -eq 0 ]
  [[ "$output" == "ok" ]]
}

@test "zshenv: does not source oh-my-zsh" {
  run grep 'oh-my-zsh.sh' "$ZSHENV"
  [ "$status" -ne 0 ]
}

@test "zshenv: does not define plugins array" {
  run grep '^plugins=' "$ZSHENV"
  [ "$status" -ne 0 ]
}

# ── .zshrc: key bindings (vi mode) ─────────────────────────────────────────────

@test "zshrc: vi mode is active (viins keymap loaded)" {
  run _zsh 'bindkey -lL main'
  [ "$status" -eq 0 ]
  [[ "$output" == *"viins"* ]]
}

@test "zshrc: insert mode preserves ^a as beginning-of-line" {
  run _zsh 'bindkey -M viins "^a"'
  [ "$status" -eq 0 ]
  [[ "$output" == *"beginning-of-line"* ]]
}

@test "zshrc: insert mode preserves ^e as end-of-line" {
  run _zsh 'bindkey -M viins "^e"'
  [ "$status" -eq 0 ]
  [[ "$output" == *"end-of-line"* ]]
}

# ── .zshrc: PATH ───────────────────────────────────────────────────────────────

@test "zshrc: PATH has no duplicate /usr/local/bin (typeset -U dedup)" {
  run _zsh 'printf "%s" "$PATH" | tr : "\n" | grep -c "^/usr/local/bin$"'
  [ "$status" -eq 0 ]
  [[ "$output" == "1" ]]
}

# ── .zshrc: history ────────────────────────────────────────────────────────────

@test "zshrc: HISTSIZE is 50000" {
  run _zsh 'printf "%s" "$HISTSIZE"'
  [ "$status" -eq 0 ]
  [[ "$output" == "50000" ]]
}

@test "zshrc: SAVEHIST is 50000" {
  run _zsh 'printf "%s" "$SAVEHIST"'
  [ "$status" -eq 0 ]
  [[ "$output" == "50000" ]]
}

# ── Aliases: editor ────────────────────────────────────────────────────────────

@test "alias: vim expands to nvim" {
  run _zsh 'alias vim'
  [ "$status" -eq 0 ]
  [[ "$output" == *"nvim"* ]]
}

@test "alias: vi expands to nvim" {
  run _zsh 'alias vi'
  [ "$status" -eq 0 ]
  [[ "$output" == *"nvim"* ]]
}

# ── Aliases: safety ────────────────────────────────────────────────────────────

@test "alias: rm has -i flag" {
  run _zsh 'alias rm'
  [ "$status" -eq 0 ]
  [[ "$output" == *"-i"* ]]
}

@test "alias: cp has -i flag" {
  run _zsh 'alias cp'
  [ "$status" -eq 0 ]
  [[ "$output" == *"-i"* ]]
}

@test "alias: mv has -i flag" {
  run _zsh 'alias mv'
  [ "$status" -eq 0 ]
  [[ "$output" == *"-i"* ]]
}

# ── Aliases: config shortcuts ──────────────────────────────────────────────────

@test "alias: szsh expands to exec zsh" {
  run _zsh 'alias szsh'
  [ "$status" -eq 0 ]
  [[ "$output" == *"exec zsh"* ]]
}

@test "alias: zshrc opens zshrc in nvim" {
  run _zsh 'alias zshrc'
  [ "$status" -eq 0 ]
  [[ "$output" == *"nvim"* ]]
}

@test "alias: weztermcfg opens wezterm.lua in nvim" {
  run _zsh 'alias weztermcfg'
  [ "$status" -eq 0 ]
  [[ "$output" == *"nvim"* && "$output" == *"wezterm"* ]]
}

@test "alias: starshipcfg opens starship.toml in nvim" {
  run _zsh 'alias starshipcfg'
  [ "$status" -eq 0 ]
  [[ "$output" == *"nvim"* && "$output" == *"starship"* ]]
}

@test "alias: tmuxcfg opens tmux.conf in nvim" {
  run _zsh 'alias tmuxcfg'
  [ "$status" -eq 0 ]
  [[ "$output" == *"nvim"* && "$output" == *"tmux"* ]]
}

# ── Aliases: clipboard ─────────────────────────────────────────────────────────

@test "alias: clipout is pbpaste on macOS" {
  [[ "$OSTYPE" == darwin* ]] || skip "darwin only"
  run _zsh 'alias clipout'
  [ "$status" -eq 0 ]
  [[ "$output" == *"pbpaste"* ]]
}

@test "alias: venv activates .venv in cwd" {
  run _zsh 'alias venv'
  [ "$status" -eq 0 ]
  [[ "$output" == *".venv/bin/activate"* ]]
}

# ── Aliases: git — expansion ──────────────────────────────────────────────────

@test "alias: gs expands to git status -sb" {
  run _zsh 'alias gs'
  [ "$status" -eq 0 ]
  [[ "$output" == *"git status"* && "$output" == *"-sb"* ]]
}

@test "alias: glg expands to git log with --graph" {
  run _zsh 'alias glg'
  [ "$status" -eq 0 ]
  [[ "$output" == *"git log"* && "$output" == *"--graph"* ]]
}

@test "alias: gca expands to git commit --amend --no-edit" {
  run _zsh 'alias gca'
  [ "$status" -eq 0 ]
  [[ "$output" == *"git commit --amend"* ]]
}

@test "alias: gwip expands to git add -A and commit" {
  run _zsh 'alias gwip'
  [ "$status" -eq 0 ]
  [[ "$output" == *"git add"* && "$output" == *"git commit"* ]]
}

# ── Aliases: git — functional ─────────────────────────────────────────────────

@test "alias: gs runs git status and shows branch status line" {
  git -C "$BATS_TMPDIR" init -q
  run _zsh "cd '$BATS_TMPDIR'; gs"
  [ "$status" -eq 0 ]
  # git status -sb always begins the branch line with ##
  [[ "$output" == "##"* ]]
}

@test "alias: glg runs git log and shows commit graph" {
  git -C "$BATS_TMPDIR" init -q
  git -C "$BATS_TMPDIR" \
    -c user.email=t@t.com -c user.name=T -c commit.gpgSign=false \
    commit --allow-empty -m "initial" -q
  run _zsh "cd '$BATS_TMPDIR'; glg"
  [ "$status" -eq 0 ]
  [[ "$output" == *"initial"* ]]
}

# ── Aliases: docker ────────────────────────────────────────────────────────────

@test "alias: dps expands to docker ps with format table" {
  run _zsh 'alias dps'
  [ "$status" -eq 0 ]
  [[ "$output" == *"docker ps"* && "$output" == *"format"* ]]
}

@test "alias: dex expands to docker exec -it" {
  run _zsh 'alias dex'
  [ "$status" -eq 0 ]
  [[ "$output" == *"docker exec"* && "$output" == *"-it"* ]]
}

@test "alias: dlog expands to docker logs -f" {
  run _zsh 'alias dlog'
  [ "$status" -eq 0 ]
  [[ "$output" == *"docker logs"* && "$output" == *"-f"* ]]
}

@test "alias: dprune expands to docker system prune" {
  run _zsh 'alias dprune'
  [ "$status" -eq 0 ]
  [[ "$output" == *"docker system prune"* ]]
}

# ── Aliases: system ────────────────────────────────────────────────────────────

@test "alias: gpu expands to nvidia-smi when nvidia-smi is installed" {
  command -v nvidia-smi >/dev/null || skip "nvidia-smi not installed"
  run _zsh 'alias gpu'
  [ "$status" -eq 0 ]
  [[ "$output" == *"nvidia-smi"* ]]
}

@test "alias: ports expands to ss -tulpn when ss is installed" {
  command -v ss >/dev/null || skip "ss not installed"
  run _zsh 'alias ports'
  [ "$status" -eq 0 ]
  [[ "$output" == *"ss"* && "$output" == *"-tulpn"* ]]
}

@test "alias: myip runs curl to fetch external IP" {
  run _zsh 'alias myip'
  [ "$status" -eq 0 ]
  [[ "$output" == *"curl"* ]]
}

# ── Aliases: dotfiles ──────────────────────────────────────────────────────────

@test "alias: dot changes directory to DOTFILES" {
  # Override DOTFILES with a real temp dir so the test works in environments
  # (e.g. CI runners) where $HOME/dotfiles doesn't exist.
  local fake="$BATS_TMPDIR/fake-dotfiles"
  mkdir -p "$fake"
  run _zsh "DOTFILES='$fake'; dot && pwd"
  [ "$status" -eq 0 ]
  [[ "$output" == *"fake-dotfiles"* ]]
}

# ── Functions: mkcd ────────────────────────────────────────────────────────────

@test "function: mkcd creates directory and enters it" {
  local newdir="$BATS_TMPDIR/test_mkcd"
  run _zsh "mkcd '$newdir' && pwd"
  [ "$status" -eq 0 ]
  [[ "$output" == "$newdir" ]]
  [ -d "$newdir" ]
}

@test "function: mkcd creates nested path in one call" {
  local newdir="$BATS_TMPDIR/a/b/c"
  run _zsh "mkcd '$newdir' && pwd"
  [ "$status" -eq 0 ]
  [[ "$output" == "$newdir" ]]
}

# ── Functions: extract ─────────────────────────────────────────────────────────

@test "function: extract unpacks .tar.gz and recovers file content" {
  printf 'archive content\n' > "$BATS_TMPDIR/file.txt"
  tar -czf "$BATS_TMPDIR/archive.tar.gz" -C "$BATS_TMPDIR" file.txt
  rm "$BATS_TMPDIR/file.txt"
  run _zsh "cd '$BATS_TMPDIR'; extract archive.tar.gz; cat file.txt"
  [ "$status" -eq 0 ]
  [[ "$output" == *"archive content"* ]]
}

@test "function: extract unpacks .zip and recovers file content" {
  command -v zip >/dev/null || skip "zip not installed"
  printf 'zip content\n' > "$BATS_TMPDIR/file.txt"
  (cd "$BATS_TMPDIR" && zip -q archive.zip file.txt && rm file.txt)
  run _zsh "cd '$BATS_TMPDIR'; extract archive.zip; cat file.txt"
  [ "$status" -eq 0 ]
  [[ "$output" == *"zip content"* ]]
}

@test "function: extract prints usage and exits non-zero with no argument" {
  run _zsh 'extract'
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage"* ]]
}

@test "function: extract exits non-zero for unrecognised extension" {
  printf 'data\n' > "$BATS_TMPDIR/file.xyz"
  run _zsh "cd '$BATS_TMPDIR'; extract file.xyz"
  [ "$status" -ne 0 ]
}

# ── Functions: mkvenv ──────────────────────────────────────────────────────────

@test "function: mkvenv creates .venv with a Python binary" {
  command -v python3 >/dev/null || skip "python3 not installed"
  # mkvenv also calls 'source .venv/bin/activate'; that may be a no-op in
  # non-interactive zsh, but the venv creation must succeed.
  env TMUX=t XDG_CACHE_HOME="$CACHE_DIR" zsh -c \
    "{ source '${ZSHENV}'; source '${ZSHRC}'; } 2>/dev/null
     cd '$BATS_TMPDIR'; mkvenv" 2>/dev/null || true
  [ -f "$BATS_TMPDIR/.venv/bin/python" ]
}

# ── Functions: clipall ─────────────────────────────────────────────────────────

@test "function: clipall pipes command output to clip" {
  local received="$BATS_TMPDIR/.clip_received"
  # Override clip as a shell function so PATH ordering can't shadow it
  _zsh "clip() { cat > '$received'; }; clipall printf 'hello world'" 2>/dev/null || true
  [ -f "$received" ]
  [[ "$(cat "$received")" == *"hello world"* ]]
}

# ── Functions: dotfiles helpers ────────────────────────────────────────────────

@test "function: dots() is defined and wraps stow" {
  run _zsh 'functions dots'
  [ "$status" -eq 0 ]
  [[ "$output" == *"stow"* ]]
}

@test "function: dotsoff() is defined and wraps stow -D" {
  run _zsh 'functions dotsoff'
  [ "$status" -eq 0 ]
  [[ "$output" == *"stow"* && "$output" == *"-D"* ]]
}

@test "function: dotsdry() is defined and wraps stow -n" {
  run _zsh 'functions dotsdry'
  [ "$status" -eq 0 ]
  [[ "$output" == *"stow"* && "$output" == *"-n"* ]]
}

@test "function: dotsync() is defined and uses git push" {
  run _zsh 'functions dotsync'
  [ "$status" -eq 0 ]
  [[ "$output" == *"git push"* ]]
}

@test "function: y() is defined and calls yazi" {
  run _zsh 'functions y'
  [ "$status" -eq 0 ]
  [[ "$output" == *"yazi"* ]]
}

# ── NVM lazy-load ──────────────────────────────────────────────────────────────

@test "nvm lazy-load: nvm.sh is not sourced at shell startup" {
  local nvm_dir="$BATS_TMPDIR/nvm"
  local marker="$BATS_TMPDIR/.nvm_sourced"
  mkdir -p "$nvm_dir"
  printf 'touch "%s"\n' "$marker" > "$nvm_dir/nvm.sh"

  # NVM_DIR must be overridden AFTER .zshenv sources (which unconditionally
  # sets it from XDG_DATA_HOME) and BEFORE .zshrc runs (which wires the stubs).
  env TMUX=t XDG_CACHE_HOME="$CACHE_DIR" \
    zsh -c "source '${ZSHENV}'
            NVM_DIR='${nvm_dir}'
            source '${ZSHRC}' 2>/dev/null
            echo done" >/dev/null

  [ ! -f "$marker" ]
}

@test "nvm lazy-load: calling nvm triggers nvm.sh source" {
  local nvm_dir="$BATS_TMPDIR/nvm"
  local marker="$BATS_TMPDIR/.nvm_sourced"
  mkdir -p "$nvm_dir"
  printf 'touch "%s"\nnvm() { :; }\n' "$marker" > "$nvm_dir/nvm.sh"

  env TMUX=t XDG_CACHE_HOME="$CACHE_DIR" \
    zsh -c "source '${ZSHENV}'
            NVM_DIR='${nvm_dir}'
            source '${ZSHRC}' 2>/dev/null
            nvm" 2>/dev/null || true

  [ -f "$marker" ]
}

# ── Tool integrations ──────────────────────────────────────────────────────────

@test "zshrc: zoxide init registers __zoxide_z when zoxide installed" {
  command -v zoxide >/dev/null || skip "zoxide not installed"
  run _zsh 'type __zoxide_z 2>/dev/null && echo loaded || echo missing'
  [ "$status" -eq 0 ]
  [[ "$output" == "loaded" ]]
}

@test "zshrc: direnv hook registers _direnv_hook when direnv installed" {
  command -v direnv >/dev/null || skip "direnv not installed"
  run _zsh 'type _direnv_hook 2>/dev/null && echo loaded || echo missing'
  [ "$status" -eq 0 ]
  [[ "$output" == "loaded" ]]
}

@test "zshrc: sheldon is invoked to load plugins when installed" {
  command -v sheldon >/dev/null || skip "sheldon not installed"
  _zsh 'true' >/dev/null 2>&1 || true
  # _initcache writes sheldon source output to this cache file when sheldon runs
  [ -f "$CACHE_DIR/zsh/sheldon.zsh" ]
}

# ── Sheldon plugin declarations ────────────────────────────────────────────────

@test "sheldon: zsh-syntax-highlighting plugin is declared" {
  grep -q 'zsh-syntax-highlighting' "$PLUGINS_TOML"
}

@test "sheldon: history-substring-search plugin is declared" {
  grep -q 'history-substring-search' "$PLUGINS_TOML"
}

# ── Local overrides ────────────────────────────────────────────────────────────

@test "zshrc: sources .zshrc.local when present" {
  local zdotdir="$BATS_TMPDIR/zdotdir"
  mkdir -p "$zdotdir"
  printf 'export ZSHRC_LOCAL_LOADED=1\n' > "$zdotdir/.zshrc.local"

  # Source zshenv first (sets ZDOTDIR to real config dir), then override ZDOTDIR
  # to our temp dir so the zshrc's local-override check finds our test file.
  run env TMUX=t XDG_CACHE_HOME="$CACHE_DIR" \
    zsh -c "source '${ZSHENV}'
            ZDOTDIR='$zdotdir'
            source '${ZSHRC}' 2>/dev/null
            printf '%s' \"\$ZSHRC_LOCAL_LOADED\""
  [ "$status" -eq 0 ]
  [[ "$output" == "1" ]]
}

# ── Tmux auto-launch guards (require expect for a real PTY) ───────────────────

@test "tmux guard: NO_TMUX=1 prevents auto-launch" {
  command -v expect >/dev/null 2>&1 || skip "expect not installed"
  _guard_test "NO_TMUX=1"
  [ ! -f "$BATS_TMPDIR/.tmux_launched" ]
}

@test "tmux guard: VSCODE_INJECTION prevents auto-launch" {
  command -v expect >/dev/null 2>&1 || skip "expect not installed"
  _guard_test "VSCODE_INJECTION=1"
  [ ! -f "$BATS_TMPDIR/.tmux_launched" ]
}

@test "tmux guard: INTELLIJ_ENVIRONMENT_READER prevents auto-launch" {
  command -v expect >/dev/null 2>&1 || skip "expect not installed"
  _guard_test "INTELLIJ_ENVIRONMENT_READER=1"
  [ ! -f "$BATS_TMPDIR/.tmux_launched" ]
}

@test "tmux guard: TMUX already set prevents auto-launch" {
  command -v expect >/dev/null 2>&1 || skip "expect not installed"
  _guard_test "TMUX=existing_session"
  [ ! -f "$BATS_TMPDIR/.tmux_launched" ]
}

@test "tmux guard: TERMINAL_EMULATOR=JetBrains prevents auto-launch" {
  command -v expect >/dev/null 2>&1 || skip "expect not installed"
  _guard_test "TERMINAL_EMULATOR=JetBrains-Terminal"
  [ ! -f "$BATS_TMPDIR/.tmux_launched" ]
}

# ── clip script routing (fake backends) ───────────────────────────────────────

@test "clip: routes stdin to pbcopy on darwin" {
  local received="$BATS_TMPDIR/.pbcopy_data"
  printf '#!/bin/sh\ncat > "%s"\n' "$received" > "$BATS_TMPDIR/pbcopy"
  chmod +x "$BATS_TMPDIR/pbcopy"

  printf 'clipboard test' \
    | env PATH="$BATS_TMPDIR:$PATH" OSTYPE=darwin bash "$BIN/clip"

  [ -f "$received" ]
  [[ "$(cat "$received")" == "clipboard test" ]]
}

@test "clip: routes stdin to wl-copy when available on linux" {
  local received="$BATS_TMPDIR/.wlcopy_data"
  printf '#!/bin/sh\ncat > "%s"\n' "$received" > "$BATS_TMPDIR/wl-copy"
  chmod +x "$BATS_TMPDIR/wl-copy"

  printf 'clipboard test' \
    | env PATH="$BATS_TMPDIR:$PATH" OSTYPE=linux-gnu bash "$BIN/clip"

  [ -f "$received" ]
  [[ "$(cat "$received")" == "clipboard test" ]]
}

@test "clip: falls back to xclip on linux when wl-copy is absent" {
  local received="$BATS_TMPDIR/.xclip_data"
  # Only xclip in PATH — wl-copy intentionally absent
  printf '#!/bin/sh\ncat > "%s"\n' "$received" > "$BATS_TMPDIR/xclip"
  chmod +x "$BATS_TMPDIR/xclip"

  # Minimal PATH: our fake xclip + system bins for cat/bash, but no wl-copy
  # (wl-copy is not in /bin or /usr/bin on macOS or stock Linux)
  printf 'clipboard test' \
    | env PATH="$BATS_TMPDIR:/bin:/usr/bin" OSTYPE=linux-gnu bash "$BIN/clip"

  [ -f "$received" ]
  [[ "$(cat "$received")" == "clipboard test" ]]
}
