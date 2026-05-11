import 'dart:async';
import 'dart:ui' as ui;

import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame_texturepacker/flame_texturepacker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../actors/salud_animal_common.dart';
import 'salud_constants.dart';

const int kToothbrushPasteFrames = 120;

/// Fullscreen (logical 1920×1080) atlas animation; calls [onFinished] when done or on load failure.
class BathToothbrushPasteAnimator extends StatefulWidget {
  const BathToothbrushPasteAnimator({
    super.key,
    required this.onFinished,
    this.frameCount = kToothbrushPasteFrames,
    this.fps = 24,
  });

  final VoidCallback onFinished;
  final int frameCount;
  final double fps;

  @override
  State<BathToothbrushPasteAnimator> createState() =>
      _BathToothbrushPasteAnimatorState();
}

class _BathToothbrushPasteAnimatorState extends State<BathToothbrushPasteAnimator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  final Images _images = Images();

  List<Sprite>? _frames;
  Object? _loadError;

  bool _finishedNotified = false;

  double get _logicalW => kSaludCowLogicalWidth;
  double get _logicalH => kSaludCowLogicalHeight;

  @override
  void initState() {
    super.initState();
    final steps = widget.frameCount.clamp(1, 9999);
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: ((steps / widget.fps) * 1000).round().clamp(1, 600000),
      ),
    )..addListener(() => setState(() {}))
     ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _notifyFinishedOnce();
        }
      });

    unawaited(_load());
  }

  void _notifyFinishedOnce() {
    if (_finishedNotified || !mounted) return;
    _finishedNotified = true;
    _images.clearCache();
    widget.onFinished();
  }

  Future<void> _load() async {
    try {
      final atlas = await TexturePackerAtlas.load(
        'bathGame/toothbrushAnimation/toothbrushAnimation.atlas',
        images: _images,
        assetsPrefix: 'images',
      );
      final sprites = saludIndexedFramesFromAtlas(
        atlas,
        preferredName: '0',
        atlasLabelForAssert: 'toothbrushAnimation',
      );
      if (!mounted) return;
      setState(() {
        _frames = sprites;
        _loadError = sprites.isEmpty ? 'No frames in atlas' : null;
      });
      if (sprites.isNotEmpty) {
        unawaited(_ctrl.forward(from: 0));
      } else {
        _notifyFinishedOnce();
      }
    } catch (e, st) {
      debugPrint('BathToothbrushPasteAnimator load error: $e\n$st');
      if (!mounted) return;
      setState(() => _loadError = e);
      _notifyFinishedOnce();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _images.clearCache();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_frames == null && _loadError == null) {
      return SizedBox(
        width: _logicalW,
        height: _logicalH,
        child: const ColoredBox(color: Colors.black54),
      );
    }

    if (_loadError != null || _frames!.isEmpty) {
      return SizedBox(
        width: _logicalW,
        height: _logicalH,
        child: const ColoredBox(color: Colors.black54),
      );
    }

    final frames = _frames!;
    final n = frames.length;
    final idx = ((_ctrl.value * n).floor()).clamp(0, n - 1);

    return SizedBox(
      width: _logicalW,
      height: _logicalH,
      child: CustomPaint(
        painter: _FramePainter(frames[idx]),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _FramePainter extends CustomPainter {
  _FramePainter(this.sprite);

  final Sprite sprite;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // BoxFit.fill: stretch every frame to the exact logical viewport (1920×1080)
    // so nothing is letterboxed or appears to slide off-screen.
    final bounds = Offset.zero & size;
    canvas.save();
    canvas.clipRect(bounds);

    sprite.render(
      canvas,
      position: Vector2.zero(),
      size: Vector2(size.width, size.height),
      anchor: Anchor.topLeft,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FramePainter oldDelegate) =>
      oldDelegate.sprite != sprite;
}

/// PNG intrinsic pixel size from asset bundle (for overlap tests).
Future<ui.Size?> bathLoadAssetRasterSize(String assetPath) async {
  try {
    final bd = await rootBundle.load(assetPath);
    final codec = await ui.instantiateImageCodec(bd.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    final img = frame.image;
    final s = ui.Size(img.width.toDouble(), img.height.toDouble());
    img.dispose();
    return s;
  } catch (e) {
    debugPrint('bathLoadAssetRasterSize($assetPath): $e');
    return null;
  }
}
