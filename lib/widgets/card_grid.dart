import 'package:fide/constants/constants.dart';
import 'package:material_ui/material_ui.dart';

/// Cards of one width, such as `StatCard`s or a page's groups, laid out in
/// rows that wrap to fill the width available.
class CardGrid extends StatelessWidget {
  /// Creates the grid of [children], each [AppSize.cardWidth] wide.
  const CardGrid({super.key, required this.children});

  /// The cards, in reading order.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xLarge,
      runSpacing: AppSpacing.xLarge,
      children: [
        for (final child in children)
          SizedBox(width: AppSize.cardWidth, child: child),
      ],
    );
  }
}
