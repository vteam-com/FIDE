import 'package:material_ui/material_ui.dart';

/// [child] centered and at most [maxWidth] wide, such as a page's header
/// and forms in a wide window.
class CenteredContent extends StatelessWidget {
  /// Creates the centered [child].
  const CenteredContent({
    super.key,
    required this.child,
    this.maxWidth = double.infinity,
  });

  /// The content.
  final Widget child;

  /// Widest [child] gets; the full width by default.
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
