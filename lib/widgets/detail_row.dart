import 'package:fide/constants/constants.dart';
import 'package:fide/widgets/truncated_text.dart';
import 'package:material_ui/material_ui.dart';

/// One fact as a line: a fixed-width [label] column, then [value] in
/// monospace, truncated to one line, with an optional [leading] mark such
/// as a color swatch.
class DetailRow extends StatelessWidget {
  /// Creates the line showing [value] under [label].
  const DetailRow(this.label, this.value, {super.key, this.leading});

  /// What the value is.
  final String label;

  /// Shown before [label].
  final Widget? leading;

  /// The fact.
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      spacing: AppSpacing.small,
      children: [
        ?leading,
        SizedBox(
          width: AppSize.detailLabelWidth,
          child: Text(label, style: AppTextStyle.secondary(context)),
        ),
        Expanded(
          child: TruncatedText(
            value,
            style: AppTextStyle.code.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
