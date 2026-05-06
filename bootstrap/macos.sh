xcode-select --install 2>/dev/null
which brew >/dev/null || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew bundle --file=$HOME/dotfiles/bootstrap/Brewfile
