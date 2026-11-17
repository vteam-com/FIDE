import 'package:fide/constants/constants.dart';
import 'package:fide/models/side_panel_widths.dart';
import 'package:flutter_test/flutter_test.dart';

/// A shown, dragged panel [width] wide.
SidePanelSize _dragged(double width) =>
    (shown: true, expanded: false, width: width);

/// A hidden panel that was [width] wide.
SidePanelSize _hidden(double width) =>
    (shown: false, expanded: false, width: width);

/// The editor's width once [left] and [right] take theirs from [available].
double _editor(double available, ({double left, double right}) widths) =>
    available - widths.left - widths.right - 2 * AppSize.splitterThickness;

void main() {
  test('panels that fit keep their dragged widths', () {
    final widths = SidePanelWidths.fit(
      1600,
      left: _dragged(300),
      right: _dragged(400),
    );

    expect(widths, (left: 300.0, right: 400.0));
  });

  test('wide panels shrink so the editor keeps its minimum', () {
    const available = 1000.0;
    final widths = SidePanelWidths.fit(
      available,
      left: _dragged(900),
      right: _dragged(250),
    );

    expect(_editor(available, widths), closeTo(AppSize.editorMinWidth, 1e-9));
    expect(widths.left, greaterThan(widths.right));
    expect(widths.right, greaterThanOrEqualTo(AppSize.minSidePanelWidth));
  });

  test('panels never shrink below their minimum', () {
    final widths = SidePanelWidths.fit(
      AppSize.minWindowSize.width,
      left: _dragged(AppSize.maxSidePanelWidth),
      right: _dragged(AppSize.maxSidePanelWidth),
    );

    expect(widths.left, greaterThanOrEqualTo(AppSize.minSidePanelWidth));
    expect(widths.right, greaterThanOrEqualTo(AppSize.minSidePanelWidth));
  });

  test('an expanded panel takes what the other and the editor leave', () {
    const available = 1400.0;
    final widths = SidePanelWidths.fit(
      available,
      left: (shown: true, expanded: true, width: 250),
      right: _dragged(300),
    );

    expect(widths.right, 300);
    expect(_editor(available, widths), closeTo(AppSize.editorMinWidth, 1e-9));
  });

  test('a hidden panel keeps its width and leaves room to the other', () {
    final widths = SidePanelWidths.fit(
      1000,
      left: _hidden(500),
      right: _dragged(600),
    );

    expect(widths.left, 500);
    expect(widths.right, 600);
  });
}
