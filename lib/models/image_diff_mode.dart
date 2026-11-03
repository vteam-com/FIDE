/// How an image diff shows the committed and modified images, as the
/// image diffs of GitHub and Kaleidoscope do. Values are in display order.
enum ImageDiffMode {
  /// Both images side by side, sharing one zoom and pan.
  twoUp('2-up'),

  /// The modified image over the committed one, revealed left of a
  /// movable divider.
  swipe('Swipe'),

  /// The modified image faded over the committed one, from fully
  /// transparent to fully opaque.
  onion('Onion'),

  /// The pixels that differ, highlighted over the faded modified image.
  difference('Difference');

  const ImageDiffMode(this.label);

  /// Name shown in the mode picker.
  final String label;
}
