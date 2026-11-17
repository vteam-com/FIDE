import 'package:fide/constants/constants.dart';
import 'package:material_ui/material_ui.dart';

/// The chevron of a collapsible entry: down while expanded, right while
/// collapsed.
class ExpansionChevron extends StatelessWidget {
  /// Creates the chevron of an entry [isExpanded], in the icon theme's
  /// color.
  const ExpansionChevron({super.key, required this.isExpanded});

  /// Whether the entry is expanded.
  final bool isExpanded;
  @override
  Widget build(BuildContext context) =>
      Icon(iconFor(isExpanded), size: AppIconSize.medium);

  /// The chevron's glyph for an entry [isExpanded], for buttons that take
  /// an icon.
  static IconData iconFor(bool isExpanded) =>
      isExpanded ? Icons.expand_more : Icons.chevron_right;
}
