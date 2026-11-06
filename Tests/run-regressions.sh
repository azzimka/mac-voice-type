#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
TEST_DIR=$(mktemp -d /tmp/froggy-tests.XXXXXX)
trap 'rm -rf "$TEST_DIR"' EXIT
# Standalone runner works with Command Line Tools, without XCTest/Xcode.
swiftc -parse-as-library -o "$TEST_DIR/regressions" \
  Sources/Froggy/Core/RecordingSignalMeter.swift \
  Sources/Froggy/Core/WhisperArtifactFilter.swift \
  Sources/Froggy/Services/GroqClient.swift \
  Sources/Froggy/UI/FloatingHUDView.swift \
  Sources/Froggy/UI/FloatingHUDWindow.swift \
  Sources/Froggy/UI/WaveformView.swift \
  Tests/FroggyTests/*.swift
"$TEST_DIR/regressions"
