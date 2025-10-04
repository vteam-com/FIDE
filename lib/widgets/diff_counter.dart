import 'package:flutter/material.dart';
import '../services/git_service.dart';
import 'badge_status.dart';

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
      parts.add(BadgeStatus.addition(count: gitStats!.added));
    }

    if (gitStats!.removed > 0) {
      parts.add(BadgeStatus.deletion(count: gitStats!.removed));
    }

    return Row(mainAxisSize: MainAxisSize.min, children: parts);
  }
}
