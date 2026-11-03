import 'package:fide/constants/constants.dart';
import 'package:fide/models/shortcut_help_entry.dart';
import 'package:fide/providers/ui_state_providers.dart';
import 'package:fide/theme/app_theme.dart';
import 'package:fide/widgets/choice_buttons.dart';
import 'package:fide/widgets/compact_icon_button.dart';
import 'package:fide/widgets/compact_text_button.dart';
import 'package:fide/widgets/outlined_surface.dart';
import 'package:fide/widgets/page_header.dart';
import 'package:fide/widgets/section_title.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The full-screen settings: the display mode and zoom, then the keyboard shortcuts
/// of the app's menus. Escape or the close button leaves it.
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

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _focusNode.dispose();
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
        child: DecoratedBox(
          decoration: AppTheme.workspaceBackground(context),
          // Padding inside the scroll view, so content scrolls to the edges
          child: SingleChildScrollView(
            padding: AppPadding.pageContent,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppSize.welcomeContentWidth,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: AppSpacing.xLarge,
                  children: [
                    PageHeader(
                      title: 'Settings',
                      logo: const Icon(
                        Icons.settings,
                        size: AppSize.heroLogoHeight,
                      ),
                      actions: [
                        CompactIconButton(
                          icon: Icons.close,
                          tooltip: 'Close (Esc)',
                          onPressed: widget.onClose,
                        ),
                      ],
                    ),
                    const SectionTitle('Appearance'),
                    OutlinedSurface(
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Display mode',
                              style: AppTextStyle.body,
                            ),
                          ),
                          _buildDisplayModeButtons(),
                        ],
                      ),
                    ),
                    OutlinedSurface(
                      child: Row(
                        children: [
                          Expanded(
                            child: Text('Zoom', style: AppTextStyle.body),
                          ),
                          _buildZoomButtons(),
                        ],
                      ),
                    ),
                    const SectionTitle('Keyboard Shortcuts'),
                    for (final MapEntry(key: menu, value: entries)
                        in byMenu.entries)
                      _buildShortcutGroup(menu, entries),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The System / Light / Dark choice, applied as soon as it is picked.
  Widget _buildDisplayModeButtons() {
    return ChoiceButtons(
      values: const [ThemeMode.system, ThemeMode.light, ThemeMode.dark],
      selected: ref.watch(themeModeProvider),
      icon: (mode) => switch (mode) {
        ThemeMode.system => Icons.brightness_auto,
        ThemeMode.light => Icons.light_mode,
        ThemeMode.dark => Icons.dark_mode,
      },
      label: (mode) => switch (mode) {
        ThemeMode.system => 'System',
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
      },
      onSelected: ref.read(themeModeProvider.notifier).select,
    );
  }

  /// Zoom Out, the current zoom (resetting it on a click) and Zoom In,
  /// as the View menu's zoom items.
  Widget _buildZoomButtons() {
    final controller = ref.read(zoomProvider.notifier);
    final zoom = ref.watch(zoomProvider);
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: AppSpacing.small,
      children: [
        CompactIconButton(
          icon: Icons.remove,
          tooltip: ShortcutHelpEntry.tooltip('Zoom Out', AppShortcut.zoomOut),
          onPressed: zoom > AppZoom.levels.first ? controller.zoomOut : null,
        ),
        Tooltip(
          message: ShortcutHelpEntry.tooltip(
            'Actual Size',
            AppShortcut.actualSize,
          ),
          child: CompactTextButton(
            label: AppZoom.label(zoom),
            onPressed: zoom == AppZoom.actualSize ? null : controller.resetZoom,
          ),
        ),
        CompactIconButton(
          icon: Icons.add,
          tooltip: ShortcutHelpEntry.tooltip('Zoom In', AppShortcut.zoomIn),
          onPressed: zoom < AppZoom.levels.last ? controller.zoomIn : null,
        ),
      ],
    );
  }

  /// The box listing the [entries] of [menu], each command beside its keys.
  Widget _buildShortcutGroup(String menu, List<ShortcutHelpEntry> entries) {
    final keysStyle = AppTextStyle.bodyStrong.copyWith(
      color: Theme.of(context).colorScheme.primary,
    );
    return OutlinedSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.small,
        children: [
          Text(menu, style: AppTextStyle.bodyStrong),
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
