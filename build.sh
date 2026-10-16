#!/bin/zsh
# Builds Snapshot.app (menu bar screenshot tool) into ./build
set -euo pipefail
cd "$(dirname "$0")"

APP=build/Snapshot.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

swiftc -O -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk Sources/main.swift -o "$APP/Contents/MacOS/Snapshot"

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Snapshot</string>
  <key>CFBundleDisplayName</key><string>Snapshot</string>
  <key>CFBundleIdentifier</key><string>com.javln.snapshot</string>
  <key>CFBundleExecutable</key><string>Snapshot</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSScreenCaptureUsageDescription</key><string>Snapshot needs screen recording access to capture screenshots.</string>
</dict>
</plist>
EOF

# Ad-hoc sign with a requirement tied to the bundle id (not the code hash), so macOS keeps
# the Screen Recording permission across rebuilds.
codesign --force --sign - -r='designated => identifier "com.javln.snapshot"' "$APP"
echo "Built $APP — run: open $APP"
