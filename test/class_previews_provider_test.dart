import 'package:fide/models/preview_item.dart';
import 'package:fide/models/preview_scope.dart';
import 'package:fide/providers/class_previews_provider.dart';
import 'package:fide/providers/preview_controller.dart';
import 'package:fide/services/preview_scanner.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A controller showing [shown] without scanning or running a host.
class _FakeController extends PreviewController {
  _FakeController(this.shown);

  final PreviewState shown;

  @override
  PreviewState build() => shown;
}

const String _path = '/p/lib/badge.dart';

void main() {
  final state = PreviewState(
    filePath: _path,
    status: PreviewStatus.ready,
    scan: const PreviewScanner().scan('''
@Preview()
Widget cardPreview() => const Card();

@Preview()
Widget badgePreview() => const Badge();
'''),
    items: const [
      PreviewItem(function: 'cardPreview', line: 2, group: 'G'),
      PreviewItem(function: 'badgePreview', line: 5, group: 'G'),
    ],
  );

  /// The previews of [className] while the controller shows [shown].
  List<(int, String)> previewsOf(PreviewState shown, String className) {
    final container = ProviderContainer(
      overrides: [
        previewControllerProvider.overrideWith(() => _FakeController(shown)),
      ],
    );
    addTearDown(container.dispose);
    return [
      for (final (:index, :item) in container.read(
        classPreviewsProvider((path: _path, className: className)),
      ))
        (index, item.function),
    ];
  }

  test('lists the previews of the file shown that build the class', () {
    expect(previewsOf(state, 'Badge'), [(1, 'badgePreview')]);
    expect(previewsOf(state, 'Chip'), isEmpty);
  });

  test('lists none while another file or the project is shown', () {
    final otherFile = PreviewState(
      filePath: '/p/lib/card.dart',
      scan: state.scan,
      items: state.items,
    );
    final project = PreviewState(
      filePath: _path,
      scope: PreviewScope.project,
      scan: state.scan,
      items: state.items,
    );

    expect(previewsOf(otherFile, 'Badge'), isEmpty);
    expect(previewsOf(project, 'Badge'), isEmpty);
  });
}
