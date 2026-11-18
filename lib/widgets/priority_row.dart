import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

/// The parts of a [PriorityRow], the slots of its children.
enum PriorityRowSlot { leading, title, trailing, compactTrailing }

/// A row of a fixed [leading] glyph, a [title] filling the width, and
/// [trailing] extras (badges, counts, actions) at the end, where the title
/// has priority: as the row narrows, the title keeps at least
/// [titleMinShare] of the room after [leading] (all of it when shorter),
/// the extras give way to [compactTrailing], then hide, rather than
/// squeezing the title.
///
/// A [packed] row puts [trailing] right after the title's own width instead,
/// leaving the end of the row empty.
///
/// Whatever still does not fit, such as a [leading] wider than the row, is
/// clipped, not flagged as an overflow.
class PriorityRow
    extends SlottedMultiChildRenderObjectWidget<PriorityRowSlot, RenderBox> {
  /// Creates the row of [leading], [title] and [trailing], [spacing] apart.
  const PriorityRow({
    super.key,
    this.leading,
    required this.title,
    this.trailing,
    this.compactTrailing,
    this.packed = false,
    this.spacing = 0,
  });

  /// Least share of the room after [leading] the title keeps before the
  /// extras give way.
  static const double titleMinShare = 0.5;

  /// Narrower stand-in for [trailing], such as its actions as icons only,
  /// shown when [trailing] does not fit; hidden too when it does not.
  final Widget? compactTrailing;

  /// Fixed glyph at the start, such as an icon or a chevron.
  final Widget? leading;

  /// Whether the title takes only its own width, [trailing] right after
  /// it, rather than filling the width up to [trailing] at the row's end.
  final bool packed;

  /// Gap between the parts.
  final double spacing;

  /// The part filling the width, such as a name that ellipsizes.
  final Widget title;

  /// Extras at the end, shown at their natural width while they fit.
  final Widget? trailing;

  @override
  Iterable<PriorityRowSlot> get slots => PriorityRowSlot.values;

  @override
  Widget? childForSlot(PriorityRowSlot slot) {
    return switch (slot) {
      PriorityRowSlot.leading => leading,
      PriorityRowSlot.title => title,
      PriorityRowSlot.trailing => trailing,
      PriorityRowSlot.compactTrailing => compactTrailing,
    };
  }

  @override
  SlottedContainerRenderObjectMixin<PriorityRowSlot, RenderBox>
  createRenderObject(BuildContext context) =>
      _RenderPriorityRow(spacing, packed);

  @override
  void updateRenderObject(
    BuildContext context,
    SlottedContainerRenderObjectMixin<PriorityRowSlot, RenderBox> renderObject,
  ) {
    (renderObject as _RenderPriorityRow)
      ..spacing = spacing
      ..packed = packed;
  }
}

/// Lays out a [PriorityRow]: measures every part, then shows [leading],
/// the title and the widest trailing part that leaves the title its share.
class _RenderPriorityRow extends RenderBox
    with SlottedContainerRenderObjectMixin<PriorityRowSlot, RenderBox> {
  _RenderPriorityRow(this._spacing, this._packed);

  /// The clip layer, kept across repaints.
  final LayerHandle<ClipRectLayer> _clipLayer = LayerHandle<ClipRectLayer>();

  /// The trailing part shown in the last layout; none when both hide.
  RenderBox? _shownTrailing;

  bool _packed;

  /// Whether the title takes only its own width, the trailing part right
  /// after it.
  set packed(bool value) {
    if (value == _packed) return;
    _packed = value;
    markNeedsLayout();
  }

  double _spacing;

  /// Gap between the parts.
  set spacing(double value) {
    if (value == _spacing) return;
    _spacing = value;
    markNeedsLayout();
  }

  RenderBox? get _leading => childForSlot(PriorityRowSlot.leading);

  RenderBox get _title => childForSlot(PriorityRowSlot.title)!;

  /// The parts painted, hit and read out, in paint order.
  List<RenderBox> get _shown => [?_leading, _title, ?_shownTrailing];

  @override
  void performLayout() {
    final heightOnly = BoxConstraints(maxHeight: constraints.maxHeight);
    final leading = _leading;
    final title = _title;
    leading?.layout(heightOnly, parentUsesSize: true);
    final leadingWidth = leading == null ? 0.0 : leading.size.width + _spacing;

    // Each candidate's width with its gap, measured at its natural size
    final candidates = <RenderBox>[
      ?childForSlot(PriorityRowSlot.trailing),
      ?childForSlot(PriorityRowSlot.compactTrailing),
    ];
    for (final candidate in candidates) {
      candidate.layout(heightOnly, parentUsesSize: true);
    }
    double widthOf(RenderBox box) => box.size.width + _spacing;

    // The title's own width, at most the room; measured by a loose layout,
    // as intrinsics fail on titles built by a LayoutBuilder
    title.layout(
      BoxConstraints(
        maxWidth: math.max(0.0, constraints.maxWidth - leadingWidth),
        maxHeight: constraints.maxHeight,
      ),
      parentUsesSize: true,
    );
    final titleNatural = title.size.width;
    final room = constraints.hasBoundedWidth
        ? math.max(0.0, constraints.maxWidth - leadingWidth)
        : titleNatural + (candidates.isEmpty ? 0 : widthOf(candidates.first));
    final titleMin = math.min(titleNatural, room * PriorityRow.titleMinShare);
    _shownTrailing = null;
    for (final candidate in candidates) {
      if (titleMin + widthOf(candidate) <= room) {
        _shownTrailing = candidate;
        break;
      }
    }
    final shownTrailing = _shownTrailing;
    final titleRoom = shownTrailing == null
        ? room
        : room - widthOf(shownTrailing);
    final titleWidth = _packed ? math.min(titleNatural, titleRoom) : titleRoom;
    title.layout(
      BoxConstraints(
        minWidth: titleWidth,
        maxWidth: titleWidth,
        maxHeight: constraints.maxHeight,
      ),
      parentUsesSize: true,
    );

    final height = _shown.map((child) => child.size.height).reduce(math.max);
    size = constraints.constrain(
      Size(
        leadingWidth +
            titleWidth +
            (shownTrailing == null ? 0 : widthOf(shownTrailing)),
        height,
      ),
    );
    if (leading != null) _place(leading, 0);
    _place(title, leadingWidth);
    if (shownTrailing != null) {
      _place(
        shownTrailing,
        _packed
            ? leadingWidth + titleWidth + _spacing
            : size.width - shownTrailing.size.width,
      );
    }
  }

  /// Puts [child] at [x], centered vertically.
  void _place(RenderBox child, double x) {
    final free = (size - child.size) as Offset;
    (child.parentData! as BoxParentData).offset = Offset(
      x,
      Alignment.center.alongOffset(free).dy,
    );
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final heightOnly = BoxConstraints(maxHeight: constraints.maxHeight);
    final height = children
        .map((child) => child.getDryLayout(heightOnly).height)
        .fold(0.0, math.max);
    return constraints.constrain(
      Size(
        constraints.hasBoundedWidth
            ? constraints.maxWidth
            : computeMaxIntrinsicWidth(height),
        height,
      ),
    );
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    final leading = _leading;
    return leading == null
        ? 0
        : leading.getMinIntrinsicWidth(height) + _spacing;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    final trailing = childForSlot(PriorityRowSlot.trailing);
    return computeMinIntrinsicWidth(height) +
        _title.getMaxIntrinsicWidth(height) +
        (trailing == null
            ? 0
            : trailing.getMaxIntrinsicWidth(height) + _spacing);
  }

  @override
  double computeMinIntrinsicHeight(double width) => children
      .map((child) => child.getMinIntrinsicHeight(width))
      .fold(0.0, math.max);

  @override
  double computeMaxIntrinsicHeight(double width) => children
      .map((child) => child.getMaxIntrinsicHeight(width))
      .fold(0.0, math.max);

  @override
  void paint(PaintingContext context, Offset offset) {
    _clipLayer.layer = context.pushClipRect(
      needsCompositing,
      offset,
      Offset.zero & size,
      (context, offset) {
        for (final child in _shown) {
          context.paintChild(
            child,
            offset + (child.parentData! as BoxParentData).offset,
          );
        }
      },
      oldLayer: _clipLayer.layer,
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final child in _shown.reversed) {
      final hit = result.addWithPaintOffset(
        offset: (child.parentData! as BoxParentData).offset,
        position: position,
        hitTest: (result, transformed) =>
            child.hitTest(result, position: transformed),
      );
      if (hit) return true;
    }
    return false;
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    _shown.forEach(visitor);
  }

  @override
  void dispose() {
    _clipLayer.layer = null;
    super.dispose();
  }
}
