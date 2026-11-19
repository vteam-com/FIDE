part of 'dry_review.dart';

/// One repetition found: the [widget] built, the [setting] concerned and
/// the [variants] it is written as.
class DryFinding {
  /// Creates a finding of [kind] about [widget].
  const DryFinding({
    required this.kind,
    required this.widget,
    required this.variants,
    this.setting,
    this.suggestion,
    this.fixes = const [],
  });

  /// The deterministic fixes offered, one per way to remove the
  /// repetition; none when it takes a choice code cannot make.
  final List<DryFix> fixes;

  /// What repeats.
  final DryFindingKind kind;

  /// The setting that differs or repeats; null when the whole set of
  /// settings does.
  final String? setting;

  /// How to remove the repetition, when one fix is evident.
  final String? suggestion;

  /// The ways the code is written: one for a repetition, several for a
  /// drift.
  final List<DryVariant> variants;

  /// The widget built, or the number for [DryFindingKind.literal].
  final String widget;

  /// The finding's name: the widget and the setting concerned, such as
  /// `Icon · color`, or the number written.
  String get title {
    final setting = this.setting;
    if (kind == DryFindingKind.literal) return 'Number $widget';
    if (setting == null) return widget;
    final name = setting.startsWith(positionalPrefix)
        ? 'argument ${int.parse(setting.substring(1)) + 1}'
        : setting;
    return '$widget · $name';
  }

  /// Prefix of a positional setting's name, followed by its 0-based index.
  static const String positionalPrefix = '#';

  /// The request asking the AI to remove the repetition: what repeats,
  /// each way it is written with where, and what to do.
  String get aiRequest {
    final setting = this.setting;
    final places = [
      for (final variant in variants)
        '- `${variant.source}` at ${variant.locations.join(', ')}',
    ];
    return [
      'Repeated widget settings "$title" (${kind.label}): $widget is built '
          '${setting == null ? 'alike' : 'alike except for `$setting`'} in '
          '$locationCount places of $fileCount files, written as:',
      ...places,
      '${kind.aiTask}${suggestion == null ? '' : ' Hint: $suggestion.'}',
    ].join('\n');
  }

  /// How many places the finding covers.
  int get locationCount =>
      variants.fold(0, (count, variant) => count + variant.locations.length);

  /// How many files the finding covers.
  int get fileCount => {
    for (final variant in variants)
      for (final location in variant.locations) location.path,
  }.length;
}
