import 'package:flutter/material.dart';

Icon getIconForFileExtension(
  final ColorScheme colorScheme,
  final String extention,
) {
  switch (extention) {
    case '.dart':
      return Icon(Icons.code, color: colorScheme.primary, size: 16);
    case '.yaml':
    case '.yml':
      return Icon(Icons.settings, color: colorScheme.secondary, size: 16);
    case '.md':
      return Icon(Icons.article, color: colorScheme.secondary, size: 16);
    case '.txt':
      return Icon(Icons.article, color: colorScheme.onSurfaceVariant, size: 16);
    case '.js':
      return Icon(Icons.javascript, color: colorScheme.tertiary, size: 16);
    case '.py':
      return Icon(Icons.code, color: colorScheme.primary, size: 16);
    case '.java':
    case '.kt':
      return Icon(Icons.code, color: colorScheme.tertiary, size: 16);
    case '.gradle':
      return Icon(Icons.build, color: colorScheme.onSurfaceVariant, size: 16);
    case '.xml':
    case '.html':
      return Icon(Icons.code, color: colorScheme.tertiary, size: 16);
    case '.css':
      return Icon(Icons.css, color: colorScheme.primary, size: 16);
    case '.arb':
    case '.json':
      return Icon(Icons.data_object, color: colorScheme.tertiary, size: 16);
    case '.png':
    case '.jpg':
    case '.jpeg':
    case '.gif':
    case '.svg':
      return Icon(Icons.image, color: colorScheme.tertiary, size: 16);
    case '.pdf':
      return Icon(Icons.picture_as_pdf, color: colorScheme.error, size: 16);
    case '.zip':
    case '.rar':
    case '.7z':
    case '.tar':
    case '.gz':
      return Icon(Icons.archive, color: colorScheme.secondary, size: 16);
    default:
      return Icon(
        Icons.insert_drive_file,
        color: colorScheme.onSurfaceVariant,
        size: 16,
      );
  }
}
