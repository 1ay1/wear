#!/usr/bin/env bash
# Screenshot -> annotate in satty.
# In satty: draw arrows/boxes/text/blur, then:
#   Ctrl+C  -> copies to clipboard AND saves the PNG to disk (--save-after-copy)
#   Enter   -> copies to clipboard AND saves, then exits
#   Escape  -> quit without saving
# Modes:  region (default) | full | window
set -euo pipefail

shotdir="${HOME}/Pictures/Screenshots"
mkdir -p "$shotdir"
mode="${1:-region}"

# satty saves here; %F_%H-%M-%S is expanded by satty's strftime support
outpat="$shotdir/shot-%Y%m%d-%H-%M-%S.png"

run_satty() {
  satty --filename - \
    --output-filename "$outpat" \
    --copy-command wl-copy \
    --save-after-copy \
    --actions-on-enter save-to-clipboard,exit \
    --actions-on-escape exit \
    --early-exit copy \
    --initial-tool arrow
}

case "$mode" in
  region)
    geom="$(slurp -d)" || exit 0   # exit cleanly if selection cancelled
    grim -g "$geom" - | run_satty
    ;;
  full)
    grim - | run_satty
    ;;
  window)
    geom="$(hyprctl activewindow -j | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')"
    grim -g "$geom" - | run_satty
    ;;
  *)
    echo "usage: screenshot.sh [region|full|window]" >&2
    exit 1
    ;;
esac
