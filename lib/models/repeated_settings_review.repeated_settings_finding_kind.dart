part of 'repeated_settings_review.dart';

/// The ways a widget's settings repeat, each with the fix it calls for.
enum RepeatedSettingsFindingKind {
  /// The same widget built with the same settings in several files.
  clone(
    'Same settings',
    'Built with the same settings in several files: one shared widget '
        'should build it.',
    noFix:
        'No automatic fix: its code can\'t move to a shared widget as '
        'written (a private name, a generic type, a default the widget '
        'would change, or a slot taking only this widget, such as an '
        'appBar).',
    aiTask:
        'Extract one shared widget under lib/widgets/ building it with these '
        'settings, and use it in every place.',
  ),

  /// The same widget built alike except for one setting.
  drift(
    'Drifted copies',
    'Built alike except for one setting: pick the right value and remove '
        'the difference.',
    noFix:
        'No automatic fix: which value is right is a choice, and the '
        'values read their own place\'s state.',
    aiTask:
        'Decide which value is right, then make every place use it and '
        'share it (a shared widget or a design token) so they no longer '
        'differ; keep what each place must show.',
  ),

  /// One setting given the same value by every use of a widget.
  sameEverywhere(
    'Same value everywhere',
    'Every use passes the same value: make it the default, in the widget '
        'or in the theme.',
    noFix: 'No automatic fix yet: making it a default comes next.',
    aiTask:
        'Make this value the default, in the widget for a project widget or '
        'in the app theme for a Flutter one, and remove it from every place.',
  ),

  /// A number equal to a constant the project defines.
  literal(
    'Numbers matching a constant',
    'A number written where a constant of the project has that value.',
    noFix: 'No automatic fix: no constant names this setting.',
    aiTask: 'Use the constant of the project for this number in every place.',
  );

  const RepeatedSettingsFindingKind(
    this.label,
    this.description, {
    required this.noFix,
    required this.aiTask,
  });

  /// What the AI is asked to do about a finding of this kind.
  final String aiTask;

  /// Why a finding of this kind has no fix code can make.
  final String noFix;

  /// What the fix is, for the user.
  final String description;

  /// The kind's name, for the user.
  final String label;
}
