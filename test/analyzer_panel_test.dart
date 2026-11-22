import 'dart:async';

import 'package:fide/constants/core_constants.dart';
import 'package:fide/models/analyzer_review.dart';
import 'package:fide/models/code_category.dart';
import 'package:fide/models/dry_review.dart';
import 'package:fide/models/file_layout_review.dart';
import 'package:fide/panels/right/analyzer_panel.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/dry_review_provider.dart';
import 'package:fide/providers/file_layout_review_provider.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/services/file_mover.dart';
import 'package:fide/theme/app_theme.dart';
import 'package:fide/widgets/busy_bar.dart';
import 'package:fide/widgets/task_button.dart';
import 'package:fide/widgets/task_ring.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_code_formatter.dart';
import 'fake_file_content_reader.dart';

/// An `Icon` whose color drifted between two files.
const DryReview _review = DryReview(
  widgetCount: 12,
  fileCount: 3,
  findings: [
    DryFinding(
      kind: DryFindingKind.drift,
      widget: 'Icon',
      setting: 'color',
      variants: [
        DryVariant('AppTheme.readable(color, colorScheme)', [
          DryLocation('lib/widgets/status.dart', 41, className: 'Status'),
        ]),
        DryVariant('color ?? colorScheme.primary', [
          DryLocation('lib/widgets/menu_row.dart', 56, className: 'MenuRow'),
        ]),
      ],
    ),
  ],
);

/// A number with a constant to use instead, in `lib/a.dart`.
const DryReview _numberReview = DryReview(
  widgetCount: 1,
  fileCount: 1,
  findings: [
    DryFinding(
      kind: DryFindingKind.literal,
      widget: '32',
      variants: [
        DryVariant('32', [DryLocation('lib/a.dart', 1)]),
      ],
      suggestion: 'Use AppIconSize.large',
      fixes: [
        DryFix('Use AppIconSize.large', [
          DryEdit('lib/a.dart', _numberOffset, '32', 'AppIconSize.large'),
        ]),
      ],
    ),
  ],
);

/// A `FittedBox` to extract into a new widget, in `lib/a.dart`.
const DryReview _extractReview = DryReview(
  widgetCount: 2,
  fileCount: 2,
  takenNames: {'FittedBox'},
  findings: [
    DryFinding(
      kind: DryFindingKind.clone,
      widget: 'FittedBox',
      variants: [
        DryVariant('fit: BoxFit.fitHeight', [DryLocation('lib/a.dart', 1)]),
      ],
      fixes: [
        DryFix(
          'Extract widget…',
          [
            DryEdit(
              'lib/a.dart',
              0,
              'FittedBox()',
              '${DryFix.widgetName}()',
              importUri: 'package:demo/widgets/${DryFix.widgetFile}.dart',
            ),
          ],
          created: {
            'lib/widgets/${DryFix.widgetFile}.dart':
                'class ${DryFix.widgetName} {}',
          },
          nameHint: 'HighFittedBox',
        ),
      ],
    ),
  ],
);

/// Offset of the number in [_numberReview]'s file, `Icon(size: 32)`.
const int _numberOffset = 11;

/// A pure widget kept with the screens, and a model kept with the
/// services whose place is taken.
const FileLayoutReview _layoutReview = FileLayoutReview(
  fileCount: 10,
  packageName: 'demo',
  moves: [
    FileMove(
      category: CodeCategory.widgets,
      path: 'lib/screens/score_card.dart',
      target: 'lib/widgets/score_card.dart',
      name: 'ScoreCard',
      line: 3,
    ),
    FileMove(
      category: CodeCategory.models,
      path: 'lib/services/score.dart',
      target: 'lib/models/score.dart',
      name: 'Score',
      line: 1,
      blocker: 'lib/models/score.dart already exists',
    ),
  ],
);

void main() {
  /// Shows the Analyzer tab with [shown] picked, its Repeated Widget
  /// Settings reviewing [review] and its File Layout [layout], each still
  /// reviewing when null, reading, writing and listing the files of
  /// [reader] when given; returns its provider scope.
  Future<ProviderContainer> pumpPanel(
    WidgetTester tester,
    DryReview? review, {
    FileLayoutReview? layout,
    AnalyzerReview shown = AnalyzerReview.repeated,
    FakeFileContentReader? reader,
  }) async {
    SharedPreferences.setMockInitialValues({
      PrefKeys.analyzerReview: shown.name,
    });
    final container = ProviderContainer(
      overrides: [
        dryReviewProvider.overrideWith(
          (_) => review ?? Completer<DryReview?>().future,
        ),
        fileLayoutReviewProvider.overrideWith(
          (_) => layout ?? Completer<FileLayoutReview?>().future,
        ),
        if (reader != null) ...[
          fileContentReaderProvider.overrideWithValue(reader),
          fileMoverProvider.overrideWithValue(
            FileMover(
              reader: reader,
              listDartFiles: (_) async => reader.files.keys.toList(),
            ),
          ),
        ],
        codeFormatterProvider.overrideWithValue(const FakeCodeFormatter()),
      ],
    );
    addTearDown(container.dispose);
    container.read(currentProjectPathProvider.notifier).state = '/p';
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(body: AnalyzerPanel()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('shows each finding with its variants and places', (
    tester,
  ) async {
    await pumpPanel(tester, _review);

    expect(find.text(AnalyzerReview.repeated.label), findsOneWidget);
    expect(find.text('1 finding in 3 files'), findsOneWidget);
    expect(find.text('Drifted copies (1)'), findsOneWidget);
    expect(find.text('Icon · color'), findsOneWidget);
    expect(find.text('color ?? colorScheme.primary'), findsOneWidget);
    expect(find.text('MenuRow'), findsOneWidget);
  });

  testWidgets('a place opens its file, the review staying in view', (
    tester,
  ) async {
    final container = await pumpPanel(tester, _review);

    await tester.tap(find.text('MenuRow'));
    await tester.pumpAndSettle();

    expect(
      container.read(selectedFileProvider)?.path,
      '/p/lib/widgets/menu_row.dart',
    );
    expect(find.text('Icon · color'), findsOneWidget);
  });

  testWidgets('Fix rewrites the places of a finding', (tester) async {
    final reader = FakeFileContentReader()
      ..files['/p/lib/a.dart'] = 'Icon(size: 32)';
    await pumpPanel(tester, _numberReview, reader: reader);

    await tester.tap(find.text('Use AppIconSize.large'));
    await tester.pumpAndSettle();

    expect(reader.files['/p/lib/a.dart'], 'Icon(size: AppIconSize.large)');
    expect(find.text('Fixed 1 place'), findsOneWidget);
  });

  testWidgets('a finding code cannot fix says why and offers the AI', (
    tester,
  ) async {
    await pumpPanel(tester, _review);

    expect(find.text(DryFindingKind.drift.noFix), findsOneWidget);
    expect(find.text('Fix with AI'), findsOneWidget);
  });

  testWidgets('extracting a widget asks its name, then writes it', (
    tester,
  ) async {
    final reader = FakeFileContentReader()
      ..files['/p/lib/a.dart'] = 'FittedBox()';
    await pumpPanel(tester, _extractReview, reader: reader);

    await tester.tap(find.text('Extract widget…'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'RightFittedBox');
    await tester.tap(find.text('Extract'));
    await tester.pumpAndSettle();

    expect(
      reader.files['/p/lib/widgets/right_fitted_box.dart'],
      'class RightFittedBox {}\n',
    );
    expect(
      reader.files['/p/lib/a.dart'],
      "import 'package:demo/widgets/right_fitted_box.dart';\n\n"
      'RightFittedBox()',
    );
  });

  testWidgets('a name the project sees already is refused', (tester) async {
    final reader = FakeFileContentReader()
      ..files['/p/lib/a.dart'] = 'FittedBox()';
    await pumpPanel(tester, _extractReview, reader: reader);

    await tester.tap(find.text('Extract widget…'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'FittedBox');
    await tester.tap(find.text('Extract'));
    await tester.pumpAndSettle();

    expect(find.text('FittedBox is taken: pick another name'), findsOneWidget);
    expect(reader.files.keys, ['/p/lib/a.dart']);
  });

  testWidgets('while it reviews, only the tab rings: the message shows '
      'without a bar and Refresh is just disabled', (tester) async {
    // Settling proves nothing spins in the panel
    await pumpPanel(tester, null);

    expect(find.text('Comparing the widgets of lib…'), findsOneWidget);
    expect(find.byType(BusyBar), findsNothing);
    expect(tester.widget<TaskRing>(find.byType(TaskRing)).spinning, isFalse);
    expect(tester.widget<TaskButton>(find.byType(TaskButton)).onRun, isNull);
  });

  testWidgets('a project without repetition says so', (tester) async {
    await pumpPanel(
      tester,
      const DryReview(findings: [], widgetCount: 4, fileCount: 2),
    );

    expect(find.text('No repeated widget settings found'), findsOneWidget);
  });

  testWidgets('opens on the File Layout: each kind, where it belongs and '
      'its files outside it', (tester) async {
    await pumpPanel(
      tester,
      null,
      layout: _layoutReview,
      shown: AnalyzerReview.layout,
    );

    expect(find.text(AnalyzerReview.layout.label), findsOneWidget);
    expect(find.text('2 files to move, of 10'), findsOneWidget);
    expect(find.text('Widgets (1)'), findsOneWidget);
    expect(
      find.text(FileLayoutReview.describe(CodeCategory.widgets)),
      findsOneWidget,
    );
    expect(find.text('score_card.dart'), findsOneWidget);
    expect(find.text('From lib/screens to lib/widgets'), findsOneWidget);
    expect(find.text('ScoreCard'), findsOneWidget);
  });

  testWidgets('a file that cannot move says why, without Move', (tester) async {
    await pumpPanel(
      tester,
      null,
      layout: _layoutReview,
      shown: AnalyzerReview.layout,
    );

    expect(find.text('lib/models/score.dart already exists'), findsOneWidget);
    // Only the widget can move
    expect(find.text('Move'), findsOneWidget);
    expect(find.text('Move All'), findsNothing);
  });

  testWidgets('Move moves the file, its importers pointed at its new place', (
    tester,
  ) async {
    final reader = FakeFileContentReader()
      ..files['/p/lib/screens/score_card.dart'] = 'class ScoreCard {}\n'
      ..files['/p/lib/main.dart'] =
          "import 'package:demo/screens/score_card.dart';\n\n"
          'void main() {}\n';
    await pumpPanel(
      tester,
      null,
      layout: _layoutReview,
      shown: AnalyzerReview.layout,
      reader: reader,
    );

    await tester.tap(find.text('Move'));
    await tester.pumpAndSettle();

    expect(
      reader.files['/p/lib/widgets/score_card.dart'],
      'class ScoreCard {}\n',
    );
    expect(reader.files.containsKey('/p/lib/screens/score_card.dart'), isFalse);
    expect(
      reader.files['/p/lib/main.dart'],
      "import 'package:demo/widgets/score_card.dart';\n\n"
      'void main() {}\n',
    );
    expect(find.text('Moved 1 file'), findsOneWidget);
  });

  testWidgets('picking the other review shows it, and is kept', (tester) async {
    final container = await pumpPanel(
      tester,
      _review,
      layout: _layoutReview,
      shown: AnalyzerReview.layout,
    );

    await tester.tap(find.byTooltip(AnalyzerReview.repeated.label));
    await tester.pumpAndSettle();

    expect(find.text('Icon · color'), findsOneWidget);
    expect(find.text('score_card.dart'), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString(PrefKeys.analyzerReview),
      AnalyzerReview.repeated.name,
    );
    expect(container.read(fileLayoutReviewProvider).value, _layoutReview);
  });

  testWidgets('a project with every file in its folder says so', (
    tester,
  ) async {
    await pumpPanel(
      tester,
      null,
      layout: const FileLayoutReview(moves: [], fileCount: 4),
      shown: AnalyzerReview.layout,
    );

    expect(find.text('Every file is in its folder'), findsOneWidget);
  });
}
