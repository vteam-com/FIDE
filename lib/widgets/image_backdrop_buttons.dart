import 'package:fide/models/image_backdrop.dart';
import 'package:fide/providers/ui_state_providers.dart';
import 'package:fide/widgets/choice_buttons.dart';
import 'package:fide/widgets/image_backdrop_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The picker of the backdrop every image preview is drawn on.
class ImageBackdropButtons extends ConsumerWidget {
  /// Creates the picker.
  const ImageBackdropButtons({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ChoiceButtons(
      values: ImageBackdrop.values,
      selected: ref.watch(imageBackdropProvider),
      icon: (backdrop) => backdrop.icon,
      label: (backdrop) => backdrop.label,
      onSelected: (backdrop) =>
          ref.read(imageBackdropProvider.notifier).state = backdrop,
    );
  }
}
