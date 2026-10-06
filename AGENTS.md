# Dotfiles — Agent Guide

Conventions and constraints for coding agents (Claude, Copilot, Cursor, …) working
in this repository. The goal is changes that fit the system rather than fight it.

This is the published subset of a larger private dotfiles repo, so some guidance
here refers to mechanisms whose host-specific half is not included.

## Philosophy

Configuration is treated as code: versioned, tested, and structured so changes are
reversible. Four properties, in priority order:

1. **Recoverability.** A new machine should be operational in minutes from the repo
   alone. Any tool whose state cannot be recreated from here should be questioned.
2. **Single source of truth.** Each piece of configuration lives in exactly one
   place. Duplicate state is a bug, not a fact to tolerate.
3. **Predictability.** Updates are boring. One canonical way to install a tool, one
   way to update everything, minimal special cases.
4. **A clean `$HOME`.** Anything that can live under `~/.config`,
   `~/.local/share`, or `~/.cache` does.

A clever 200-character one-liner nobody can read in six months is worse than a
verbose, obvious solution.

## Structure

Each top-level directory is a [GNU Stow](https://www.gnu.org/software/stow/)
package whose internal layout mirrors `$HOME`:

```
zsh/.zshenv                           # bootstrap: XDG paths, env for every shell
zsh/.config/zsh/.zshrc                # interactive shell config
zsh/.local/bin/                       # small user scripts
sheldon/.config/sheldon/plugins.toml  # zsh plugin declarations
tmux/.config/tmux/tmux.conf
starship/.config/starship.toml
wezterm/.config/wezterm/wezterm.lua
yazi/.config/yazi/*.toml
nvim/.config/nvim/
bootstrap/                            # install scripts — not a stow package
test/                                 # bats suite — not a stow package
```

`stow <package>` from the repo root symlinks from `$HOME` into the package, so
editing `~/.config/zsh/.zshrc` is editing `zsh/.config/zsh/.zshrc`. New config
belongs in a stow package, never directly in `$HOME`.

## Shell architecture

**`.zshenv`** runs for *every* zsh invocation, including non-interactive scripts.
Environment variables only — no interactive logic, nothing that prints or prompts,
no sourcing of other configs. It must stay fast and side-effect-free.

**`.zshrc`** runs only for interactive shells: aliases, functions, plugins, prompt.
It assumes `.zshenv` has run.

The boundary matters. Interactive setup in `.zshenv` slows every script; env vars in
`.zshrc` mean scripts cannot find tools.

Plugins are managed by **sheldon** from `sheldon/.config/sheldon/plugins.toml`.
Oh My Zsh was removed — do not reintroduce it. `test/zsh.bats` asserts it is never
sourced and that no `plugins=()` array exists.

Expensive initialisations go through the `_initcache` helper in `.zshrc`, which
caches a command's output and regenerates only when a trigger file is newer. `nvm`
is lazy-loaded behind shim functions. Keep interactive startup near 0.2s; if you add
an `eval "$(tool init)"`, route it through `_initcache`.

Homebrew is located by probing `/opt/homebrew/bin/brew` (Apple Silicon),
`/usr/local/bin/brew` (Intel), then `/home/linuxbrew/.linuxbrew/bin/brew` — first
existing wins. Do not replace this with an `$OSTYPE` branch or hardcode one prefix;
the probe is what makes all three work from one code path.

`.zshenv` sets `skip_global_compinit=1`. This is load-bearing. Ubuntu's
`/etc/zsh/zshrc` runs a bare `compinit` before `$ZDOTDIR/.zshrc`, and without `-u`
it blocks on `Ignore insecure directories and continue [y]/[n]?`, hanging a new
terminal indefinitely whenever something on `fpath` is group- or world-writable.
`.zshrc` runs its own `compinit` with `-u`/`-C`, which never prompts. Do not remove
the flag.

Tmux is auto-launched from `.zshrc` only when stdin and stdout are real TTYs and the
shell is not inside a JetBrains terminal, a VS Code injection probe, or Emacs. Each
guard exists because that environment broke tmux or terminal rendering. If a new
wrapper misbehaves, add it to the guard rather than removing the auto-launch.

## Testing

17 bats files, ~235 assertions, covering shell config, aliases, functions, stow
integrity, shellcheck over every script, and actionlint over the workflow.

```sh
make test                                   # canonical; CI runs this
bash test/run.sh --no-cache test/*.bats     # force a full run
bats -f "pattern" test/zsh.bats             # one file, filtered
make test-linux                             # whole suite in the Ubuntu CI image
```

Two things will mislead you:

**`test/run.sh` caches by content hash** under `.cache/tests/passed/`. If `make test`
prints no test output and exits 0, nothing changed since the last green run — it is
*not* a silent failure. Use `--no-cache` for certainty.

**`.githooks/pre-commit` runs the suite on every commit** (`make init` sets
`core.hooksPath`). A commit that seems to hang is probably running tests.

Many tests skip when their tool is absent (`# skip tmux not installed`). That is
expected in CI; it also means a green CI run proves less than a green local run.

When adding a test that spawns an interactive shell, model it on `_guard_test` in
`test/zsh.bats` and read its comments first. It encodes three mistakes that each
produced a suite which passed while testing nothing:

- `expect`'s `spawn` does not go through a shell, so quoted env values arrive with
  literal quote characters — set the environment outside `spawn`.
- `.zshrc` rebuilds `path` with `$PYENV_ROOT/bin` first, so stub binaries merely
  prepended to `PATH` get shadowed by the real ones.
- Discarding the pty transcript makes every failure indistinguishable. Keep it and
  print it on failure.

Any guard test needs a positive control proving the guarded behaviour fires when the
guard is absent.

## Stow hazards

**Never untrack a file whose stow symlink is live without replacing it first.**
`~/.config/foo` is a symlink into this repo; deleting the repo file leaves a dangling
symlink and the application silently loses its config. The correct order:

```sh
cp -L ~/.config/foo /tmp/foo && rm ~/.config/foo && cp /tmp/foo ~/.config/foo
git rm --cached <pkg>/.config/foo && rm <pkg>/.config/foo
# then add the gitignore entry
find ~ -maxdepth 3 -xtype l          # must print nothing pointing into the repo
```

Use the Makefile's package filters rather than `stow */` — `bootstrap/` and `test/`
are not stow packages.

## Conventions

Config files are heavily commented because tools are inscrutable. Comments
explaining *why* a setting exists are valuable; comments restating *what* the next
line does are noise. When a setting depends on platform, terminal, or external
state, name the dependency.

Section dividers (`# ===...===`) delineate logical groups in `.zshrc`, `.zshenv`,
and `tmux.conf`. Maintain them.

Trailing whitespace, mixed indentation, and stray tabs in TOML are real bugs — many
of these tools parse strictly. Copy formatting from existing entries.

The stow helpers in `.zshrc` are `dot`, `dotedit`, `dotstat`, `dots`, `dotsoff`,
`dotsdry`, `dotsall`, and `dotsync`. There is no `dotadd`. Note that `dotsync` is
`git add -A && git commit && git push`, so it sweeps up unrelated dirty files —
prefer plain `git` unless the worktree is clean.

## Do not

1. **Add interactive logic to `.zshenv`.** Anything that prints, prompts, or needs a
   TTY belongs in `.zshrc`.
2. **Track regenerable files.** `.zcompdump*`, `*.zwc`, plugin downloads, build
   artifacts, history files. Add gitignore entries proactively — but see the stow
   hazard above before untracking something already committed.
3. **Hardcode user-specific paths.** Use `$HOME`, `$XDG_CONFIG_HOME`, `$DOTFILES`.
   Never a literal `/home/<username>/…`.
4. **Edit `~/.zshenv` directly.** It is a symlink; edit `zsh/.zshenv`. A second
   one-line `zsh/.config/zsh/.zshenv` exists only to source it, because zsh reads
   `$ZDOTDIR/.zshenv` instead of `~/.zshenv` when `ZDOTDIR` is already set. Do not
   put settings there.
5. **Remove `zsh`, `tmux`, `stow`, or `git` from the system package manager** in
   favour of Homebrew. They must be findable before the shell environment loads.
6. **Disable the safety aliases** (`rm -i`, `cp -i`, `mv -i`) without asking. Bypass
   with `\rm` or `rm -f` instead.
7. **Introduce wrapper tools** (topgrade and friends) for work already done by a
   short, transparent shell function.

## Do

Prefer minimal diffs. If one line needs to change, change one line; do not refactor
surrounding code unless asked.

Diagnose before fixing. `which <tool>`, `echo $PATH`, reading the file, and
`git status` are almost always the right first step. Speculative fixes are worse
than confirmed ones — and in a repo this full of indirection, a plausible hypothesis
is often wrong. Reproduce first, ideally in `make test-linux`.

Explain trade-offs when proposing a tool or pattern, not just the recommendation.

Keep commit history clean: discrete commits, conventional prefixes (`feat:`, `fix:`,
`refactor:`, `test:`, `docs:`, `chore:`), one logical change each.

## Verification

```sh
make test                                     # see the caching note above
zsh -l -i -c exit                             # starts clean, no stderr
find ~ -maxdepth 3 -xtype l                   # no dangling symlinks into the repo
cd ~/dotfiles && stow -n -v nvim sheldon starship tmux wezterm yazi zsh
git status                                    # clean, or only intended changes
```

If any of these fail after a change, the change is incomplete.
