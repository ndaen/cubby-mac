#!/usr/bin/env bash
# Construit Cubby.app + Cubby-<version>.dmg dans ./dist (n'installe rien).
# Source unique partagée par build-app.sh (install local) et la CI (release).
# Usage : bash package.sh [version]   (défaut : 0.1.0)
set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="${1:-0.1.0}"
DIST="$DIR/dist"
APP="$DIST/Cubby.app"

echo "▸ build release…"
swift build -c release --package-path "$DIR"

echo "▸ assemblage du bundle (v$VERSION)…"
rm -rf "$DIST"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$DIR/.build/release/Cubby" "$APP/Contents/MacOS/Cubby"
if [ -f "$DIR/Logo/Cubby.icns" ]; then
  cp "$DIR/Logo/Cubby.icns" "$APP/Contents/Resources/AppIcon.icns"
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Cubby</string>
  <key>CFBundleDisplayName</key><string>Cubby</string>
  <key>CFBundleIdentifier</key><string>com.cubby.app</string>
  <key>CFBundleExecutable</key><string>Cubby</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleIconName</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSAppleEventsUsageDescription</key><string>Cubby controls Apple Music to show and control playback from the notch.</string>
</dict>
</plist>
PLIST

# signature ad-hoc (identifiant stable → TCC redemande proprement après rebuild)
codesign --force --deep --sign - --identifier com.cubby.app "$APP" 2>/dev/null || true

echo "▸ DMG…"
STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/Cubby.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "Cubby" -srcfolder "$STAGE" -ov -format UDZO "$DIST/Cubby-$VERSION.dmg" >/dev/null
rm -rf "$STAGE"

echo "✅ dist/ :"
ls -1 "$DIST"
