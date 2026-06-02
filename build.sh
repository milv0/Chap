#!/bin/bash
set -e
cd "$(dirname "$0")"
mkdir -p QuickAccess.app/Contents/MacOS QuickAccess.app/Contents/Resources
git checkout HEAD -- QuickAccess.app/Contents/Info.plist QuickAccess.app/Contents/Resources/AppIcon.icns 2>/dev/null || true
swiftc QuickAccess.swift -o QuickAccess.app/Contents/MacOS/QuickAccess -framework Cocoa
echo "✅ Build complete. Run: open QuickAccess.app"
