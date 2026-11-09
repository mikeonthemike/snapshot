#!/bin/zsh
# Builds Snapshot.app (menu bar screenshot tool) into ./build
set -euo pipefail
cd "$(dirname "$0")"

APP=build/Snapshot.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -O -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk Sources/main.swift -o "$APP/Contents/MacOS/Snapshot"

cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Snapshot</string>
  <key>CFBundleDisplayName</key><string>Snapshot</string>
  <key>CFBundleIdentifier</key><string>com.javln.snapshot</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleExecutable</key><string>Snapshot</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>15.0</string>
  <key>LSUIElement</key><true/>
  <key>NSMicrophoneUsageDescription</key><string>Snapshot can record your microphone alongside screen recordings.</string>
  <key>NSScreenCaptureUsageDescription</key><string>Snapshot needs screen recording access to capture screenshots.</string>
</dict>
</plist>
EOF

# Ad-hoc sign with a requirement tied to the bundle id (not the code hash), so macOS keeps
# the Screen Recording permission across rebuilds.
codesign --force --sign - -r='designated => identifier "com.javln.snapshot"' "$APP"
echo "Built $APP"

# Install a copy where Spotlight, Raycast and Login Items can find it.
# Set INSTALL_DIR=/Applications to install system-wide instead.
INSTALL_DIR="${INSTALL_DIR:-$HOME/Applications}"
mkdir -p "$INSTALL_DIR"
rm -rf "$INSTALL_DIR/Snapshot.app"
ditto "$APP" "$INSTALL_DIR/Snapshot.app"
echo "Installed $INSTALL_DIR/Snapshot.app"
