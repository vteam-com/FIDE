import 'package:flutter/material.dart';
import '../services/git_service.dart';

class DiffCounter extends StatelessWidget {
  final GitDiffStats? gitStats;

  const DiffCounter({super.key, required this.gitStats});

  @override
  Widget build(BuildContext context) {
    if (gitStats == null || !gitStats!.hasChanges) {
      return const SizedBox.shrink();
    }

    final parts = <Widget>[];

    if (gitStats!.added > 0) {
      parts.add(
        Text(
          '+${gitStats!.added}',
          style: TextStyle(
            color: Colors.green,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    if (gitStats!.removed > 0) {
      if (gitStats!.added > 0) {
        parts.add(const SizedBox(width: 4));
      }
      parts.add(
        Text(
          '-${gitStats!.removed}',
          style: TextStyle(
            color: Colors.red,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return Row(mainAxisSize: MainAxisSize.min, children: parts);
  }
}
