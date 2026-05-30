import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../widgets/menu_back_pill.dart';

const String kGridPuzzleIntroAsset = 'assets/video/GridPuzzleIntro.mp4';

/// Fullscreen grid puzzle: intro video, then draggable rects on the last frame.
class GridPuzzleLayer extends StatefulWidget {
  const GridPuzzleLayer({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  State<GridPuzzleLayer> createState() => _GridPuzzleLayerState();
}

class _GridPuzzleLayerState extends State<GridPuzzleLayer> {
  static const double _kLogicalW = 1980;
  static const double _kLogicalH = 1080;

  static const Size _kRect1Size = Size(940, 740);
  static const Size _kRect2Size = Size(1400, 200);

  VideoPlayerController? _introController;
  bool _introReady = false;
  bool _introFinished = false;

  Offset _rect1Pos = const Offset(100, 120);
  Offset _rect2Pos = const Offset(80, 720);

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrapIntro());
  }

  Future<void> _bootstrapIntro() async {
    final c = VideoPlayerController.asset(
      kGridPuzzleIntroAsset,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    try {
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      await c.setLooping(false);
      c.addListener(_onIntroTick);
      await c.play();
      setState(() {
        _introController = c;
        _introReady = true;
      });
    } catch (_) {
      await c.dispose();
      if (mounted) widget.onClose();
    }
  }

  void _onIntroTick() {
    final v = _introController;
    if (v == null || !mounted) return;
    final value = v.value;
    if (!value.isInitialized || value.hasError) return;
    if (value.isCompleted && !_introFinished) {
      unawaited(v.pause());
      setState(() => _introFinished = true);
    }
  }

  @override
  void dispose() {
    _introController?.removeListener(_onIntroTick);
    _introController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: FittedBox(
                fit: BoxFit.fill,
                child: SizedBox(
                  width: _kLogicalW,
                  height: _kLogicalH,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      if (_introReady && _introController != null)
                        Positioned.fill(child: VideoPlayer(_introController!))
                      else
                        const ColoredBox(color: Colors.black),
                      if (_introFinished) ...[
                        _DraggablePuzzleRect(
                          position: _rect1Pos,
                          size: _kRect1Size,
                          color: const Color(0x80FFFFFF),
                          onPositionChanged: (pos) => _rect1Pos = pos,
                          onReleased: (pos) {
                            debugPrint(
                              'Grid puzzle rect 1: x=${pos.dx}, y=${pos.dy}',
                            );
                          },
                        ),
                        _DraggablePuzzleRect(
                          position: _rect2Pos,
                          size: _kRect2Size,
                          color: const Color(0x800099FF),
                          onPositionChanged: (pos) => _rect2Pos = pos,
                          onReleased: (pos) {
                            debugPrint(
                              'Grid puzzle rect 2: x=${pos.dx}, y=${pos.dy}',
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 20,
              right: 16,
              child: MenuBackPill(onPressed: widget.onClose),
            ),
          ],
        ),
      ),
    );
  }
}

class _DraggablePuzzleRect extends StatefulWidget {
  const _DraggablePuzzleRect({
    required this.position,
    required this.size,
    required this.color,
    required this.onPositionChanged,
    required this.onReleased,
  });

  final Offset position;
  final Size size;
  final Color color;
  final ValueChanged<Offset> onPositionChanged;
  final ValueChanged<Offset> onReleased;

  @override
  State<_DraggablePuzzleRect> createState() => _DraggablePuzzleRectState();
}

class _DraggablePuzzleRectState extends State<_DraggablePuzzleRect> {
  late Offset _position;

  @override
  void initState() {
    super.initState();
    _position = widget.position;
  }

  @override
  void didUpdateWidget(covariant _DraggablePuzzleRect oldWidget) {
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
            widget.onPositionChanged(_position);
          });
        },
        onPanEnd: (_) => widget.onReleased(_position),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: widget.color,
            border: Border.all(color: Colors.white70, width: 2),
          ),
        ),
      ),
    );
  }
}
