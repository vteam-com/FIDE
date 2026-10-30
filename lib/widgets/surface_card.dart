import 'package:fide/constants/constants.dart';
import 'package:flutter/material.dart';

/// A filled, rounded card on the highest surface tone, setting a summary,
/// note, details or list entry apart from what surrounds it.
///
/// The one filled box of the app; outlined boxes use `OutlinedSurface`.
class SurfaceCard extends StatelessWidget {
  /// Creates the card around [child].
  const SurfaceCard({super.key, required this.child, this.dense = false});

  /// The content.
  final Widget child;

  /// Whether to use the tighter padding of list entries and details.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(dense ? AppSpacing.medium : AppSpacing.xLarge),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: child,
    );
  }
}
