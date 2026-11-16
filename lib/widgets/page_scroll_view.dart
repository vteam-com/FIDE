import 'package:fide/constants/constants.dart';
import 'package:fide/widgets/centered_scroll_view.dart';
import 'package:material_ui/material_ui.dart';

/// A full page's scrolling content, such as the project overview, the app
/// icons or the settings: [children] stacked full width, usually a
/// `PageHeader` first, inset by the screen padding.
///
/// The page counterpart of `PanelScrollView`.
class PageScrollView extends StatelessWidget {
  /// Creates the scrolling page of [children], centered and at most
  /// [maxWidth] wide.
  const PageScrollView({
    super.key,
    required this.children,
    this.maxWidth = double.infinity,
  });

  /// The page's header and sections, top to bottom.
  final List<Widget> children;

  /// Widest the page's content gets; the full width by default.
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return CenteredScrollView(
      maxWidth: maxWidth,
      padding: AppPadding.screen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.xxLarge,
        children: children,
      ),
    );
  }
}
