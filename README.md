# dotfiles

Personal configuration managed with [GNU Stow](https://www.gnu.org/software/stow/) and versioned with git.

## Packages

| Package | Purpose |
|---------|---------|
| `zsh` | Shell — aliases, functions, lazy-loaded tools, XDG env |
| `sheldon` | Zsh plugin declarations (`plugins.toml`) |
| `nvim` | Neovim — LazyVim distribution, Tokyo Night theme |
| `tmux` | Terminal multiplexer — vim-style keys, sensible defaults |
| `starship` | Cross-shell prompt — git, python, node, docker segments |
| `wezterm` | Terminal emulator — FiraCode font, Tokyo Night, auto-attaches tmux |
| `yazi` | Terminal file manager — git status, syntax highlighting, image previews |

## Install

```sh
git clone <this-repo> ~/dotfiles
cd ~/dotfiles
make install-mac      # macOS (Intel or Apple Silicon)
make install-linux    # Debian/Ubuntu
exec zsh
```

`make install-*` runs the matching `bootstrap/` script — system packages, Homebrew,
language version managers and CLI tools — then stows every package.

**macOS note.** Homebrew does not add itself to the PATH of the shell that installs
it. On Apple Silicon it lands in `/opt/homebrew/bin`, which is not on the default
PATH, so run `eval "$(/opt/homebrew/bin/brew shellenv)"` before continuing. On Intel
it lands in `/usr/local/bin`, already on the default PATH.

**Linux prerequisite.** `zsh`, `tmux`, `stow`, `git` and `curl` must come from apt,
not Homebrew — they have to be findable before the shell environment loads:

```sh
sudo apt install zsh tmux stow git curl
chsh -s "$(which zsh)"
```

**Plugins** are declared in `sheldon/.config/sheldon/plugins.toml` and installed by
[sheldon](https://github.com/rossmacarthur/sheldon) via `bootstrap/install-tools.sh`.
Nothing to clone by hand.

### Tests

```sh
make test          # bats suite, shellcheck, actionlint
make test-linux    # same, inside an Ubuntu container
```

Results are cached per file, so a run printing no tests means nothing changed since
the last green run. Force a full run with
`bash test/run.sh --no-cache test/*.bats`.


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
upd    # apt (Linux), brew, rustup, pipx, sheldon, version managers, lang audit
```

## Architecture

### XDG layout

`$HOME` is kept clean. Tools are redirected to XDG locations via `.zshenv`:

```
~/.config/         configuration
~/.local/share/    persistent data (sheldon, cargo, nvm, pyenv)
~/.local/state/    state (zsh history)
~/.cache/          regenerable caches
```

### Shell startup order

```
.zshenv   every zsh invocation — XDG paths, env vars, no interactive code
.zshrc    interactive shells only — plugins, aliases, tmux auto-launch, prompt
```

### Tooling boundaries

- **apt** (Linux) — system tools (`zsh`, `tmux`, `stow`, `git`, `curl`)
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
`.zshenv` does not hardcode a prefix — it probes `/opt/homebrew/bin/brew`
(Apple Silicon), `/usr/local/bin/brew` (Intel), then
`/home/linuxbrew/.linuxbrew/bin/brew`, and uses the first that exists. If brew
lives somewhere else, add it to that list. If brew moved, the cached `shellenv`
output may be stale — delete `$XDG_CACHE_HOME/brew_shellenv.zsh`.

**A new terminal hangs with no prompt (Ubuntu/Debian)**
Ubuntu's `/etc/zsh/zshrc` runs a bare `compinit`, which stops on
`Ignore insecure directories and continue [y]/[n]?` and waits for input whenever
anything on `fpath` is group- or world-writable — hanging the shell before
`.zshrc` is reached. `.zshenv` sets `skip_global_compinit=1` to suppress it;
check that line is still present. Run `compaudit` to list offending directories.

**Stow created a broken symlink / an app lost its config**
A file was removed from the repo while its symlink in `~` was still live.
Restore a real file from git history, then gitignore it:
```sh
git show HEAD:<pkg>/.config/foo > ~/.config/foo
find ~ -maxdepth 3 -xtype l          # find any others
```

**Tmux launches inside JetBrains or VS Code terminal**
The auto-launch guard in `.zshrc` checks `TERMINAL_EMULATOR`, `VSCODE_INJECTION`, and `INTELLIJ_ENVIRONMENT_READER`. Add the new editor's env marker to the guard if needed.
