import 'package:fide/constants/constants.dart';
import 'package:flutter/material.dart';

/// The line saying a section, folder or list has nothing in it, such as
/// "empty folder"; a whole panel with nothing to show uses `EmptyState`.
class EmptyLabel extends StatelessWidget {
  /// Creates the line reading [text].
  const EmptyLabel(this.text, {super.key});

  /// What is missing.
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: AppTextStyle.secondary(context));
  }
}
