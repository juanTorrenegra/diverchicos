import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import 'salud_constants.dart';

/// Default paste-on-brush clip under [assets/video/].
const String kBathPasteBrushVideoAsset = 'assets/video/toothbrush1.mp4';

/// Fullscreen paste clip (logical 1920×1080); stretches with [BoxFit.fill]. Calls [onFinished] once when playback ends or on init/play error.
class BathToothbrushPasteAnimator extends StatefulWidget {
  const BathToothbrushPasteAnimator({
    super.key,
    required this.onFinished,
    this.assetPath = kBathPasteBrushVideoAsset,
  });

  final VoidCallback onFinished;

  /// Bundled asset path (e.g. [kBathPasteBrushVideoAsset]).
  final String assetPath;

  @override
  State<BathToothbrushPasteAnimator> createState() =>
      _BathToothbrushPasteAnimatorState();
}

class _BathToothbrushPasteAnimatorState extends State<BathToothbrushPasteAnimator> {
  VideoPlayerController? _controller;
  bool _finishedNotified = false;

  double get _logicalW => kSaludCowLogicalWidth;
  double get _logicalH => kSaludCowLogicalHeight;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  void _notifyFinishedOnce() {
    if (_finishedNotified || !mounted) return;
    _finishedNotified = true;
    widget.onFinished();
  }

  Future<void> _bootstrap() async {
    final c = VideoPlayerController.asset(
      widget.assetPath,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    try {
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      await c.setLooping(false);
      c.addListener(_onVideoTick);
      await c.play();
      setState(() => _controller = c);
    } catch (e, st) {
      debugPrint('BathToothbrushPasteAnimator video error: $e\n$st');
      await c.dispose();
      if (mounted) _notifyFinishedOnce();
    }
  }

  void _onVideoTick() {
    final c = _controller;
    if (c == null || !mounted) return;
    final v = c.value;
    if (v.hasError) {
      debugPrint('VideoPlayer: ${v.errorDescription}');
      c.removeListener(_onVideoTick);
      _notifyFinishedOnce();
      return;
    }
    if (!v.isInitialized || v.duration == Duration.zero) return;

    if (v.isCompleted) {
      c.removeListener(_onVideoTick);
      _notifyFinishedOnce();
      return;
    }

    const epsilon = Duration(milliseconds: 80);
    if (v.position + epsilon >= v.duration) {
      c.removeListener(_onVideoTick);
      _notifyFinishedOnce();
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onVideoTick);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      return SizedBox(
        width: _logicalW,
        height: _logicalH,
        child: const ColoredBox(color: Colors.black87),
      );
    }

    final v = c.value;
    final vw = v.size.width;
    final vh = v.size.height;
    if (vw <= 0 || vh <= 0) {
      return SizedBox(
        width: _logicalW,
        height: _logicalH,
        child: const ColoredBox(color: Colors.black87),
      );
    }

    return SizedBox(
      width: _logicalW,
      height: _logicalH,
      child: ClipRect(
        child: FittedBox(
          fit: BoxFit.fill,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: vw,
            height: vh,
            child: VideoPlayer(c),
          ),
        ),
      ),
    );
  }
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
