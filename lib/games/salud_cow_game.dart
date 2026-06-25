import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../utils/cutscene_instruction_loop.dart';
import '../widgets/menu_back_pill.dart';
import 'salud_cow_game2.dart';
import 'salud_instruction_audio.dart';

const String kSaludCowEntersBathAsset = 'assets/video/salud/cowEntersBath.mp4';
const String kSaludToothpasteOnCepilloAsset =
    'assets/video/salud/toothpasteOnCepillo.mp4';
const String kSaludCowShowsDirtyTeethAsset =
    'assets/video/salud/cowShowsDirtyTeeth.mp4';
const String kSaludWaterPourAsset = 'assets/video/salud/waterPour.mp4';
const String kSaludCowEndingAsset = 'assets/video/salud/cowEnding.mp4';

const String kSaludBathColgatePng = 'assets/images/bathGame/colgate.png';
const String kSaludBathCepilloPng = 'assets/images/bathGame/cepillo.png';
/// On disk the file is `cepilloCrema.png` (see `assets/images/bathGame/`).
const String kSaludBathCepilloConCremaPng =
    'assets/images/bathGame/cepilloCrema.png';

/// Cow teeth scrub zone (logical 1980×1080); paste tip must overlap to spawn bubbles.
class _ScrubBubble {
  _ScrubBubble({
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

class _CompletionStar {
  _CompletionStar({
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

/// Cow branch after [cowPick.mp4] ends: white cross-fade, bath clip, props, back pill.
///
/// Takes ownership of [pickController] (paused on last frame) and disposes it mid-sequence.
class SaludCowGameLayer extends StatefulWidget {
  const SaludCowGameLayer({
    super.key,
    required this.pickController,
    required this.onTeardownIntro,
    required this.onClose,
  });

  final VideoPlayerController pickController;
  final Future<void> Function() onTeardownIntro;
  final VoidCallback onClose;

  @override
  State<SaludCowGameLayer> createState() => _SaludCowGameLayerState();
}

class _SaludCowGameLayerState extends State<SaludCowGameLayer>
    with TickerProviderStateMixin {
  static const double _kLogicalW = 1980;
  static const double _kLogicalH = 1080;

  static const Offset _kBathColgatePos = Offset(1319.8, 917.7);
  static const Offset _kBathCepilloPos = Offset(210.2, 911.0);

  static const double _kTeethScrubZoneW = 300;
  static const double _kTeethScrubZoneH = 100;
  static const Offset _kTeethScrubZonePos = Offset(767.6, 538.3);

  /// Paste tip hitbox as fraction of cepilloCrema (top-left).
  static const double _kPasteHitFracW = 0.22;
  static const double _kPasteHitFracH = 0.20;

  static const int _kMaxScrubBubbles = 64;
  static const int _kScrubStarLifetimeMs = 500;

  static const double _kPostTaskProbeSize = 250;
  /// Post-task cue (logical 1980×1080); fixed, pulses on a loop after lock.
  static const Offset _kPostTaskProbePos = Offset(914.5, 737.6);
  /// Loop every 3s: two consecutive alpha↔scale pulses, then invisible idle.
  static const Duration _kPostTaskProbePulsePeriod = Duration(milliseconds: 3000);
  static const double _kPostTaskProbeRampMs = 280;

  /// Tappable cue after water pour (logical 1980×1080).
  static const Offset _kWaterPourCuePos = Offset(843.6, 864.1);

  /// Cleared after [pick] is disposed; avoids building [VideoPlayer] with a disposed controller.
  VideoPlayerController? _pickHeld;

  VideoPlayerController? _bathController;
  bool _bathReady = false;
  bool _bathAnimFinished = false;
  AnimationController? _whiteFade;
  bool _exitingToMenu = false;

  final CutsceneInstructionLoop _instructions = CutsceneInstructionLoop();

  Offset _colgatePos = _kBathColgatePos;
  bool _colgateDragging = false;

  /// PNG pixel sizes for overlap tests (logical canvas matches asset pixels here).
  Size? _colgateAssetSize;
  Size? _cepilloAssetSize;
  Size? _cepilloCremaAssetSize;

  bool _propsHidden = false;
  bool _mergeTriggered = false;
  VideoPlayerController? _mergeVideoController;
  bool _mergeVideoReady = false;

  /// After merge clip ends: draggable cepillo con crema at [\_kBathCepilloPos].
  bool _cepilloCremaVisible = false;
  Offset _cepilloCremaPos = _kBathCepilloPos;
  bool _cepilloCremaDragging = false;

  VideoPlayerController? _dirtyTeethController;
  bool _dirtyTeethReady = false;

  VideoPlayerController? _waterPourController;
  bool _waterPourReady = false;

  /// Frozen copy of scrub bubbles shown on top of [waterPour.mp4] at tap time.
  List<_ScrubBubble> _waterPourCopiedBubbles = [];
  int? _waterPourBubbleEpochMs;

  bool _teethScrubZoneActive = false;
  final List<_ScrubBubble> _scrubBubbles = [];
  int _lastBubbleSpawnMs = 0;
  /// 0 = fading bubble; 1–3 = permanent (repeats every 4 spawns).
  int _bubbleSpawnCycleIndex = 0;
  bool _scrubTaskComplete = false;
  bool _scrubCapCelebrationShown = false;
  /// Stars done → snap home, then lock cepillo (no drag, no idle scale).
  bool _cepilloCremaLockedAfterTask = false;
  bool _cepilloCremaSettlingPostCelebration = false;

  bool _postTaskProbeDismissed = false;

  final List<_CompletionStar> _scrubCompletionStars = [];
  late final AnimationController _bubbleAnimController;
  late final AnimationController _postTaskProbePulseController;
  bool _postTaskProbeLoopStarted = false;
  late final AnimationController _waterPourCuePulseController;
  bool _waterPourCueLoopStarted = false;
  bool _waterPourCueDismissed = false;
  bool _cowPhase2Active = false;

  VideoPlayerController? _endingController;
  bool _endingReady = false;
  bool _endingVisible = false;
  bool _endingSequenceStarted = false;
  bool _endingHoldPassed = false;

  static const List<Color> _kScrubBubblePalette = [
    Color.fromRGBO(255, 255, 255, 1),
    Color.fromRGBO(175, 238, 255, 1),
    Color.fromRGBO(225, 205, 255, 1),
  ];

  Timer? _idleColgateTimer;
  late final AnimationController _idleColgatePulse;
  late final Animation<double> _idleColgateScale;

  late final AnimationController _colgateSnapController;
  Animation<Offset>? _snapColgateAnim;
  bool _snapColgateActive = false;

  /// While dragging colgate: cepillo scales 1→1.2→1 over 2s (1s each way).
  late final AnimationController _cepilloDragPulse;
  late final Animation<double> _cepilloDragScaleAnim;

  late final AnimationController _cepilloCremaSnapController;
  Animation<Offset>? _snapCepilloCremaAnim;
  bool _snapCepilloCremaActive = false;

  Timer? _idleCepilloCremaTimer;
  late final AnimationController _idleCepilloCremaPulse;
  late final Animation<double> _idleCepilloCremaScale;

  Future<Size> _decodeAssetImageSize(String assetKey) async {
    final data = await rootBundle.load(assetKey);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    final img = frame.image;
    final s = Size(img.width.toDouble(), img.height.toDouble());
    img.dispose();
    return s;
  }

  Future<void> _loadPropAssetSizes() async {
    try {
      final col = await _decodeAssetImageSize(kSaludBathColgatePng);
      final cep = await _decodeAssetImageSize(kSaludBathCepilloPng);
      final crema = await _decodeAssetImageSize(kSaludBathCepilloConCremaPng);
      if (!mounted) return;
      setState(() {
        _colgateAssetSize = col;
        _cepilloAssetSize = cep;
        _cepilloCremaAssetSize = crema;
      });
    } catch (_) {}
  }

  Rect? _cepilloHitRect() {
    final tw = _cepilloAssetSize?.width;
    final th = _cepilloAssetSize?.height;
    if (tw == null || th == null || tw <= 0 || th <= 0) return null;
    final cx = _kBathCepilloPos.dx + tw / 2;
    final cy = _kBathCepilloPos.dy + th / 2;
    return Rect.fromCenter(
      center: Offset(cx, cy),
      width: tw * 2,
      height: th * 2,
    );
  }

  bool _colgateOverlapsCepilloHitbox() {
    final cw = _colgateAssetSize?.width;
    final ch = _colgateAssetSize?.height;
    if (cw == null || ch == null || cw <= 0 || ch <= 0) return false;
    final hit = _cepilloHitRect();
    if (hit == null) return false;
    final colgateRect = Rect.fromLTWH(_colgatePos.dx, _colgatePos.dy, cw, ch);
    return colgateRect.overlaps(hit);
  }

  bool get _brushInstructionsEligible =>
      _teethScrubZoneActive &&
      _cepilloCremaVisible &&
      !_cepilloCremaLockedAfterTask &&
      !_cepilloCremaSettlingPostCelebration;

  void _startBrushInstructions() {
    if (!_brushInstructionsEligible) return;
    unawaited(_instructions.start(SaludInstructionAudio.cepilloADientes));
  }

  void _pauseBrushInstructions() {
    if (_instructions.isRunning && !_instructions.isPaused) {
      unawaited(_instructions.pause());
    }
  }

  void _resumeBrushInstructionsIfIdle() {
    if (!_brushInstructionsEligible) return;
    if (_cepilloCremaDragging || _snapCepilloCremaActive) return;
    if (_instructions.isRunning && _instructions.isPaused) {
      unawaited(_instructions.resume());
    } else if (!_instructions.isRunning) {
      _startBrushInstructions();
    }
  }

  Future<void> _stopBrushInstructions() => _instructions.stop();

  void _startWaterCupInstructions() {
    unawaited(_instructions.start(SaludInstructionAudio.aguaAvaso));
  }

  void _startWaterMouthInstructions() {
    unawaited(_instructions.start(SaludInstructionAudio.aguaABoca));
  }

  Future<void> _stopWaterInstructions() => _instructions.stop();

  void _onMergeVideoTick() {
    final c = _mergeVideoController;
    if (c == null || !mounted) return;
    final v = c.value;
    if (!v.isInitialized || v.hasError) return;
    if (v.isCompleted) {
      c.removeListener(_onMergeVideoTick);
      unawaited(_finishMergeAndShowCepilloCrema(c));
    }
  }

  Future<void> _finishMergeAndShowCepilloCrema(VideoPlayerController c) async {
    await c.pause();
    if (!mounted) {
      await c.dispose();
      return;
    }
    setState(() {
      _mergeVideoController = null;
      _mergeVideoReady = false;
      _cepilloCremaVisible = true;
      _cepilloCremaPos = _kBathCepilloPos;
    });
    await c.dispose();
    if (mounted) {
      _scheduleCepilloCremaIdlePulse();
      unawaited(_startDirtyTeethVideo());
    }
  }

  void _onDirtyTeethTick() {
    final v = _dirtyTeethController;
    if (v == null || !mounted) return;
    final value = v.value;
    if (!value.isInitialized || value.hasError) return;
    if (value.isCompleted) {
      v.removeListener(_onDirtyTeethTick);
      unawaited(v.pause());
      if (mounted) setState(() {});
    }
  }

  Future<void> _startDirtyTeethVideo() async {
    if (!mounted || !_cepilloCremaVisible) return;

    final v = VideoPlayerController.asset(
      kSaludCowShowsDirtyTeethAsset,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    try {
      await v.initialize();
      if (!mounted) {
        await v.dispose();
        return;
      }
      await v.setLooping(false);
      v.addListener(_onDirtyTeethTick);
      await v.play();
      if (!mounted) {
        await v.dispose();
        return;
      }
      setState(() {
        _dirtyTeethController = v;
        _dirtyTeethReady = true;
        _teethScrubZoneActive = true;
      });
      _startBrushInstructions();
    } catch (_) {
      await v.dispose();
    }
  }

  Future<void> _disposeDirtyTeeth() async {
    final v = _dirtyTeethController;
    _dirtyTeethController = null;
    _dirtyTeethReady = false;
    if (v != null) {
      v.removeListener(_onDirtyTeethTick);
      await v.dispose();
    }
  }

  void _onWaterPourTick() {
    final v = _waterPourController;
    if (v == null || !mounted) return;
    final value = v.value;
    if (!value.isInitialized || value.hasError) return;
    if (value.isCompleted) {
      v.removeListener(_onWaterPourTick);
      unawaited(v.pause());
      if (mounted) setState(() {});
    }
  }

  Future<void> _disposeWaterPour() async {
    _stopWaterPourCueLoop();
    _waterPourCopiedBubbles.clear();
    _waterPourBubbleEpochMs = null;
    final v = _waterPourController;
    _waterPourController = null;
    _waterPourReady = false;
    if (v != null) {
      v.removeListener(_onWaterPourTick);
      await v.dispose();
    }
  }

  /// Disposes any existing water-pour player without clearing the bubble snapshot.
  Future<void> _disposeWaterPourVideoOnly() async {
    final v = _waterPourController;
    _waterPourController = null;
    _waterPourReady = false;
    if (v != null) {
      v.removeListener(_onWaterPourTick);
      await v.dispose();
    }
  }

  Future<void> _startWaterPourVideo() async {
    if (!mounted) return;
    await _disposeWaterPourVideoOnly();
    if (!mounted) return;

    final v = VideoPlayerController.asset(
      kSaludWaterPourAsset,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    try {
      await v.initialize();
      if (!mounted) {
        await v.dispose();
        return;
      }
      await v.setLooping(false);
      v.addListener(_onWaterPourTick);
      await v.play();
      if (!mounted) {
        await v.dispose();
        return;
      }
      setState(() {
        _waterPourController = v;
        _waterPourReady = true;
      });
      _maybeStartWaterPourCueLoop();
    } catch (_) {
      await v.dispose();
      if (mounted) {
        setState(() {
          _waterPourCopiedBubbles.clear();
          _waterPourBubbleEpochMs = null;
        });
        _stopWaterPourCueLoop();
      }
    }
  }

  Future<void> _onMergeColgateCepillo() async {
    if (_mergeTriggered || !mounted) return;
    _mergeTriggered = true;
    await _instructions.stop();
    _cancelColgateIdleTimer();
    _cancelColgateSnap();
    _cepilloDragPulse.stop();
    _cepilloDragPulse.reset();
    _idleColgatePulse.stop();
    _idleColgatePulse.reset();
    setState(() {
      _propsHidden = true;
      _colgateDragging = false;
    });

    final v = VideoPlayerController.asset(
      kSaludToothpasteOnCepilloAsset,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    try {
      await v.initialize();
      if (!mounted) {
        await v.dispose();
        return;
      }
      await v.setLooping(false);
      v.addListener(_onMergeVideoTick);
      await v.play();
      if (!mounted) {
        await v.dispose();
        return;
      }
      setState(() {
        _mergeVideoController = v;
        _mergeVideoReady = true;
      });
    } catch (_) {
      await v.dispose();
      if (mounted) widget.onClose();
    }
  }

  Future<void> _disposeMergeVideo() async {
    final c = _mergeVideoController;
    _mergeVideoController = null;
    _mergeVideoReady = false;
    if (c != null) {
      c.removeListener(_onMergeVideoTick);
      await c.dispose();
    }
  }

  void _cancelCepilloCremaSnap() {
    if (_cepilloCremaSnapController.isAnimating) {
      final v = _snapCepilloCremaAnim?.value ?? _cepilloCremaPos;
      _cepilloCremaSnapController.stop();
      _cepilloCremaPos = v;
    }
    _snapCepilloCremaActive = false;
    _snapCepilloCremaAnim = null;
    _cepilloCremaSnapController.reset();
  }

  void _onCepilloCremaSnapComplete() {
    if (!mounted) return;

    if (_cepilloCremaSettlingPostCelebration) {
      _cepilloCremaSettlingPostCelebration = false;
      setState(() {
        _cepilloCremaPos = _kBathCepilloPos;
        _snapCepilloCremaActive = false;
        _snapCepilloCremaAnim = null;
        _cepilloCremaLockedAfterTask = true;
      });
      _cepilloCremaSnapController.reset();
      _maybeStartPostTaskProbeLoop();
      return;
    }

    setState(() {
      _cepilloCremaPos = _kBathCepilloPos;
      _snapCepilloCremaActive = false;
      _snapCepilloCremaAnim = null;
    });
    _cepilloCremaSnapController.reset();
    _scheduleCepilloCremaIdlePulse();
    _resumeBrushInstructionsIfIdle();
  }

  void _startCepilloCremaSnapBack() {
    if (!_cepilloCremaVisible || !mounted) return;
    if (_cepilloCremaLockedAfterTask || _cepilloCremaSettlingPostCelebration) {
      return;
    }

    _cancelCepilloCremaIdleTimer();

    final from = _snapCepilloCremaActive && _snapCepilloCremaAnim != null
        ? _snapCepilloCremaAnim!.value
        : _cepilloCremaPos;
    if ((from - _kBathCepilloPos).distance < 1.0) {
      _cancelCepilloCremaSnap();
      _cepilloCremaPos = _kBathCepilloPos;
      setState(() {});
      _scheduleCepilloCremaIdlePulse();
      _resumeBrushInstructionsIfIdle();
      return;
    }

    _cepilloCremaSnapController.stop();
    _cepilloCremaSnapController.reset();
    _snapCepilloCremaAnim = Tween<Offset>(begin: from, end: _kBathCepilloPos)
        .animate(
          CurvedAnimation(
            parent: _cepilloCremaSnapController,
            curve: Curves.elasticOut,
          ),
        );
    _snapCepilloCremaActive = true;
    setState(() {});
    unawaited(
      _cepilloCremaSnapController
          .forward(from: 0)
          .whenComplete(_onCepilloCremaSnapComplete),
    );
  }

  void _beginCepilloPostCelebrationSnap() {
    if (!mounted || !_cepilloCremaVisible) return;
    if (_cepilloCremaLockedAfterTask) return;
    if (_cepilloCremaSettlingPostCelebration) return;

    unawaited(_stopBrushInstructions());

    _cancelCepilloCremaIdleTimer();
    _idleCepilloCremaPulse.stop();
    _idleCepilloCremaPulse.reset();

    setState(() => _cepilloCremaDragging = false);

    final from = _effectiveCepilloCremaPos();
    if ((from - _kBathCepilloPos).distance < 1.0) {
      _cancelCepilloCremaSnap();
      setState(() {
        _cepilloCremaPos = _kBathCepilloPos;
        _cepilloCremaLockedAfterTask = true;
      });
      _maybeStartPostTaskProbeLoop();
      return;
    }

    _cepilloCremaSettlingPostCelebration = true;
    _cepilloCremaSnapController.stop();
    _cepilloCremaSnapController.reset();
    _snapCepilloCremaAnim = Tween<Offset>(begin: from, end: _kBathCepilloPos)
        .animate(
          CurvedAnimation(
            parent: _cepilloCremaSnapController,
            curve: Curves.elasticOut,
          ),
        );
    _snapCepilloCremaActive = true;
    setState(() {});
    unawaited(
      _cepilloCremaSnapController
          .forward(from: 0)
          .whenComplete(_onCepilloCremaSnapComplete),
    );
  }

  void _cancelCepilloCremaIdleTimer() {
    _idleCepilloCremaTimer?.cancel();
    _idleCepilloCremaTimer = null;
  }

  void _scheduleCepilloCremaIdlePulse() {
    _cancelCepilloCremaIdleTimer();
    if (!_cepilloCremaVisible || !mounted) return;
    if (_cepilloCremaLockedAfterTask) return;
    _idleCepilloCremaTimer = Timer(
      const Duration(seconds: 3),
      _onCepilloCremaIdleTimer,
    );
  }

  Future<void> _onCepilloCremaIdleTimer() async {
    _idleCepilloCremaTimer = null;
    if (!mounted || !_cepilloCremaVisible || _cepilloCremaLockedAfterTask) {
      return;
    }
    if (_cepilloCremaDragging || _snapCepilloCremaActive) {
      _scheduleCepilloCremaIdlePulse();
      return;
    }
    await _idleCepilloCremaPulse.forward(from: 0);
    if (!mounted) return;
    _idleCepilloCremaPulse.reset();
    _scheduleCepilloCremaIdlePulse();
  }

  double _cepilloCremaDisplayScale() {
    if (_cepilloCremaLockedAfterTask) return 1.0;
    if (_cepilloCremaDragging || _snapCepilloCremaActive) return 1.0;
    return _idleCepilloCremaScale.value;
  }

  Offset _effectiveCepilloCremaPos() {
    if (_snapCepilloCremaActive && _snapCepilloCremaAnim != null) {
      return _snapCepilloCremaAnim!.value;
    }
    return _cepilloCremaPos;
  }

  Rect _teethScrubRect() {
    return Rect.fromLTWH(
      _kTeethScrubZonePos.dx,
      _kTeethScrubZonePos.dy,
      _kTeethScrubZoneW,
      _kTeethScrubZoneH,
    );
  }

  Rect? _cepilloCremaPasteHitRect() {
    final w = _cepilloCremaAssetSize?.width;
    final h = _cepilloCremaAssetSize?.height;
    if (w == null || h == null || w <= 0 || h <= 0) return null;

    final s = _cepilloCremaDisplayScale();
    final pos = _effectiveCepilloCremaPos();
    final sw = w * s;
    final sh = h * s;
    final left = pos.dx + w * (1 - s) / 2;
    final top = pos.dy + h * (1 - s) / 2;
    return Rect.fromLTWH(
      left,
      top,
      sw * _kPasteHitFracW,
      sh * _kPasteHitFracH,
    );
  }

  Color _randomScrubBubbleColor(math.Random rng) {
    final roll = rng.nextDouble();
    final white = _kScrubBubblePalette[0];
    final cyan = _kScrubBubblePalette[1];
    final purple = _kScrubBubblePalette[2];

    if (roll < 0.6) {
      final n = rng.nextInt(10);
      return Color.fromRGBO(255 - n, 255 - n, 255 - n, 1);
    }
    if (roll < 0.8) {
      return Color.lerp(white, cyan, 0.25 + rng.nextDouble() * 0.35)!;
    }
    return Color.lerp(white, purple, 0.25 + rng.nextDouble() * 0.35)!;
  }

  bool _hasAnimatingScrubBubbles(int now, int lifetimeMs) {
    return _scrubBubbles.any((b) => now - b.birthMs < lifetimeMs);
  }

  void _triggerScrubCapCelebration() {
    if (_scrubCapCelebrationShown || !_teethScrubZoneActive) return;
    _scrubCapCelebrationShown = true;
    _scrubTaskComplete = true;

    final center = _teethScrubRect().center;
    final now = DateTime.now().millisecondsSinceEpoch;
    final rng = math.Random();
    const count = 20;
    for (var i = 0; i < count; i++) {
      final angle = (i / count) * 2 * math.pi + rng.nextDouble() * 0.25;
      final speed = 140 + rng.nextDouble() * 200;
      final roll = rng.nextDouble();
      final Color starColor;
      if (roll < 0.6) {
        starColor = const Color.fromRGBO(255, 255, 255, 1);
      } else if (roll < 0.8) {
        starColor = _kScrubBubblePalette[1];
      } else {
        starColor = _kScrubBubblePalette[2];
      }
      _scrubCompletionStars.add(
        _CompletionStar(
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
    if (!_bubbleAnimController.isAnimating) {
      _bubbleAnimController.repeat();
    }
    if (mounted) setState(() {});
  }

  Widget _scrubCompletionStarWidget(_CompletionStar s) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final t = ((now - s.birthMs) / _kScrubStarLifetimeMs).clamp(0.0, 1.0);
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

  void _onBubbleAnimTick() {
    final now = DateTime.now().millisecondsSinceEpoch;
    const lifetimeMs = 900;

    final hadStarsThisFrame = _scrubCompletionStars.isNotEmpty;

    final expired = <_ScrubBubble>[];
    for (final b in _scrubBubbles) {
      if (!b.permanent && now - b.birthMs > lifetimeMs) {
        expired.add(b);
      }
    }
    for (final b in expired) {
      _scrubBubbles.remove(b);
    }

    _scrubCompletionStars.removeWhere(
      (s) => now - s.birthMs > _kScrubStarLifetimeMs,
    );

    if (_scrubCapCelebrationShown &&
        !_cepilloCremaLockedAfterTask &&
        hadStarsThisFrame &&
        _scrubCompletionStars.isEmpty) {
      _beginCepilloPostCelebrationSnap();
    }

    final needsTick = _hasAnimatingScrubBubbles(now, lifetimeMs) ||
        _scrubCompletionStars.isNotEmpty;
    if (!needsTick) {
      _bubbleAnimController.stop();
    }
    if (mounted) setState(() {});
  }

  void _trySpawnScrubBubbles() {
    if (!_cepilloCremaDragging || !_teethScrubZoneActive) return;
    if (_scrubTaskComplete) return;

    final paste = _cepilloCremaPasteHitRect();
    if (paste == null) return;

    final teeth = _teethScrubRect();
    if (!teeth.overlaps(paste)) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastBubbleSpawnMs < 70) return;
    _lastBubbleSpawnMs = now;

    final hit = teeth.intersect(paste);
    final rng = math.Random();
    final permanent = _bubbleSpawnCycleIndex != 0;
    _bubbleSpawnCycleIndex = (_bubbleSpawnCycleIndex + 1) % 4;

    _scrubBubbles.add(
      _ScrubBubble(
        position: hit.center,
        birthMs: now,
        drift: Offset(
          (rng.nextDouble() - 0.5) * 32,
          (rng.nextDouble() - 0.5) * 28 - 10,
        ),
        baseRadius: 18 + rng.nextDouble() * 20,
        color: _randomScrubBubbleColor(rng),
        permanent: permanent,
      ),
    );
    while (_scrubBubbles.length > _kMaxScrubBubbles) {
      final transientIdx = _scrubBubbles.indexWhere((b) => !b.permanent);
      if (transientIdx >= 0) {
        _scrubBubbles.removeAt(transientIdx);
      } else {
        _scrubBubbles.removeAt(0);
      }
    }
    if (!_scrubCapCelebrationShown &&
        _scrubBubbles.length >= _kMaxScrubBubbles) {
      _triggerScrubCapCelebration();
    }
    if (!_bubbleAnimController.isAnimating) {
      _bubbleAnimController.repeat();
    }
    if (mounted) setState(() {});
  }

  Widget _scrubBubbleWidgetAtEpoch(_ScrubBubble b, int epochMs) {
    const lifetimeMs = 900;
    final rawT = (epochMs - b.birthMs) / lifetimeMs;
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

  Widget _scrubBubbleWidget(_ScrubBubble b) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return _scrubBubbleWidgetAtEpoch(b, now);
  }

  Widget _interactiveCepilloConCrema() {
    return IgnorePointer(
      ignoring: _cepilloCremaSettlingPostCelebration,
      child: GestureDetector(
        onPanStart: (_) {
          _cancelCepilloCremaIdleTimer();
          _idleCepilloCremaPulse.stop();
          _idleCepilloCremaPulse.reset();
          _cancelCepilloCremaSnap();
          _pauseBrushInstructions();
          setState(() => _cepilloCremaDragging = true);
        },
        onPanEnd: (_) {
          setState(() => _cepilloCremaDragging = false);
          _startCepilloCremaSnapBack();
        },
        onPanCancel: () {
          setState(() => _cepilloCremaDragging = false);
          _startCepilloCremaSnapBack();
        },
        onPanUpdate: (details) {
          setState(() => _cepilloCremaPos += details.delta);
          _trySpawnScrubBubbles();
        },
        child: Image.asset(kSaludBathCepilloConCremaPng),
      ),
    );
  }

  void _maybeStartPostTaskProbeLoop() {
    if (!mounted ||
        !_cepilloCremaLockedAfterTask ||
        _postTaskProbeDismissed) {
      return;
    }
    if (_postTaskProbeLoopStarted) return;
    _postTaskProbeLoopStarted = true;
    _postTaskProbePulseController.repeat();
    _startWaterCupInstructions();
  }

  void _onPostTaskProbeTap() {
    if (!mounted ||
        !_cepilloCremaLockedAfterTask ||
        _postTaskProbeDismissed) {
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    _stopPostTaskProbeLoop();
    setState(() {
      _postTaskProbeDismissed = true;
      _waterPourBubbleEpochMs = now;
      _waterPourCopiedBubbles = [
        for (final b in _scrubBubbles)
          _ScrubBubble(
            position: b.position,
            birthMs: b.birthMs,
            drift: b.drift,
            baseRadius: b.baseRadius,
            color: b.color,
            permanent: b.permanent,
          ),
      ];
    });
    unawaited(_startWaterPourVideo());
  }

  void _stopPostTaskProbeLoop() {
    _postTaskProbePulseController.stop();
    _postTaskProbePulseController.reset();
    _postTaskProbeLoopStarted = false;
  }

  double _postTaskProbeIdleLeadMs(double periodMs, double rampMs) {
    return math.max(0.0, (periodMs - 4 * rampMs) / 2);
  }

  ({double peakOpacity, double scale}) _postTaskProbePairAt(
    double ms,
    double rampMs,
    double pairStartMs,
  ) {
    if (ms <= pairStartMs) {
      return (peakOpacity: 0.0, scale: 1.0);
    }
    if (ms <= pairStartMs + rampMs) {
      final u = Curves.easeInOut.transform((ms - pairStartMs) / rampMs);
      return (peakOpacity: 0.5 * u, scale: 1.0 - 0.2 * u);
    }
    if (ms <= pairStartMs + rampMs + rampMs) {
      final u =
          Curves.easeInOut.transform((ms - pairStartMs - rampMs) / rampMs);
      return (peakOpacity: 0.5 * (1.0 - u), scale: 0.8 + 0.2 * u);
    }
    return (peakOpacity: 0.0, scale: 1.0);
  }

  ({double peakOpacity, double scale}) _postTaskProbePeakAndScale(double normalizedT) {
    final periodMs = _kPostTaskProbePulsePeriod.inMilliseconds.toDouble();
    const rampMs = _kPostTaskProbeRampMs;
    final ms = normalizedT * periodMs;
    final idleLead = _postTaskProbeIdleLeadMs(periodMs, rampMs);
    final p1 = idleLead;
    final p2 = idleLead + 2 * rampMs;

    final v1 = _postTaskProbePairAt(ms, rampMs, p1);
    if (v1.peakOpacity > 0 || v1.scale < 1.0) {
      return v1;
    }
    return _postTaskProbePairAt(ms, rampMs, p2);
  }

  Widget _postTaskLayoutProbe() {
    return AnimatedBuilder(
      animation: _postTaskProbePulseController,
      builder: (context, child) {
        final t = _postTaskProbePulseController.value;
        final viz = _postTaskProbePeakAndScale(t);
        return Transform.scale(
          scale: viz.scale,
          alignment: Alignment.center,
          child: SizedBox(
            width: _kPostTaskProbeSize,
            height: _kPostTaskProbeSize,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: viz.peakOpacity),
              ),
            ),
          ),
        );
      },
    );
  }

  void _onWaterPourCueTap() {
    if (!mounted || !_waterPourReady || _waterPourCueDismissed) return;
    _stopWaterPourCueLoop();
    _startWaterMouthInstructions();
    setState(() {
      _waterPourCueDismissed = true;
      _cowPhase2Active = true;
    });
  }

  void _maybeStartWaterPourCueLoop() {
    if (!mounted ||
        !_waterPourReady ||
        _waterPourCueDismissed ||
        _waterPourCueLoopStarted) {
      return;
    }
    _waterPourCueLoopStarted = true;
    _waterPourCuePulseController.reset();
    _waterPourCuePulseController.repeat();
  }

  void _stopWaterPourCueLoop() {
    _waterPourCuePulseController.stop();
    _waterPourCuePulseController.reset();
    _waterPourCueLoopStarted = false;
  }

  Widget _waterPourCueCircle() {
    return Positioned(
      left: _kWaterPourCuePos.dx,
      top: _kWaterPourCuePos.dy,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _onWaterPourCueTap,
        child: AnimatedBuilder(
          animation: _waterPourCuePulseController,
          builder: (context, child) {
            final t = _waterPourCuePulseController.value;
            final viz = _postTaskProbePeakAndScale(t);
            return Transform.scale(
              scale: viz.scale,
              alignment: Alignment.center,
              child: SizedBox(
                width: _kPostTaskProbeSize,
                height: _kPostTaskProbeSize,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: viz.peakOpacity),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
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
    if (!_propsHidden && !_mergeTriggered) {
      _scheduleColgateIdlePulse();
    }
  }

  void _startColgateSnapBack() {
    _cancelColgateIdleTimer();
    if (!_bathAnimFinished || !mounted) return;
    if (_propsHidden || _mergeTriggered) return;

    final from = _snapColgateActive && _snapColgateAnim != null
        ? _snapColgateAnim!.value
        : _colgatePos;
    if ((from - _kBathColgatePos).distance < 1.0) {
      _cancelColgateSnap();
      _colgatePos = _kBathColgatePos;
      setState(() {});
      if (!_propsHidden && !_mergeTriggered) {
        _scheduleColgateIdlePulse();
      }
      return;
    }

    _colgateSnapController.stop();
    _colgateSnapController.reset();
    _snapColgateAnim = Tween<Offset>(begin: from, end: _kBathColgatePos)
        .animate(
          CurvedAnimation(
            parent: _colgateSnapController,
            curve: Curves.elasticOut,
          ),
        );
    _snapColgateActive = true;
    setState(() {});
    unawaited(
      _colgateSnapController
          .forward(from: 0)
          .whenComplete(_onColgateSnapComplete),
    );
  }

  void _cancelColgateIdleTimer() {
    _idleColgateTimer?.cancel();
    _idleColgateTimer = null;
  }

  void _scheduleColgateIdlePulse() {
    _cancelColgateIdleTimer();
    if (!_bathAnimFinished || !mounted) return;
    if (_propsHidden || _mergeTriggered) return;
    _idleColgateTimer = Timer(const Duration(seconds: 3), _onColgateIdleTimer);
  }

  Future<void> _onColgateIdleTimer() async {
    _idleColgateTimer = null;
    if (!mounted || !_bathAnimFinished) return;
    if (_propsHidden || _mergeTriggered) return;
    if (_colgateDragging || _snapColgateActive) {
      _scheduleColgateIdlePulse();
      return;
    }
    await _idleColgatePulse.forward(from: 0);
    if (!mounted) return;
    _idleColgatePulse.reset();
    _scheduleColgateIdlePulse();
  }

  @override
  void initState() {
    super.initState();
    _idleColgatePulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _idleColgateScale =
        TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween<double>(begin: 1.0, end: 1.3),
            weight: 50,
          ),
          TweenSequenceItem(
            tween: Tween<double>(begin: 1.3, end: 1.0),
            weight: 50,
          ),
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
    _cepilloCremaSnapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _bubbleAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..addListener(_onBubbleAnimTick);
    _idleCepilloCremaPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _idleCepilloCremaScale =
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
          CurvedAnimation(
            parent: _idleCepilloCremaPulse,
            curve: Curves.easeInOut,
          ),
        );
    _postTaskProbePulseController = AnimationController(
      vsync: this,
      duration: _kPostTaskProbePulsePeriod,
    );
    _waterPourCuePulseController = AnimationController(
      vsync: this,
      duration: _kPostTaskProbePulsePeriod,
    );
    _pickHeld = widget.pickController;
    unawaited(_loadPropAssetSizes());
    unawaited(_runCowPickToBathSequence());
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
        unawaited(_instructions.start(SaludInstructionAudio.cremaACepillo));
      }
    }
  }

  Future<void> _disposeBath() async {
    _stopPostTaskProbeLoop();
    _cancelColgateIdleTimer();
    _cancelColgateSnap();
    _cancelCepilloCremaIdleTimer();
    _idleCepilloCremaPulse.stop();
    _idleCepilloCremaPulse.reset();
    _cancelCepilloCremaSnap();
    _cepilloDragPulse.stop();
    _cepilloDragPulse.reset();
    _idleColgatePulse.stop();
    _idleColgatePulse.reset();
    final b = _bathController;
    _bathController = null;
    _bathReady = false;
    _bathAnimFinished = false;
    if (mounted) {
      setState(() {
        _cepilloCremaVisible = false;
        _teethScrubZoneActive = false;
        _scrubBubbles.clear();
        _scrubCompletionStars.clear();
        _bubbleSpawnCycleIndex = 0;
        _scrubTaskComplete = false;
        _scrubCapCelebrationShown = false;
        _cepilloCremaLockedAfterTask = false;
        _cepilloCremaSettlingPostCelebration = false;
        _postTaskProbeDismissed = false;
        _waterPourCueDismissed = false;
        _cowPhase2Active = false;
      });
    }
    await _disposeDirtyTeeth();
    await _disposeWaterPour();
    if (b != null) {
      b.removeListener(_onBathTick);
      await b.dispose();
    }
  }

  Future<void> _runCowPickToBathSequence() async {
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
        _bathAnimFinished = false;
      });

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

  Future<void> _disposeEnding() async {
    final v = _endingController;
    _endingController = null;
    _endingReady = false;
    _endingVisible = false;
    _endingHoldPassed = false;
    if (v != null) {
      v.removeListener(_onEndingTick);
      await v.dispose();
    }
    if (mounted) setState(() {});
  }

  void _onEndingTick() {
    final v = _endingController;
    if (v == null || !mounted || _endingHoldPassed) return;
    final value = v.value;
    if (!value.isInitialized || value.hasError) return;
    if (!value.isCompleted) return;
    _endingHoldPassed = true;
    v.removeListener(_onEndingTick);
    unawaited(_onEndingVideoFinished());
  }

  Future<void> _onEndingVideoFinished() async {
    final v = _endingController;
    if (v != null) await v.pause();
    await Future<void>.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    await _fadeToWhiteTeardownAndReturnToMenu();
  }

  void _onCowPhase2Complete() {
    if (_endingSequenceStarted || !mounted) return;
    unawaited(_stopWaterInstructions());
    unawaited(_runCowEndingSequence());
  }

  Future<void> _prepareForEndingPlayback() async {
    final dirty = _dirtyTeethController;
    if (dirty != null && dirty.value.isInitialized) {
      await dirty.pause();
    }
    final water = _waterPourController;
    if (water != null && water.value.isInitialized) {
      await water.pause();
    }
  }

  Future<void> _runCowEndingSequence() async {
    if (_endingSequenceStarted) return;
    _endingSequenceStarted = true;
    if (mounted) {
      setState(() {
        _cowPhase2Active = false;
        _teethScrubZoneActive = false;
        _scrubBubbles.clear();
        _scrubCompletionStars.clear();
      });
    }
    await _prepareForEndingPlayback();

    final ending = VideoPlayerController.asset(
      kSaludCowEndingAsset,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    try {
      await ending.initialize();
      if (!mounted) {
        await ending.dispose();
        return;
      }
      await ending.setLooping(false);
      ending.addListener(_onEndingTick);
      await ending.play();
      if (!mounted) {
        ending.removeListener(_onEndingTick);
        await ending.dispose();
        return;
      }
      setState(() {
        _endingController = ending;
        _endingReady = true;
        _endingVisible = true;
      });
    } catch (_) {
      ending.removeListener(_onEndingTick);
      await ending.dispose();
      if (mounted) await _fadeToWhiteTeardownAndReturnToMenu();
    }
  }

  Future<void> _fadeToWhiteTeardownAndReturnToMenu() async {
    if (!mounted || _exitingToMenu) return;
    _exitingToMenu = true;

    _whiteFade?.dispose();
    _whiteFade = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    setState(() {});
    await _whiteFade!.forward();
    if (!mounted) return;

    _whiteFade?.dispose();
    _whiteFade = null;
    if (mounted) widget.onClose();
  }

  void _exitBathAndClose() {
    if (_exitingToMenu) return;
    _exitingToMenu = true;
    widget.onClose();
  }

  Widget _interactiveColgate() {
    return GestureDetector(
      onPanStart: (_) {
        if (_mergeTriggered) return;
        _cancelColgateSnap();
        _cancelColgateIdleTimer();
        _idleColgatePulse.stop();
        _idleColgatePulse.reset();
        setState(() => _colgateDragging = true);
        _cepilloDragPulse.repeat(reverse: true);
      },
      onPanEnd: (_) {
        if (_mergeTriggered) return;
        _cepilloDragPulse.stop();
        _cepilloDragPulse.reset();
        setState(() => _colgateDragging = false);
        _startColgateSnapBack();
      },
      onPanCancel: () {
        if (_mergeTriggered) return;
        _cepilloDragPulse.stop();
        _cepilloDragPulse.reset();
        setState(() => _colgateDragging = false);
        _startColgateSnapBack();
      },
      onPanUpdate: (details) {
        if (_mergeTriggered) return;
        setState(() => _colgatePos += details.delta);
        if (_colgateOverlapsCepilloHitbox()) {
          unawaited(_onMergeColgateCepillo());
        }
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
    unawaited(_instructions.dispose());
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
    _cancelCepilloCremaIdleTimer();
    _idleCepilloCremaPulse.stop();
    _idleCepilloCremaPulse.dispose();
    _idleColgatePulse.stop();
    _idleColgatePulse.dispose();
    _colgateSnapController.dispose();
    _cepilloDragPulse.dispose();
    _cancelCepilloCremaSnap();
    _cepilloCremaSnapController.dispose();
    _bubbleAnimController.dispose();
    _postTaskProbePulseController.dispose();
    _stopWaterPourCueLoop();
    _waterPourCuePulseController.dispose();
    final merge = _mergeVideoController;
    _mergeVideoController = null;
    _mergeVideoReady = false;
    if (merge != null) {
      merge.removeListener(_onMergeVideoTick);
      unawaited(merge.dispose());
    }
    final dirty = _dirtyTeethController;
    _dirtyTeethController = null;
    _dirtyTeethReady = false;
    if (dirty != null) {
      dirty.removeListener(_onDirtyTeethTick);
      unawaited(dirty.dispose());
    }
    final water = _waterPourController;
    _waterPourController = null;
    _waterPourReady = false;
    _waterPourCopiedBubbles.clear();
    _waterPourBubbleEpochMs = null;
    if (water != null) {
      water.removeListener(_onWaterPourTick);
      unawaited(water.dispose());
    }
    final ending = _endingController;
    if (ending != null) {
      ending.removeListener(_onEndingTick);
      unawaited(ending.dispose());
    }
    super.dispose();
  }

  Widget _fullscreenVideo(VideoPlayerController controller) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: FittedBox(
          fit: BoxFit.fill,
          child: SizedBox(
            width: _kLogicalW,
            height: _kLogicalH,
            child: VideoPlayer(controller),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_endingVisible && _endingReady && _endingController != null)
            Positioned.fill(child: _fullscreenVideo(_endingController!))
          else if (_endingSequenceStarted)
            const Positioned.fill(child: ColoredBox(color: Colors.black))
          else if (!_bathReady || _bathController == null)
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
                        children: [
                          Positioned.fill(
                            child: _pickHeld != null
                                ? VideoPlayer(_pickHeld!)
                                : const ColoredBox(color: Colors.black),
                          ),
                          GameLogicalBackPill(
                            onPressed: _exitBathAndClose,
                          ),
                        ],
                      ),
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
                          if (_dirtyTeethReady && _dirtyTeethController != null)
                            Positioned.fill(
                              child: VideoPlayer(_dirtyTeethController!),
                            ),
                          if (_teethScrubZoneActive)
                            ..._scrubBubbles.map(_scrubBubbleWidget),
                          if (_teethScrubZoneActive)
                            ..._scrubCompletionStars.map(
                              _scrubCompletionStarWidget,
                            ),
                          if (!_propsHidden)
                            Positioned(
                              left: _kBathCepilloPos.dx,
                              top: _kBathCepilloPos.dy,
                              child: _bathAnimFinished
                                  ? AnimatedBuilder(
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
                                    )
                                  : Image.asset(kSaludBathCepilloPng),
                            ),
                          if (!_propsHidden)
                            AnimatedBuilder(
                              animation: Listenable.merge([
                                _idleColgatePulse,
                                _colgateSnapController,
                              ]),
                              builder: (context, child) {
                                final pos =
                                    _snapColgateActive &&
                                        _snapColgateAnim != null
                                    ? _snapColgateAnim!.value
                                    : _colgatePos;
                                return Positioned(
                                  left: pos.dx,
                                  top: pos.dy,
                                  child: child!,
                                );
                              },
                              child: _bathAnimFinished
                                  ? _interactiveColgate()
                                  : Image.asset(kSaludBathColgatePng),
                            ),
                          if (_mergeVideoReady && _mergeVideoController != null)
                            Positioned.fill(
                              child: VideoPlayer(_mergeVideoController!),
                            ),
                          if (_cepilloCremaVisible && _cepilloCremaLockedAfterTask)
                            Positioned(
                              left: _kBathCepilloPos.dx,
                              top: _kBathCepilloPos.dy,
                              child: Image.asset(kSaludBathCepilloConCremaPng),
                            )
                          else if (_cepilloCremaVisible)
                            AnimatedBuilder(
                              animation: Listenable.merge([
                                _cepilloCremaSnapController,
                                _idleCepilloCremaPulse,
                              ]),
                              builder: (context, child) {
                                final pos =
                                    _snapCepilloCremaActive &&
                                        _snapCepilloCremaAnim != null
                                    ? _snapCepilloCremaAnim!.value
                                    : _cepilloCremaPos;
                                return Positioned(
                                  left: pos.dx,
                                  top: pos.dy,
                                  child: Transform.scale(
                                    scale: _cepilloCremaDisplayScale(),
                                    alignment: Alignment.center,
                                    child: child!,
                                  ),
                                );
                              },
                              child: _interactiveCepilloConCrema(),
                            ),
                          if (_waterPourReady && _waterPourController != null)
                            Positioned.fill(
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Positioned.fill(
                                    child:
                                        VideoPlayer(_waterPourController!),
                                  ),
                                  if (_waterPourBubbleEpochMs != null &&
                                      _waterPourCopiedBubbles.isNotEmpty)
                                    ..._waterPourCopiedBubbles.map(
                                      (bubble) =>
                                          _scrubBubbleWidgetAtEpoch(
                                            bubble,
                                            _waterPourBubbleEpochMs!,
                                          ),
                                    ),
                                  if (!_waterPourCueDismissed)
                                    _waterPourCueCircle(),
                                ],
                              ),
                            ),
                          if (_cowPhase2Active)
                            Positioned.fill(
                              child: SaludCowGame2Layer(
                                onPhaseComplete: _onCowPhase2Complete,
                              ),
                            ),
                          if (_cepilloCremaLockedAfterTask &&
                              !_postTaskProbeDismissed)
                            Positioned(
                              left: _kPostTaskProbePos.dx,
                              top: _kPostTaskProbePos.dy,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: _onPostTaskProbeTap,
                                child: _postTaskLayoutProbe(),
                              ),
                            ),
                          if (!_endingSequenceStarted)
                            GameLogicalBackPill(
                              onPressed: _exitBathAndClose,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          _whiteFadeOverlay(),
        ],
      ),
    );
  }
}
