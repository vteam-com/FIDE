import 'package:fide/models/file_system_item.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/center_view.dart';
import 'package:fide/providers/editor_navigation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  /// A [WidgetRef] of [container], from a widget built in it.
  Future<WidgetRef> refOf(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    late WidgetRef widgetRef;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (_, ref, _) {
            widgetRef = ref;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return widgetRef;
  }

  testWidgets('opening the active file from a center view shows it, and '
      'remembers the view to go back to', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final ref = await refOf(tester, container);
    container.read(selectedFileProvider.notifier).state =
        FileSystemItem.fromPath('/p/lib/a.dart');
    container.read(centerViewProvider.notifier).state = CenterView.overview;

    openFile(ref, '/p/lib/a.dart');

    expect(container.read(centerViewProvider), isNull);
    expect(container.read(centerViewOpenedFileProvider), (
      view: CenterView.overview,
      path: '/p/lib/a.dart',
    ));
    expect(container.read(selectedFileProvider)?.path, '/p/lib/a.dart');
  });
}
