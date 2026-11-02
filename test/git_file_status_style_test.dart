import 'package:fide/constants/constants.dart';
import 'package:fide/models/git_file_status.dart';
import 'package:fide/models/status_tone.dart';
import 'package:fide/widgets/git_file_status_style.dart';
import 'package:fide/widgets/status_tone_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final brightness in Brightness.values) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: brightness,
    );

    test('changes use the status tones, the rest the $brightness theme', () {
      expect(GitFileStatus.added.color(colorScheme), StatusTone.success.color);
      expect(
        GitFileStatus.modified.color(colorScheme),
        StatusTone.warning.color,
      );
      expect(GitFileStatus.deleted.color(colorScheme), StatusTone.error.color);
      expect(
        GitFileStatus.untracked.color(colorScheme),
        colorScheme.onSurfaceVariant,
      );
      expect(GitFileStatus.ignored.color(colorScheme), colorScheme.outline);
      expect(GitFileStatus.clean.color(colorScheme), colorScheme.onSurface);
    });

    test('deleted names are struck through, clean ones unchanged', () {
      const base = AppTextStyle.body;
      final deleted = GitFileStatus.deleted.textStyle(colorScheme, base);
      expect(deleted.decoration, TextDecoration.lineThrough);
      expect(deleted.color, StatusTone.error.color);
      expect(deleted.fontSize, base.fontSize);

      expect(GitFileStatus.clean.textStyle(colorScheme, base), same(base));
      expect(
        GitFileStatus.added.textStyle(colorScheme, base).decoration,
        isNull,
      );
    });
  }

  test('only changed folders get an icon', () {
    expect(GitFileStatus.added.icon, Icons.add_circle);
    expect(GitFileStatus.clean.icon, isNull);
    expect(GitFileStatus.ignored.icon, isNull);
  });
}
