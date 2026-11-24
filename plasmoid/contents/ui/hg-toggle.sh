#!/bin/sh
# hg-toggle.sh — reads the current state and calls the matching
# subcommand of ~/.local/bin/hermes-gaming (on | off; there is no
# native "toggle").

HG="${HOME}/.local/bin/hermes-gaming"

if [ "$(sed -n 's/.*"active": *\(true\|false\).*/\1/p' "$HOME/.hermes/state/gaming.json" 2>/dev/null)" = "true" ]; then
    exec "$HG" off
else
    exec "$HG" on
fi
