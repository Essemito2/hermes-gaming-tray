#!/bin/sh
# hg-state.sh — emits the state markers for hermes-gaming-tray (main.qml).
# Reads the state written by ~/.local/bin/hermes-gaming; the path is
# overridable for tests: HERMES_GAMING_STATE=/path/to/fake.json hg-state.sh
# Icons: absolute path (Kirigami.Icon resolves relative paths against
# plasmashell's CWD, not against the QML; cf. the official
# FilesystemSource.qml example).
BASE="$(cd "$(dirname "$0")" && pwd)"
STATE_FILE="${HERMES_GAMING_STATE:-$HOME/.hermes/state/gaming.json}"
DEFAULTS_FILE="${HERMES_GAMING_DEFAULTS:-$HOME/.hermes/state/gaming-defaults.json}"

# JSON field extraction (file written by hermes-gaming, one field per line)
get_bool() { sed -n 's/.*"'$1'": *\(true\|false\).*/\1/p' "$STATE_FILE" 2>/dev/null | head -n1; }
get_str()  { sed -n 's/.*"'$1'": *"\([^"]*\)".*/\1/p' "$STATE_FILE" 2>/dev/null | head -n1; }
get_int()  { sed -n 's/.*"'$1'": *\([0-9][0-9]*\).*/\1/p' "$STATE_FILE" 2>/dev/null | head -n1; }
get_bool_d() { sed -n 's/.*"'$1'": *\(true\|false\).*/\1/p' "$DEFAULTS_FILE" 2>/dev/null | head -n1; }

# $1 = seconds -> "45m" | "1h 05m"
fmt_dur() {
    _m=$(( $1 / 60 ))
    if [ "$_m" -lt 60 ]; then
        echo "${_m}m"
    else
        echo "$((_m / 60))h $((_m % 60))m"
    fi
}

ICON="$BASE/icons/gamepad-off.svg"
HEAD="Hermes Gaming"
BODY="Gaming mode: OFF · Hermes available · double-click to enable"
STATUS="passive"

# effective auto-off flag: active session if any, else the persistent default
AUTO_OFF="1"
if [ "$(get_bool active)" = "true" ]; then
    [ "$(get_bool auto_off)" = "false" ] && AUTO_OFF="0"
else
    [ "$(get_bool_d auto_off)" = "false" ] && AUTO_OFF="0"
fi

if [ "$(get_bool active)" = "true" ]; then
    ICON="$BASE/icons/gamepad-on.svg"
    STATUS="active"

    # duration of the current session (from "since")
    NOW_EPOCH=$(date +%s)
    SINCE=$(get_str since)
    SINCE_EPOCH=""
    if [ -n "$SINCE" ]; then
        SINCE_EPOCH=$(date -d "$SINCE" +%s 2>/dev/null)
    fi
    DUR_TXT=""
    if [ -n "$SINCE_EPOCH" ] && [ "$SINCE_EPOCH" -le "$NOW_EPOCH" ]; then
        DUR_TXT=" for $(fmt_dur $(( NOW_EPOCH - SINCE_EPOCH )))"
    fi

    # auto-off countdown: same target as deadline() in hermes-gaming —
    # the first off_hour:00 STRICTLY after the session start ("since").
    # If the state file already has "off_at" (legacy format) it wins.
    # The systemd "check" timer switches off at the deadline, within 2 min.
    OFF_TXT=""
    TGT_EPOCH=""
    if [ "$AUTO_OFF" = "0" ]; then
        OFF_TXT="disabled"
    fi
    OFF_AT=$(get_str off_at)
    if [ -n "$OFF_AT" ]; then
        TGT_EPOCH=$(date -d "$OFF_AT" +%s 2>/dev/null)
    fi
    if [ -z "$TGT_EPOCH" ] && [ -n "$SINCE_EPOCH" ]; then
        OFF_HOUR=$(get_int off_hour)
        [ -n "$OFF_HOUR" ] || OFF_HOUR=5
        TGT_EPOCH=$(date -d "$(printf '%s %02d:00:00' "$(echo "$SINCE" | cut -c1-10)" "$OFF_HOUR")" +%s 2>/dev/null)
        if [ -n "$TGT_EPOCH" ] && [ "$TGT_EPOCH" -le "$SINCE_EPOCH" ]; then
            TGT_EPOCH=$(( TGT_EPOCH + 86400 ))
        fi
    fi
    if [ -n "$TGT_EPOCH" ] && [ "$OFF_TXT" = "" ]; then
        REMAIN=$(( TGT_EPOCH - NOW_EPOCH ))
        TGT_HHMM=$(date -d "@$TGT_EPOCH" +%H:%M)
        if [ "$REMAIN" -le 120 ]; then
            OFF_TXT="due (within 2 min)"
        else
            OFF_TXT="in $(fmt_dur "$REMAIN") ($TGT_HHMM)"
        fi
    elif [ "$OFF_TXT" = "" ]; then
        # defensive case: without "since" the target cannot be computed
        OFF_HOUR=$(get_int off_hour)
        [ -n "$OFF_HOUR" ] || OFF_HOUR=5
        OFF_TXT="at $(printf '%02d:00' "$OFF_HOUR")"
    fi

    BODY="Gaming mode: ON$DUR_TXT · auto-off $OFF_TXT · double-click to disable"
fi

echo "{IconStart}$ICON{IconEnd}"
echo "{TipHeadStart}$HEAD{TipHeadEnd}"
echo "{TipBodyStart}$BODY{TipBodyEnd}"
echo "{StatusStart}$STATUS{StatusEnd}"
echo "{AutoOffStart}$AUTO_OFF{AutoOffEnd}"
