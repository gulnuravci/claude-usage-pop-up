#!/bin/bash
# Removes Claude Usage Popup and its settings.
set -euo pipefail

APP_NAME="Claude Usage Popup"
INSTALL_DIR="${INSTALL_DIR:-$HOME/Applications}"

pkill -x ClaudeUsagePopup 2>/dev/null || true
rm -rf "$INSTALL_DIR/$APP_NAME.app"
defaults delete io.github.claude-usage-popup 2>/dev/null || true
echo "👋 Uninstalled. (If it still shows under System Settings → General → Login Items, remove it there.)"
