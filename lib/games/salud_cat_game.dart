import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../widgets/menu_back_pill.dart';
import 'salud_cow_game.dart' show kSaludBathCepilloPng, kSaludBathColgatePng;

const String kSaludCatEntersBathAsset = 'assets/video/salud/catEntersBath.mp4';

/// Cat branch after [catPick.mp4]: white cross-fade, bath clip, cepillo + colgate (cow layout).
class SaludCatGameLayer extends StatefulWidget {
  const SaludCatGameLayer({
    super.key,
    required this.pickController,
    required this.onTeardownIntro,
    required this.onClose,
  });

  final VideoPlayerController pickController;
  final Future<void> Function() onTeardownIntro;
  final VoidCallback onClose;

  @override
  State<SaludCatGameLayer> createState() => _SaludCatGameLayerState();
}

class _SaludCatGameLayerState extends State<SaludCatGameLayer>
    with TickerProviderStateMixin {
  static const double _kLogicalW = 1980;
  static const double _kLogicalH = 1080;

  static const Offset _kBathColgatePos = Offset(1319.8, 917.7);
  static const Offset _kBathCepilloPos = Offset(210.2, 911.0);

  static const Duration _kBathFirstFrameHold = Duration(seconds: 2);

  VideoPlayerController? _pickHeld;

  VideoPlayerController? _bathController;
  bool _bathReady = false;
  bool _bathAnimFinished = false;
  AnimationController? _whiteFade;

  Offset _colgatePos = _kBathColgatePos;
  bool _colgateDragging = false;

  Timer? _idleColgateTimer;
  late final AnimationController _idleColgatePulse;
  late final Animation<double> _idleColgateScale;

  late final AnimationController _colgateSnapController;
  Animation<Offset>? _snapColgateAnim;
  bool _snapColgateActive = false;

  late final AnimationController _cepilloDragPulse;
  late final Animation<double> _cepilloDragScaleAnim;

  @override
  void initState() {
    super.initState();
    _idleColgatePulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _idleColgateScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.3), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: 1.3, end: 1.0), weight: 50),
    ]).animate(
      CurvedAnimation(parent: _idleColgatePulse, curve: Curves.easeInOut),
    );
    _colgateSnapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _cepilloDragPulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _cepilloDragScaleAnim = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _cepilloDragPulse, curve: Curves.easeInOut),
    );
    _pickHeld = widget.pickController;
    unawaited(_runCatPickToBathSequence());
  }

  void _onBathTick() {
    final b = _bathController;
    if (b == null || !mounted) return;
    final value = b.value;
    if (!value.isInitialized || value.hasError) return;
    if (value.isCompleted) {
      b.removeListener(_onBathTick);
      unawaited(b.pause());
      if (mounted) {
        setState(() => _bathAnimFinished = true);
        _scheduleColgateIdlePulse();
      }
    }
  }

  Future<void> _disposeBath() async {
    _cancelColgateIdleTimer();
    _cancelColgateSnap();
    _cepilloDragPulse.stop();
    _cepilloDragPulse.reset();
    _idleColgatePulse.stop();
    _idleColgatePulse.reset();
    final b = _bathController;
    _bathController = null;
    _bathReady = false;
    _bathAnimFinished = false;
    if (b != null) {
      b.removeListener(_onBathTick);
      await b.dispose();
    }
    if (mounted) setState(() {});
  }

  Future<void> _runCatPickToBathSequence() async {
    final pick = _pickHeld;
    if (pick == null) return;
    await pick.pause();

    _whiteFade?.dispose();
    _whiteFade = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    if (!mounted) {
      await pick.dispose();
      _pickHeld = null;
      _whiteFade?.dispose();
      _whiteFade = null;
      return;
    }

    setState(() {});
    await _whiteFade!.forward();
    if (!mounted) {
      await pick.dispose();
      _pickHeld = null;
      _whiteFade?.dispose();
      _whiteFade = null;
      return;
    }

    await widget.onTeardownIntro();
    await pick.dispose();
    _pickHeld = null;
    if (mounted) setState(() {});

    if (!mounted) {
      _whiteFade?.dispose();
      _whiteFade = null;
      return;
    }

    final bath = VideoPlayerController.asset(
      kSaludCatEntersBathAsset,
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
        _bathAnimFinished = false;
      });

      final fadeOut = _whiteFade!.reverse();
      await Future<void>.delayed(_kBathFirstFrameHold);
      if (!mounted) {
        await bath.dispose();
        await fadeOut;
        _whiteFade?.dispose();
        _whiteFade = null;
        return;
      }
      await fadeOut;
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
          _bathReady = false;
          _bathController = null;
          _bathAnimFinished = false;
        });
        _whiteFade?.dispose();
        _whiteFade = null;
        widget.onClose();
      }
    }
  }

  void _cancelColgateSnap() {
    if (_colgateSnapController.isAnimating) {
      final v = _snapColgateAnim?.value ?? _colgatePos;
      _colgateSnapController.stop();
      _colgatePos = v;
    }
    _snapColgateActive = false;
    _snapColgateAnim = null;
    _colgateSnapController.reset();
  }

  void _onColgateSnapComplete() {
    if (!mounted) return;
    setState(() {
      _colgatePos = _kBathColgatePos;
      _snapColgateActive = false;
      _snapColgateAnim = null;
    });
    _colgateSnapController.reset();
    _scheduleColgateIdlePulse();
  }

  void _startColgateSnapBack() {
    _cancelColgateIdleTimer();
    if (!_bathAnimFinished || !mounted) return;

    final from = _snapColgateActive && _snapColgateAnim != null
        ? _snapColgateAnim!.value
        : _colgatePos;
    if ((from - _kBathColgatePos).distance < 1.0) {
      _cancelColgateSnap();
      _colgatePos = _kBathColgatePos;
      setState(() {});
      _scheduleColgateIdlePulse();
      return;
    }

    _colgateSnapController.stop();
    _colgateSnapController.reset();
    _snapColgateAnim = Tween<Offset>(begin: from, end: _kBathColgatePos).animate(
      CurvedAnimation(
        parent: _colgateSnapController,
        curve: Curves.elasticOut,
      ),
    );
    _snapColgateActive = true;
    setState(() {});
    unawaited(
      _colgateSnapController.forward(from: 0).whenComplete(_onColgateSnapComplete),
    );
  }

  void _cancelColgateIdleTimer() {
    _idleColgateTimer?.cancel();
    _idleColgateTimer = null;
  }

  void _scheduleColgateIdlePulse() {
    _cancelColgateIdleTimer();
    if (!_bathAnimFinished || !mounted) return;
    _idleColgateTimer = Timer(const Duration(seconds: 3), _onColgateIdleTimer);
  }

  Future<void> _onColgateIdleTimer() async {
    _idleColgateTimer = null;
    if (!mounted || !_bathAnimFinished) return;
    if (_colgateDragging || _snapColgateActive) {
      _scheduleColgateIdlePulse();
      return;
    }
    await _idleColgatePulse.forward(from: 0);
    if (!mounted) return;
    _idleColgatePulse.reset();
    _scheduleColgateIdlePulse();
  }

  Future<void> _exitBathAndClose() async {
    await _disposeBath();
    _whiteFade?.dispose();
    _whiteFade = null;
    if (mounted) setState(() {});
    widget.onClose();
  }

  Widget _interactiveColgate() {
    return GestureDetector(
      onPanStart: (_) {
        _cancelColgateSnap();
        _cancelColgateIdleTimer();
        _idleColgatePulse.stop();
        _idleColgatePulse.reset();
        setState(() => _colgateDragging = true);
        _cepilloDragPulse.repeat(reverse: true);
      },
      onPanEnd: (_) {
        _cepilloDragPulse.stop();
        _cepilloDragPulse.reset();
        setState(() => _colgateDragging = false);
        _startColgateSnapBack();
      },
      onPanCancel: () {
        _cepilloDragPulse.stop();
        _cepilloDragPulse.reset();
        setState(() => _colgateDragging = false);
        _startColgateSnapBack();
      },
      onPanUpdate: (details) {
        setState(() => _colgatePos += details.delta);
      },
      child: AnimatedBuilder(
        animation: _idleColgatePulse,
        builder: (context, child) {
          final idleScale = _idleColgateScale.value;
          final scale = _colgateDragging ? 1.2 : idleScale;
          return Transform.scale(
            scale: scale,
            alignment: Alignment.center,
            child: child,
          );
        },
        child: Image.asset(kSaludBathColgatePng),
      ),
    );
  }

  Widget _whiteFadeOverlay() {
    final ctrl = _whiteFade;
    if (ctrl == null) return const SizedBox.shrink();
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: ctrl,
          builder: (context, child) {
            final t = ctrl.value.clamp(0.0, 1.0);
            return ColoredBox(color: Color.fromRGBO(255, 255, 255, t));
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    final held = _pickHeld;
    if (held != null) {
      held.dispose();
      _pickHeld = null;
    }
    final bath = _bathController;
    if (bath != null) {
      bath.removeListener(_onBathTick);
      bath.dispose();
    }
    _whiteFade?.dispose();
    _cancelColgateIdleTimer();
    _cancelColgateSnap();
    _idleColgatePulse.dispose();
    _colgateSnapController.dispose();
    _cepilloDragPulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (!_bathReady || _bathController == null)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.fill,
                    child: SizedBox(
                      width: _kLogicalW,
                      height: _kLogicalH,
                      child: _pickHeld != null
                          ? VideoPlayer(_pickHeld!)
                          : const ColoredBox(color: Colors.black),
                    ),
                  ),
                ),
              ),
            )
          else
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
                          Positioned.fill(child: VideoPlayer(_bathController!)),
                          if (_bathAnimFinished)
                            Positioned(
                              left: _kBathCepilloPos.dx,
                              top: _kBathCepilloPos.dy,
                              child: AnimatedBuilder(
                                animation: _cepilloDragPulse,
                                builder: (context, child) {
                                  final scale = _colgateDragging
                                      ? _cepilloDragScaleAnim.value
                                      : 1.0;
                                  return Transform.scale(
                                    scale: scale,
                                    alignment: Alignment.center,
                                    child: child!,
                                  );
                                },
                                child: Image.asset(kSaludBathCepilloPng),
                              ),
                            ),
                          if (_bathAnimFinished)
                            AnimatedBuilder(
                              animation: Listenable.merge([
                                _idleColgatePulse,
                                _colgateSnapController,
                              ]),
                              builder: (context, child) {
                                final pos = _snapColgateActive &&
                                        _snapColgateAnim != null
                                    ? _snapColgateAnim!.value
                                    : _colgatePos;
                                return Positioned(
                                  left: pos.dx,
                                  top: pos.dy,
                                  child: child!,
                                );
                              },
                              child: _interactiveColgate(),
                            ),
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
              onPressed: () => unawaited(_exitBathAndClose()),
            ),
          ),
        ],
      ),
    );
  }
}
