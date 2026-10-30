import 'package:fide/widgets/empty_state.dart';
import 'package:flutter/material.dart';

/// Widget to display a message when a file is too large to load in the editor
class LargeFileMessage extends StatelessWidget {
  const LargeFileMessage({
    super.key,
    required this.fileName,
    required this.fileSizeMB,
  });

  final String fileName;
  final double fileSizeMB;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.warning,
      isError: true,
      title: 'File "$fileName" is too large to load in the editor',
      message:
          'File size: ${fileSizeMB.toStringAsFixed(1)} MB\n'
          'Consider using an external editor for large files',
    );
  }
}
