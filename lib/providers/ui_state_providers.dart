import 'package:fide/constants/constants.dart';
import 'package:fide/models/image_backdrop.dart';
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

/// Whether each panel is expanded to its largest size; restoring it brings
/// back the size it had.
final leftPanelExpandedProvider = StateProvider<bool>((_ /*ref*/) => false);
final bottomPanelExpandedProvider = StateProvider<bool>((_ /*ref*/) => false);
final rightPanelExpandedProvider = StateProvider<bool>((_ /*ref*/) => false);

/// Theme mode provider (moved from app_providers.dart for better organization)
final themeModeProvider = StateProvider<ThemeMode>(
  (_ /*ref*/) => ThemeMode.system,
);

/// Zoom of the whole UI, [AppZoom.actualSize] for unscaled.
final zoomProvider = StateProvider<double>((_ /*ref*/) => AppZoom.actualSize);

/// Whether the center panel shows the App Icons view instead of the
/// editor or the project overview.
final appIconsVisibleProvider = StateProvider<bool>((_ /*ref*/) => false);

/// What image previews are drawn on, kept from one image to the next.
final imageBackdropProvider = StateProvider<ImageBackdrop>(
  (_ /*ref*/) => ImageBackdrop.transparent,
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

/// Text the Search panel should search for, waiting to be picked up; the
/// panel focuses its input and clears it once shown. Empty focuses the input
/// without changing its text.
final projectSearchRequestProvider = StateProvider<String?>(
  (_ /*ref*/) => null,
);
