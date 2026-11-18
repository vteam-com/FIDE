import 'package:fide/models/file_system_item.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/center_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('details the icon picked while App Icons shows, else the selected '
      'file', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(detailedFilePathProvider), isNull);

    container.read(selectedFileProvider.notifier).state =
        FileSystemItem.fromPath('/p/lib/main.dart');
    container.read(appIconSelectionProvider.notifier).state = '/p/icon.png';
    expect(container.read(detailedFilePathProvider), '/p/lib/main.dart');

    container.read(centerViewProvider.notifier).state = CenterView.appIcons;
    expect(container.read(detailedFilePathProvider), '/p/icon.png');
  });
}
