#!/bin/bash
set -e
cd "$(dirname "$0")"
mkdir -p QuickAccess.app/Contents/MacOS
git checkout HEAD -- QuickAccess.app/Contents/Info.plist QuickAccess.app/Contents/Resources/AppIcon.icns 2>/dev/null || true
swiftc QuickAccess.swift -o QuickAccess.app/Contents/MacOS/QuickAccess -framework Cocoa -framework SwiftUI
rm -f docs/QuickAccess-v2.2.0.zip
zip -r docs/QuickAccess-v2.2.0.zip QuickAccess.app install.sh
echo "✅ Build complete + docs/QuickAccess-v2.2.0.zip updated"
echo "Run: open QuickAccess.app"
