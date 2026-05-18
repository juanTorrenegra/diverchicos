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

  Offset position;
  final int birthMs;
  final Offset drift;
  final double baseRadius;
  final Color color;
  final bool permanent;
  int? attachedDropId;
  Offset attachOffset = Offset.zero;
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

class _CyanDrop {
  _CyanDrop({
    required this.id,
    required this.origin,
    required this.birthMs,
    required this.velocityY,
    required this.driftX,
    required this.radius,
    required this.sticky,
  });

  final int id;
  final Offset origin;
  final int birthMs;
  final double velocityY;
  final double driftX;
  final double radius;
  final bool sticky;
}

/// Cow bath phase 2: mouth rinse clip, layout cue, then draggable soap.
///
/// Started from [SaludCowGameLayer] when the water-pour cue circle is tapped.
class SaludCowGame2Layer extends StatefulWidget {
  const SaludCowGame2Layer({super.key, required this.onPhaseComplete});

  /// Called after the soap and triangle have been disposed at the end of phase 2.
  final VoidCallback onPhaseComplete;

  @override
  State<SaludCowGame2Layer> createState() => _SaludCowGame2LayerState();
}

class _SaludCowGame2LayerState extends State<SaludCowGame2Layer>
    with TickerProviderStateMixin {
  static const double _kLogicalH = 1080;

  static const Offset _kBathSoapPos = Offset(1200.9, 149.9);

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
    Color.fromRGBO(255, 235, 59, 1),
    Color.fromRGBO(255, 213, 0, 1),
    Color.fromRGBO(255, 193, 7, 1),
  ];

  static const double _kLayoutTriangleSize = 150;
  static const Offset _kLayoutTriangleStart = Offset(841.9, -44.2);
  static const Duration _kTriangleIdleDelay = Duration(seconds: 3);
  static const Duration _kTriangleIdleAnimDuration = Duration(milliseconds: 650);

  static const Color _kCyanDropColor = Colors.cyan;
  static const Color _kTriangleFillColor = Color(0xB39C27B0);

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
  bool _soapDisposing = false;
  bool _soapDisposed = false;
  bool _phaseCompleteNotified = false;

  late final ValueNotifier<double> _triangleX;
  late final ValueNotifier<double> _triangleY;
  bool _triangleUnlocked = false;
  bool _triangleSpawningDrops = false;
  bool _triangleDropSessionComplete = false;
  bool _triangleExiting = false;
  bool _triangleDisposed = false;
  int _cyanDropSpawnTotal = 0;
  int _nextCyanDropId = 0;

  final List<_CyanDrop> _cyanDrops = [];
  final List<_SoapBubble> _soapBubbles = [];
  final List<_SoapCompletionStar> _soapCompletionStars = [];
  int _lastSoapBubbleSpawnMs = 0;
  /// 0 = fading bubble; 1–3 = permanent (repeats every 4 spawns).
  int _soapBubbleSpawnCycleIndex = 0;

  late final AnimationController _soapBubbleAnimController;
  late final AnimationController _cyanDropAnimController;

  Timer? _idleSoapTimer;
  late final AnimationController _idleSoapPulse;
  late final Animation<double> _idleSoapScale;

  Timer? _idleTriangleIdleTimer;
  late final AnimationController _triangleIdlePulse;
  late final Animation<double> _triangleIdleScale;

  late final AnimationController _soapSnapController;
  Animation<Offset>? _snapSoapAnim;
  bool _snapSoapActive = false;

  late final AnimationController _triangleExitController;
  late final AnimationController _soapShrinkController;
  late final Animation<double> _soapShrinkScale;

  @override
  void initState() {
    super.initState();
    _soapBubbleAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..addListener(_onSoapBubbleAnimTick);
    _cyanDropAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..addListener(_onCyanDropAnimTick);
    _triangleX = ValueNotifier(_kLayoutTriangleStart.dx);
    _triangleY = ValueNotifier(_kLayoutTriangleStart.dy);
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
    _triangleIdlePulse = AnimationController(
      vsync: this,
      duration: _kTriangleIdleAnimDuration,
    );
    _triangleIdleScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.5), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: 1.5, end: 1.0), weight: 50),
    ]).animate(
      CurvedAnimation(parent: _triangleIdlePulse, curve: Curves.easeInOut),
    );
    _triangleExitController = AnimationController(vsync: this);
    _soapShrinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );
    _soapShrinkScale = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _soapShrinkController, curve: Curves.easeInOut),
    );
    _soapShrinkController.addStatusListener(_onSoapShrinkStatus);
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
    const count = 40;
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
          size: 44 + rng.nextDouble() * 36,
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
      _triangleUnlocked = true;
      _playTriangleIdlePulse();
      _beginSoapPostCelebrationSnap();
    }

    _processStickyDropBubbleCoupling(now);

    final needsTick = _hasAnimatingSoapBubbles(now) ||
        _soapCompletionStars.isNotEmpty ||
        _soapBubbles.any((b) => b.attachedDropId != null) ||
        (_triangleUnlocked && _hasActiveDropsOrBubblesOnScreen(now));
    if (!needsTick) {
      _soapBubbleAnimController.stop();
    }
    _maybeStartTriangleExit();
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

  Offset _cyanDropCenter(_CyanDrop d, int now) {
    final elapsed = (now - d.birthMs) / 1000.0;
    return Offset(
      d.origin.dx + d.driftX * elapsed,
      d.origin.dy + d.velocityY * elapsed,
    );
  }

  Offset _soapBubbleFreeCenter(_SoapBubble b, int now) {
    const lifetimeMs = _kSoapBubbleLifetimeMs;
    final rawT = (now - b.birthMs) / lifetimeMs;
    final t = rawT.clamp(0.0, 1.0);
    final spread = Curves.easeOut.transform(t);
    return Offset(
      b.position.dx + b.drift.dx * spread,
      b.position.dy + b.drift.dy * spread,
    );
  }

  double _soapBubbleRadiusAt(_SoapBubble b, int now) {
    if (b.attachedDropId != null) {
      return b.baseRadius * 0.82;
    }
    const lifetimeMs = _kSoapBubbleLifetimeMs;
    final rawT = (now - b.birthMs) / lifetimeMs;
    final t = rawT.clamp(0.0, 1.0);
    final scaleT = math.sin(t * math.pi);
    return b.baseRadius * (0.55 + 0.45 * scaleT);
  }

  _CyanDrop? _cyanDropById(int id) {
    for (final d in _cyanDrops) {
      if (d.id == id) return d;
    }
    return null;
  }

  void _processStickyDropBubbleCoupling(int now) {
    for (final drop in _cyanDrops) {
      if (!drop.sticky) continue;
      final dropCenter = _cyanDropCenter(drop, now);
      for (final bubble in _soapBubbles) {
        if (bubble.attachedDropId != null) continue;
        final bubbleCenter = _soapBubbleFreeCenter(bubble, now);
        final bubbleRadius = _soapBubbleRadiusAt(bubble, now);
        if ((dropCenter - bubbleCenter).distance >
            drop.radius + bubbleRadius) {
          continue;
        }
        bubble.attachedDropId = drop.id;
        bubble.attachOffset = bubbleCenter - dropCenter;
        if (!_soapBubbleAnimController.isAnimating) {
          _soapBubbleAnimController.repeat();
        }
      }
    }

    for (final bubble in _soapBubbles) {
      final dropId = bubble.attachedDropId;
      if (dropId == null) continue;
      final drop = _cyanDropById(dropId);
      if (drop == null) {
        bubble.attachedDropId = null;
        continue;
      }
      bubble.position = _cyanDropCenter(drop, now) + bubble.attachOffset;
    }
  }

  void _detachBubblesFromRemovedDrops() {
    final activeIds = _cyanDrops.map((d) => d.id).toSet();
    for (final bubble in _soapBubbles) {
      final id = bubble.attachedDropId;
      if (id != null && !activeIds.contains(id)) {
        bubble.attachedDropId = null;
      }
    }
  }

  void _removeOffScreenDropsAndAttachedBubbles(int now) {
    final exitedDropIds = <int>[];
    _cyanDrops.removeWhere((d) {
      final y = _cyanDropCenter(d, now).dy;
      if (y - d.radius > _kLogicalH) {
        exitedDropIds.add(d.id);
        return true;
      }
      return false;
    });
    if (exitedDropIds.isEmpty) return;
    _soapBubbles.removeWhere(
      (b) =>
          b.attachedDropId != null &&
          exitedDropIds.contains(b.attachedDropId),
    );
  }

  bool _bubbleStillOnScreen(_SoapBubble bubble, int now) {
    final double cy;
    final double radius;
    if (bubble.attachedDropId != null) {
      cy = bubble.position.dy;
      radius = bubble.baseRadius * 0.82;
    } else {
      final center = _soapBubbleFreeCenter(bubble, now);
      cy = center.dy;
      radius = _soapBubbleRadiusAt(bubble, now);
    }
    return cy - radius <= _kLogicalH;
  }

  /// True while any drop is falling or any permanent scrub bubble is still on screen.
  bool _hasActiveDropsOrBubblesOnScreen(int now) {
    if (_cyanDrops.isNotEmpty) return true;
    for (final bubble in _soapBubbles) {
      if (!bubble.permanent) continue;
      if (_bubbleStillOnScreen(bubble, now)) return true;
    }
    return false;
  }

  Widget _soapBubbleWidget(_SoapBubble b) {
    const lifetimeMs = _kSoapBubbleLifetimeMs;
    final now = DateTime.now().millisecondsSinceEpoch;
    final rawT = (now - b.birthMs) / lifetimeMs;
    if (!b.permanent && rawT >= 1 && b.attachedDropId == null) {
      return const SizedBox.shrink();
    }

    final t = rawT.clamp(0.0, 1.0);
    final spread = Curves.easeOut.transform(t);
    final scaleT = math.sin(t * math.pi);
    final attached = b.attachedDropId != null;
    final radius = attached
        ? b.baseRadius * 0.82
        : b.baseRadius * (0.55 + 0.45 * scaleT);
    final cx = attached
        ? b.position.dx
        : b.position.dx + b.drift.dx * spread;
    final cy = attached
        ? b.position.dy
        : b.position.dy + b.drift.dy * spread;
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
    if (_soapDisposing) return _soapShrinkScale.value;
    if (_soapLockedAfterTask) return 1.0;
    if (_soapDragging || _snapSoapActive || _soapSettlingPostCelebration) {
      return 1.0;
    }
    return _idleSoapScale.value;
  }

  void _onSoapShrinkStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    setState(() {
      _soapDisposing = false;
      _soapDisposed = true;
    });
    _maybeNotifyPhaseComplete();
  }

  void _maybeNotifyPhaseComplete() {
    if (_phaseCompleteNotified ||
        !_triangleDisposed ||
        !_soapDisposed ||
        !mounted) {
      return;
    }
    _phaseCompleteNotified = true;
    widget.onPhaseComplete();
  }

  void _beginSoapShrink() {
    if (_soapDisposed || _soapDisposing || !_soapLockedAfterTask) return;
    _cancelSoapIdleTimer();
    _idleSoapPulse.stop();
    _idleSoapPulse.reset();
    _soapDisposing = true;
    _soapShrinkController.forward(from: 0);
    if (mounted) setState(() {});
  }

  void _disposeTriangleAndParticles() {
    _triangleDisposed = true;
    _triangleExiting = false;
    _soapBubbles.clear();
    _cyanDrops.clear();
    _soapCompletionStars.clear();
    _cyanDropAnimController.stop();
    _soapBubbleAnimController.stop();
    _detachBubblesFromRemovedDrops();
    if (mounted) setState(() {});
    _maybeNotifyPhaseComplete();
  }

  void _beginTriangleExit() {
    if (_triangleExiting || _triangleDisposed || !_triangleUnlocked) return;

    _triangleDropSessionComplete = false;
    _triangleExiting = true;
    _cancelTriangleIdlePulse();
    _beginSoapShrink();

    const scale = 1.0;
    final exitTop = -_kLayoutTriangleSize * scale - 8;
    final distance = _triangleY.value - exitTop;
    const speedPxPerSec = 55.0;
    final durationMs =
        ((distance / speedPxPerSec) * 1000).round().clamp(800, 12000);

    _triangleExitController.duration = Duration(milliseconds: durationMs);
    _triangleExitController.stop();
    _triangleExitController.reset();
    final exitAnim = Tween<double>(
      begin: _triangleY.value,
      end: exitTop,
    ).animate(
      CurvedAnimation(
        parent: _triangleExitController,
        curve: Curves.linear,
      ),
    );
    void onExitTick() {
      _triangleY.value = exitAnim.value;
    }

    _triangleExitController.removeListener(onExitTick);
    _triangleExitController.addListener(onExitTick);
    unawaited(
      _triangleExitController.forward(from: 0).whenComplete(() {
        _triangleExitController.removeListener(onExitTick);
        if (!mounted) return;
        _disposeTriangleAndParticles();
      }),
    );
    if (mounted) setState(() {});
  }

  void _maybeStartTriangleExit() {
    if (!_triangleUnlocked ||
        _triangleDisposed ||
        _triangleExiting ||
        _triangleSpawningDrops ||
        !_triangleDropSessionComplete) {
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_hasActiveDropsOrBubblesOnScreen(now)) return;
    _beginTriangleExit();
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

  void _spawnCyanDropBatch({int count = 5}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rng = math.Random();
    final baseY = _triangleY.value + _kLayoutTriangleSize;
    final baseLeft = _triangleX.value;

    for (var i = 0; i < count; i++) {
      final x = baseLeft + rng.nextDouble() * _kLayoutTriangleSize;
      _cyanDropSpawnTotal++;
      final sticky = _cyanDropSpawnTotal % 30 == 0;
      _cyanDrops.add(
        _CyanDrop(
          id: ++_nextCyanDropId,
          origin: Offset(x, baseY),
          birthMs: now,
          velocityY: 280 + rng.nextDouble() * 180,
          driftX: (rng.nextDouble() - 0.5) * 40,
          radius: 4 + rng.nextDouble() * 5,
          sticky: sticky,
        ),
      );
    }
  }

  void _onCyanDropAnimTick() {
    if (_triangleSpawningDrops && _triangleUnlocked) {
      _spawnCyanDropBatch(count: 6);
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    _processStickyDropBubbleCoupling(now);
    _removeOffScreenDropsAndAttachedBubbles(now);
    _detachBubblesFromRemovedDrops();
    if (_soapBubbles.any((b) => b.attachedDropId != null) &&
        !_soapBubbleAnimController.isAnimating) {
      _soapBubbleAnimController.repeat();
    }
    if (_cyanDrops.isEmpty && !_triangleSpawningDrops) {
      _cyanDropAnimController.stop();
    }
    _maybeStartTriangleExit();
    if (mounted) setState(() {});
  }

  Widget _cyanDropsLayer() {
    return AnimatedBuilder(
      animation: _cyanDropAnimController,
      builder: (context, child) {
        return Stack(
          clipBehavior: Clip.none,
          children: _cyanDrops.map(_cyanDropWidget).toList(),
        );
      },
    );
  }

  void _cancelTriangleIdleTimer() {
    _idleTriangleIdleTimer?.cancel();
    _idleTriangleIdleTimer = null;
  }

  void _cancelTriangleIdlePulse() {
    _cancelTriangleIdleTimer();
    _triangleIdlePulse.stop();
    _triangleIdlePulse.reset();
  }

  void _scheduleTriangleIdleLoop() {
    _cancelTriangleIdleTimer();
    if (!_triangleUnlocked ||
        _triangleSpawningDrops ||
        _triangleExiting ||
        _triangleDisposed) {
      return;
    }
    _idleTriangleIdleTimer = Timer(_kTriangleIdleDelay, () {
      unawaited(_playTriangleIdlePulse());
    });
  }

  Future<void> _playTriangleIdlePulse() async {
    _cancelTriangleIdleTimer();
    if (!mounted ||
        !_triangleUnlocked ||
        _triangleSpawningDrops ||
        _triangleExiting ||
        _triangleDisposed) {
      return;
    }
    await _triangleIdlePulse.forward(from: 0);
    if (!mounted) return;
    _triangleIdlePulse.reset();
    if (_triangleSpawningDrops || _triangleExiting || _triangleDisposed) {
      return;
    }
    _scheduleTriangleIdleLoop();
  }

  double _triangleDisplayScale() {
    if (_triangleSpawningDrops || _triangleExiting) return 1.0;
    return _triangleIdleScale.value;
  }

  void _startTriangleDropStream() {
    if (!_triangleUnlocked) return;
    _cancelTriangleIdlePulse();
    _triangleSpawningDrops = true;
    if (!_cyanDropAnimController.isAnimating) {
      _cyanDropAnimController.repeat();
    }
  }

  void _stopTriangleDropStream() {
    _triangleSpawningDrops = false;
    _triangleDropSessionComplete = true;
    _scheduleTriangleIdleLoop();
    _maybeStartTriangleExit();
  }

  Widget _cyanDropWidget(_CyanDrop d) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final center = _cyanDropCenter(d, now);
    if (center.dy - d.radius > _kLogicalH) return const SizedBox.shrink();

    return Positioned(
      left: center.dx - d.radius,
      top: center.dy - d.radius,
      child: IgnorePointer(
        child: Container(
          width: d.radius * 2,
          height: d.radius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: d.sticky ? Colors.teal : _kCyanDropColor,
            border: d.sticky
                ? Border.all(color: Colors.cyanAccent, width: 1.5)
                : null,
          ),
        ),
      ),
    );
  }

  void _logLayoutTrianglePosition() {
    debugPrint(
      'dragLayoutTriangle: x=${_triangleX.value.toStringAsFixed(1)}, '
      'y=${_kLayoutTriangleStart.dy.toStringAsFixed(1)}',
    );
  }

  Widget _draggableLayoutTriangle() {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _triangleX,
        _triangleY,
        _triangleIdlePulse,
        _triangleExitController,
      ]),
      builder: (context, child) {
        return Positioned(
          left: _triangleX.value,
          top: _triangleY.value,
          child: Transform.scale(
            scale: _triangleDisplayScale(),
            alignment: Alignment.center,
            child: child!,
          ),
        );
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) {
          if (_triangleExiting) return;
          _startTriangleDropStream();
        },
        onPanUpdate: (details) {
          if (_triangleExiting) return;
          _triangleX.value += details.delta.dx;
        },
        onPanEnd: (_) {
          _stopTriangleDropStream();
          _logLayoutTrianglePosition();
        },
        onPanCancel: () {
          _stopTriangleDropStream();
          _logLayoutTrianglePosition();
        },
        child: SizedBox(
          width: _kLayoutTriangleSize,
          height: _kLayoutTriangleSize,
          child: ClipPath(
            clipper: _UpTriangleClipper(),
            child: const ColoredBox(
              color: _kTriangleFillColor,
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
      animation: Listenable.merge([
        _idleSoapPulse,
        _soapSnapController,
        _soapShrinkController,
      ]),
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
    _cancelTriangleIdlePulse();
    _triangleIdlePulse.dispose();
    _soapSnapController.dispose();
    _soapBubbleAnimController.dispose();
    _cyanDropAnimController.dispose();
    _triangleX.dispose();
    _triangleY.dispose();
    _triangleExitController.dispose();
    _soapShrinkController.removeStatusListener(_onSoapShrinkStatus);
    _soapShrinkController.dispose();
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
          if (!_triangleDisposed) ...[
            ..._soapBubbles.map(_soapBubbleWidget),
            ..._soapCompletionStars.map(_soapCompletionStarWidget),
          ],
          if (!_soapDisposed) _soapWidget(),
          if (_triangleUnlocked && !_triangleDisposed) ...[
            _cyanDropsLayer(),
            _draggableLayoutTriangle(),
          ],
        ],
      ],
    );
  }
}

/// Up-pointing triangle inscribed in a square (150×150 layout box).
class _UpTriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
