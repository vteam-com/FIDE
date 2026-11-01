import 'dart:math';

import 'package:fcheck/fcheck.dart';
import 'package:fide/constants/constants.dart';
import 'package:fide/models/status_tone.dart';
import 'package:fide/widgets/app_icon_image.dart';
import 'package:fide/widgets/clickable.dart';
import 'package:fide/widgets/ico_frame_image.dart';
import 'package:fide/widgets/outlined_surface.dart';
import 'package:fide/widgets/status_indicator.dart';
import 'package:fide/widgets/surface_padding.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

/// One app icon slot as Xcode's icon set editor shows it: the image at its
/// own size (up to the tile's), its label and pixel size, and a warning
/// mark when it is empty, wrong or still Flutter's default.
class AppIconSlotTile extends StatelessWidget {
  /// Creates the tile of [slot], whose file path is relative to
  /// [projectPath].
  const AppIconSlotTile({
    super.key,
    required this.slot,
    required this.projectPath,
    this.problems = const [],
    this.isSelected = false,
    this.onTap,
  });

  /// Whether the slot's file is the one picked, filling the tile.
  final bool isSelected;

  /// Picks the slot's file; null leaves the tile unclickable.
  final VoidCallback? onTap;

  /// What is wrong with the slot's file, one message each.
  final List<String> problems;

  /// The project the slot's file path is relative to.
  final String projectPath;

  /// The slot shown.
  final AppIconSlot slot;

  @override
  Widget build(BuildContext context) {
    final relativePath = slot.filePath;
    final path = relativePath == null
        ? null
        : p.join(projectPath, relativePath);
    final size = slot.size;
    final file = slot.file;
    final drawn = size == null
        ? AppSize.appIconSlot
        : max(
            AppSize.appIconSlotMinDrawn,
            min(AppSize.appIconSlot, size.toDouble()),
          );
    final notes = [
      if (!slot.isFilled) 'Empty',
      if (slot.isFlutterDefault) "Flutter's default icon",
      ...problems,
    ];
    final empty = Icon(
      Icons.add_photo_alternate_outlined,
      size: AppIconSize.xLarge,
      color: Theme.of(context).colorScheme.outline,
    );

    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: [relativePath ?? 'No file assigned', ...notes].join('\n'),
      child: Clickable(
        onTap: onTap,
        child: Container(
          width: AppSize.appIconSlot + SurfacePadding.dense.insets.horizontal,
          // The fill of the picked row in trees
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primaryContainer.withValues(
                    alpha: AppOpacity.divider,
                  )
                : null,
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
                    child: CustomPaint(
                      painter: slot.isFilled ? _TransparencyPainter() : null,
                      child: SizedBox.square(
                        dimension: slot.isFilled ? drawn : AppSize.appIconSlot,
                        child: Center(
                          child: path == null || !slot.isFilled
                              ? empty
                              : file != null &&
                                    file.icoSizes.isNotEmpty &&
                                    size != null
                              ? IcoFrameImage(
                                  path: path,
                                  size: size,
                                  drawnSize: drawn,
                                  fallback: empty,
                                )
                              : AppIconImage(
                                  path: path,
                                  size: drawn,
                                  fallback: empty,
                                ),
                        ),
                      ),
                    ),
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
                    ? file == null
                          ? 'any size'
                          : '${file.width}×${file.height} px'
                    : '$size×$size px',
                style: AppTextStyle.secondary(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A checkerboard behind an icon, so its transparent parts show as such,
/// light or dark artwork alike; nothing behind an empty slot.
class _TransparencyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = AppColor.transparencyLight,
    );
    final dark = Paint()..color = AppColor.transparencyDark;
    const square = AppSize.transparencySquare;
    for (var y = 0.0; y < size.height; y += square) {
      for (var x = 0.0; x < size.width; x += square) {
        if (((x + y) / square).round().isOdd) {
          canvas.drawRect(
            Rect.fromLTWH(
              x,
              y,
              min(square, size.width - x),
              min(square, size.height - y),
            ),
            dark,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_TransparencyPainter oldDelegate) => false;
}
