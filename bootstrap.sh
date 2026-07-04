#!/usr/bin/env bash
# Phosphor bootstrap: clone the repo then run the installer.
# Usage:  curl -fsSL https://raw.githubusercontent.com/1ay1/phosphor-hypr/main/bootstrap.sh | bash
set -euo pipefail

REPO_URL="${PHOSPHOR_REPO:-https://github.com/1ay1/phosphor-hypr.git}"
DEST="${PHOSPHOR_DIR:-$HOME/.local/share/phosphor-hypr}"

command -v git >/dev/null 2>&1 || { echo "git is required"; exit 1; }

if [ -d "$DEST/.git" ]; then
  echo ":: Updating existing clone in $DEST"
  git -C "$DEST" pull --ff-only
else
  echo ":: Cloning $REPO_URL → $DEST"
  git clone --depth 1 "$REPO_URL" "$DEST"
fi

cd "$DEST"
chmod +x install.sh
exec ./install.sh "$@"
