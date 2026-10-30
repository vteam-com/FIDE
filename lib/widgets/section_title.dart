import 'package:fide/constants/constants.dart';
import 'package:flutter/material.dart';

/// The heading of a section of a panel, card or form step.
class SectionTitle extends StatelessWidget {
  /// Creates the heading [text].
  const SectionTitle(this.text, {super.key});

  /// The heading.
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: AppTextStyle.title);
  }
}
