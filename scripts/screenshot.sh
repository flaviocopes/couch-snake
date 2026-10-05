#!/bin/bash
# Captures docs/screenshot.png from the app in a tvOS simulator. The simulator boots headless.
set -euo pipefail
cd "$(dirname "$0")/.."

device="Apple TV 4K (3rd generation)"
xcodebuild -project Snake.xcodeproj -scheme Snake -destination "platform=tvOS Simulator,name=$device" \
  -derivedDataPath build/sim -quiet build
xcrun simctl boot "$device" 2>/dev/null || true
# A fresh simulator can fail the first install, so it gets a second try.
xcrun simctl install "$device" build/sim/Build/Products/Debug-appletvsimulator/Snake.app \
  || { sleep 5; xcrun simctl install "$device" build/sim/Build/Products/Debug-appletvsimulator/Snake.app; }
# -best 0 overrides the saved best score, so the screenshot shows HI 0000.
xcrun simctl launch --terminate-running-process "$device" com.flaviocopes.snake -best 0 >/dev/null
sleep 3
xcrun simctl io "$device" screenshot build/screenshot-4k.png
sips -Z 1920 build/screenshot-4k.png --out docs/screenshot.png >/dev/null
xcrun simctl shutdown "$device"
echo "Wrote docs/screenshot.png"
