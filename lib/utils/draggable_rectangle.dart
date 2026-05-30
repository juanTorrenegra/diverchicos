import 'package:flutter/material.dart';

/// Dev helper: semi-transparent rectangle that prints logical x/y on pan release.
class DraggableRect extends StatefulWidget {
  const DraggableRect({
    super.key,
    required this.position,
    required this.size,
    required this.color,
    this.label,
    this.onPositionChanged,
    this.onReleased,
  });

  final Offset position;
  final Size size;
  final Color color;
  final String? label;
  final ValueChanged<Offset>? onPositionChanged;
  final ValueChanged<Offset>? onReleased;

  @override
  State<DraggableRect> createState() => _DraggableRectState();
}

class _DraggableRectState extends State<DraggableRect> {
  late Offset _position;

  @override
  void initState() {
    super.initState();
    _position = widget.position;
  }

  @override
  void didUpdateWidget(covariant DraggableRect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.position != widget.position) {
      _position = widget.position;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _position.dx,
      top: _position.dy,
      width: widget.size.width,
      height: widget.size.height,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _position += details.delta;
            widget.onPositionChanged?.call(_position);
          });
        },
        onPanEnd: (_) {
          debugPrint(
            'DraggableRect${widget.label != null ? ' (${widget.label})' : ''}: '
            'x=${_position.dx}, y=${_position.dy}',
          );
          widget.onReleased?.call(_position);
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: widget.color,
            border: Border.all(color: Colors.white70, width: 2),
          ),
          child: widget.label != null
              ? Center(
                  child: Text(
                    widget.label!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}
