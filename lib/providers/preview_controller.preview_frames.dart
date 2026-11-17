part of 'preview_controller.dart';

/// The latest frame of each preview [PreviewController] lists, by its
/// index in [PreviewState.items]; null until the preview's first frame.
///
/// Kept apart from [PreviewState] because frames stream in many times a
/// second while previews animate: each `PreviewCard` watches its own frame
/// alone, so a frame repaints its card, not the Preview panel.
final previewFramesProvider =
    NotifierProvider<PreviewFrames, List<PreviewFrame?>>(PreviewFrames.new);

/// Holds the frames [previewFramesProvider] provides; [PreviewController]
/// sets them.
class PreviewFrames extends Notifier<List<PreviewFrame?>> {
  @override
  List<PreviewFrame?> build() {
    // A new project starts without frames
    ref.watch(currentProjectPathProvider);
    return const [];
  }

  /// Shows [frame] on the preview at its index, among [count] previews.
  void show(PreviewFrame frame, int count) {
    state = [
      for (var index = 0; index < count; index++)
        index == frame.index ? frame : state.elementAtOrNull(index),
    ];
  }

  /// Keeps only the frames [keep] picks by index, for a new list of
  /// [count] previews, so cards don't blink until their new frames come.
  void reset(int count, bool Function(int index) keep) {
    state = [
      for (var index = 0; index < count; index++)
        keep(index) ? state.elementAtOrNull(index) : null,
    ];
  }
}
