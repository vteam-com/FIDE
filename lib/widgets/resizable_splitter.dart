import 'package:flutter/material.dart';

class ResizableSplitter extends StatefulWidget {
  const ResizableSplitter({
    super.key,
    required this.onResize,
    this.isHorizontal = false,
  });

  final bool isHorizontal;

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
        child: Container(
          width: widget.isHorizontal ? double.infinity : 8,
          height: widget.isHorizontal ? 8 : double.infinity,
          color: _isHovering || _isDragging
              ? Theme.of(context).colorScheme.primary.withAlpha(50)
              : Colors.transparent,
          child: Center(
            child: Container(
              width: widget.isHorizontal ? 40 : 4,
              height: widget.isHorizontal ? 4 : 40,
              decoration: BoxDecoration(
                color: _isHovering || _isDragging
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
