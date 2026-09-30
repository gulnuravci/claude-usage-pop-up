#!/bin/bash
# Removes Claude Usage Popup and its settings.
set -euo pipefail

APP_NAME="Claude Usage Popup"

pkill -x ClaudeUsagePopup 2>/dev/null || true
for dir in /Applications "$HOME/Applications"; do
  if [[ -d "$dir/$APP_NAME.app" ]]; then rm -rf "$dir/$APP_NAME.app"; fi
done
defaults delete io.github.claude-usage-popup 2>/dev/null || true
echo "👋 Uninstalled. (If it still shows under System Settings → General → Login Items, remove it there.)"
