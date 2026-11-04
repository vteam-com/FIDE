import 'package:fide/widgets/choice_buttons.dart';
import 'package:flutter/material.dart';

/// The System / Light / Dark choice, for FIDE's theme in the settings and
/// for the widget previews' brightness.
class ThemeModeButtons extends StatelessWidget {
  /// Creates the choice showing [selected], calling [onSelected] with the
  /// mode picked.
  const ThemeModeButtons({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  /// Called with the mode picked.
  final ValueChanged<ThemeMode> onSelected;

  /// The mode picked.
  final ThemeMode selected;
  @override
  Widget build(BuildContext context) {
    return ChoiceButtons(
      values: const [ThemeMode.system, ThemeMode.light, ThemeMode.dark],
      selected: selected,
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
      onSelected: onSelected,
    );
  }
}
