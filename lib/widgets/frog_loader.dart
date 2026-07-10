import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

const String kFrogIntroVideoAsset = 'assets/video/frogIntro.mp4';
const String kDiverchicosLogoAsset = 'assets/images/diverchicos.png';
const String kFrogStillAsset = 'assets/images/frog.png';

/// Shared Diverchicos blue used by the frog splash and loading screens.
const Color kDiverchicosLoaderBlue = Color.fromRGBO(0, 158, 233, 1);

/// Animated frog jump + logo (+ optional load percentage).
///
/// Plays [kFrogIntroVideoAsset] in the center with the Diverchicos logo below.
/// Use [jumpCount] for a fixed number of plays (app intro) or leave it `null`
/// to loop jumps until the widget is removed (in-game loading).
class FrogLoader extends StatefulWidget {
  const FrogLoader({
    super.key,
    this.progress,
    this.showLogo = true,
    this.showProgress = true,
    this.jumpCount,
    this.pauseBetweenJumps = const Duration(seconds: 1),
    this.onFirstJump,
    this.onAllJumpsComplete,
    this.backgroundColor = kDiverchicosLoaderBlue,
    this.frogWidthFraction = 0.2,
    this.logoWidthFraction = 0.55,
    this.frogBottomFraction = 0.55,
    this.useFrogVideo = true,
  });

  /// Load progress from `0.0` to `1.0`. When null, the percentage is hidden.
  final double? progress;

  final bool showLogo;
  final bool showProgress;

  /// How many frog jumps to play. `null` loops until disposed.
  final int? jumpCount;

  final Duration pauseBetweenJumps;
  final VoidCallback? onFirstJump;
  final VoidCallback? onAllJumpsComplete;
  final Color backgroundColor;
  final double frogWidthFraction;
  final double logoWidthFraction;
  final double frogBottomFraction;
  /// When false, shows [kFrogStillAsset] instead of decoding a second video.
  /// Use this on game load screens that also initialize an intro video (Chrome
  /// struggles with two simultaneous HTML video decoders).
  final bool useFrogVideo;

  @override
  State<FrogLoader> createState() => _FrogLoaderState();
}

class _FrogLoaderState extends State<FrogLoader> {
  VideoPlayerController? _controller;
  bool _videoReady = false;
  bool _jumpInProgress = false;
  bool _firstJumpFired = false;
  bool _allJumpsFinished = false;
  int _jumpsDone = 0;

  /// Guarantees a jump "completes" even if the platform video decoder stalls or
  /// [VideoPlayerValue.isCompleted] never fires, so the intro can never block
  /// the app from reaching the main menu.
  Timer? _jumpWatchdog;

  @override
  void initState() {
    super.initState();
    if (widget.useFrogVideo) {
      unawaited(_bootstrapVideo());
    }
  }

  Future<void> _bootstrapVideo() async {
    final controller = VideoPlayerController.asset(
      kFrogIntroVideoAsset,
      // Mix with others so starting the intro BGM does not steal audio focus
      // and pause this (muted) clip — on Android that froze the frog mid-jump.
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    try {
      await controller.initialize().timeout(const Duration(seconds: 10));
      if (!mounted) {
        await controller.dispose();
        return;
      }
      await controller.setLooping(false);
      await controller.setVolume(0);
      controller.addListener(_onVideoTick);
      setState(() {
        _controller = controller;
        _videoReady = true;
      });
      _startJump();
    } catch (_) {
      await controller.dispose();
      // If the clip can't load/init, don't strand the app on the blue splash.
      _forceFinishAllJumps();
    }
  }

  void _startJump() {
    final controller = _controller;
    if (controller == null || _allJumpsFinished) return;

    if (!_firstJumpFired) {
      _firstJumpFired = true;
      widget.onFirstJump?.call();
    }

    _jumpInProgress = true;

    final duration = controller.value.duration;
    final watchdogDelay =
        (duration > Duration.zero ? duration : const Duration(seconds: 2)) +
            const Duration(milliseconds: 700);
    _jumpWatchdog?.cancel();
    _jumpWatchdog = Timer(watchdogDelay, () {
      if (!mounted || _allJumpsFinished || !_jumpInProgress) return;
      _jumpInProgress = false;
      _onJumpComplete();
    });

    unawaited(() async {
      await controller.seekTo(Duration.zero);
      if (!mounted || _allJumpsFinished) return;
      await controller.play();
    }());
  }

  void _forceFinishAllJumps() {
    if (_allJumpsFinished) return;
    if (!_firstJumpFired) {
      _firstJumpFired = true;
      widget.onFirstJump?.call();
    }
    _jumpInProgress = false;
    _allJumpsFinished = true;
    _jumpWatchdog?.cancel();
    widget.onAllJumpsComplete?.call();
  }

  void _onVideoTick() {
    final controller = _controller;
    if (controller == null || !_jumpInProgress || _allJumpsFinished) return;
    final value = controller.value;
    if (!value.isInitialized || value.hasError) return;
    if (value.isCompleted) {
      _jumpInProgress = false;
      _jumpWatchdog?.cancel();
      _onJumpComplete();
    }
  }

  void _onJumpComplete() {
    _jumpsDone++;
    final target = widget.jumpCount;
    if (target != null && _jumpsDone >= target) {
      _allJumpsFinished = true;
      widget.onAllJumpsComplete?.call();
      return;
    }

    unawaited(() async {
      await Future<void>.delayed(widget.pauseBetweenJumps);
      if (!mounted || _allJumpsFinished) return;
      _startJump();
    }());
  }

  @override
  void dispose() {
    _jumpWatchdog?.cancel();
    _jumpWatchdog = null;
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      controller.removeListener(_onVideoTick);
      unawaited(controller.dispose());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: widget.backgroundColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          if (w <= 0 || h <= 0) return const SizedBox.shrink();

          final controller = _controller;
          final videoSize = controller?.value.size ?? const Size(768, 960);
          final ratio = videoSize.height <= 0 || videoSize.width <= 0
              ? 960 / 768
              : videoSize.height / videoSize.width;

          final frogW = w * widget.frogWidthFraction;
          final frogH = frogW * ratio;
          final frogBottomY = h * widget.frogBottomFraction;
          final logoW = w * widget.logoWidthFraction;
          final percent = widget.progress?.clamp(0.0, 1.0);

          return Stack(
            children: [
              if (widget.useFrogVideo && _videoReady && controller != null)
                Positioned(
                  left: (w - frogW) / 2,
                  top: frogBottomY - frogH,
                  width: frogW,
                  height: frogH,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: videoSize.width,
                      height: videoSize.height,
                      child: VideoPlayer(controller),
                    ),
                  ),
                )
              else if (!widget.useFrogVideo)
                Positioned(
                  left: (w - frogW) / 2,
                  top: frogBottomY - frogH,
                  width: frogW,
                  height: frogH,
                  child: Image.asset(
                    kFrogStillAsset,
                    fit: BoxFit.contain,
                  ),
                ),
              if (widget.showLogo)
                Positioned(
                  left: (w - logoW) / 2,
                  top: frogBottomY + 10,
                  width: logoW,
                  child: Image.asset(
                    kDiverchicosLogoAsset,
                    fit: BoxFit.contain,
                  ),
                ),
              if (widget.showProgress && percent != null)
                Positioned(
                  left: 0,
                  right: 0,
                  top: frogBottomY + h * 0.14,
                  child: Text(
                    '${(percent * 100).round()}%',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: (w * 0.045).clamp(18, 42),
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      shadows: const [
                        Shadow(
                          color: Color(0x66000000),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
