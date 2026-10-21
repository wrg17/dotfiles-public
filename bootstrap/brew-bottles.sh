#!/usr/bin/env bash
# Exits 0 when Homebrew ships bottles (prebuilt binaries) for this machine,
# 1 when it does not.
#
# Homebrew only bottles macOS versions at or above its support floor. Below
# that floor every `brew install`/`brew upgrade` compiles from source, and it
# compiles the whole dependency tree: on a Ventura box, installing zoxide and
# direnv pulled openssl, libgit2, python and llvm, and ran for two hours
# before being killed mid-llvm. Callers use this to downgrade an upgrade into
# an install-only step, or to soften a "run brew upgrade" recommendation.
#
# Non-macOS always exits 0 — apt and Linuxbrew have no equivalent cliff.
set -euo pipefail

[[ "$(uname -s)" == Darwin ]] || exit 0
command -v brew >/dev/null 2>&1 || exit 0

# Read the floor from Homebrew's own brew.sh (it defines and exports
# HOMEBREW_MACOS_OLDEST_SUPPORTED there) rather than hardcoding a number that
# moves with every macOS release.
floor="$(sed -nE 's/^HOMEBREW_MACOS_OLDEST_SUPPORTED="([0-9]+)".*/\1/p' \
  "$(brew --repository)/Library/Homebrew/brew.sh" 2>/dev/null | head -1)"

# Unknown floor: assume bottles exist. Guessing "no" here would silently stop
# upgrading on a perfectly healthy machine.
[[ -n "$floor" ]] || exit 0

[[ "$(sw_vers -productVersion | cut -d. -f1)" -ge "$floor" ]]
