import 'package:fide/models/image_backdrop.dart';
import 'package:fide/models/reference_search.dart';
import 'package:fide/providers/left_panel_tab.dart';
import 'package:fide/providers/right_panel_tab.dart';
import 'package:fide/providers/side_panel.dart';
import 'package:flutter_riverpod/legacy.dart';

export 'package:fide/providers/theme_mode_notifier.dart';
export 'package:fide/providers/zoom_notifier.dart';

// UI State Providers - extracted from main.dart for better separation

/// Whether each side panel is shown, by name: [SidePanel.visibleProvider].
final leftPanelVisibleProvider = SidePanel.left.visibleProvider;
final bottomPanelVisibleProvider = SidePanel.bottom.visibleProvider;
final rightPanelVisibleProvider = SidePanel.right.visibleProvider;

/// Whether each side panel is expanded to its largest size, by name:
/// [SidePanel.expandedProvider].
final leftPanelExpandedProvider = SidePanel.left.expandedProvider;
final bottomPanelExpandedProvider = SidePanel.bottom.expandedProvider;
final rightPanelExpandedProvider = SidePanel.right.expandedProvider;

/// Whether the settings screen covers the current view.
final settingsVisibleProvider = StateProvider<bool>((_ /*ref*/) => false);

/// Whether the center panel shows the App Icons view instead of the
/// editor or the project overview.
final appIconsVisibleProvider = StateProvider<bool>((_ /*ref*/) => false);

/// What image previews are drawn on, kept from one image to the next.
final imageBackdropProvider = StateProvider<ImageBackdrop>(
  (_ /*ref*/) => ImageBackdrop.transparent,
);

/// A file the Explorer is asked to reveal; it clears it once shown.
final explorerRevealPathProvider = StateProvider<String?>((_ /*ref*/) => null);

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
