#!/bin/sh
# hermes-gaming-tray — installer
#
# Installs:
#   ~/.local/bin/hermes-gaming                            (control script)
#   ~/.config/systemd/user/hermes-gaming-off.{service,timer} (auto-off timer)
#   ~/.local/share/plasma/plasmoids/com.hermes.gaming-tray   (Plasma applet)
#
# Usage:
#   ./install.sh             install / upgrade (idempotent)
#   ./install.sh uninstall   remove script, units and applet
set -eu

APP_ID="com.hermes.gaming-tray"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN="$HOME/.local/bin/hermes-gaming"
PLASMOID_DIR="$HOME/.local/share/plasma/plasmoids/$APP_ID"
UNIT_DIR="$HOME/.config/systemd/user"

warn() { printf 'WARNING: %s\n' "$*" >&2; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

uninstall() {
    systemctl --user disable --now hermes-gaming-off.timer 2>/dev/null || true
    rm -f "$UNIT_DIR/hermes-gaming-off.service" "$UNIT_DIR/hermes-gaming-off.timer"
    rm -f "$BIN"
    rm -rf "$PLASMOID_DIR"
    systemctl --user daemon-reload 2>/dev/null || true
    echo "Uninstalled."
    echo "State files (gaming.json, gaming-defaults.json, gaming.log) remain in ~/.hermes/state/."
    echo "Remove the 'Hermes Gaming Tray' applet from the notification area (or log out) to finish."
}

if [ "${1:-install}" = "uninstall" ]; then
    uninstall
    exit 0
fi

# --- preflight -------------------------------------------------------------
command -v python3 >/dev/null 2>&1 \
    || die "python3 not found (required, standard library only)."
command -v plasmashell >/dev/null 2>&1 \
    || die "plasmashell not found: this applet requires KDE Plasma 6 (Linux)."
[ -d "$HOME/.hermes/runtimes/llamacpp" ] \
    || warn "no Hermes llamacpp runtime found at ~/.hermes/runtimes/llamacpp — set up a local llama.cpp model in Hermes before using the applet."

# --- install ----------------------------------------------------------------
umask 022
mkdir -p "$HOME/.local/bin" "$UNIT_DIR"

install -m 755 "$SCRIPT_DIR/hermes-gaming" "$BIN"

install -m 644 "$SCRIPT_DIR/systemd/hermes-gaming-off.service" "$UNIT_DIR/"
install -m 644 "$SCRIPT_DIR/systemd/hermes-gaming-off.timer" "$UNIT_DIR/"

# replace the applet (previous installations are overwritten)
rm -rf "$PLASMOID_DIR"
mkdir -p "$(dirname "$PLASMOID_DIR")"
cp -r "$SCRIPT_DIR/plasmoid" "$PLASMOID_DIR"

systemctl --user daemon-reload
systemctl --user enable --now hermes-gaming-off.timer 2>/dev/null \
    || warn "could not enable hermes-gaming-off.timer — run manually: systemctl --user enable --now hermes-gaming-off.timer"

echo "Installed."
echo
echo "Next steps:"
echo "  1. Restart the shell (or log out and back in):"
echo "       systemctl --user restart plasma-plasmashell"
echo "  2. Right-click the notification area -> Add Widgets -> search 'Hermes Gaming Tray'."
echo "  3. Double-click the tray icon to toggle gaming mode."
