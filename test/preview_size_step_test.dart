import 'package:fide/models/preview_size_step.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lengths snap to steps of 10, within the bounds', () {
    expect(PreviewSizeStep.snap(244), 240);
    expect(PreviewSizeStep.snap(246), 250);
    expect(PreviewSizeStep.snap(2), PreviewSizeStep.step);
    expect(PreviewSizeStep.snap(5000), PreviewSizeStep.max);
  });
}
