#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
REPO="$PWD"
APP="${1:-$HOME/MGS4-Native/MGS4 Builder.app}"
ICON="$REPO/tools/mgs4-builder/AppIcon.icns"
[ -f "$ICON" ] || { echo "Missing icon: $ICON" >&2; exit 1; }
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ICON" "$APP/Contents/Resources/AppIcon.icns"
xcrun swiftc -O -parse-as-library -target arm64-apple-macos14.0 -framework SwiftUI -framework AppKit "$REPO/tools/mgs4-builder/Builder.swift" -o "$APP/Contents/MacOS/MGS4Builder"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>MGS4Builder</string>
<key>CFBundleIdentifier</key><string>org.nxnative.mgs4builder</string>
<key>CFBundleIconFile</key><string>AppIcon.icns</string>
<key>CFBundleName</key><string>MGS4 Builder</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.1</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
codesign --verify --strict "$APP"
open "$APP"
