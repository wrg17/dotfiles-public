# Sourced when ZDOTDIR is already set in the environment (e.g. inherited from
# a parent shell). Delegates to ~/.zshenv so env vars load regardless of which
# path zsh takes at startup.
[[ -f "$HOME/.zshenv" ]] && source "$HOME/.zshenv"
