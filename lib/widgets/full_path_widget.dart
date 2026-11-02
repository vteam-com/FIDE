import 'package:fide/constants/constants.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

/// Widget for displaying a full path with the filename in bold and full opacity,
/// and the prefix path in normal weight with 0.75 opacity; the path wraps
/// and can be selected.
class FullPathWidget extends StatelessWidget {
  /// Creates the display of [path] in [style].
  const FullPathWidget({
    super.key,
    required this.path,
    this.style = AppTextStyle.label,
  });

  /// The path shown.
  final String path;

  /// Size of the text; the filename is drawn bold on top of it.
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textColor = colorScheme.onSurface;

    final filename = p.basename(path);
    final directory = p.dirname(path);
    final prefix = directory.isNotEmpty ? '$directory${p.separator}' : '';

    return SelectableText.rich(
      TextSpan(
        children: [
          if (prefix.isNotEmpty)
            TextSpan(
              text: prefix,
              style: style.copyWith(
                color: textColor.withAlpha(AppAlpha.pathPrefix),
              ),
            ),
          TextSpan(
            text: filename,
            style: style.merge(AppTextStyle.strong).copyWith(color: textColor),
          ),
        ],
      ),
    );
  }
}
