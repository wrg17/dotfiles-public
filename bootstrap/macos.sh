#!/usr/bin/env bash
xcode-select --install 2>/dev/null || true
command -v brew >/dev/null || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew bundle --file="$(dirname "$0")/Brewfile"
"$(dirname "$0")/install-tools.sh"
