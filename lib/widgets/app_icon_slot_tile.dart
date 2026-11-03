import 'dart:math';

import 'package:fide/constants/constants.dart';
import 'package:fide/models/app_icon_review.dart';
import 'package:fide/models/image_backdrop.dart';
import 'package:fide/models/status_tone.dart';
import 'package:fide/theme/app_theme.dart';
import 'package:fide/widgets/app_icon_image.dart';
import 'package:fide/widgets/clickable.dart';
import 'package:fide/widgets/ico_frame_image.dart';
import 'package:fide/widgets/image_backdrop_box.dart';
import 'package:fide/widgets/outlined_surface.dart';
import 'package:fide/widgets/status_indicator.dart';
import 'package:fide/widgets/surface_padding.dart';
import 'package:flutter/material.dart';

/// One app icon slot as Xcode's icon set editor shows it: the image at its
/// own size (up to the tile's), its label and pixel size, and a warning
/// mark when it is empty, wrong or still Flutter's default.
class AppIconSlotTile extends StatelessWidget {
  /// Creates the tile of [slot].
  const AppIconSlotTile({
    super.key,
    required this.slot,
    this.isSelected = false,
    this.onTap,
    this.onDoubleTap,
  });

  /// Whether the slot's file is the one picked, filling the tile.
  final bool isSelected;

  /// Opens the slot's file, such as in the editor's image preview.
  final VoidCallback? onDoubleTap;

  /// Picks the slot's file; null leaves the tile unclickable.
  final VoidCallback? onTap;

  /// The slot shown.
  final AppIconSlotInfo slot;

  @override
  Widget build(BuildContext context) {
    final size = slot.size;
    final drawn = size == null
        ? AppSize.appIconSlot
        : max(
            AppSize.appIconSlotMinDrawn,
            min(AppSize.appIconSlot, size.toDouble()),
          );
    final notes = [
      if (!slot.isFilled) 'Empty',
      if (slot.isFlutterDefault) "Flutter's default icon",
      ...slot.problems,
    ];
    final empty = Icon(
      Icons.add_photo_alternate_outlined,
      size: AppIconSize.xLarge,
      color: Theme.of(context).colorScheme.outline,
    );

    return Tooltip(
      message: [slot.filePath ?? 'No file assigned', ...notes].join('\n'),
      child: Clickable(
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        child: Container(
          width: AppSize.appIconSlot + SurfacePadding.dense.insets.horizontal,
          // The fill of the picked row in trees
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.selectedFill(context) : null,
            borderRadius: BorderRadius.circular(AppRadius.medium),
          ),
          child: Column(
            spacing: AppSpacing.tiny,
            children: [
              OutlinedSurface(
                padding: SurfacePadding.dense,
                child: SizedBox.square(
                  dimension: AppSize.appIconSlot,
                  child: Center(
                    child: slot.isFilled
                        ? ImageBackdropBox(
                            backdrop: ImageBackdrop.transparent,
                            child: _buildImage(drawn, empty),
                          )
                        : empty,
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: AppSpacing.micro,
                children: [
                  if (notes.isNotEmpty)
                    StatusIndicator.tone(StatusTone.warning),
                  Flexible(
                    child: Text(
                      slot.label,
                      style: AppTextStyle.captionStrong,
                      textAlign: TextAlign.center,
                      maxLines: AppMetric.doubleLineLimit,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              Text(
                size == null
                    ? slot.isReadable
                          ? '${slot.fileWidth}×${slot.fileHeight} px'
                          : 'any size'
                    : '$size×$size px',
                style: AppTextStyle.secondary(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The image of the slot, [drawn] pixels wide; [empty] when there is
  /// none or it can't be drawn.
  Widget _buildImage(double drawn, Widget empty) {
    final path = slot.path;
    final size = slot.size;
    return SizedBox.square(
      dimension: drawn,
      child: Center(
        child: path == null
            ? empty
            : slot.isIco && size != null
            ? IcoFrameImage(
                path: path,
                size: size,
                drawnSize: drawn,
                fallback: empty,
              )
            : AppIconImage(path: path, size: drawn, fallback: empty),
      ),
    );
  }
}
