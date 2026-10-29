import 'package:fide/constants/constants.dart';
import 'package:flutter/material.dart';

/// A small thin-stroked progress spinner for buttons, list rows and
/// headers.
class InlineSpinner extends StatelessWidget {
  /// Creates a spinner [size] wide.
  const InlineSpinner({super.key, this.size = AppIconSize.large, this.color});

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
