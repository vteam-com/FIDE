import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';

// UI State Providers - extracted from main.dart for better separation

/// Panel visibility state providers
final leftPanelVisibleProvider = StateProvider<bool>((ref) => true);
final bottomPanelVisibleProvider = StateProvider<bool>((ref) => false);
final rightPanelVisibleProvider = StateProvider<bool>((ref) => true);

/// Theme mode provider (moved from app_providers.dart for better organization)
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

/// Active panel index providers (moved here for UI state organization)
final activeLeftPanelTabProvider = StateProvider<int>((ref) => 0);
final activeRightPanelTabProvider = StateProvider<int>((ref) => 0);
