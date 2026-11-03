import 'package:fide/constants/constants.dart';
import 'package:flutter/material.dart';

/// The filled band heading an outlined box (a section, a diff), its
/// [child] inset by the section header padding.
class SurfaceHeaderBand extends StatelessWidget {
  /// Creates the band around [child].
  const SurfaceHeaderBand({super.key, required this.child});

  /// The band's content, such as a title row.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(padding: AppPadding.sectionHeader, child: child),
    );
  }
}
