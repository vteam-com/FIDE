import 'package:fide/constants/constants.dart';
import 'package:fide/widgets/surface_padding.dart';
import 'package:flutter/material.dart';

/// A filled, rounded card on the highest surface tone, setting a summary,
/// note, details or list entry apart from what surrounds it.
///
/// The one filled box of the app; outlined boxes use `OutlinedSurface`.
class SurfaceCard extends StatelessWidget {
  /// Creates the card around [child].
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = SurfacePadding.normal,
  });

  /// The content.
  final Widget child;

  /// Space between the card's edge and [child].
  final SurfacePadding padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding.insets,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: child,
    );
  }
}
