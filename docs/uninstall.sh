#!/bin/bash
set -e
echo "🗑️ Uninstalling QuickAccess..."
killall QuickAccess 2>/dev/null || true
osascript -e 'tell application "System Events" to delete login item "QuickAccess"' 2>/dev/null || true
rm -rf /Applications/QuickAccess.app
rm -f ~/.quickaccess.json
echo "✅ QuickAccess removed (app + config + login item)."
