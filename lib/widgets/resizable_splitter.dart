import 'package:fide/constants/constants.dart';
import 'package:flutter/material.dart';

/// A draggable gap between two panel islands that reports resize deltas.
class ResizableSplitter extends StatefulWidget {
  /// Creates a splitter that reports drags through [onResize].
  const ResizableSplitter({
    super.key,
    required this.onResize,
    this.isHorizontal = false,
  });

  /// Whether the splitter separates stacked panels and drags vertically.
  final bool isHorizontal;

  /// Called with the pointer delta, in logical pixels, on each drag update.
  final Function(double) onResize;

  @override
  State<ResizableSplitter> createState() => _ResizableSplitterState();
}

class _ResizableSplitterState extends State<ResizableSplitter> {
  bool _isDragging = false;
  bool _isHovering = false;
  double _startPosition = 0.0;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: _isHovering || _isDragging
          ? (widget.isHorizontal
                ? SystemMouseCursors.resizeUpDown
                : SystemMouseCursors.resizeLeftRight)
          : MouseCursor.defer,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        // The gap is transparent, so claim the whole strip for hit testing
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: widget.isHorizontal
            ? null
            : (details) {
                setState(() {
                  _isDragging = true;
                  _startPosition = details.globalPosition.dx;
                });
              },
        onHorizontalDragUpdate: widget.isHorizontal
            ? null
            : (details) {
                if (_isDragging) {
                  final delta = details.globalPosition.dx - _startPosition;
                  widget.onResize(delta);
                  _startPosition = details.globalPosition.dx;
                }
              },
        onHorizontalDragEnd: widget.isHorizontal
            ? null
            : (_) {
                setState(() => _isDragging = false);
              },
        onVerticalDragStart: widget.isHorizontal
            ? (details) {
                setState(() {
                  _isDragging = true;
                  _startPosition = details.globalPosition.dy;
                });
              }
            : null,
        onVerticalDragUpdate: widget.isHorizontal
            ? (details) {
                if (_isDragging) {
                  final delta = details.globalPosition.dy - _startPosition;
                  widget.onResize(delta);
                  _startPosition = details.globalPosition.dy;
                }
              }
            : null,
        onVerticalDragEnd: widget.isHorizontal
            ? (_) {
                setState(() => _isDragging = false);
              }
            : null,
        // The splitter is the gap between two panel islands: it stays
        // transparent so the workspace gradient shows through, and only a
        // pill grip fades in while the pointer is over it
        child: SizedBox(
          width: widget.isHorizontal
              ? double.infinity
              : AppSize.splitterThickness,
          height: widget.isHorizontal
              ? AppSize.splitterThickness
              : double.infinity,
          child: Center(
            child: AnimatedContainer(
              duration: AppDuration.splitterHover,
              width: widget.isHorizontal
                  ? AppSize.splitterGripLength
                  : AppSize.splitterGripThickness,
              height: widget.isHorizontal
                  ? AppSize.splitterGripThickness
                  : AppSize.splitterGripLength,
              decoration: BoxDecoration(
                color: _gripColor(Theme.of(context).colorScheme),
                borderRadius: BorderRadius.circular(
                  AppSize.splitterGripThickness,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The grip tint: hidden at rest, soft on hover, solid while dragging.
  Color _gripColor(ColorScheme colorScheme) {
    if (_isDragging) return colorScheme.primary;
    if (_isHovering) {
      return colorScheme.primary.withValues(alpha: AppOpacity.muted);
    }
    return Colors.transparent;
  }
}
