#!/bin/bash
# Runs the rule tests on a throwaway tvOS simulator, for CI. Some GitHub runner images come
# without the tvOS platform, so it gets downloaded first when it's missing.
set -euo pipefail
cd "$(dirname "$0")/.."

if ! xcrun simctl list runtimes available | grep -q tvOS; then
  xcodebuild -downloadPlatform tvOS
fi
runtime=$(xcrun simctl list runtimes available | grep tvOS | tail -1 | sed -E 's/.* - (com\.apple\.CoreSimulator\.SimRuntime\.tvOS[^ ]*).*/\1/')
device=$(xcrun simctl create "Snake CI" com.apple.CoreSimulator.SimDeviceType.Apple-TV-4K-3rd-generation-4K "$runtime")
trap 'xcrun simctl delete "$device"' EXIT

xcodebuild test -project Snake.xcodeproj -scheme Snake -destination "id=$device" \
  -only-testing:SnakeTests CODE_SIGNING_ALLOWED=NO
