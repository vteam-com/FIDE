import 'package:fide/constants/constants.dart';
import 'package:flutter/material.dart';

/// A filled, rounded card on the highest surface tone, setting a summary or
/// note apart from the form around it.
class SurfaceCard extends StatelessWidget {
  /// Creates the card around [child].
  const SurfaceCard({super.key, required this.child});

  /// The content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xLarge),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: child,
    );
  }
}
