import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../widgets/diverchicos_loading_screen.dart';
import '../widgets/menu_back_pill.dart';

const String kCreditosVideoAsset = 'assets/video/creditos2.mp4';

/// Fullscreen looping credits clip opened from the main-menu CREDITOS link.
class CreditosLayer extends StatefulWidget {
  const CreditosLayer({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  State<CreditosLayer> createState() => _CreditosLayerState();
}

class _CreditosLayerState extends State<CreditosLayer> {
  static const double _kLogicalW = 1980;
  static const double _kLogicalH = 1080;

  VideoPlayerController? _controller;
  bool _ready = false;
  bool _exitingToMenu = false;

  Future<void> _bootstrapVideo(LoadProgressCallback reportProgress) async {
    reportProgress(0.1);
    final c = VideoPlayerController.asset(
      kCreditosVideoAsset,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    reportProgress(0.25);
    try {
      await c.initialize().timeout(const Duration(seconds: 20));
      reportProgress(0.85);
      if (!mounted) {
        await c.dispose();
        return;
      }
      await c.setLooping(true);
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() {
        _controller = c;
        _ready = true;
      });
      reportProgress(1);
    } catch (_) {
      await c.dispose();
      if (mounted) _exitToMenu();
    }
  }

  void _startPlayback() {
    final c = _controller;
    if (c == null) return;
    unawaited(c.play());
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
    return DiverchicosLoadingScreen(
      load: _bootstrapVideo,
      useFrogVideo: false,
      showLogo: false,
      onRevealed: _startPlayback,
      child: _buildViewport(),
    );
  }

  Widget _buildViewport() {
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
