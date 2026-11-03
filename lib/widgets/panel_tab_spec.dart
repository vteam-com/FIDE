import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

/// What a side panel shows under one of its tabs and flags on the tab's
/// header; the tab's key, label, icon and shortcut are the enum value's.
/// Adding a tab is adding its enum value and its spec.
class PanelTabSpec<T extends Enum> {
  /// Count of pending items flagged on the tab's header; null for a tab
  /// without a badge.
  final ProviderListenable<int>? badge;

  /// Builds the panel shown under the tab.
  final Widget Function() build;

  /// The tab.
  final T tab;

  /// Creates the spec of [tab].
  const PanelTabSpec(this.tab, {required this.build, this.badge});

  /// The count flagged on the tab's header, watched through [ref]; zero
  /// for a tab without a badge.
  int badgeCount(WidgetRef ref) {
    final badge = this.badge;
    return badge == null ? 0 : ref.watch(badge);
  }
}
