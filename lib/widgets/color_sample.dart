import 'package:fide/constants/constants.dart';
import 'package:fide/widgets/optional_tooltip.dart';
import 'package:material_ui/material_ui.dart';

/// A small square of [color], outlined so white shows on light themes,
/// such as before a color's hex value in a list of colors.
class ColorSample extends StatelessWidget {
  /// Creates the square of the color [argb], as 0xAARRGGBB.
  const ColorSample(this.argb, {super.key, this.tooltip});

  /// The color shown, as 0xAARRGGBB.
  final int argb;

  /// Shown on hover, such as the theme the color is from; none when null.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return OptionalTooltip(
      message: tooltip,
      child: Container(
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
      ),
    );
  }
}
