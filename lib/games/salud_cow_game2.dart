import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

const String kSaludCowMouthRinseAsset =
    'assets/video/salud/cowMouthRinse.mp4';

const String kSaludBathSoapPng = 'assets/images/bathGame/soap.png';

class _SoapBubble {
  _SoapBubble({
    required this.position,
    required this.birthMs,
    required this.drift,
    required this.baseRadius,
    required this.color,
    required this.permanent,
  });

  final Offset position;
  final int birthMs;
  final Offset drift;
  final double baseRadius;
  final Color color;
  final bool permanent;
}

class _SoapCompletionStar {
  _SoapCompletionStar({
    required this.birthMs,
    required this.origin,
    required this.velocity,
    required this.size,
    required this.color,
  });

  final int birthMs;
  final Offset origin;
  final Offset velocity;
  final double size;
  final Color color;
}

/// Cow bath phase 2: mouth rinse clip, layout cue, then draggable soap.
///
/// Started from [SaludCowGameLayer] when the water-pour cue circle is tapped.
class SaludCowGame2Layer extends StatefulWidget {
  const SaludCowGame2Layer({super.key});

  @override
  State<SaludCowGame2Layer> createState() => _SaludCowGame2LayerState();
}

class _SaludCowGame2LayerState extends State<SaludCowGame2Layer>
    with TickerProviderStateMixin {
  static const Offset _kBathSoapPos = Offset(1230.9, 169.9);

  static const Offset _kLayoutCuePos = Offset(745.3, 205.0);
  static const double _kLayoutCueW = 350;
  static const double _kLayoutCueH = 850;

  static const int _kMaxSoapBubbles = 64;
  static const int _kSoapBubbleLifetimeMs = 900;
  static const int _kSoapStarLifetimeMs = 500;

  /// Half of the previous soap bubble size (was 3× cepillo, now 1.5×).
  static const double _kSoapBubbleRadiusMin = 27;
  static const double _kSoapBubbleRadiusRange = 30;

  static const List<Color> _kSoapStarPalette = [
    Color.fromRGBO(255, 255, 255, 1),
    Color.fromRGBO(248, 248, 252, 1),
    Color.fromRGBO(200, 200, 200, 1),
  ];

  VideoPlayerController? _mouthRinseController;
  bool _mouthRinseReady = false;
  bool _mouthRinseFinished = false;

  Size? _soapAssetSize;

  Offset _soapPos = _kBathSoapPos;
  bool _soapDragging = false;
  bool _soapScrubTaskComplete = false;
  bool _soapCapCelebrationShown = false;
  bool _soapSettlingPostCelebration = false;
  bool _soapLockedAfterTask = false;

  final List<_SoapBubble> _soapBubbles = [];
  final List<_SoapCompletionStar> _soapCompletionStars = [];
  int _lastSoapBubbleSpawnMs = 0;
  /// 0 = fading bubble; 1–3 = permanent (repeats every 4 spawns).
  int _soapBubbleSpawnCycleIndex = 0;

  late final AnimationController _soapBubbleAnimController;

  Timer? _idleSoapTimer;
  late final AnimationController _idleSoapPulse;
  late final Animation<double> _idleSoapScale;

  late final AnimationController _soapSnapController;
  Animation<Offset>? _snapSoapAnim;
  bool _snapSoapActive = false;

  @override
  void initState() {
    super.initState();
    _soapBubbleAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..addListener(_onSoapBubbleAnimTick);
    _idleSoapPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _idleSoapScale =
        TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween<double>(begin: 1.0, end: 1.2),
            weight: 50,
          ),
          TweenSequenceItem(
            tween: Tween<double>(begin: 1.2, end: 1.0),
            weight: 50,
          ),
        ]).animate(
          CurvedAnimation(parent: _idleSoapPulse, curve: Curves.easeInOut),
        );
    _soapSnapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    unawaited(_loadSoapAssetSize());
    unawaited(_startMouthRinseVideo());
  }

  Future<Size> _decodeAssetImageSize(String assetKey) async {
    final data = await rootBundle.load(assetKey);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    final img = frame.image;
    final s = Size(img.width.toDouble(), img.height.toDouble());
    img.dispose();
    return s;
  }

  Future<void> _loadSoapAssetSize() async {
    try {
      final s = await _decodeAssetImageSize(kSaludBathSoapPng);
      if (!mounted) return;
      setState(() => _soapAssetSize = s);
    } catch (_) {}
  }

  void _onMouthRinseTick() {
    final v = _mouthRinseController;
    if (v == null || !mounted) return;
    final value = v.value;
    if (!value.isInitialized || value.hasError) return;
    if (value.isCompleted) {
      v.removeListener(_onMouthRinseTick);
      unawaited(v.pause());
      if (mounted) {
        setState(() => _mouthRinseFinished = true);
        _scheduleSoapIdlePulse();
      }
    }
  }

  Future<void> _startMouthRinseVideo() async {
    final v = VideoPlayerController.asset(
      kSaludCowMouthRinseAsset,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    try {
      await v.initialize();
      if (!mounted) {
        await v.dispose();
        return;
      }
      await v.setLooping(false);
      v.addListener(_onMouthRinseTick);
      await v.play();
      if (!mounted) {
        await v.dispose();
        return;
      }
      setState(() {
        _mouthRinseController = v;
        _mouthRinseReady = true;
      });
    } catch (_) {
      await v.dispose();
    }
  }

  Rect _layoutScrubRect() {
    return Rect.fromLTWH(
      _kLayoutCuePos.dx,
      _kLayoutCuePos.dy,
      _kLayoutCueW,
      _kLayoutCueH,
    );
  }

  Rect? _soapHitRect() {
    final w = _soapAssetSize?.width;
    final h = _soapAssetSize?.height;
    if (w == null || h == null || w <= 0 || h <= 0) return null;

    final s = _soapDisplayScale();
    final pos = _effectiveSoapPos();
    final sw = w * s;
    final sh = h * s;
    final left = pos.dx + w * (1 - s) / 2;
    final top = pos.dy + h * (1 - s) / 2;
    return Rect.fromLTWH(left, top, sw, sh);
  }

  Color _randomSoapBubbleColor(math.Random rng) {
    if (rng.nextDouble() < 0.8) {
      final n = rng.nextInt(12);
      return Color.fromRGBO(248 - n, 248 - n, 252 - n, 1);
    }
    final grey = rng.nextInt(25);
    return Color.fromRGBO(220 - grey, 220 - grey, 220 - grey, 1);
  }

  bool _hasAnimatingSoapBubbles(int now) {
    return _soapBubbles.any(
      (b) => now - b.birthMs < _kSoapBubbleLifetimeMs,
    );
  }

  void _triggerSoapCapCelebration() {
    if (_soapCapCelebrationShown || !_mouthRinseFinished) return;
    _soapCapCelebrationShown = true;
    _soapScrubTaskComplete = true;

    final center = _layoutScrubRect().center;
    final now = DateTime.now().millisecondsSinceEpoch;
    final rng = math.Random();
    const count = 20;
    for (var i = 0; i < count; i++) {
      final angle = (i / count) * 2 * math.pi + rng.nextDouble() * 0.25;
      final speed = 140 + rng.nextDouble() * 200;
      final roll = rng.nextDouble();
      final Color starColor;
      if (roll < 0.6) {
        starColor = _kSoapStarPalette[0];
      } else if (roll < 0.8) {
        starColor = _kSoapStarPalette[1];
      } else {
        starColor = _kSoapStarPalette[2];
      }
      _soapCompletionStars.add(
        _SoapCompletionStar(
          birthMs: now,
          origin: center,
          velocity: Offset(
            math.cos(angle) * speed,
            math.sin(angle) * speed,
          ),
          size: 22 + rng.nextDouble() * 18,
          color: starColor,
        ),
      );
    }
    if (!_soapBubbleAnimController.isAnimating) {
      _soapBubbleAnimController.repeat();
    }
    if (mounted) setState(() {});
  }

  Widget _soapCompletionStarWidget(_SoapCompletionStar s) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final t = ((now - s.birthMs) / _kSoapStarLifetimeMs).clamp(0.0, 1.0);
    if (t >= 1) return const SizedBox.shrink();

    final spread = Curves.easeOut.transform(t);
    final cx = s.origin.dx + s.velocity.dx * spread;
    final cy = s.origin.dy + s.velocity.dy * spread;
    final opacity = (1 - t).clamp(0.0, 1.0);
    final scale = 0.65 + 0.35 * (1 - t);

    return Positioned(
      left: cx - s.size / 2,
      top: cy - s.size / 2,
      child: IgnorePointer(
        child: Transform.scale(
          scale: scale,
          child: Icon(
            Icons.star_rounded,
            size: s.size,
            color: s.color.withValues(alpha: opacity),
          ),
        ),
      ),
    );
  }

  void _onSoapBubbleAnimTick() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final hadStarsThisFrame = _soapCompletionStars.isNotEmpty;

    _soapBubbles.removeWhere(
      (b) => !b.permanent && now - b.birthMs > _kSoapBubbleLifetimeMs,
    );

    _soapCompletionStars.removeWhere(
      (s) => now - s.birthMs > _kSoapStarLifetimeMs,
    );

    if (_soapCapCelebrationShown &&
        !_soapLockedAfterTask &&
        hadStarsThisFrame &&
        _soapCompletionStars.isEmpty) {
      _beginSoapPostCelebrationSnap();
    }

    final needsTick = _hasAnimatingSoapBubbles(now) ||
        _soapCompletionStars.isNotEmpty;
    if (!needsTick) {
      _soapBubbleAnimController.stop();
    }
    if (mounted) setState(() {});
  }

  void _trySpawnSoapBubbles() {
    if (!_soapDragging ||
        !_mouthRinseFinished ||
        _soapScrubTaskComplete ||
        _soapLockedAfterTask) {
      return;
    }

    final soap = _soapHitRect();
    if (soap == null) return;

    final zone = _layoutScrubRect();
    if (!zone.overlaps(soap)) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastSoapBubbleSpawnMs < 70) return;
    _lastSoapBubbleSpawnMs = now;

    final hit = zone.intersect(soap);
    final rng = math.Random();
    final permanent = _soapBubbleSpawnCycleIndex != 0;
    _soapBubbleSpawnCycleIndex = (_soapBubbleSpawnCycleIndex + 1) % 4;

    _soapBubbles.add(
      _SoapBubble(
        position: hit.center,
        birthMs: now,
        drift: Offset(
          (rng.nextDouble() - 0.5) * 48,
          (rng.nextDouble() - 0.5) * 42 - 15,
        ),
        baseRadius:
            _kSoapBubbleRadiusMin + rng.nextDouble() * _kSoapBubbleRadiusRange,
        color: _randomSoapBubbleColor(rng),
        permanent: permanent,
      ),
    );
    while (_soapBubbles.length > _kMaxSoapBubbles) {
      final transientIdx = _soapBubbles.indexWhere((b) => !b.permanent);
      if (transientIdx >= 0) {
        _soapBubbles.removeAt(transientIdx);
      } else {
        _soapBubbles.removeAt(0);
      }
    }
    if (!_soapCapCelebrationShown &&
        _soapBubbles.length >= _kMaxSoapBubbles) {
      _triggerSoapCapCelebration();
    }
    if (!_soapBubbleAnimController.isAnimating) {
      _soapBubbleAnimController.repeat();
    }
    if (mounted) setState(() {});
  }

  void _beginSoapPostCelebrationSnap() {
    if (!mounted || !_mouthRinseFinished) return;
    if (_soapLockedAfterTask || _soapSettlingPostCelebration) return;

    _cancelSoapIdleTimer();
    _idleSoapPulse.stop();
    _idleSoapPulse.reset();

    setState(() => _soapDragging = false);

    final from = _effectiveSoapPos();
    if ((from - _kBathSoapPos).distance < 1.0) {
      _cancelSoapSnap();
      setState(() {
        _soapPos = _kBathSoapPos;
        _soapLockedAfterTask = true;
      });
      return;
    }

    _soapSettlingPostCelebration = true;
    _soapSnapController.stop();
    _soapSnapController.reset();
    _snapSoapAnim = Tween<Offset>(begin: from, end: _kBathSoapPos).animate(
      CurvedAnimation(
        parent: _soapSnapController,
        curve: Curves.elasticOut,
      ),
    );
    _snapSoapActive = true;
    setState(() {});
    unawaited(
      _soapSnapController
          .forward(from: 0)
          .whenComplete(_onSoapSnapComplete),
    );
  }

  Widget _soapBubbleWidget(_SoapBubble b) {
    const lifetimeMs = _kSoapBubbleLifetimeMs;
    final now = DateTime.now().millisecondsSinceEpoch;
    final rawT = (now - b.birthMs) / lifetimeMs;
    if (!b.permanent && rawT >= 1) return const SizedBox.shrink();

    final t = rawT.clamp(0.0, 1.0);
    final spread = Curves.easeOut.transform(t);
    final scaleT = math.sin(t * math.pi);
    final radius = b.baseRadius * (0.55 + 0.45 * scaleT);
    final cx = b.position.dx + b.drift.dx * spread;
    final cy = b.position.dy + b.drift.dy * spread;
    final opacity = b.permanent ? 0.82 : (1 - t) * 0.82;
    final fill = b.color.withValues(alpha: opacity);
    final stroke = b.color.withValues(alpha: opacity * 0.5);

    return Positioned(
      left: cx - radius,
      top: cy - radius,
      child: IgnorePointer(
        child: Container(
          width: radius * 2,
          height: radius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: fill,
            border: Border.all(color: stroke),
          ),
        ),
      ),
    );
  }

  void _cancelSoapSnap() {
    if (_soapSnapController.isAnimating) {
      final v = _snapSoapAnim?.value ?? _soapPos;
      _soapSnapController.stop();
      _soapPos = v;
    }
    _snapSoapActive = false;
    _snapSoapAnim = null;
    _soapSnapController.reset();
  }

  void _onSoapSnapComplete() {
    if (!mounted) return;

    if (_soapSettlingPostCelebration) {
      _soapSettlingPostCelebration = false;
      setState(() {
        _soapPos = _kBathSoapPos;
        _snapSoapActive = false;
        _snapSoapAnim = null;
        _soapLockedAfterTask = true;
      });
      _soapSnapController.reset();
      return;
    }

    setState(() {
      _soapPos = _kBathSoapPos;
      _snapSoapActive = false;
      _snapSoapAnim = null;
    });
    _soapSnapController.reset();
    if (_mouthRinseFinished && !_soapLockedAfterTask) {
      _scheduleSoapIdlePulse();
    }
  }

  void _startSoapSnapBack() {
    _cancelSoapIdleTimer();
    if (!mounted || !_mouthRinseFinished || _soapLockedAfterTask) return;
    if (_soapScrubTaskComplete || _soapSettlingPostCelebration) return;

    final from =
        _snapSoapActive && _snapSoapAnim != null ? _snapSoapAnim!.value : _soapPos;
    if ((from - _kBathSoapPos).distance < 1.0) {
      _cancelSoapSnap();
      _soapPos = _kBathSoapPos;
      setState(() {});
      _scheduleSoapIdlePulse();
      return;
    }

    _soapSnapController.stop();
    _soapSnapController.reset();
    _snapSoapAnim = Tween<Offset>(begin: from, end: _kBathSoapPos).animate(
      CurvedAnimation(
        parent: _soapSnapController,
        curve: Curves.elasticOut,
      ),
    );
    _snapSoapActive = true;
    setState(() {});
    unawaited(
      _soapSnapController.forward(from: 0).whenComplete(_onSoapSnapComplete),
    );
  }

  void _cancelSoapIdleTimer() {
    _idleSoapTimer?.cancel();
    _idleSoapTimer = null;
  }

  void _scheduleSoapIdlePulse() {
    _cancelSoapIdleTimer();
    if (!mounted || !_mouthRinseFinished || _soapLockedAfterTask) return;
    _idleSoapTimer = Timer(const Duration(seconds: 3), _onSoapIdleTimer);
  }

  Future<void> _onSoapIdleTimer() async {
    _idleSoapTimer = null;
    if (!mounted || !_mouthRinseFinished || _soapLockedAfterTask) return;
    if (_soapDragging || _snapSoapActive) {
      _scheduleSoapIdlePulse();
      return;
    }
    await _idleSoapPulse.forward(from: 0);
    if (!mounted) return;
    _idleSoapPulse.reset();
    _scheduleSoapIdlePulse();
  }

  double _soapDisplayScale() {
    if (_soapLockedAfterTask) return 1.0;
    if (_soapDragging || _snapSoapActive || _soapSettlingPostCelebration) {
      return 1.0;
    }
    return _idleSoapScale.value;
  }

  Offset _effectiveSoapPos() {
    if (_snapSoapActive && _snapSoapAnim != null) {
      return _snapSoapAnim!.value;
    }
    return _soapPos;
  }

  Widget _layoutCueRect() {
    return Positioned(
      left: _kLayoutCuePos.dx,
      top: _kLayoutCuePos.dy,
      child: IgnorePointer(
        child: SizedBox(
          width: _kLayoutCueW,
          height: _kLayoutCueH,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.transparent,
            ),
          ),
        ),
      ),
    );
  }

  Widget _soapWidget() {
    final soapImage = Image.asset(kSaludBathSoapPng);
    final child = _soapLockedAfterTask
        ? soapImage
        : GestureDetector(
            onPanStart: (_) {
              if (_soapScrubTaskComplete) return;
              _cancelSoapIdleTimer();
              _idleSoapPulse.stop();
              _idleSoapPulse.reset();
              _cancelSoapSnap();
              setState(() => _soapDragging = true);
            },
            onPanEnd: (_) {
              if (_soapScrubTaskComplete) return;
              setState(() => _soapDragging = false);
              _startSoapSnapBack();
            },
            onPanCancel: () {
              if (_soapScrubTaskComplete) return;
              setState(() => _soapDragging = false);
              _startSoapSnapBack();
            },
            onPanUpdate: (details) {
              if (_soapScrubTaskComplete) return;
              setState(() => _soapPos += details.delta);
              _trySpawnSoapBubbles();
            },
            child: soapImage,
          );

    return AnimatedBuilder(
      animation: Listenable.merge([_idleSoapPulse, _soapSnapController]),
      builder: (context, child) {
        final pos = _effectiveSoapPos();
        return Positioned(
          left: pos.dx,
          top: pos.dy,
          child: Transform.scale(
            scale: _soapDisplayScale(),
            alignment: Alignment.center,
            child: child!,
          ),
        );
      },
      child: child,
    );
  }

  @override
  void dispose() {
    _cancelSoapIdleTimer();
    _cancelSoapSnap();
    _idleSoapPulse.stop();
    _idleSoapPulse.dispose();
    _soapSnapController.dispose();
    _soapBubbleAnimController.dispose();
    final v = _mouthRinseController;
    _mouthRinseController = null;
    _mouthRinseReady = false;
    if (v != null) {
      v.removeListener(_onMouthRinseTick);
      unawaited(v.dispose());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (_mouthRinseReady && _mouthRinseController != null)
          Positioned.fill(child: VideoPlayer(_mouthRinseController!)),
        if (_mouthRinseFinished) ...[
          _layoutCueRect(),
          ..._soapBubbles.map(_soapBubbleWidget),
          ..._soapCompletionStars.map(_soapCompletionStarWidget),
          _soapWidget(),
        ],
      ],
    );
  }
}
