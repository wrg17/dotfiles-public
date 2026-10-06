#!/usr/bin/env bash
# bootstrap/link-jetbrains.sh
# Symlinks shared JetBrains configs from ~/dotfiles/jetbrains-shared/
# into every installed JetBrains product version directory.
# Safe to re-run after installing a new IDE or updating versions.

set -euo pipefail

case "$OSTYPE" in
  darwin*) JB_ROOT="$HOME/Library/Application Support/JetBrains" ;;
  linux*)  JB_ROOT="$HOME/.config/JetBrains" ;;
  *) echo "Unsupported OS: $OSTYPE" >&2; exit 1 ;;
esac

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$DOTFILES_DIR/jetbrains-shared"

[[ -d "$SRC" ]]     || { echo "Error: $SRC does not exist" >&2; exit 1; }
[[ -d "$JB_ROOT" ]] || { echo "No JetBrains dir at $JB_ROOT" >&2; exit 0; }

SHARED_DIRS=(keymaps colors codestyles templates inspection fileTemplates)

SHARED_OPTION_FILES=(
  editor.xml
  editor-font.xml
  colors.scheme.xml
  code.style.schemes.xml
  keymap.xml
  customization.xml
  notifications.xml
  ui.lnf.xml
  codeInsightSettings.xml
  contexts.xml
)

# Create or repoint a symlink, backing up any existing real file/dir
link() {
  local src="$1" dst="$2"
  if [[ -L "$dst" ]]; then
    ln -sfn "$src" "$dst"
  elif [[ -e "$dst" ]]; then
    mv "$dst" "$dst.pre-stow.$(date +%Y%m%d-%H%M%S)"
    ln -s "$src" "$dst"
  else
    mkdir -p "$(dirname "$dst")"
    ln -s "$src" "$dst"
  fi
}

echo "JetBrains root: $JB_ROOT"
echo "Source:         $SRC"
echo

for product_dir in "$JB_ROOT"/*/; do
  [[ -d "$product_dir" ]] || continue
  product_name="$(basename "$product_dir")"
  [[ "$product_name" == "Toolbox" ]] && continue
  [[ "$product_name" == "consentOptions" ]] && continue

  echo "→ $product_name"

  for dir in "${SHARED_DIRS[@]}"; do
    [[ -d "$SRC/$dir" ]] && link "$SRC/$dir" "${product_dir}${dir}"
  done

  for file in "${SHARED_OPTION_FILES[@]}"; do
    [[ -f "$SRC/options/$file" ]] && link "$SRC/options/$file" "${product_dir}options/$file"
  done
done

echo
echo "Done."