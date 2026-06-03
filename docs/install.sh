#!/bin/bash
set -e
echo "⚡ Installing QuickAccess..."
cd /tmp
curl -sL https://milv0.github.io/QuickAccess/QuickAccess-v2.2.0.zip -o QuickAccess-v2.2.0.zip
unzip -qo QuickAccess-v2.2.0.zip
xattr -cr QuickAccess.app
rm -rf /Applications/QuickAccess.app
mv QuickAccess.app /Applications/
rm -f QuickAccess-v2.2.0.zip
echo "✅ Installed to /Applications/QuickAccess.app"
sleep 1
echo "🚀 Launching..."
open /Applications/QuickAccess.app
