import 'package:fide/constants/constants.dart';
import 'package:fide/models/git_file_status.dart';
import 'package:fide/models/status_tone.dart';
import 'package:fide/widgets/status_tone_style.dart';
import 'package:flutter/material.dart';

/// How a Git status looks in the trees: its color, folder icon and name
/// style.
///
/// Changes take the [StatusTone] colors the diff counters use, so a file's
/// name and its `+`/`-` counts agree; the other states take the theme's
/// [ColorScheme].
extension GitFileStatusStyle on GitFileStatus {
  /// Color for names and badges with this status; the theme's text color
  /// for clean files.
  Color color(ColorScheme colorScheme) {
    return switch (this) {
      GitFileStatus.added => StatusTone.success.color,
      GitFileStatus.modified => StatusTone.warning.color,
      GitFileStatus.deleted => StatusTone.error.color,
      GitFileStatus.untracked => colorScheme.onSurfaceVariant,
      GitFileStatus.ignored => colorScheme.outline,
      _ => colorScheme.onSurface,
    };
  }

  /// Small icon marking a folder with this status; null when unmarked.
  IconData? get icon => switch (this) {
    GitFileStatus.added => Icons.add_circle,
    GitFileStatus.modified => Icons.edit,
    GitFileStatus.deleted => Icons.remove_circle,
    GitFileStatus.untracked => Icons.new_releases,
    _ => null,
  };

  /// [base] styled for this status: colored, and struck through when
  /// deleted; [base] itself when clean.
  TextStyle textStyle(ColorScheme colorScheme, TextStyle base) {
    return switch (this) {
      GitFileStatus.deleted =>
        base
            .merge(AppTextStyle.struckThrough)
            .copyWith(color: color(colorScheme)),
      GitFileStatus.ignored ||
      GitFileStatus.untracked ||
      GitFileStatus.added ||
      GitFileStatus.modified => base.copyWith(color: color(colorScheme)),
      _ => base,
    };
  }
}
