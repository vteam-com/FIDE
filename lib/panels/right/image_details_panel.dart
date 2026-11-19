import 'package:fide/constants/constants.dart';
import 'package:fide/models/byte_size.dart';
import 'package:fide/models/image_details.dart';
import 'package:fide/models/locale_number.dart';
import 'package:fide/models/relative_time.dart';
import 'package:fide/models/wcag_color.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/image_providers.dart';
import 'package:fide/widgets/color_sample.dart';
import 'package:fide/widgets/detail_row.dart';
import 'package:fide/widgets/detail_section.dart';
import 'package:fide/widgets/empty_state.dart';
import 'package:fide/widgets/loading_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Shown in the Info tab's file section for an image: everything FIDE
/// reads from it, from its size on disk to its dimensions, color mode,
/// transparency, dominant colors and format-specific facts.
class ImageDetailsPanel extends ConsumerStatefulWidget {
  /// Creates the details of the image at [path].
  const ImageDetailsPanel({super.key, required this.path});

  /// The image file.
  final String path;

  @override
  ConsumerState<ImageDetailsPanel> createState() => _ImageDetailsPanelState();
}

class _ImageDetailsPanelState extends ConsumerState<ImageDetailsPanel> {
  /// The details of [ImageDetailsPanel.path], read once per file.
  late Future<ImageDetails> _details;

  /// Percent in a share of 1.
  static const int _percent = 100;

  /// Pixels in a megapixel.
  static const int _pixelsPerMegapixel = 1000000;

  /// Starts reading the details of [ImageDetailsPanel.path].
  Future<ImageDetails> _inspect() =>
      ref.read(imageInspectorProvider).inspect(widget.path);

  /// Reads the details again when the image changed on disk since they
  /// were read, or they couldn't be.
  Future<void> _inspectIfChanged() async {
    final shown = _details;
    final path = widget.path;
    bool current;
    try {
      current = await ref
          .read(imageInspectorProvider)
          .isCurrent(path, await shown);
    } on Object {
      current = false;
    }
    if (!mounted || current || shown != _details) return;
    setState(() {
      _details = _inspect();
    });
  }

  @override
  void initState() {
    super.initState();
    _details = _inspect();
  }

  @override
  void didUpdateWidget(ImageDetailsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _details = _inspect();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Files rewritten outside the editor, e.g. by an icon fix
    ref.listen(savedFilesRevisionProvider, (_, _) => _inspectIfChanged());
    return FutureBuilder(
      future: _details,
      builder: (_, snapshot) {
        final details = snapshot.data;
        if (snapshot.hasError) {
          return EmptyState.error(
            message: 'Could not read the image: ${snapshot.error}',
          );
        }
        if (details == null) return const LoadingIndicator();
        // Vector images have no pixels: no color mode, and colors counted
        // by use rather than by area
        final isRaster = details.colorMode != null;
        final sections = [
          DetailSection('File', [
            DetailRow('Format', details.format),
            DetailRow('Size', details.fileBytes.readableSize),
            DetailRow('Modified', details.modified.timeAgo()),
            DetailRow('Date', details.modified.toSecond),
          ]),
          DetailSection('Image', [
            if (details.width case final width?)
              if (details.height case final height?) ...[
                DetailRow('Dimensions', '$width × $height px'),
                DetailRow('Aspect ratio', details.aspectRatio ?? '?'),
                DetailRow(
                  'Megapixels',
                  (width * height / _pixelsPerMegapixel).localized,
                ),
              ],
            if (details.frames > 1)
              DetailRow('Frames', details.frames.localized),
          ]),
          DetailSection('Color', [
            if (details.colorMode case final mode?) DetailRow('Mode', mode),
            if (details.bitsPerChannel case final bits?)
              DetailRow('Bit depth', '$bits bits per channel'),
            if (isRaster)
              DetailRow('Transparency', switch (details.transparentShare) {
                null => 'None (no alpha channel)',
                0 => 'Alpha channel, every pixel opaque',
                final share => '${(share * _percent).localized}% of pixels',
              }),
          ]),
          DetailSection(isRaster ? 'Dominant colors' : 'Colors used', [
            for (final color in details.dominantColors)
              DetailRow(
                WcagColor(color.argb).opaque.hex,
                '${(color.share * _percent).round()}%'
                '${isRaster ? '' : ' of uses'}',
                leading: ColorSample(color.argb),
              ),
          ]),
          DetailSection('${details.format} details', [
            for (final MapEntry(:key, :value) in details.formatDetails.entries)
              DetailRow(key, value),
          ]),
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.large,
          children: [
            for (final section in sections)
              if (section.rows.isNotEmpty) section,
          ],
        );
      },
    );
  }
}
