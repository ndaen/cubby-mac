#!/usr/bin/env bash
# Active / désactive le lancement de Cubby à l'ouverture de session.
# Usage : bash autostart.sh on   |   bash autostart.sh off
set -e
LABEL="com.cubby.app"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
BIN="/Applications/Cubby.app/Contents/MacOS/Cubby"
ACTION="${1:-on}"

if [ "$ACTION" = "off" ]; then
  launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
  rm -f "$PLIST"
  echo "🛑 Lancement au login désactivé."
  exit 0
fi

mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key><array><string>$BIN</string></array>
  <key>RunAtLoad</key><true/>
  <key>ProcessType</key><string>Interactive</string>
</dict>
</plist>
PL

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "✅ Cubby se lancera à chaque ouverture de session."
echo "   (désactiver : bash autostart.sh off)"
