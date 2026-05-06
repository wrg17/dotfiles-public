#!/usr/bin/env bats

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
ZSHENV="$REPO_ROOT/zsh/.zshenv"
ZSHRC="$REPO_ROOT/zsh/.config/zsh/.zshrc"

# ── .zshenv: XDG base directories ─────────────────────────────────────────

@test "zshenv: XDG_CONFIG_HOME is exported" {
  grep -q 'export XDG_CONFIG_HOME' "$ZSHENV"
}

@test "zshenv: XDG_DATA_HOME is exported" {
  grep -q 'export XDG_DATA_HOME' "$ZSHENV"
}

@test "zshenv: XDG_CACHE_HOME is exported" {
  grep -q 'export XDG_CACHE_HOME' "$ZSHENV"
}

@test "zshenv: XDG_STATE_HOME is exported" {
  grep -q 'export XDG_STATE_HOME' "$ZSHENV"
}

# ── .zshenv: tool home dirs ────────────────────────────────────────────────

@test "zshenv: ZDOTDIR points into XDG_CONFIG_HOME" {
  grep -q 'ZDOTDIR=.*XDG_CONFIG_HOME.*zsh' "$ZSHENV"
}

@test "zshenv: HISTFILE uses XDG_STATE_HOME" {
  grep -q 'HISTFILE=.*XDG_STATE_HOME' "$ZSHENV"
}

@test "zshenv: ZSH (oh-my-zsh) redirected to XDG_DATA_HOME" {
  grep -q 'ZSH=.*XDG_DATA_HOME' "$ZSHENV"
}

@test "zshenv: CARGO_HOME redirected to XDG_DATA_HOME" {
  grep -q 'CARGO_HOME=.*XDG_DATA_HOME' "$ZSHENV"
}

@test "zshenv: RUSTUP_HOME redirected to XDG_DATA_HOME" {
  grep -q 'RUSTUP_HOME=.*XDG_DATA_HOME' "$ZSHENV"
}

@test "zshenv: NVM_DIR redirected to XDG_DATA_HOME" {
  grep -q 'NVM_DIR=.*XDG_DATA_HOME' "$ZSHENV"
}

@test "zshenv: GOPATH redirected to XDG_DATA_HOME" {
  grep -q 'GOPATH=.*XDG_DATA_HOME' "$ZSHENV"
}

@test "zshenv: EDITOR is nvim" {
  grep -qF "EDITOR='nvim'" "$ZSHENV"
}

@test "zshenv: VISUAL is nvim" {
  grep -qF "VISUAL='nvim'" "$ZSHENV"
}

@test "zshenv: Homebrew detection loop is present" {
  grep -q 'linuxbrew' "$ZSHENV"
}

# ── .zshenv: must NOT contain interactive shell logic ──────────────────────

@test "zshenv: does not source oh-my-zsh" {
  run grep 'oh-my-zsh.sh' "$ZSHENV"
  [ "$status" -ne 0 ]
}

@test "zshenv: does not define plugins array" {
  run grep '^plugins=' "$ZSHENV"
  [ "$status" -ne 0 ]
}

# ── .zshrc: history ────────────────────────────────────────────────────────

@test "zshrc: HISTSIZE is 50000" {
  grep -qF 'HISTSIZE=50000' "$ZSHRC"
}

@test "zshrc: SAVEHIST is 50000" {
  grep -qF 'SAVEHIST=50000' "$ZSHRC"
}

@test "zshrc: SHARE_HISTORY is set" {
  grep -q 'SHARE_HISTORY' "$ZSHRC"
}

@test "zshrc: HIST_IGNORE_ALL_DUPS is set" {
  grep -q 'HIST_IGNORE_ALL_DUPS' "$ZSHRC"
}

# ── .zshrc: shell options ──────────────────────────────────────────────────

@test "zshrc: AUTO_CD is enabled" {
  grep -q 'AUTO_CD' "$ZSHRC"
}

# ── .zshrc: oh-my-zsh plugins ─────────────────────────────────────────────

@test "zshrc: zsh-autosuggestions plugin is listed" {
  grep -q 'zsh-autosuggestions' "$ZSHRC"
}

@test "zshrc: zsh-syntax-highlighting plugin is listed" {
  grep -q 'zsh-syntax-highlighting' "$ZSHRC"
}

@test "zshrc: history-substring-search plugin is listed" {
  grep -q 'history-substring-search' "$ZSHRC"
}

# ── .zshrc: editor aliases ─────────────────────────────────────────────────

@test "zshrc: vim aliased to nvim" {
  grep -qF "alias vim='nvim'" "$ZSHRC"
}

@test "zshrc: vi aliased to nvim" {
  grep -qF "alias vi='nvim'" "$ZSHRC"
}

# ── .zshrc: safety aliases ─────────────────────────────────────────────────

@test "zshrc: rm is interactive by default" {
  grep -qF "alias rm='rm -i'" "$ZSHRC"
}

@test "zshrc: cp is interactive by default" {
  grep -qF "alias cp='cp -i'" "$ZSHRC"
}

@test "zshrc: mv is interactive by default" {
  grep -qF "alias mv='mv -i'" "$ZSHRC"
}

# ── .zshrc: config shortcuts ───────────────────────────────────────────────

@test "zshrc: zshrc alias opens config" {
  grep -q "alias zshrc=" "$ZSHRC"
}

@test "zshrc: weztermcfg alias is defined" {
  grep -q "alias weztermcfg=" "$ZSHRC"
}

@test "zshrc: starshipcfg alias is defined" {
  grep -q "alias starshipcfg=" "$ZSHRC"
}

@test "zshrc: tmuxcfg alias is defined" {
  grep -q "alias tmuxcfg=" "$ZSHRC"
}

@test "zshrc: szsh reloads shell" {
  grep -qF "alias szsh='exec zsh'" "$ZSHRC"
}

# ── Clipboard (clip script + clipout alias) ────────────────────────────────

@test "clip script exists and is executable" {
  [ -x "$REPO_ROOT/zsh/.local/bin/clip" ]
}

@test "clip script handles macOS (pbcopy)" {
  grep -q 'pbcopy' "$REPO_ROOT/zsh/.local/bin/clip"
}

@test "clip script handles Linux Wayland (wl-copy)" {
  grep -q 'wl-copy' "$REPO_ROOT/zsh/.local/bin/clip"
}

@test "clip script handles Linux X11 (xclip)" {
  grep -q 'xclip' "$REPO_ROOT/zsh/.local/bin/clip"
}

@test "zshrc: clip alias is not hardcoded to xclip" {
  run grep "alias clip='xclip" "$ZSHRC"
  [ "$status" -ne 0 ]
}

@test "zshrc: clipout covers macOS" {
  grep -q 'pbpaste' "$ZSHRC"
}

@test "zshrc: clipout covers Linux Wayland" {
  grep -q 'wl-paste' "$ZSHRC"
}

@test "zshrc: clipout covers Linux X11" {
  grep -q 'xclip.*-o' "$ZSHRC"
}

@test "zshrc: clipall pipes through clip script" {
  grep -qF '| clip' "$ZSHRC"
}

@test "zshrc: clipall does not hardcode xclip" {
  run grep 'clipall.*xclip' "$ZSHRC"
  [ "$status" -ne 0 ]
}

# ── .zshrc: git aliases ────────────────────────────────────────────────────

@test "zshrc: gs is short git status" {
  grep -qF "alias gs='git status" "$ZSHRC"
}

@test "zshrc: glg is git log graph" {
  grep -q "alias glg='git log" "$ZSHRC"
}

@test "zshrc: gca amends last commit" {
  grep -q "alias gca='git commit --amend" "$ZSHRC"
}

@test "zshrc: gwip stages and commits as wip" {
  grep -q "alias gwip='git add" "$ZSHRC"
}

# ── .zshrc: docker aliases ─────────────────────────────────────────────────

@test "zshrc: dps lists containers in table format" {
  grep -q "alias dps='docker ps" "$ZSHRC"
}

@test "zshrc: dex runs docker exec interactively" {
  grep -q "alias dex='docker exec" "$ZSHRC"
}

@test "zshrc: dlog follows container logs" {
  grep -q "alias dlog='docker logs" "$ZSHRC"
}

@test "zshrc: dprune cleans docker system" {
  grep -q "alias dprune='docker system prune" "$ZSHRC"
}

# ── .zshrc: GPU / system aliases ──────────────────────────────────────────

@test "zshrc: gpu runs nvidia-smi" {
  grep -qF "alias gpu='nvidia-smi'" "$ZSHRC"
}

@test "zshrc: ports lists listening sockets" {
  grep -qF "alias ports='ss -tulpn'" "$ZSHRC"
}

@test "zshrc: myip fetches external IP" {
  grep -q "alias myip='curl" "$ZSHRC"
}

# ── .zshrc: dotfiles helpers ───────────────────────────────────────────────

@test "zshrc: dot alias changes to DOTFILES dir" {
  grep -qF "alias dot='cd \$DOTFILES'" "$ZSHRC"
}

@test "zshrc: dots() wraps stow" {
  grep -q '^dots()' "$ZSHRC"
}

@test "zshrc: dotsoff() wraps stow -D" {
  grep -q '^dotsoff()' "$ZSHRC"
}

@test "zshrc: dotsdry() wraps stow -n" {
  grep -q '^dotsdry()' "$ZSHRC"
}

@test "zshrc: dotsall() stows all packages" {
  grep -q '^dotsall()' "$ZSHRC"
}

@test "zshrc: dotsync() commits and pushes" {
  grep -q '^dotsync()' "$ZSHRC"
}

# ── .zshrc: utility functions ──────────────────────────────────────────────

@test "zshrc: upd() updates all package managers" {
  grep -q '^upd()' "$ZSHRC"
}

@test "zshrc: mkcd() creates and enters directory" {
  grep -q '^mkcd()' "$ZSHRC"
}

@test "zshrc: extract() handles archives" {
  grep -q '^extract()' "$ZSHRC"
}

@test "zshrc: extract() handles .tar.gz" {
  grep -q '\.tar\.gz' "$ZSHRC"
}

@test "zshrc: extract() handles .zip" {
  grep -q '\.zip' "$ZSHRC"
}

@test "zshrc: mkvenv() creates Python venv" {
  grep -q '^mkvenv()' "$ZSHRC"
}

@test "zshrc: clipall() tees output to clipboard" {
  grep -q '^clipall()' "$ZSHRC"
}

@test "zshrc: y() wraps yazi with cwd tracking" {
  grep -q '^function y()' "$ZSHRC"
}

# ── .zshrc: tool integrations ─────────────────────────────────────────────

@test "zshrc: nvm is lazy-loaded" {
  grep -q '_load_nvm' "$ZSHRC"
}

@test "zshrc: zoxide is initialised when available" {
  grep -q 'zoxide init zsh' "$ZSHRC"
}

@test "zshrc: direnv is hooked when available" {
  grep -q 'direnv hook zsh' "$ZSHRC"
}

@test "zshrc: fzf is sourced when available" {
  grep -q 'fzf.zsh' "$ZSHRC"
}

@test "zshrc: starship init is present" {
  grep -q 'starship init zsh' "$ZSHRC"
}

# ── .zshrc: tmux auto-launch ───────────────────────────────────────────────

@test "zshrc: tmux auto-launch is guarded against JetBrains" {
  grep -q 'JetBrains' "$ZSHRC"
}

@test "zshrc: tmux auto-launch is guarded against VS Code" {
  grep -q 'VSCODE_INJECTION' "$ZSHRC"
}

@test "zshrc: tmux auto-launch checks for existing session" {
  grep -q 'TMUX' "$ZSHRC"
}

# ── .zshrc: local overrides ───────────────────────────────────────────────

@test "zshrc: sources .zshrc.local at end if present" {
  grep -qF 'source $ZDOTDIR/.zshrc.local' "$ZSHRC"
}

@test "zshrc: .zshrc.local source is conditional" {
  grep -q '\[\[ -f.*zshrc\.local \]\]' "$ZSHRC"
}
