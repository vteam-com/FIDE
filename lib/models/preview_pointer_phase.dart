/// The part of a pointer gesture the Preview panel forwards to a preview;
/// each value's `name` is how the preview host spells it.
enum PreviewPointerPhase {
  /// The primary button went down.
  down,

  /// The pointer moved with the button down.
  move,

  /// The button went up.
  up,

  /// The wheel or trackpad scrolled.
  scroll,
}
