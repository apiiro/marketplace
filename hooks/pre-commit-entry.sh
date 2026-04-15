#!/usr/bin/env bash
# Wrapper for pre-commit hooks — ensures apiiro CLI is installed before running.

if ! command -v apiiro &>/dev/null; then
  echo "Error: apiiro CLI is not installed." >&2
  echo "" >&2
  echo "Install via Homebrew:" >&2
  echo "  brew tap apiiro/tap && brew install apiiro" >&2
  echo "" >&2
  echo "Or download from: https://github.com/apiiro/marketplace/releases" >&2
  exit 1
fi

exec apiiro "$@"
