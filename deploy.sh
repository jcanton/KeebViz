#!/bin/bash
set -e
cd "$(dirname "$0")"
swift build -c release
cp .build/release/KeebViz dist/KeebViz.app/Contents/MacOS/KeebViz
touch dist/KeebViz.app
rm -f ~/Applications/KeebViz.app
ln -s "$PWD/dist/KeebViz.app" ~/Applications/KeebViz.app
rm -f ~/Library/LaunchAgents/com.keebviz.launcher.plist
ln -s "$PWD/dist/com.keebviz.launcher.plist" ~/Library/LaunchAgents/com.keebviz.launcher.plist
launchctl load ~/Library/LaunchAgents/com.keebviz.launcher.plist 2>/dev/null || true
echo "Deployed. Running launchctl kickstart..."
launchctl kickstart -k gui/$(id -u)/com.keebviz.launcher 2>/dev/null || true
echo "Done. KeebViz is running."