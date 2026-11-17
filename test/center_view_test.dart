import 'package:fide/providers/center_view.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('centerViewAfterFileChange', () {
    test('opening a file from a view leaves it and remembers it', () {
      final after = centerViewAfterFileChange(
        previous: null,
        next: '/p/a.dart',
        showing: CenterView.overview,
        opened: null,
      );

      expect(after.view, isNull);
      expect(after.opened, (view: CenterView.overview, path: '/p/a.dart'));
    });

    test('closing the file opened from a view goes back to it', () {
      final after = centerViewAfterFileChange(
        previous: '/p/a.dart',
        next: null,
        showing: null,
        opened: (view: CenterView.architecture, path: '/p/a.dart'),
      );

      expect(after.view, CenterView.architecture);
      expect(after.opened, isNull);
    });

    test('switching to another file forgets the view', () {
      final after = centerViewAfterFileChange(
        previous: '/p/a.dart',
        next: '/p/b.dart',
        showing: null,
        opened: (view: CenterView.appIcons, path: '/p/a.dart'),
      );

      expect(after.view, isNull);
      expect(after.opened, isNull);
    });

    test('closing another file keeps the one opened from the view', () {
      const opened = (view: CenterView.appIcons, path: '/p/a.dart');
      final after = centerViewAfterFileChange(
        previous: '/p/b.dart',
        next: '/p/a.dart',
        showing: null,
        opened: opened,
      );

      expect(after.view, isNull);
      expect(after.opened, opened);
    });
  });
}
