import 'dart:isolate';
import 'dart:math' as math;

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/scope.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/dart/element/type_system.dart';
import 'package:fide/models/dart_imports.dart';
import 'package:fide/models/dry_review.dart';
import 'package:fide/models/unique_name.dart';
import 'package:fide/services/dart_references.dart';
import 'package:path/path.dart' as p;

part 'dry_analyzer.argument.dart';
part 'dry_analyzer.call_collector.dart';
part 'dry_analyzer.constant.dart';
part 'dry_analyzer.extraction.dart';
part 'dry_analyzer.literal_use.dart';
part 'dry_analyzer.shared_widget.dart';
part 'dry_analyzer.source_file.dart';
part 'dry_analyzer.state_finder.dart';
part 'dry_analyzer.widget_call.dart';

/// Finds the widget settings a Flutter project repeats, the Repeated Widget Settings review's
/// findings: knowing every project is a Flutter app, it compares only the
/// styling settings of the widgets built (sizes, colors, text styles,
/// paddings, icons, enums…), never their content (children, text,
/// callbacks), and skips layout widgets, whose repetition is no concern.
///
/// A setting reading the widget's own state (its fields, parameters and
/// locals) is compared by shape only, so `Icon(icon, size: AppIconSize.medium)`
/// matches whatever `icon` is.
///
/// Evaluation: FIDE finds these itself for now; once they prove useful,
/// the analysis moves into fCheck.
class DryAnalyzer {
  /// Creates a stateless analyzer.
  const DryAnalyzer();

  /// Fewest files a repetition spans to be reported.
  static const int minFiles = 2;

  /// Fewest styling settings a widget needs for its settings to count as
  /// a configuration worth sharing.
  static const int minSettings = 2;

  /// A setting picking one value of the design system: a token such as
  /// `AppTextStyle.label` or `AppTextStyle.secondary($)`, an enum value,
  /// or a number. Variants made only of these are choices, not drift.
  static final RegExp _tokenPattern = RegExp(
    r'^(?:[A-Z]\w*(?:\.\w+)+(?:\(\$\))?|-?[\d.]+)$',
  );

  /// Most variants a drift has: more is a palette of choices, such as the
  /// text styles of a design system, not copies that drifted apart.
  static const int maxDriftVariants = 3;

  /// Most constants suggested for one number.
  static const int maxSuggestions = 3;

  /// A word of a camel-cased name: `App`, `Icon`, `Size`.
  static final RegExp _wordPattern = RegExp('[A-Z]?[a-z]+|[A-Z]+(?![a-z])');

  /// Fewest uses of a widget giving a setting the same value for that
  /// value to be its default.
  static const int minUses = 3;

  /// Reviews the `lib` folder of the project at [projectPath], resolved
  /// against the Dart SDK at [sdkPath], off the UI thread.
  Future<DryReview> review(String projectPath, String sdkPath) =>
      Isolate.run(() => _review(projectPath, sdkPath));

  /// [review]'s work, on the background isolate: resolves every Dart file
  /// of `lib`, collects the widgets built, then derives each kind of
  /// finding from them.
  static Future<DryReview> _review(String projectPath, String sdkPath) async {
    final collection = AnalysisContextCollection(
      includedPaths: [p.join(projectPath, 'lib')],
      sdkPath: sdkPath,
    );
    final collector = _CallCollector(projectPath);
    var fileCount = 0;
    for (final context in collection.contexts) {
      final paths = context.contextRoot.analyzedFiles().toList()..sort();
      for (final path in paths) {
        if (!path.endsWith('.dart') || path.endsWith('.g.dart')) continue;
        final result = await context.currentSession.getResolvedUnit(path);
        if (result is! ResolvedUnitResult) continue;
        fileCount++;
        collector.collect(result);
      }
    }
    final calls = collector.calls;
    final findings = [
      ..._clones(calls, collector.takenNames),
      ..._drifts(calls),
      ..._sameEverywhere(calls),
      ..._literals(collector.literals, collector.constants),
    ]..sort((a, b) => b.locationCount.compareTo(a.locationCount));
    return DryReview(
      findings: findings,
      widgetCount: calls.length,
      fileCount: fileCount,
      takenNames: collector.takenNames,
    );
  }

  /// Widgets built with the same settings in several files, each fixed by
  /// a shared widget: an existing one, else one extracted under a name
  /// none of [takenNames].
  static Iterable<DryFinding> _clones(
    List<_WidgetCall> calls,
    Set<String> takenNames,
  ) sync* {
    final builds = [
      for (final call in calls)
        if (call.shared != null) call,
    ];
    final groups = _groupBy(
      calls.where((call) => call.settings.length >= minSettings),
      (call) => '${call.widget}(${call.key()})',
    );
    for (final group in groups.values) {
      if (_fileCount(group) < minFiles) continue;
      // Only a widget the clones can be rewritten as is worth naming
      final use = _useSharedWidget(group, builds);
      final suggested = use?.built;
      yield DryFinding(
        kind: DryFindingKind.clone,
        widget: group.first.widget,
        variants: [
          DryVariant(group.first.display(), [
            for (final call in group) call.location,
          ]),
        ],
        suggestion: suggested == null
            ? 'Extract a shared widget'
            : 'Use ${suggested.location.className} '
                  '(${suggested.location.path})',
        fixes: [?use?.fix ?? _Extraction.fixOf(group, takenNames)],
      );
    }
  }

  /// The fix rewriting the clones of [group] as calls to a shared widget,
  /// with the call its `build` returns: one of [builds] building the same
  /// widget with some of the group's settings, the others passed to its
  /// parameters, such as a `TruncatedText(name, style: …)` for a
  /// `Text(name, style: …, maxLines: 1, overflow: …)`; the group's own
  /// first. Null when no clone maps onto such a widget's constructor.
  /// The shared widget's own code is left alone, lest it build itself.
  static ({DryFix fix, _WidgetCall built})? _useSharedWidget(
    List<_WidgetCall> group,
    List<_WidgetCall> builds,
  ) {
    final settings = group.first.settings;
    final candidates = {
      ...group.where((call) => call.shared != null),
      ...builds.where(
        (built) =>
            built.widget == group.first.widget &&
            built.settings.isNotEmpty &&
            built.settings.entries.every(
              (setting) => settings[setting.key] == setting.value,
            ),
      ),
    };
    for (final built in candidates) {
      final shared = built.shared!;
      final edits = [
        for (final call in group)
          if (call.location.className != shared.name)
            ?shared.rewrite(call, built),
      ];
      if (edits.isNotEmpty) {
        return (fix: DryFix(shared.label, edits), built: built);
      }
    }
    return null;
  }

  /// Widgets built alike except for one setting, across files.
  static Iterable<DryFinding> _drifts(List<_WidgetCall> calls) sync* {
    final groups = <String, List<_WidgetCall>>{};
    final settingOf = <String, String>{};
    for (final call in calls) {
      if (call.settings.length < minSettings) continue;
      for (final setting in call.settings.keys) {
        if (call.choices.contains(setting)) continue;
        final key = '${call.widget}(${call.key(except: setting)}, $setting: ?)';
        groups.putIfAbsent(key, () => []).add(call);
        settingOf[key] = setting;
      }
    }
    for (final MapEntry(:key, value: group) in groups.entries) {
      final setting = settingOf[key]!;
      final variants = _groupBy(group, (call) => call.settings[setting]!);
      if (variants.length < minFiles ||
          variants.length > maxDriftVariants ||
          _fileCount(group) < minFiles ||
          variants.keys.every(_tokenPattern.hasMatch)) {
        continue;
      }
      final ranked = variants.values.toList()
        ..sort((a, b) => b.length.compareTo(a.length));
      yield DryFinding(
        kind: DryFindingKind.drift,
        widget: group.first.widget,
        setting: setting,
        variants: [
          for (final variant in ranked)
            DryVariant(variant.first.sources[setting]!, [
              for (final call in variant) call.location,
            ]),
        ],
      );
    }
  }

  /// Settings every use of a widget gives the same value.
  static Iterable<DryFinding> _sameEverywhere(List<_WidgetCall> calls) sync* {
    final byWidget = _groupBy(calls, (call) => call.widget);
    for (final uses in byWidget.values) {
      if (uses.length < minUses || _fileCount(uses) < minFiles) continue;
      final first = uses.first;
      for (final MapEntry(key: setting, :value) in first.settings.entries) {
        if (uses.any((call) => call.settings[setting] != value)) continue;
        yield DryFinding(
          kind: DryFindingKind.sameEverywhere,
          widget: first.widget,
          setting: setting,
          variants: [
            DryVariant(first.sources[setting]!, [
              for (final call in uses) call.location,
            ]),
          ],
          suggestion: first.isProjectWidget
              ? 'Make it the default of `$setting` in ${first.widget}'
              : 'Set it once in the app theme',
        );
      }
    }
  }

  /// Numbers in styling settings equal to a constant of the project, each
  /// with a fix per constant it may stand for.
  static Iterable<DryFinding> _literals(
    List<_LiteralUse> uses,
    Map<num, List<_Constant>> constants,
  ) sync* {
    final suggested = [
      for (final use in uses)
        if (_closest(constants[use.value], use) case final matches
            when matches.isNotEmpty)
          (use: use, constants: matches),
    ];
    final groups = _groupBy(
      suggested,
      (match) =>
          '${match.use.value} '
          '${[for (final constant in match.constants) constant.name]}',
    );
    for (final group in groups.values) {
      final matches = group.first.constants;
      yield DryFinding(
        kind: DryFindingKind.literal,
        widget: group.first.use.source,
        variants: [
          DryVariant(group.first.use.source, [
            for (final match in group) match.use.location,
          ]),
        ],
        suggestion:
            'Use ${[for (final constant in matches) constant.name].join(' or ')}',
        fixes: [
          for (final constant in matches)
            DryFix('Use ${constant.name}', [
              for (final match in group) constant.editOf(match.use),
            ]),
        ],
      );
    }
  }

  /// The constants among [candidates] of [use]'s type whose name has
  /// every word of its setting's (`AppBorderRadius` for a `borderRadius`,
  /// not for a `blurRadius`), ranked by the words they share with its
  /// context, at most [maxSuggestions]. None when no name says what the
  /// setting is, the value then being a coincidence.
  static List<_Constant> _closest(
    List<_Constant>? candidates,
    _LiteralUse use,
  ) {
    final settingWords = _wordsOf(use.setting);
    if (candidates == null || settingWords.isEmpty) return const [];
    final words = _wordsOf(use.context);
    final scores = {
      for (final constant in candidates)
        if (constant.type == use.type &&
            _wordsOf(constant.name).containsAll(settingWords))
          constant: _wordsOf(constant.name).where(words.contains).length,
    };
    final best = scores.values.fold(0, math.max);
    if (best == 0) return const [];
    return [
      for (final MapEntry(key: constant, value: score) in scores.entries)
        if (score == best) constant,
    ].take(maxSuggestions).toList();
  }

  /// The lowercase words of camel-cased, dotted or spaced [text].
  static Set<String> _wordsOf(String text) => {
    for (final match in _wordPattern.allMatches(text)) match[0]!.toLowerCase(),
  };

  /// How many files [calls] are in.
  static int _fileCount(Iterable<_WidgetCall> calls) =>
      {for (final call in calls) call.location.path}.length;

  /// [items] grouped by [keyOf], in first-seen order.
  static Map<String, List<T>> _groupBy<T>(
    Iterable<T> items,
    String Function(T item) keyOf,
  ) {
    final groups = <String, List<T>>{};
    for (final item in items) {
      groups.putIfAbsent(keyOf(item), () => []).add(item);
    }
    return groups;
  }
}
