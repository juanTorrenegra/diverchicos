import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../widgets/menu_back_pill.dart';

/// Bundled cow/cat intro clip for the SALUD entry point.
const String kSaludCowCatIntroAsset = 'assets/video/salud/cowCatIntro.mp4';

const String kSaludCowPickAsset = 'assets/video/salud/cowPick.mp4';
const String kSaludCatPickAsset = 'assets/video/salud/catPick.mp4';
const String kSaludCowCatBlinkAsset = 'assets/video/salud/cowCatBlink.mp4';
const String kSaludCowEntersBathAsset = 'assets/video/salud/cowEntersBath.mp4';

const String kSaludBathColgatePng = 'assets/images/bathGame/colgate.png';
const String kSaludBathCepilloPng = 'assets/images/bathGame/cepillo.png';

/// Fullscreen intro: fixed logical **1980×1080**, stretched to device; pauses on last frame; [onClose] from back pill.
class SaludCowCatIntroLayer extends StatefulWidget {
  const SaludCowCatIntroLayer({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  State<SaludCowCatIntroLayer> createState() => _SaludCowCatIntroLayerState();
}

class _SaludCowCatIntroLayerState extends State<SaludCowCatIntroLayer>
    with TickerProviderStateMixin {
  static const double _kLogicalW = 1980;
  static const double _kLogicalH = 1080;

  /// Cow = larger tap target.
  static const Size _kRectCowSize = Size(300, 700);
  static const Offset _kRectCowPos = Offset(373.4, 185.7);

  /// Cat = smaller tap target.
  static const Size _kRectCatSize = Size(300, 300);
  static const Offset _kRectCatPos = Offset(720.8, 586.2);

  /// Starting positions for bath props (1980×1080 logical); drag to tune.
  static const Offset _kBathColgateStart = Offset(600, 450);
  static const Offset _kBathCepilloStart = Offset(1100, 450);

  VideoPlayerController? _introController;
  bool _introReady = false;
  bool _showTapTargets = false;

  VideoPlayerController? _pickController;
  bool _pickReady = false;
  bool _pickBusy = false;
  bool _lastPickWasCow = false;

  VideoPlayerController? _blinkController;
  bool _blinkReady = false;

  Timer? _idleBlinkTimer;

  /// After cow pick: bath clip + white cross-fades.
  bool _cowBathFlow = false;
  VideoPlayerController? _bathController;
  bool _bathReady = false;
  bool _bathPlayFinished = false;
  AnimationController? _whiteFade;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrapIntro());
  }

  Future<void> _bootstrapIntro() async {
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
    if (value.isCompleted) {
      unawaited(v.pause());
      if (!_showTapTargets) {
        setState(() => _showTapTargets = true);
        _scheduleIdleBlink();
      }
    }
  }

  void _scheduleIdleBlink() {
    _idleBlinkTimer?.cancel();
    if (!_showTapTargets || !_introReady) return;
    if (_pickReady && _pickController != null) return;
    if (_blinkReady && _blinkController != null) return;
    if (_cowBathFlow) return;

    _idleBlinkTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      unawaited(_playBlink());
    });
  }

  void _cancelIdleBlinkTimer() {
    _idleBlinkTimer?.cancel();
    _idleBlinkTimer = null;
  }

  void _onBlinkTick() {
    final c = _blinkController;
    if (c == null || !mounted) return;
    final value = c.value;
    if (!value.isInitialized || value.hasError) return;
    if (value.isCompleted) {
      c.removeListener(_onBlinkTick);
      unawaited(c.dispose());
      if (!mounted) return;
      setState(() {
        _blinkController = null;
        _blinkReady = false;
      });
      _scheduleIdleBlink();
    }
  }

  Future<void> _disposeBlink() async {
    final c = _blinkController;
    _blinkController = null;
    _blinkReady = false;
    if (c != null) {
      c.removeListener(_onBlinkTick);
      await c.dispose();
    }
    if (mounted) setState(() {});
  }

  Future<void> _playBlink() async {
    if (!_showTapTargets || !_introReady) return;
    if (_pickReady && _pickController != null) return;
    if (_blinkController != null) return;
    if (_cowBathFlow) return;

    _cancelIdleBlinkTimer();

    final c = VideoPlayerController.asset(
      kSaludCowCatBlinkAsset,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    try {
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        _scheduleIdleBlink();
        return;
      }
      await c.setLooping(false);
      c.addListener(_onBlinkTick);
      await c.play();
      setState(() {
        _blinkController = c;
        _blinkReady = true;
      });
    } catch (_) {
      await c.dispose();
      if (mounted) _scheduleIdleBlink();
    }
  }

  void _onPickTick() {
    final c = _pickController;
    if (c == null || !mounted) return;
    final value = c.value;
    if (!value.isInitialized || value.hasError) return;
    if (value.isCompleted) {
      c.removeListener(_onPickTick);
      if (_lastPickWasCow) {
        unawaited(_cowPickToBathSequence(c));
      } else {
        unawaited(c.dispose());
        if (!mounted) return;
        setState(() {
          _pickController = null;
          _pickReady = false;
          _pickBusy = false;
        });
        _scheduleIdleBlink();
      }
    }
  }

  void _onBathTick() {
    final b = _bathController;
    if (b == null || !mounted) return;
    final value = b.value;
    if (!value.isInitialized || value.hasError) return;
    if (value.isCompleted) {
      b.removeListener(_onBathTick);
      unawaited(b.pause());
      if (mounted) setState(() => _bathPlayFinished = true);
    }
  }

  Future<void> _disposePickOnly() async {
    final c = _pickController;
    _pickController = null;
    _pickReady = false;
    if (c != null) {
      c.removeListener(_onPickTick);
      await c.dispose();
    }
  }

  Future<void> _disposeIntro() async {
    final c = _introController;
    _introController = null;
    _introReady = false;
    _showTapTargets = false;
    if (c != null) {
      c.removeListener(_onIntroTick);
      await c.dispose();
    }
  }

  Future<void> _disposeBath() async {
    final b = _bathController;
    _bathController = null;
    _bathReady = false;
    _bathPlayFinished = false;
    if (b != null) {
      b.removeListener(_onBathTick);
      await b.dispose();
    }
  }

  Future<void> _cowPickToBathSequence(VideoPlayerController pick) async {
    await pick.pause();

    _whiteFade?.dispose();
    _whiteFade = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    if (!mounted) {
      await pick.dispose();
      _whiteFade?.dispose();
      _whiteFade = null;
      return;
    }

    // 1s: last cowPick frame + fade to white (together).
    setState(() {});
    await _whiteFade!.forward();
    if (!mounted) {
      await pick.dispose();
      _whiteFade?.dispose();
      _whiteFade = null;
      return;
    }

    // Fully white: dispose intro, blink, pick.
    _cancelIdleBlinkTimer();
    await _disposeBlink();
    await pick.dispose();
    if (!mounted) return;
    setState(() {
      _pickController = null;
      _pickReady = false;
      _pickBusy = false;
    });
    await _disposeIntro();

    if (!mounted) {
      _whiteFade?.dispose();
      _whiteFade = null;
      return;
    }

    setState(() => _cowBathFlow = true);

    final bath = VideoPlayerController.asset(
      kSaludCowEntersBathAsset,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    try {
      await bath.initialize();
      if (!mounted) {
        await bath.dispose();
        _whiteFade?.dispose();
        _whiteFade = null;
        return;
      }
      await bath.setLooping(false);
      await bath.seekTo(Duration.zero);
      await bath.pause();
      if (!mounted) {
        await bath.dispose();
        _whiteFade?.dispose();
        _whiteFade = null;
        return;
      }

      setState(() {
        _bathController = bath;
        _bathReady = true;
        _bathPlayFinished = false;
      });

      // 1s: first bath frame under white, white fades out.
      await _whiteFade!.reverse();
      if (!mounted) return;
      _whiteFade?.dispose();
      _whiteFade = null;

      bath.addListener(_onBathTick);
      await bath.play();
      if (mounted) setState(() {});
    } catch (_) {
      await bath.dispose();
      if (mounted) {
        setState(() {
          _cowBathFlow = false;
          _bathReady = false;
          _bathController = null;
        });
        _whiteFade?.dispose();
        _whiteFade = null;
        widget.onClose();
      }
    }
  }

  Future<void> _disposePick() async {
    await _disposePickOnly();
  }

  Future<void> _playPick(String assetPath) async {
    if (_pickBusy) return;
    _pickBusy = true;
    _lastPickWasCow = assetPath == kSaludCowPickAsset;
    _cancelIdleBlinkTimer();
    await _disposeBlink();
    await _disposePick();
    if (!mounted) return;

    final c = VideoPlayerController.asset(
      assetPath,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    try {
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        _pickBusy = false;
        _scheduleIdleBlink();
        return;
      }
      await c.setLooping(false);
      c.addListener(_onPickTick);
      await c.play();
      setState(() {
        _pickController = c;
        _pickReady = true;
        _pickBusy = false;
      });
    } catch (_) {
      await c.dispose();
      if (mounted) {
        setState(() => _pickBusy = false);
        _scheduleIdleBlink();
      }
    }
  }

  Future<void> _exitBathAndClose() async {
    _cancelIdleBlinkTimer();
    await _disposeBath();
    _whiteFade?.dispose();
    _whiteFade = null;
    if (mounted) {
      setState(() => _cowBathFlow = false);
    }
    widget.onClose();
  }

  Widget _tapTarget({
    required Offset position,
    required Size size,
    required VoidCallback onTap,
  }) {
    return Positioned(
      left: position.dx,
      top: position.dy,
      width: size.width,
      height: size.height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(width: size.width, height: size.height),
      ),
    );
  }

  bool get _hideIntroStack =>
      (_pickReady && _pickController != null) || _cowBathFlow;

  Widget _whiteFadeOverlay() {
    final ctrl = _whiteFade;
    if (ctrl == null) return const SizedBox.shrink();
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: ctrl,
          builder: (context, child) {
            final t = ctrl.value.clamp(0.0, 1.0);
            return ColoredBox(
              color: Color.fromRGBO(255, 255, 255, t),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cancelIdleBlinkTimer();
    _introController?.removeListener(_onIntroTick);
    _introController?.dispose();
    final pick = _pickController;
    if (pick != null) {
      pick.removeListener(_onPickTick);
      pick.dispose();
    }
    final blink = _blinkController;
    if (blink != null) {
      blink.removeListener(_onBlinkTick);
      blink.dispose();
    }
    final bath = _bathController;
    if (bath != null) {
      bath.removeListener(_onBathTick);
      bath.dispose();
    }
    _whiteFade?.dispose();
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
            if (!_hideIntroStack)
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
                          Positioned.fill(
                            child: VideoPlayer(_introController!),
                          )
                        else
                          const ColoredBox(color: Colors.black),
                        if (_blinkReady && _blinkController != null)
                          Positioned.fill(
                            child: VideoPlayer(_blinkController!),
                          ),
                        if (_showTapTargets &&
                            !(_pickReady && _pickController != null) &&
                            !_cowBathFlow) ...[
                          _tapTarget(
                            position: _kRectCowPos,
                            size: _kRectCowSize,
                            onTap: () {
                              _cancelIdleBlinkTimer();
                              unawaited(_disposeBlink());
                              unawaited(_playPick(kSaludCowPickAsset));
                            },
                          ),
                          _tapTarget(
                            position: _kRectCatPos,
                            size: _kRectCatSize,
                            onTap: () {
                              _cancelIdleBlinkTimer();
                              unawaited(_disposeBlink());
                              unawaited(_playPick(kSaludCatPickAsset));
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            if (_pickReady && _pickController != null)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black,
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.fill,
                      child: SizedBox(
                        width: _kLogicalW,
                        height: _kLogicalH,
                        child: VideoPlayer(_pickController!),
                      ),
                    ),
                  ),
                ),
              ),
            if (_cowBathFlow && _bathReady && _bathController != null)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black,
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.fill,
                      child: SizedBox(
                        width: _kLogicalW,
                        height: _kLogicalH,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned.fill(
                              child: VideoPlayer(_bathController!),
                            ),
                            if (_bathPlayFinished) ...[
                              _BathDraggablePng(
                                asset: kSaludBathColgatePng,
                                label: 'colgate',
                                initialOffset: _kBathColgateStart,
                              ),
                              _BathDraggablePng(
                                asset: kSaludBathCepilloPng,
                                label: 'cepillo',
                                initialOffset: _kBathCepilloStart,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            _whiteFadeOverlay(),
            Positioned(
              top: 20,
              right: 16,
              child: MenuBackPill(
                onPressed: () {
                  if (_cowBathFlow) {
                    unawaited(_exitBathAndClose());
                  } else {
                    widget.onClose();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Draggable prop on the 1980×1080 bath canvas; [Image] uses intrinsic pixel size (no scale).
class _BathDraggablePng extends StatefulWidget {
  const _BathDraggablePng({
    required this.asset,
    required this.label,
    required this.initialOffset,
  });

  final String asset;
  final String label;
  final Offset initialOffset;

  @override
  State<_BathDraggablePng> createState() => _BathDraggablePngState();
}

class _BathDraggablePngState extends State<_BathDraggablePng> {
  late Offset _pos = widget.initialOffset;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _pos.dx,
      top: _pos.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() => _pos += details.delta);
          debugPrint(
            '${widget.label}: x=${_pos.dx.toStringAsFixed(1)}, y=${_pos.dy.toStringAsFixed(1)}',
          );
        },
        child: Image.asset(widget.asset),
      ),
    );
  }
}
