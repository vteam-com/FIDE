#!/usr/bin/env bash
set -e

clear

# Run AI service integration tests
# These tests exercise AIService.generateProject() to create TicTacToe games
# and validate they build successfully with Flutter
# Ollama will be started automatically if not running
echo "🚀 Running AI Service Tests - TicTacToe Game Generation & Build Validation"
flutter test integration_test/ai_service_test.dart -d macos