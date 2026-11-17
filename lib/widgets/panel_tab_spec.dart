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

  /// Whether the panel's work, which can outlast the panel, is running,
  /// ringing the tab's icon so it shows from the other tabs; null for a
  /// tab that never rings.
  final ProviderListenable<bool>? busy;

  /// The tab.
  final T tab;

  /// Creates the spec of [tab].
  const PanelTabSpec(this.tab, {required this.build, this.badge, this.busy});

  /// The count flagged on the tab's header, watched through [ref]; zero
  /// for a tab without a badge.
  int badgeCount(WidgetRef ref) {
    final badge = this.badge;
    return badge == null ? 0 : ref.watch(badge);
  }

  /// Whether the tab's header rings its icon, watched through [ref];
  /// false for a tab without [busy].
  bool isBusy(WidgetRef ref) {
    final busy = this.busy;
    return busy != null && ref.watch(busy);
  }
}
