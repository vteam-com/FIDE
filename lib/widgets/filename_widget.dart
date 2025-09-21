import 'package:fide/models/file_extension_icon.dart';
import 'package:flutter/material.dart';

/// Reusable widget for displaying a filename with a leading icon
class FileNameWithIcon extends StatelessWidget {
  final String name;
  final bool isDirectory;
  final String? extension;
  final TextStyle? textStyle;
  final double iconSize;

  const FileNameWithIcon({
    super.key,
    required this.name,
    required this.isDirectory,
    this.extension,
    this.textStyle,
    this.iconSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        _getIcon(colorScheme),
        const SizedBox(width: 6),
        Expanded(
          child: Text(name, style: textStyle, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  Widget _getIcon(ColorScheme colorScheme) {
    if (isDirectory) {
      return Icon(Icons.folder, color: colorScheme.primary, size: iconSize);
    }
    return getIconForFileExtension(colorScheme, extension ?? '');
  }
}
