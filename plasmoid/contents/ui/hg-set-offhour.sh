#!/bin/sh
# hermes-gaming-tray — QML helper: sets the auto-off hour
# Derived from Scriptinator (GPL-3.0-or-later, tubbadu): stdout marker pattern.
#
# Usage: hg-set-offhour.sh <hour 0-23>
# Output markers:
#   {SetHourStart}OK message{SetHourEnd}   (success)
#   {ErrStart}error message{ErrEnd}        (failure)
set -u
HOUR="${1:-}"
case "$HOUR" in
    ''|*[!0-9]*)
        echo '{ErrStart}invalid hour (use an integer 0-23){ErrEnd}'
        exit 1
        ;;
esac
HG="${HOME}/.local/bin/hermes-gaming"
OUT="$("$HG" set-offhour "$HOUR" 2>&1)"
RC=$?
if [ "$RC" -eq 0 ]; then
    echo "{SetHourStart}$(printf '%s\n' "$OUT" | tail -n 1){SetHourEnd}"
else
    echo "{ErrStart}$(printf '%s\n' "$OUT" | tail -n 1){ErrEnd}"
fi
exit "$RC"
