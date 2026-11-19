import 'package:fide/constants/constants.dart';
import 'package:material_ui/material_ui.dart';

/// The thin vertical line between two side-by-side panes, such as the
/// original and modified sides of a diff or a graph and its details.
class PaneDivider extends StatelessWidget {
  /// Creates the line.
  const PaneDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const VerticalDivider(width: AppBorderWidth.thin);
  }
}
