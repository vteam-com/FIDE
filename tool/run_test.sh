#!/usr/bin/env bash
set -e

clear

# Run unit tests
flutter test --coverage --coverage-path=coverage/unit.info

# Run integration tests
flutter test integration_test --coverage --coverage-path=coverage/integration.info -d macos

# Merge coverage
lcov --add-tracefile coverage/unit.info \
     --add-tracefile coverage/integration.info \
     --output-file coverage/lcov.info > /dev/null 2>&1

# Generate HTML report
genhtml coverage/lcov.info -o coverage/html > /dev/null 2>&1

open coverage/html/index.html