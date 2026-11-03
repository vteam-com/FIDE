import 'package:fide/constants/constants.dart';
import 'package:fide/models/byte_size.dart';
import 'package:fide/models/image_details.dart';
import 'package:fide/models/locale_number.dart';
import 'package:fide/models/relative_time.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/image_providers.dart';
import 'package:fide/widgets/detail_row.dart';
import 'package:fide/widgets/empty_state.dart';
import 'package:fide/widgets/loading_indicator.dart';
import 'package:fide/widgets/section_title.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shown in the Outline tab for an image file: everything FIDE reads from
/// it, from its size on disk to its dimensions, color mode, transparency,
/// dominant colors and format-specific facts.
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

  /// Base of hexadecimal digits.
  static const int _hexRadix = 16;

  /// Percent in a share of 1.
  static const int _percent = 100;

  /// Pixels in a megapixel.
  static const int _pixelsPerMegapixel = 1000000;

  /// Hexadecimal digits of a color without its alpha.
  static const int _rgbHexDigits = 6;

  /// Mask of an ARGB color's red, green and blue.
  static const int _rgbMask = 0xFFFFFF;

  /// Starts reading the details of [ImageDetailsPanel.path].
  Future<ImageDetails> _inspect() =>
      ref.read(imageInspectorProvider).inspect(widget.path);

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
    ref.listen(savedFilesRevisionProvider, (_, _) {
      setState(() {
        _details = _inspect();
      });
    });
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
        return ListView(
          padding: AppPadding.panelContent,
          children: [
            ..._section('File', [
              DetailRow('Format', details.format),
              DetailRow('Size', details.fileBytes.readableSize),
              DetailRow('Modified', details.modified.timeAgo()),
              DetailRow('Date', details.modified.toString().split('.').first),
            ]),
            ..._section('Image', [
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
            ..._section('Color', [
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
            ..._section(isRaster ? 'Dominant colors' : 'Colors used', [
              for (final color in details.dominantColors)
                DetailRow(
                  _hex(color.argb),
                  '${(color.share * _percent).round()}%'
                  '${isRaster ? '' : ' of uses'}',
                  leading: _swatch(color.argb),
                ),
            ]),
            ..._section('${details.format} details', [
              for (final MapEntry(:key, :value)
                  in details.formatDetails.entries)
                DetailRow(key, value),
            ]),
          ],
        );
      },
    );
  }

  /// [argb] as `#RRGGBB`.
  static String _hex(int argb) =>
      '#${(argb & _rgbMask).toRadixString(_hexRadix).padLeft(_rgbHexDigits, '0').toUpperCase()}';

  /// A titled group of [rows]; nothing when there are none.
  List<Widget> _section(String title, List<Widget> rows) => rows.isEmpty
      ? const []
      : [
          Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.large,
              bottom: AppSpacing.small,
            ),
            child: SectionTitle(title),
          ),
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.micro),
              child: row,
            ),
          ),
        ];

  /// A small square of [argb], outlined so white shows on light themes.
  Widget _swatch(int argb) {
    return Container(
      width: AppIconSize.medium,
      height: AppIconSize.medium,
      decoration: BoxDecoration(
        color: Color(argb),
        borderRadius: BorderRadius.circular(AppRadius.small),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline,
          width: AppSize.borderThin,
        ),
      ),
    );
  }
}
