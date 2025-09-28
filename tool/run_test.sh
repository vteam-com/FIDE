#!/usr/bin/env bash
set -e

# Run unit tests
flutter test --coverage --coverage-path=coverage/unit.info

# Run integration tests
flutter test integration_test --coverage --coverage-path=coverage/integration.info -d macos

# Merge coverage
lcov --add-tracefile coverage/unit.info \
     --add-tracefile coverage/integration.info \
     --output-file coverage/lcov.info

# Generate HTML report
genhtml coverage/lcov.info -o coverage/html

open coverage/html/index.html