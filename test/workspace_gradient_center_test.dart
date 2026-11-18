import 'package:fide/providers/project_lifecycle_providers.dart';
import 'package:fide/providers/side_panel.dart';
import 'package:fide/providers/ui_state_providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Where the editor area's island sits, as fractions of the window, below
/// a title bar an eighth of its height and above the bottom panel.
const Rect _editor = Rect.fromLTRB(0.25, 0.125, 0.75, 0.75);

/// Where each side panel's island sits, as fractions of the window.
const Map<SidePanel, Rect> _panels = {
  SidePanel.left: Rect.fromLTRB(0, 0.125, 0.25, 1),
  SidePanel.bottom: Rect.fromLTRB(0.25, 0.75, 0.75, 1),
  SidePanel.right: Rect.fromLTRB(0.75, 0.125, 1, 1),
};

/// The middle of [island], as the gradient's center.
Alignment _middle(Rect island) =>
    FractionalOffset(island.center.dx, island.center.dy);

void main() {
  /// A container whose project is open, so the IDE layout shows, and
  /// whose islands have all reported where they sit.
  ProviderContainer openProject() {
    final container = ProviderContainer(
      overrides: [projectLoadedProvider.overrideWith((_) => true)],
    );
    addTearDown(container.dispose);
    container.read(islandWindowRectProvider(null).notifier).state = _editor;
    _panels.forEach((panel, rect) {
      container.read(islandWindowRectProvider(panel).notifier).state = rect;
    });
    return container;
  }

  test('centers in the middle of the active island, the editor by default', () {
    final container = openProject();
    final active = container.read(activePanelProvider.notifier);
    Alignment center() => container.read(workspaceGradientCenterProvider);

    expect(center(), _middle(_editor));
    active.state = SidePanel.left;
    expect(center(), _middle(_panels[SidePanel.left]!));
    active.state = SidePanel.right;
    expect(center(), _middle(_panels[SidePanel.right]!));
    // The bottom panel starts hidden
    container.read(SidePanel.bottom.visibleProvider.notifier).state = true;
    active.state = SidePanel.bottom;
    expect(center(), _middle(_panels[SidePanel.bottom]!));
    active.state = null;
    expect(center(), _middle(_editor));
  });

  test('follows the active island as it reports a move', () {
    final container = openProject();
    // The left panel hides: the editor widens to the window's left edge
    const widened = Rect.fromLTRB(0, 0.125, 0.75, 1);
    container.read(SidePanel.left.visibleProvider.notifier).state = false;
    container.read(islandWindowRectProvider(null).notifier).state = widened;
    expect(container.read(workspaceGradientCenterProvider), _middle(widened));
  });

  test('returns to the editor once the active panel hides', () {
    final container = openProject();
    container.read(activePanelProvider.notifier).state = SidePanel.left;
    container.read(SidePanel.left.visibleProvider.notifier).state = false;
    expect(container.read(workspaceGradientCenterProvider), _middle(_editor));
  });

  test('stays at the top until the island reports', () {
    final container = ProviderContainer(
      overrides: [projectLoadedProvider.overrideWith((_) => true)],
    );
    addTearDown(container.dispose);
    container.read(activePanelProvider.notifier).state = SidePanel.right;
    expect(
      container.read(workspaceGradientCenterProvider),
      Alignment.topCenter,
    );
  });

  test('moves to the top for the settings, then back to the panel', () {
    final container = openProject();
    Alignment center() => container.read(workspaceGradientCenterProvider);
    final settings = container.read(settingsVisibleProvider.notifier);
    container.read(activePanelProvider.notifier).state = SidePanel.right;

    settings.state = true;
    expect(center(), Alignment.topCenter);
    settings.state = false;
    expect(center(), _middle(_panels[SidePanel.right]!));
  });

  test('stays at the top while no project is open', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(islandWindowRectProvider(SidePanel.right).notifier).state =
        _panels[SidePanel.right];
    container.read(activePanelProvider.notifier).state = SidePanel.right;
    expect(
      container.read(workspaceGradientCenterProvider),
      Alignment.topCenter,
    );
  });
}
