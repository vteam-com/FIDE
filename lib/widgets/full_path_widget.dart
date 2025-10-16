import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

/// Widget for displaying a full path with the filename in bold and full opacity,
/// and the prefix path in normal weight with 0.75 opacity.
class FullPathWidget extends StatelessWidget {
  const FullPathWidget({super.key, required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textColor = colorScheme.onSurface;
    final bodyLarge = Theme.of(context).textTheme.bodyLarge!;

    final filename = p.basename(path);
    final directory = p.dirname(path);
    final prefix = directory.isNotEmpty ? '$directory${p.separator}' : '';

    return RichText(
      text: TextSpan(
        children: [
          if (prefix.isNotEmpty)
            TextSpan(
              text: prefix,
              style: bodyLarge.copyWith(
                color: textColor.withAlpha(200),
                fontWeight: FontWeight.normal,
              ),
            ),
          TextSpan(
            text: filename,
            style: bodyLarge.copyWith(
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      overflow: TextOverflow.ellipsis,
    );
  }
}
