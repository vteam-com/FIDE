import 'package:fide/constants/constants.dart';
import 'package:material_ui/material_ui.dart';

/// A small thin-stroked progress spinner for buttons, list rows and
/// headers.
///
/// Two sizes cover them: the default for a header or toolbar, [small]
/// beside a line of text, in a button or in a tree row.
class InlineSpinner extends StatelessWidget {
  /// Creates a spinner [size] wide.
  const InlineSpinner({super.key, this.size = AppIconSize.large, this.color});

  /// Creates a spinner for a line of text, a button or a tree row.
  const InlineSpinner.small({super.key, this.color})
    : size = AppIconSize.medium;

  /// Spinner color; the theme's when null.
  final Color? color;

  /// Width and height of the spinner.
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: AppBorderWidth.medium,
        valueColor: color == null ? null : AlwaysStoppedAnimation(color!),
      ),
    );
  }
}
