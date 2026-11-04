import 'package:fide/models/preview_size_step.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lengths snap to steps of 10, within the bounds', () {
    expect(PreviewSizeStep.snap(244), 240);
    expect(PreviewSizeStep.snap(246), 250);
    expect(PreviewSizeStep.snap(2), PreviewSizeStep.step);
    expect(PreviewSizeStep.snap(5000), PreviewSizeStep.max);
  });

  test('fitting rounds up, so no content is cut', () {
    expect(PreviewSizeStep.fit(41), 50);
    expect(PreviewSizeStep.fit(8.8), 10);
    expect(PreviewSizeStep.fit(40), 40);
    expect(PreviewSizeStep.fit(5000), PreviewSizeStep.max);
  });
}
