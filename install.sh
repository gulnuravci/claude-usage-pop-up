#!/bin/bash
# Builds Claude Usage Popup from this folder and installs it to your Applications folder.
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Claude Usage Popup"
# Use the main Applications folder when we can (no password needed on most Macs), so the app
# shows up in Finder and Launchpad. Otherwise use the one in your home folder.
if [[ -z "${INSTALL_DIR:-}" ]]; then
  if [[ -w /Applications ]]; then INSTALL_DIR="/Applications"; else INSTALL_DIR="$HOME/Applications"; fi
fi

if ! command -v swift >/dev/null 2>&1; then
  echo "Swift isn't installed. Run this, then try again:"
  echo "  xcode-select --install"
  exit 1
fi

echo "🔨 Building (the first build takes a minute)…"
scripts/build-app.sh

echo "🚚 Installing to ${INSTALL_DIR}…"
pkill -x ClaudeUsagePopup 2>/dev/null && sleep 1 || true
mkdir -p "$INSTALL_DIR"
rm -rf "$INSTALL_DIR/$APP_NAME.app"
# Remove a copy left in the other Applications folder by an older install.
for dir in /Applications "$HOME/Applications"; do
  if [[ "$dir" != "$INSTALL_DIR" && -d "$dir/$APP_NAME.app" ]]; then rm -rf "$dir/$APP_NAME.app" 2>/dev/null || true; fi
done
cp -R "build/$APP_NAME.app" "$INSTALL_DIR/"
open "$INSTALL_DIR/$APP_NAME.app"

echo ""
echo "✨ Done! Look for the little ring in your menu bar and Tok in the top-right corner."
echo "   It starts automatically when you log in (turn that off from the menu bar item)."
