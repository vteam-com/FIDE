import 'package:material_ui/material_ui.dart';

/// A scroll view holding [child] centered and at most [maxWidth] wide,
/// such as the welcome screen's choices, a wizard's form or a settings
/// page in a wide window.
class CenteredScrollView extends StatelessWidget {
  /// Creates the scroll view around [child], inset by [padding] inside the
  /// scroll view so content scrolls to its edges.
  const CenteredScrollView({
    super.key,
    required this.child,
    this.maxWidth = double.infinity,
    this.padding = EdgeInsets.zero,
  });

  /// The content.
  final Widget child;

  /// Widest [child] gets; the full width by default.
  final double maxWidth;

  /// Space around [child], inside the scroll view.
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: padding,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      ),
    );
  }
}
