#!/bin/sh
# hermes-gaming-tray — QML helper: reads the effective auto-off hour and flag
# (active session if any, else the persistent defaults, else 5/1)
#
# Usage: hg-current-offhour.sh
# Output markers: {CurHourStart}N{CurHourEnd}  {CurAutoOffStart}N{CurAutoOffEnd}
HG="${HOME}/.local/bin/hermes-gaming"
OUT="$("$HG" offhour 2>&1)"
RC=$?
[ "$RC" -eq 0 ] || OUT=5
AO="$("$HG" autooff 2>&1)"
RC2=$?
[ "$RC2" -eq 0 ] || AO=1
echo "{CurHourStart}$OUT{CurHourEnd}"
echo "{CurAutoOffStart}$AO{CurAutoOffEnd}"
exit "$RC"
