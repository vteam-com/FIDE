import 'package:fide/models/left_panel_tab.dart';
import 'package:fide/models/reference_search.dart';
import 'package:fide/models/right_panel_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';

// UI State Providers - extracted from main.dart for better separation

/// Panel visibility state providers
final leftPanelVisibleProvider = StateProvider<bool>((_ /*ref*/) => true);
final bottomPanelVisibleProvider = StateProvider<bool>((_ /*ref*/) => false);
final rightPanelVisibleProvider = StateProvider<bool>((_ /*ref*/) => true);

/// Theme mode provider (moved from app_providers.dart for better organization)
final themeModeProvider = StateProvider<ThemeMode>(
  (_ /*ref*/) => ThemeMode.system,
);

/// The tab shown in the left panel.
final activeLeftPanelTabProvider = StateProvider<LeftPanelTab>(
  (_ /*ref*/) => LeftPanelTab.values.first,
);

/// The tab shown in the right panel.
final activeRightPanelTabProvider = StateProvider<RightPanelTab>(
  (_ /*ref*/) => RightPanelTab.values.first,
);

/// 1-based line of the caret in the active editor, for panels that track it.
final editorCursorLineProvider = StateProvider<int>((_ /*ref*/) => 1);

/// Uses of a declaration waiting to be listed by the Search panel, which
/// clears it once shown.
final referenceSearchProvider = StateProvider<ReferenceSearch?>(
  (_ /*ref*/) => null,
);
