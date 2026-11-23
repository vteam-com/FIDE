import 'package:fide/models/dart_imports.dart';
import 'package:fide/models/import_graph.dart';
import 'package:fide/models/project_name.dart';
import 'package:fide/models/text_offsets.dart';

part 'repeated_settings_review.repeated_settings_edit.dart';
part 'repeated_settings_review.repeated_settings_finding.dart';
part 'repeated_settings_review.repeated_settings_finding_kind.dart';
part 'repeated_settings_review.repeated_settings_fix.dart';
part 'repeated_settings_review.repeated_settings_location.dart';
part 'repeated_settings_review.repeated_settings_variant.dart';

/// What the Analyzer tab's Repeated Widget Settings review shows for a project: the repeated widget settings
/// found across its `lib` folder, read once off the UI thread.
///
/// Evaluation: FIDE finds these itself for now; once they prove useful,
/// the analysis moves into fCheck.
class RepeatedSettingsReview {
  /// Creates a review of [widgetCount] widgets built across [fileCount]
  /// files.
  const RepeatedSettingsReview({
    required this.findings,
    required this.widgetCount,
    required this.fileCount,
    this.takenNames = const {},
    this.graph = const ImportGraph({}),
    this.packageName,
  });

  /// Every name a file of the project sees, which a widget extracted by a
  /// fix can't take.
  final Set<String> takenNames;

  /// How many Dart files were read.
  final int fileCount;

  /// The dependencies between the files of `lib`, so a fix adds no Layers
  /// issue; empty when unknown.
  final ImportGraph graph;

  /// The project's package name, which its `package:` imports start with;
  /// null without one.
  final String? packageName;

  /// What was found, most repeated first.
  final List<RepeatedSettingsFinding> findings;

  /// How many widgets the files build.
  final int widgetCount;

  /// The findings of [kind], in order.
  List<RepeatedSettingsFinding> of(RepeatedSettingsFindingKind kind) => [
    for (final finding in findings)
      if (finding.kind == kind) finding,
  ];
}
