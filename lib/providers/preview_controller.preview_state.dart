part of 'preview_controller.dart';

/// What the Preview panel shows about the file selected.
enum PreviewStatus {
  /// No Dart file is selected.
  noFile,

  /// The file is a `part of` another library.
  part,

  /// The file has no preview.
  noPreviews,

  /// The preview host is starting, compiling the project.
  starting,

  /// The previews are reloading after a change.
  reloading,

  /// The previews are live.
  ready,

  /// The previews failed to compile or the host stopped; see
  /// [PreviewState.message].
  failed,
}

/// The brightness the Preview panel renders the previews in.
enum PreviewBrightness {
  /// Each preview's own brightness, else FIDE's.
  auto('Brightness: Each Preview', Icons.brightness_auto),

  /// Light, for every preview.
  light('Brightness: Light', Icons.light_mode_outlined),

  /// Dark, for every preview.
  dark('Brightness: Dark', Icons.dark_mode_outlined);

  const PreviewBrightness(this.tooltip, this.icon);

  /// The toggle's tooltip.
  final String tooltip;

  /// The toggle's icon.
  final IconData icon;

  /// The brightness after this one, as the toggle cycles them.
  PreviewBrightness get next => values[(index + 1) % values.length];

  /// The brightness forced on the previews; null for [auto].
  Brightness? get forced => switch (this) {
    auto => null,
    light => Brightness.light,
    dark => Brightness.dark,
  };
}

/// A preview of the project's list: its file and its declaration's label.
typedef PreviewKey = ({String path, String label});

/// The Preview panel's file, its previews and their latest frames.
@immutable
class PreviewState {
  /// The file shown, absolute; null when none is selected.
  final String? filePath;

  /// What the panel shows.
  final PreviewStatus status;

  /// The file's previews and widgets.
  final PreviewScan scan;

  /// The previews the host renders, with their latest frames.
  final List<PreviewItem> items;

  /// The host's list [items] come from; frames of another are dropped.
  final int generation;

  /// Why the previews failed, with the compile errors; empty otherwise.
  final String message;

  /// The latest errors the previews reported while running.
  final List<String> logs;

  /// The brightness the previews render in.
  final PreviewBrightness brightness;

  /// Whether previews are being generated for the file's widgets.
  final bool isGenerating;

  /// Which previews the panel lists.
  final PreviewScope scope;

  /// The project's files with previews, for [PreviewScope.project].
  final List<PreviewFileScan> projectFiles;

  /// The one project preview expanded and rendered; null when all are
  /// collapsed.
  final PreviewKey? expanded;

  /// Whether the project is being scanned for its previews.
  final bool isScanning;

  /// Creates the state.
  const PreviewState({
    this.filePath,
    this.status = PreviewStatus.noFile,
    this.scan = PreviewScan.empty,
    this.items = const [],
    this.generation = 0,
    this.message = '',
    this.logs = const [],
    this.brightness = PreviewBrightness.auto,
    this.isGenerating = false,
    this.scope = PreviewScope.file,
    this.projectFiles = const [],
    this.expanded,
    this.isScanning = false,
  });

  /// Whether the host is busy starting or reloading.
  bool get isBusy =>
      isScanning ||
      status == PreviewStatus.starting ||
      status == PreviewStatus.reloading;

  /// A copy with the given fields replaced.
  PreviewState copyWith({
    String? filePath,
    PreviewStatus? status,
    PreviewScan? scan,
    List<PreviewItem>? items,
    int? generation,
    String? message,
    List<String>? logs,
    PreviewBrightness? brightness,
    bool? isGenerating,
    PreviewScope? scope,
    List<PreviewFileScan>? projectFiles,
    ({PreviewKey? key})? expanded,
    bool? isScanning,
  }) {
    return PreviewState(
      filePath: filePath ?? this.filePath,
      status: status ?? this.status,
      scan: scan ?? this.scan,
      items: items ?? this.items,
      generation: generation ?? this.generation,
      message: message ?? this.message,
      logs: logs ?? this.logs,
      brightness: brightness ?? this.brightness,
      isGenerating: isGenerating ?? this.isGenerating,
      scope: scope ?? this.scope,
      projectFiles: projectFiles ?? this.projectFiles,
      expanded: expanded == null ? this.expanded : expanded.key,
      isScanning: isScanning ?? this.isScanning,
    );
  }
}
