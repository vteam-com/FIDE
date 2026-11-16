import 'package:material_ui/material_ui.dart';

/// Shows the [CompactTextButton]s below it by their icon alone, their
/// label as a tooltip, such as a section's actions in a narrow panel.
class IconOnlyLabels extends InheritedWidget {
  /// Shows the buttons in [child] as icons.
  const IconOnlyLabels({super.key, required super.child});

  /// Whether the buttons at [context] show as icons only.
  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<IconOnlyLabels>() != null;

  @override
  bool updateShouldNotify(IconOnlyLabels oldWidget) => false;
}
