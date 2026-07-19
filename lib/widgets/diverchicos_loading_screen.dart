import 'dart:async';

import 'package:flutter/material.dart';

import '../utils/game_debug.dart';
import 'frog_loader.dart';

/// Reports load progress as a value from `0.0` to `1.0`.
typedef LoadProgressCallback = void Function(double progress);

/// Runs [load] behind a full-screen [FrogLoader] (frog + logo + percentage).
///
/// Once [load] completes, the loader fades out and [child] is shown.
class DiverchicosLoadingScreen extends StatefulWidget {
  const DiverchicosLoadingScreen({
    super.key,
    required this.load,
    required this.child,
    this.minDisplayTime = const Duration(milliseconds: 600),
    this.fadeOutDuration = const Duration(milliseconds: 350),
    this.useFrogVideo = false,
    this.showLogo = false,
    this.onRevealed,
    this.debugArea = 'LoadingScreen',
  });

  /// Receives [LoadProgressCallback] to update the on-screen percentage.
  final Future<void> Function(LoadProgressCallback reportProgress) load;

  final Widget child;

  /// Minimum time the loader stays visible so the animation does not flash.
  final Duration minDisplayTime;
  final Duration fadeOutDuration;

  /// When false, the loader shows a still frog image so only one video decoder
  /// is active while [load] initializes a game's intro clip.
  final bool useFrogVideo;

  /// Whether to show the Diverchicos logo under the frog.
  final bool showLogo;

  /// Called once the loader fade-out finishes and [child] is fully visible.
  final VoidCallback? onRevealed;

  final String debugArea;

  @override
  State<DiverchicosLoadingScreen> createState() =>
      _DiverchicosLoadingScreenState();
}

class _DiverchicosLoadingScreenState extends State<DiverchicosLoadingScreen>
    with SingleTickerProviderStateMixin {
  double _progress = 0;
  bool _loadFinished = false;
  bool _minTimeElapsed = false;
  bool _revealed = false;
  late final AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    GameDebug.log(widget.debugArea, 'loading screen initState');
    _fadeController = AnimationController(
      vsync: this,
      duration: widget.fadeOutDuration,
      value: 1,
    )..addStatusListener((status) {
        if (status == AnimationStatus.dismissed && mounted) {
          GameDebug.log(widget.debugArea, 'loader revealed → onRevealed');
          setState(() => _revealed = true);
          try {
            widget.onRevealed?.call();
          } catch (e, st) {
            GameDebug.log(widget.debugArea, 'onRevealed threw', e, st);
          }
        }
      });
    unawaited(_runLoad());
  }

  Future<void> _runLoad() async {
    final minTimer = Future<void>.delayed(widget.minDisplayTime);
    try {
      GameDebug.log(widget.debugArea, 'load() started');
      await widget.load(_reportProgress);
      _reportProgress(1);
      GameDebug.log(widget.debugArea, 'load() finished ok');
    } catch (e, st) {
      GameDebug.log(
        widget.debugArea,
        'load() failed — continuing reveal',
        e,
        st,
      );
      _reportProgress(1);
    }
    _loadFinished = true;
    await minTimer;
    if (!mounted) return;
    setState(() => _minTimeElapsed = true);
    _tryReveal();
  }

  void _reportProgress(double value) {
    if (!mounted) return;
    setState(() => _progress = value.clamp(0.0, 1.0));
  }

  void _tryReveal() {
    if (!_loadFinished || !_minTimeElapsed || _revealed) return;
    unawaited(_fadeController.reverse());
  }

  @override
  void dispose() {
    GameDebug.log(widget.debugArea, 'loading screen dispose');
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (!_revealed)
          FadeTransition(
            opacity: _fadeController,
            child: FrogLoader(
              progress: _progress,
              showLogo: widget.showLogo,
              showProgress: true,
              useFrogVideo: widget.useFrogVideo,
            ),
          ),
      ],
    );
  }
}
