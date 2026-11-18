import 'package:fide/constants/constants.dart';
import 'package:fide/models/app_release.dart';
import 'package:fide/models/readable_error.dart';
import 'package:fide/models/shortcut_help_entry.dart';
import 'package:fide/providers/app_update_notifier.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/providers/ui_state_providers.dart';
import 'package:fide/widget_services/update_button.dart';
import 'package:fide/widgets/action_card.dart';
import 'package:fide/widgets/card_grid.dart';
import 'package:fide/widgets/centered_content.dart';
import 'package:fide/widgets/hero_title_widget.dart';
import 'package:fide/widgets/outlined_surface.dart';
import 'package:fide/widgets/page_scroll_view.dart';
import 'package:fide/widgets/refresh_button.dart';
import 'package:fide/widgets/section_title.dart';
import 'package:fide/widgets/theme_mode_buttons.dart';
import 'package:fide/widgets/zoom_buttons.dart';
import 'package:fide/widgets/zoom_label.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// The full-screen settings: the display mode and zoom, FIDE's version and
/// its updates, then the keyboard shortcuts of the app's menus. Escape or
/// the title bar's close button leaves it, giving the keyboard focus back
/// to where it was.
///
/// It paints no background: it shows on the window's workspace gradient.
class SettingsScreen extends ConsumerStatefulWidget {
  /// Creates the settings listing the shortcuts of [menus].
  const SettingsScreen({super.key, required this.menus, required this.onClose});

  /// The native menus whose shortcuts the help lists.
  final List<PlatformMenuItem> menus;

  /// Closes the screen.
  final VoidCallback onClose;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  /// Takes focus from the view underneath, so Escape reaches this screen.
  final FocusNode _focusNode = FocusNode();

  /// What had the focus before this screen took it, such as the editor;
  /// it gets it back when the screen closes.
  FocusNode? _previousFocus;

  @override
  void initState() {
    super.initState();
    _previousFocus = FocusManager.instance.primaryFocus;
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    final previous = _previousFocus;
    if (previous != null && previous.context != null) previous.requestFocus();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final byMenu = <String, List<ShortcutHelpEntry>>{};
    for (final entry in ShortcutHelpEntry.fromMenus(
      widget.menus,
      aliases: AppShortcut.aliases,
    )) {
      byMenu.putIfAbsent(entry.menu, () => []).add(entry);
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): widget.onClose,
      },
      child: Focus(
        focusNode: _focusNode,
        child: PageScrollView(
          children: [
            CenteredContent(
              maxWidth: AppSize.welcomeContentWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: AppSpacing.xxLarge,
                children: [
                  // The title bar's close button leaves the screen
                  const HeroTitleWidget(
                    title: AppName.short,
                    subTitle: AppName.full,
                  ),
                  _buildSection('Appearance', [
                    _buildSettingRow(
                      'Display mode',
                      _buildDisplayModeButtons(),
                    ),
                    _buildSettingRow('Zoom', _buildZoomButtons()),
                  ]),
                  _buildSection('Updates', [_buildUpdateRow()]),
                ],
              ),
            ),
            // The shortcut cards wrap across the window's width, the
            // section as wide as their widest row and centered
            CenteredContent(
              child: _buildSection('Keyboard Shortcuts', [
                CardGrid(
                  children: [
                    for (final MapEntry(key: menu, value: entries)
                        in byMenu.entries)
                      _buildShortcutGroup(menu, entries),
                  ],
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  /// The section [title] over its [children], as wide as the widest child
  /// that does not fill the width.
  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.xLarge,
      children: [SectionTitle(title), ...children],
    );
  }

  /// The box naming a setting by [label], its [control] at the end.
  Widget _buildSettingRow(String label, Widget control) {
    return OutlinedSurface(
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTextStyle.body)),
          control,
        ],
      ),
    );
  }

  /// The System / Light / Dark choice, applied as soon as it is picked.
  Widget _buildDisplayModeButtons() {
    return ThemeModeButtons(
      selected: ref.watch(themeModeProvider),
      onSelected: ref.read(themeModeProvider.notifier).select,
    );
  }

  /// Zoom Out, the current zoom (resetting it on a click) and Zoom In,
  /// as the View menu's zoom items.
  Widget _buildZoomButtons() {
    final controller = ref.read(zoomProvider.notifier);
    final zoom = ref.watch(zoomProvider);
    return ZoomButtons(
      label: ZoomLabel(
        scale: zoom,
        onReset: controller.resetZoom,
        tooltip: ShortcutHelpEntry.tooltip(
          ZoomLabel.defaultTooltip,
          AppShortcut.actualSize,
        ),
      ),
      zoomOutTooltip: ShortcutHelpEntry.tooltip(
        'Zoom Out',
        AppShortcut.zoomOut,
      ),
      zoomInTooltip: ShortcutHelpEntry.tooltip('Zoom In', AppShortcut.zoomIn),
      onZoomOut: zoom > AppZoom.levels.first ? controller.zoomOut : null,
      onZoomIn: zoom < AppZoom.levels.last ? controller.zoomIn : null,
    );
  }

  /// The running version and whether a newer one is out, beside the
  /// button installing it and the one checking again.
  Widget _buildUpdateRow() {
    final canUpdate = ref.watch(appUpdaterProvider) != null;
    final update = ref.watch(appUpdateProvider);
    return _buildSettingRow(
      _updateSummary(canUpdate, update),
      Row(
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpacing.medium,
        children: [
          const UpdateButton(),
          if (canUpdate)
            RefreshButton(
              onPressed: ref.read(appUpdateProvider.notifier).check,
              busy: update.isLoading,
            ),
        ],
      ),
    );
  }

  /// The running version, then what the last check for a newer one,
  /// [update], found; a build that can't update itself, as [canUpdate]
  /// tells, runs from its source code.
  String _updateSummary(bool canUpdate, AsyncValue<AppRelease?> update) {
    final running =
        '${AppName.short} ${ref.watch(appVersionProvider).value ?? ''}';
    final release = update.value;
    return switch (update) {
      _ when !canUpdate =>
        '$running runs from its source code, which Git updates',
      AsyncError(:final error) =>
        "$running: couldn't check for a newer version: "
            '${ReadableError.describe(error)}',
      _ when release != null =>
        '$running: version ${release.version} is available',
      AsyncValue(hasValue: true) => '$running is up to date',
      _ => running,
    };
  }

  /// The card listing the [entries] of [menu], each command beside its
  /// keys.
  Widget _buildShortcutGroup(String menu, List<ShortcutHelpEntry> entries) {
    final keysStyle = AppTextStyle.bodyStrong.copyWith(
      color: Theme.of(context).colorScheme.primary,
    );
    return ActionCard(
      title: menu,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.small,
        children: [
          for (final entry in entries)
            Row(
              children: [
                Expanded(child: Text(entry.label, style: AppTextStyle.body)),
                Text.rich(
                  TextSpan(
                    children: [
                      for (final (index, keys) in entry.keys.indexed) ...[
                        if (index > 0)
                          TextSpan(
                            text: ' or ',
                            style: AppTextStyle.secondary(context),
                          ),
                        TextSpan(text: keys, style: keysStyle),
                      ],
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
