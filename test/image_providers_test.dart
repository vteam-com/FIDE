import 'package:fide/providers/image_providers.dart';
import 'package:fide/services/image_differ.dart';
import 'package:fide/services/image_inspector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('provides the image inspector and differ', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(imageInspectorProvider), isA<ImageInspector>());
    expect(container.read(imageDifferProvider), isA<ImageDiffer>());
  });
}
