import 'package:fide/models/code_category.dart';
import 'package:fide/models/file_layout_review.dart';
import 'package:fide/models/repeated_settings_review.dart';
import 'package:fide/providers/analyzer_tab_providers.dart';
import 'package:fide/providers/file_layout_review_provider.dart';
import 'package:fide/providers/repeated_settings_review_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A File Layout review moving [count] files.
FileLayoutReview _layout(int count) => FileLayoutReview(
  moves: [
    for (var index = 0; index < count; index++)
      FileMove(
        category: CodeCategory.widgets,
        path: 'lib/w$index.dart',
        target: 'lib/widgets/w$index.dart',
        name: 'W$index',
        line: 1,
      ),
  ],
  fileCount: count,
);

/// A Repeated Widget Settings review with [count] findings.
RepeatedSettingsReview _repeated(int count) => RepeatedSettingsReview(
  findings: [
    for (var index = 0; index < count; index++)
      const RepeatedSettingsFinding(
        kind: RepeatedSettingsFindingKind.clone,
        widget: 'Text',
        variants: [],
      ),
  ],
  widgetCount: count,
  fileCount: count,
);

void main() {
  test('the badge counts nothing, starting no review, until the tab runs '
      'one', () async {
    var reviews = 0;
    final container = ProviderContainer(
      overrides: [
        fileLayoutReviewProvider.overrideWith((_) async {
          reviews++;
          return _layout(2);
        }),
        repeatedSettingsReviewProvider.overrideWith((_) async {
          reviews++;
          return _repeated(3);
        }),
      ],
    );
    addTearDown(container.dispose);
    container.listen(analyzerFindingCountProvider, (_, _) {});

    await Future<void>.delayed(Duration.zero);

    expect(container.read(analyzerFindingCountProvider), 0);
    expect(reviews, 0);
  });

  test('the badge counts the files to move and the repeated settings of '
      'the reviews the tab ran', () async {
    final container = ProviderContainer(
      overrides: [
        fileLayoutReviewProvider.overrideWith((_) async => _layout(2)),
        repeatedSettingsReviewProvider.overrideWith((_) async => _repeated(3)),
      ],
    );
    addTearDown(container.dispose);
    container.listen(analyzerFindingCountProvider, (_, _) {});

    // The tab shows the File Layout, then the Repeated Widget Settings
    await container.read(fileLayoutReviewProvider.future);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(analyzerFindingCountProvider), 2);

    await container.read(repeatedSettingsReviewProvider.future);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(analyzerFindingCountProvider), 5);
  });
}
