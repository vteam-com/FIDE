#!/bin/sh
# Regenerates the README screenshots in docs/screenshots: runs FIDE on
# macOS, opens this repository and saves each view as drawn by the app
echo --- README screenshots
flutter test integration_test/screenshots_test.dart -d macos --dart-define=FIDE_ROOT="$PWD"
