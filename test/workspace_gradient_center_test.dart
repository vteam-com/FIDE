import 'package:fide/providers/project_lifecycle_providers.dart';
import 'package:fide/providers/side_panel.dart';
import 'package:fide/providers/ui_state_providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// A container whose project is open, so the IDE layout shows.
  ProviderContainer openProject() {
    final container = ProviderContainer(
      overrides: [projectLoadedProvider.overrideWith((_) => true)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('centers on the active panel, at the top for the editor', () {
    final container = openProject();
    final active = container.read(activePanelProvider.notifier);
    Alignment center() => container.read(workspaceGradientCenterProvider);

    expect(center(), Alignment.topCenter);
    active.state = SidePanel.left;
    expect(center(), Alignment.centerLeft);
    active.state = SidePanel.right;
    expect(center(), Alignment.centerRight);
    // The bottom panel starts hidden
    container.read(SidePanel.bottom.visibleProvider.notifier).state = true;
    active.state = SidePanel.bottom;
    expect(center(), Alignment.bottomCenter);
    active.state = null;
    expect(center(), Alignment.topCenter);
  });

  test('returns to the top once the active panel hides', () {
    final container = openProject();
    container.read(activePanelProvider.notifier).state = SidePanel.left;
    container.read(SidePanel.left.visibleProvider.notifier).state = false;
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
    expect(center(), Alignment.centerRight);
  });

  test('stays at the top while no project is open', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(activePanelProvider.notifier).state = SidePanel.right;
    expect(
      container.read(workspaceGradientCenterProvider),
      Alignment.topCenter,
    );
  });
}
