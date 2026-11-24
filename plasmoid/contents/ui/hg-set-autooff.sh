#!/bin/sh
# hermes-gaming-tray — QML helper: sets the persistent auto-off flag
# Derived from Scriptinator (GPL-3.0-or-later, tubbadu): stdout marker pattern.
#
# Usage: hg-set-autooff.sh <0|1> [--silent]   (0 = disable, 1 = enable)
#   --silent: no desktop notification — used by the settings tab, which
#   already has the green/red result label; without the flag (contextual
#   menu of the tray) the notification acts as the confirmation.
# Output markers:
#   {SetAutoOffStart}OK message{SetAutoOffEnd}   (success)
#   {ErrStart}error message{ErrEnd}              (failure)
set -u
VAL=""
NOTIFY=1
for a in "$@"; do
    case "$a" in
        0|1)
            VAL="$a"
            ;;
        --silent|--no-notify)
            NOTIFY=0
            ;;
        *)
            echo '{ErrStart}invalid value (use 0|1 and --silent){ErrEnd}'
            exit 1
            ;;
    esac
done
if [ -z "$VAL" ]; then
    echo '{ErrStart}missing value 0 or 1{ErrEnd}'
    exit 1
fi
HG="${HOME}/.local/bin/hermes-gaming"
OUT="$("$HG" set-autooff "$VAL" 2>&1)"
RC=$?
if [ "$RC" -eq 0 ]; then
    MSG="$(printf '%s\n' "$OUT" | tail -n 1)"
    echo "{SetAutoOffStart}${MSG}{SetAutoOffEnd}"
    if [ "$NOTIFY" -eq 1 ]; then
        # body without the "OK: " prefix (redundant in a notification)
        BODY="${MSG#OK: }"
        if [ "$VAL" = "1" ]; then
            TITLE="Gaming: auto-off re-enabled"
        else
            TITLE="Gaming: auto-off disabled"
        fi
        # best effort: never block or fail the set
        notify-send -a hermes-gaming-tray "$TITLE" "$BODY" 2>/dev/null || true
    fi
else
    echo "{ErrStart}$(printf '%s\n' "$OUT" | tail -n 1){ErrEnd}"
fi
exit "$RC"
