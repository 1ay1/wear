#!/usr/bin/env bash
# fastfetch-responsive -- pick the fastfetch layout that fits the terminal.
# Generated configs live in ~/.config/fastfetch/{phosphor,compact,minimal}.jsonc
# and are re-themed by `wear` on every theme change. This wrapper measures the
# real terminal width at launch and hands fastfetch the widest layout that fits
# so the boot-diagnostic banner never wraps or gets clipped.
#
# Tiers (interior box + logo + padding budget):
#   >= 74 cols  -> phosphor  (logo + full box, 14-wide keys)
#   48..73      -> compact   (no logo, narrow box, 8-wide keys)
#   <  48       -> minimal   (no box art, essential rows only)
#
# Any extra args are forwarded to fastfetch (e.g. --pipe, --logo none).

cfg_dir="${XDG_CONFIG_HOME:-$HOME/.config}/fastfetch"

# Terminal width: prefer a live TTY probe (tput), fall back to $COLUMNS, then 80.
cols=""
if [ -t 1 ]; then
  cols="$(tput cols 2>/dev/null)"
fi
[ -z "$cols" ] && cols="${COLUMNS:-}"
[ -z "$cols" ] && cols=80
case "$cols" in *[!0-9]*) cols=80 ;; esac

if   [ "$cols" -ge 74 ]; then tier=phosphor
elif [ "$cols" -ge 48 ]; then tier=compact
else                          tier=minimal
fi

cfg="$cfg_dir/$tier.jsonc"
# Graceful degradation: if the picked tier is missing, walk down to whatever
# exists, and finally fall back to fastfetch's own default config.
for try in "$tier" phosphor compact minimal; do
  if [ -f "$cfg_dir/$try.jsonc" ]; then cfg="$cfg_dir/$try.jsonc"; break; fi
done

if [ -f "$cfg" ]; then
  exec fastfetch --config "$cfg" "$@"
else
  exec fastfetch "$@"
fi
