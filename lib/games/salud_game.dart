import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../widgets/menu_back_pill.dart';

/// Bundled cow/cat intro clip for the SALUD entry point.
const String kSaludCowCatIntroAsset = 'assets/video/salud/cowCatIntro.mp4';

/// Fullscreen intro: fixed logical **1980×1080**, stretched to device; pauses on last frame; [onClose] from back pill.
class SaludCowCatIntroLayer extends StatefulWidget {
  const SaludCowCatIntroLayer({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  State<SaludCowCatIntroLayer> createState() => _SaludCowCatIntroLayerState();
}

class _SaludCowCatIntroLayerState extends State<SaludCowCatIntroLayer> {
  static const double _kLogicalW = 1980;
  static const double _kLogicalH = 1080;

  VideoPlayerController? _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    final c = VideoPlayerController.asset(
      kSaludCowCatIntroAsset,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    try {
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      await c.setLooping(false);
      c.addListener(_onTick);
      await c.play();
      setState(() {
        _controller = c;
        _ready = true;
      });
    } catch (_) {
      await c.dispose();
      if (mounted) widget.onClose();
    }
  }

  void _onTick() {
    final v = _controller;
    if (v == null || !mounted) return;
    final value = v.value;
    if (!value.isInitialized || value.hasError) return;
    if (value.isCompleted) {
      unawaited(v.pause());
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onTick);
    _controller?.dispose();
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
                  child: _ready && _controller != null
                      ? VideoPlayer(_controller!)
                      : const ColoredBox(color: Colors.black),
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
