import 'package:fide/constants/constants.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppZoom', () {
    test('larger and smaller step to the neighbouring level', () {
      expect(AppZoom.larger(AppZoom.actualSize), 1.1);
      expect(AppZoom.smaller(AppZoom.actualSize), 0.9);
    });

    test(
      'a zoom between levels steps to the nearest one in that direction',
      () {
        expect(AppZoom.larger(1.2), 1.25);
        expect(AppZoom.smaller(1.2), 1.1);
      },
    );

    test('stops at the smallest and largest levels', () {
      expect(AppZoom.larger(AppZoom.levels.last), AppZoom.levels.last);
      expect(AppZoom.smaller(AppZoom.levels.first), AppZoom.levels.first);
    });

    test('label shows a whole percent', () {
      expect(AppZoom.label(1.25), '125%');
      expect(AppZoom.label(0.67), '67%');
    });
  });
}
