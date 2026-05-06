# dotfiles

Personal configuration for a Linux workstation, managed with [GNU Stow](https://www.gnu.org/software/stow/) and versioned with git.

## Packages

| Package | Purpose |
|---------|---------|
| `zsh` | Shell — Oh My Zsh, aliases, functions, lazy-loaded tools |
| `nvim` | Neovim — LazyVim distribution, Tokyo Night theme |
| `tmux` | Terminal multiplexer — vim-style keys, sensible defaults |
| `starship` | Cross-shell prompt — git, python, node, docker segments |
| `wezterm` | Terminal emulator — FiraCode font, Tokyo Night, auto-attaches tmux |
| `yazi` | Terminal file manager — git status, syntax highlighting, image previews |

## Install

```sh
# Prerequisites
sudo apt install zsh tmux stow git curl

# Make zsh the default shell
chsh -s $(which zsh)

# Clone
git clone <repo-url> ~/dotfiles

# Install Oh My Zsh (skip its default zshrc)
ZSH="$HOME/.local/share/oh-my-zsh" sh -c \
  "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
  "" --unattended --keep-zshrc

# Install Oh My Zsh plugins
git clone https://github.com/zsh-users/zsh-autosuggestions \
  $HOME/.local/share/oh-my-zsh/custom/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting \
  $HOME/.local/share/oh-my-zsh/custom/plugins/zsh-syntax-highlighting
git clone https://github.com/zsh-users/zsh-history-substring-search \
  $HOME/.local/share/oh-my-zsh/custom/plugins/zsh-history-substring-search

# Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Stow all packages
cd ~/dotfiles && stow nvim starship tmux wezterm yazi zsh

# Reload shell
exec zsh

# Install CLI tools
brew install neovim starship eza bat fd ripgrep zoxide direnv \
             fzf lazygit gh tree jq imagemagick yazi
```

## Daily use

### Config shortcuts

```sh
zshrc        # open .zshrc in nvim
zshenv       # open .zshenv in nvim
starshipcfg  # open starship config
tmuxcfg      # open tmux config
weztermcfg   # open wezterm config
```

### Dotfiles helpers

```sh
dot              # cd to ~/dotfiles
dotedit          # cd and open repo in nvim
dotstat          # git status of the repo
dotsync "msg"    # add -A, commit, push in one step

dots <pkg>       # stow a package
dotsoff <pkg>    # unstow a package
dotsdry <pkg>    # preview what stow would do
dotsall          # stow every package
```

### Updating tools

```sh
upd    # runs apt, brew, rustup, pipx, oh-my-zsh in sequence
```

## Architecture

### XDG layout

`$HOME` is kept clean. Tools are redirected to XDG locations via `.zshenv`:

```
~/.config/         configuration
~/.local/share/    persistent data (oh-my-zsh, cargo, nvm)
~/.local/state/    state (zsh history)
~/.cache/          regenerable caches
```

### Shell startup order

```
.zshenv   every zsh invocation — XDG paths, env vars, no interactive code
.zshrc    interactive shells only — plugins, aliases, tmux auto-launch, prompt
```

### Tooling boundaries

- **apt** — system tools (`zsh`, `tmux`, `stow`, `git`, `curl`)
- **Homebrew** — developer CLI tools (`nvim`, `starship`, `eza`, `bat`, etc.)
- **cargo** — Rust toolchain and crates
- **pipx** — Python CLI applications

## Troubleshooting

**Stow refuses with "existing target is not a link or directory"**
A real file is in the way. Back it up and re-run stow:
```sh
mv ~/.<file> ~/.<file>.backup
stow <pkg>
```

**`brew not found` after restart**
Check that brew's bin is in the `path=()` array in `.zshrc` and that `.zshenv` sets `HOMEBREW_PREFIX`.

**Tmux launches inside JetBrains or VS Code terminal**
The auto-launch guard in `.zshrc` checks `TERMINAL_EMULATOR`, `VSCODE_INJECTION`, and `INTELLIJ_ENVIRONMENT_READER`. Add the new editor's env marker to the guard if needed.
