#!/usr/bin/env bash
# Construit Cubby.app (bundle macOS autonome) dans /Applications.
set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"   # .../notch
APP="/Applications/Cubby.app"

echo "▸ build release…"
swift build -c release --package-path "$DIR"

echo "▸ assemblage du bundle…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$DIR/.build/release/Cubby" "$APP/Contents/MacOS/Cubby"
if [ -f "$DIR/Logo/Cubby.icns" ]; then
  cp "$DIR/Logo/Cubby.icns" "$APP/Contents/Resources/AppIcon.icns"
fi

cat > "$APP/Contents/Info.plist" <<'PLIST'
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
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSAppleEventsUsageDescription</key><string>Cubby controls Apple Music to show and control playback from the notch.</string>
</dict>
</plist>
PLIST

# enlève l'attribut de quarantaine (build local) pour éviter les blocages Gatekeeper
xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true

# signature ad-hoc avec identifiant stable → TCC (autorisation Music) redemande
# proprement après un rebuild au lieu de refuser en silence.
codesign --force --deep --sign - --identifier com.cubby.app "$APP" 2>/dev/null || true

echo "✅ $APP créé."
echo "   Lancer : open \"$APP\"   (ou double-clic dans /Applications)"
