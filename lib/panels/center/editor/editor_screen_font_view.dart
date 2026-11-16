import 'dart:async';

import 'package:fide/constants/constants.dart';
import 'package:fide/models/font_sample_colors.dart';
import 'package:fide/models/readable_error.dart';
import 'package:fide/services/font_file_loader.dart';
import 'package:fide/widgets/choice_buttons.dart';
import 'package:fide/widgets/compact_toggle_button.dart';
import 'package:fide/widgets/empty_state.dart';
import 'package:fide/widgets/file_facts_label.dart';
import 'package:fide/widgets/image_backdrop_box.dart';
import 'package:fide/widgets/image_backdrop_icon.dart';
import 'package:fide/widgets/loading_indicator.dart';
import 'package:fide/widgets/viewer_toolbar.dart';
import 'package:material_ui/material_ui.dart';

/// Previews a TrueType or OpenType font file: its alphabet, digits and
/// punctuation, then a sentence at sizes from small to large, under a
/// strip toggling bold, italic, underline and strikethrough and picking
/// black on white or white on black.
class EditorScreenFontView extends StatefulWidget {
  /// Creates the preview of the font file at [filePath].
  const EditorScreenFontView({super.key, required this.filePath});

  /// The font file shown.
  final String filePath;

  @override
  State<EditorScreenFontView> createState() => _EditorScreenFontViewState();
}

class _EditorScreenFontViewState extends State<EditorScreenFontView> {
  /// Whether the samples show the font's bold face.
  bool _bold = false;

  /// The characters shown first, one line each.
  static const List<String> _characterLines = [
    'ABCDEFGHIJKLMNOPQRSTUVWXYZ',
    'abcdefghijklmnopqrstuvwxyz',
    '0123456789',
    r'''!?.,:;'"()[]{}<>@#$%&*+-=/\_|~^''',
  ];

  /// The ink and paper of the samples.
  FontSampleColors _colors = FontSampleColors.blackOnWhite;

  /// The family the font file is registered as, once loaded.
  late Future<String> _family;

  /// Whether the samples show the font's italic face.
  bool _italic = false;

  /// The sentence shown at each of [EditorConfig.fontSampleSizes].
  static const String _sentence = 'The quick brown fox jumps over the lazy dog';

  /// Whether the samples are struck through.
  bool _strikethrough = false;

  /// Whether the samples are underlined.
  bool _underline = false;
  @override
  void initState() {
    super.initState();
    _family = FontFileLoader.load(widget.filePath);
  }

  @override
  void didUpdateWidget(EditorScreenFontView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) {
      _family = FontFileLoader.load(widget.filePath);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ViewerToolbar(
          leading: [
            CompactToggleButton(
              icon: Icons.format_bold,
              tooltip: 'Bold',
              isOn: _bold,
              onChanged: (on) => setState(() => _bold = on),
            ),
            CompactToggleButton(
              icon: Icons.format_italic,
              tooltip: 'Italic',
              isOn: _italic,
              onChanged: (on) => setState(() => _italic = on),
            ),
            CompactToggleButton(
              icon: Icons.format_underlined,
              tooltip: 'Underline',
              isOn: _underline,
              onChanged: (on) => setState(() => _underline = on),
            ),
            CompactToggleButton(
              icon: Icons.format_strikethrough,
              tooltip: 'Strikethrough',
              isOn: _strikethrough,
              onChanged: (on) => setState(() => _strikethrough = on),
            ),
            ChoiceButtons(
              values: FontSampleColors.values,
              selected: _colors,
              icon: (colors) => colors.paper.icon,
              label: (colors) => colors.label,
              onSelected: (colors) => setState(() => _colors = colors),
            ),
          ],
          trailing: [FileFactsLabel(filePath: widget.filePath)],
        ),
        Expanded(
          child: FutureBuilder<String>(
            future: _family,
            builder: (_, snapshot) {
              final error = snapshot.error;
              if (error != null) {
                return EmptyState.error(
                  title: "Can't open this font",
                  message: ReadableError.describe(error),
                );
              }
              final family = snapshot.data;
              if (family == null) return const LoadingIndicator();
              return _buildSamples(family);
            },
          ),
        ),
      ],
    );
  }

  /// The font's characters, then [_sentence] at every sample size, drawn
  /// in [family] on [_colors]' paper.
  Widget _buildSamples(String family) {
    final ink = _colors.foreground;
    final sizeStyle = AppTextStyle.caption.copyWith(
      color: ink.withValues(alpha: AppOpacity.muted),
    );
    TextStyle sample(double fontSize) => AppTextStyle.fontSample(
      family: family,
      fontSize: fontSize,
      color: ink,
      bold: _bold,
      italic: _italic,
      underline: _underline,
      strikethrough: _strikethrough,
    );
    return ImageBackdropBox(
      backdrop: _colors.paper,
      child: SizedBox.expand(
        child: SingleChildScrollView(
          padding: AppPadding.pageContent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppSpacing.large,
            children: [
              for (final line in _characterLines)
                Text(line, style: sample(AppFontSize.headline)),
              Divider(color: ink.withValues(alpha: AppOpacity.divider)),
              for (final fontSize in EditorConfig.fontSampleSizes)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${fontSize.round()} pt', style: sizeStyle),
                    Text(_sentence, style: sample(fontSize)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
