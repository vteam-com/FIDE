part of 'architecture_focus.dart';

/// How the architecture view shows one file against the [ArchitectureFocus].
enum ArchitectureRole {
  /// The file in focus.
  focused,

  /// A file the focused one imports.
  callee,

  /// A file importing the focused one.
  caller,

  /// A file shown as usual: nothing is in focus and it matches the filter.
  plain,

  /// A file set aside: unrelated to the focused one, or not matching the
  /// filter.
  dimmed,
}
