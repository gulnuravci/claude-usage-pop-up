#!/bin/bash
# One-line installer for Claude Usage Popup:
#   curl -fsSL https://raw.githubusercontent.com/gulnuravci/claude-usage-pop-up/main/get.sh | bash
#
# Downloads the latest release and puts it in ~/Applications. If there's no release to download,
# it builds from source instead (that needs Apple's command line tools).
set -euo pipefail

REPO="gulnuravci/claude-usage-pop-up"
APP_NAME="Claude Usage Popup"
INSTALL_DIR="${INSTALL_DIR:-$HOME/Applications}"
ZIP_URL="${ZIP_URL:-https://github.com/$REPO/releases/latest/download/ClaudeUsagePopup.zip}"

if [[ "$(uname)" != "Darwin" ]]; then
  echo "Sorry, Claude Usage Popup only runs on macOS."
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "⬇️  Downloading Claude Usage Popup…"
if curl -fsSL "$ZIP_URL" -o "$TMP/app.zip"; then
  ditto -x -k "$TMP/app.zip" "$TMP"
  APP_SRC="$TMP/$APP_NAME.app"
else
  echo "   No download available, so building from source instead."
  if ! command -v swift >/dev/null 2>&1; then
    echo "   That needs Apple's command line tools. Run this, then try again:"
    echo "     xcode-select --install"
    exit 1
  fi
  git clone --quiet --depth 1 "https://github.com/$REPO.git" "$TMP/src"
  "$TMP/src/scripts/build-app.sh"
  APP_SRC="$TMP/src/build/$APP_NAME.app"
fi

echo "🚚 Installing to ${INSTALL_DIR}…"
pkill -x ClaudeUsagePopup 2>/dev/null && sleep 1 || true
mkdir -p "$INSTALL_DIR"
rm -rf "$INSTALL_DIR/$APP_NAME.app"
ditto "$APP_SRC" "$INSTALL_DIR/$APP_NAME.app"
open "$INSTALL_DIR/$APP_NAME.app"

echo ""
echo "✨ Done! Look for the little ring in your menu bar and Tok in the top-right corner."
echo "   It starts automatically when you log in (turn that off from the menu bar item)."
echo "   To update later, just run this command again."
