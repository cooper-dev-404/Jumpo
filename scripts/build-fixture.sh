#!/bin/bash
set -euo pipefail
JUMPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$JUMPO_ROOT"
JUMPO_FIXTURE="$JUMPO_ROOT/.build/Jumpo Window Fixture.app"
mkdir -p "$JUMPO_FIXTURE/Contents/MacOS" .build/module-cache
swiftc -parse-as-library -swift-version 6 -module-cache-path .build/module-cache \
    Tools/WindowFixture.swift -o "$JUMPO_FIXTURE/Contents/MacOS/WindowFixture"
cat > "$JUMPO_FIXTURE/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>local.jumpo.window-fixture</string>
<key>CFBundleName</key><string>Jumpo Window Fixture</string>
<key>CFBundleExecutable</key><string>WindowFixture</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST
codesign --force --sign - "$JUMPO_FIXTURE"
printf 'Built %s\n' "$JUMPO_FIXTURE"
