import 'package:fide/constants/constants.dart';
import 'package:material_ui/material_ui.dart';

/// A fixed-width slider for a toolbar, such as an image diff's Swipe
/// divider or the audio editor's speed and pitch.
class CompactSlider extends StatelessWidget {
  /// Creates the slider setting [value], from [min] to [max].
  const CompactSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.divisions,
  });

  /// Steps between [min] and [max]; any value in between when null.
  final int? divisions;

  /// Largest value.
  final double max;

  /// Smallest value.
  final double min;

  /// Called with each new value while dragging; disabled when null.
  final ValueChanged<double>? onChanged;

  /// The value shown.
  final double value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AppSize.compactSliderWidth,
      child: Slider(
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        onChanged: onChanged,
      ),
    );
  }
}
