import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../widgets/menu_back_pill.dart';

const String kChickenIntroAsset = 'assets/video/chicken/chickenIntro.mp4';

/// Fullscreen chicken-path intro opened from the main-menu CHICKEN PATH card.
class ChickenPathLayer extends StatefulWidget {
  const ChickenPathLayer({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  State<ChickenPathLayer> createState() => _ChickenPathLayerState();
}

class _ChickenPathLayerState extends State<ChickenPathLayer> {
  static const double _kLogicalW = 1980;
  static const double _kLogicalH = 1080;

  VideoPlayerController? _controller;
  bool _ready = false;
  bool _exitingToMenu = false;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrapIntro());
  }

  Future<void> _bootstrapIntro() async {
    final c = VideoPlayerController.asset(
      kChickenIntroAsset,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    try {
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      await c.setLooping(false);
      await c.play();
      setState(() {
        _controller = c;
        _ready = true;
      });
    } catch (_) {
      await c.dispose();
      if (mounted) _exitToMenu();
    }
  }

  void _exitToMenu() {
    if (_exitingToMenu) return;
    _exitingToMenu = true;
    widget.onClose();
  }

  @override
  void dispose() {
    final c = _controller;
    _controller = null;
    c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: FittedBox(
          fit: BoxFit.fill,
          child: SizedBox(
            width: _kLogicalW,
            height: _kLogicalH,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                if (_ready && _controller != null)
                  Positioned.fill(child: VideoPlayer(_controller!))
                else
                  const ColoredBox(color: Colors.black),
                GameLogicalBackPill(onPressed: _exitToMenu),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
