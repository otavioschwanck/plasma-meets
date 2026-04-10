#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DEST="$HOME/.local/share/plasma/plasmoids/org.kde.plasma.plasma-meets"
rm -rf "$DEST"
cp -r "$SCRIPT_DIR/package" "$DEST"
echo "Widget installed to $DEST"

# Install notifyrc so KNotification works
NOTIFYRC_SRC="$SCRIPT_DIR/package/contents/knotifications6/plasma_meets.notifyrc"
NOTIFYRC_DST="$HOME/.local/share/knotifications6/plasma_meets.notifyrc"
mkdir -p "$HOME/.local/share/knotifications6"
cp "$NOTIFYRC_SRC" "$NOTIFYRC_DST"
echo "Notifications configured."

echo ""
echo "To use: right-click on the desktop or panel → Add Widgets → 'Plasma Meets'"
echo "To restart Plasma: kquitapp6 plasmashell && kstart plasmashell"
