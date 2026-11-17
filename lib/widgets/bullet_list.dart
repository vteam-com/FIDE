import 'package:fide/constants/constants.dart';
import 'package:material_ui/material_ui.dart';

/// A list of short [items], one bulleted line each, in the secondary text
/// style: steps, ranges or what an action will do.
class BulletList extends StatelessWidget {
  /// Creates the list of [items].
  const BulletList(this.items, {super.key});

  /// The mark before each item.
  static const String _bullet = '• ';

  /// The lines listed.
  final List<String> items;
  @override
  Widget build(BuildContext context) {
    final style = AppTextStyle.secondary(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [for (final item in items) Text('$_bullet$item', style: style)],
    );
  }

  /// [items] as plain text, one bulleted line each, for a message that
  /// only takes a string.
  static String text(Iterable<String> items) =>
      items.map((item) => '$_bullet$item').join('\n');
}
