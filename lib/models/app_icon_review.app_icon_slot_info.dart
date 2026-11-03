part of 'app_icon_review.dart';

/// One app icon slot as its tile shows it: what it is for, the file
/// filling it, and what is wrong with that file.
class AppIconSlotInfo {
  /// Height of the file in pixels; null when it is missing or unreadable.
  final int? fileHeight;

  /// Project-relative path of the file filling the slot, with `/`
  /// separators; null when the slot lists no file.
  final String? filePath;

  /// Width of the file in pixels; null when it is missing or unreadable.
  final int? fileWidth;

  /// What the slot is for, grouping slots as Xcode does: `iPhone`,
  /// `iPad`, `App Store`, `Mac`, `Launcher`, `Browser`…
  final String group;

  /// Whether an image fills the slot.
  final bool isFilled;

  /// Whether the file still shows Flutter's default icon.
  final bool isFlutterDefault;

  /// Whether the file is an ICO holding several sizes.
  final bool isIco;

  /// The slot within its [group], such as `20pt @2x` or `xxhdpi`.
  final String label;

  /// Absolute path of the file filling the slot; null when the slot
  /// lists no file.
  final String? path;

  /// What is wrong with the file, one message each.
  final List<String> problems;

  /// Width and height the slot expects, in pixels; null when any square
  /// size will do.
  final int? size;

  /// Creates a slot.
  const AppIconSlotInfo({
    required this.group,
    required this.label,
    this.filePath,
    this.path,
    this.size,
    this.fileWidth,
    this.fileHeight,
    this.isIco = false,
    this.isFilled = false,
    this.isFlutterDefault = false,
    this.problems = const [],
  });

  /// Reads fCheck's [slot] of the project at [projectPath], keeping the
  /// messages of the [issues] about its file.
  factory AppIconSlotInfo.fromSlot(
    fcheck.AppIconSlot slot, {
    required String projectPath,
    required List<AppIconProblem> issues,
  }) {
    final filePath = slot.filePath;
    final file = slot.file;
    return AppIconSlotInfo(
      group: slot.group,
      label: slot.label,
      filePath: filePath,
      path: filePath == null ? null : p.join(projectPath, filePath),
      size: slot.size,
      fileWidth: file?.width,
      fileHeight: file?.height,
      isIco: file?.icoSizes.isNotEmpty ?? false,
      isFilled: slot.isFilled,
      isFlutterDefault: slot.isFlutterDefault,
      problems: [
        for (final issue in issues)
          if (filePath != null && issue.filePath == filePath) issue.message,
      ],
    );
  }

  /// Whether the file could be read, so it can be shown and opened.
  bool get isReadable => fileWidth != null;

  /// The absolute path of the file when it can be shown; null otherwise.
  String? get readablePath => isReadable ? path : null;
}
