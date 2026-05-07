import 'dart:async';
import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame_texturepacker/flame_texturepacker.dart';
import 'package:flutter/painting.dart';

import '../games/salud_constants.dart';
import 'salud_animal_common.dart';

/// LibGDX atlases under `assets/images/`.
const String kCowJumpingAtlasAsset = 'cowAnimations/jumping/jumping.atlas';

const String kCowJumpToIdleAtlasAsset =
    'cowAnimations/jumpToIdle/jumpToIdle.atlas';

const String kCowStaticPngAsset = 'cow.png';
const String kCowAtlasNamePreferred = 'cow';

const int kCowJumpLoopsOnEnter = 3;

/// Tweaking knobs for SALUD intro walk + clip.
class SaludCowTuning {
  const SaludCowTuning({
    this.cowEnterStartX = -154,
    this.cowIdleCenterX = 538,
    this.cowExitEndX = 1728,
    this.cowFeetBaselineY = 929,
    this.cowClipLineX = 1325,
    this.showClipDebugLine = false,
    this.clipDebugLineWidthPx = 2,
    this.clipDebugLineColor = const Color(0xCCFF1744),
    this.walkSpeedPixelsPerSecond = 240,
  });

  final double cowEnterStartX;
  final double cowIdleCenterX;
  final double cowExitEndX;
  final double cowFeetBaselineY;
  final double cowClipLineX;
  final bool showClipDebugLine;
  final double clipDebugLineWidthPx;
  final Color clipDebugLineColor;
  final double walkSpeedPixelsPerSecond;
}

enum SaludCowPhase { entering, idle, exiting, done }

/// Cow strip: jump ×3 → jump‑to‑idle → static → tap → jumping exit.
final class SaludCowActor extends PositionComponent
    with HasGameReference<FlameGame>, TapCallbacks {
  SaludCowActor({
    required this.tuning,
    required this.startX,
    required this.idleX,
    required this.exitX,
    required this.onIdleTap,
    this.onExitFinished,
    this.enableClip = true,
  }) : super(anchor: Anchor.bottomCenter);

  final SaludCowTuning tuning;
  final double startX;
  final double idleX;
  final double exitX;
  final VoidCallback onIdleTap;
  final VoidCallback? onExitFinished;
  final bool enableClip;

  static const double _arrive = 4;

  bool _visualReady = false;
  bool _resizeScheduled = false;

  ClipComponent? _clipRoot;
  SpriteAnimationComponent? _animComp;

  late SpriteAnimation _jumpingLoopTemplate;
  late SpriteAnimation _enterOnceTemplate;
  late SpriteAnimation _staticTemplate;

  bool _enterSequenceDone = false;

  Vector2 _displaySize = Vector2.zero();

  SaludCowPhase _phase = SaludCowPhase.entering;
  bool _exitFinishNotified = false;
  bool _tapEnabled = true;

  double _clipLineX = 0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
  }

  void syncLayout(Vector2 logicalSize) {
    _clipLineX = tuning.cowClipLineX;
    position.y = tuning.cowFeetBaselineY;

    if (!_visualReady && !_resizeScheduled) {
      _resizeScheduled = true;
      scheduleMicrotask(() => unawaited(_firstPaint()));
    } else if (_visualReady) {
      _applyResize();
    }
  }

  void _applyResize() {
    _displaySize = _cowDisplaySize();

    position.y = tuning.cowFeetBaselineY;
    _clipLineX = tuning.cowClipLineX;

    _animComp?.size.setFrom(_displaySize);
    _clipRoot?.size.setFrom(_displaySize);
    size.setValues(_displaySize.x, _displaySize.y);
    _updateClipWindow();

    switch (_phase) {
      case SaludCowPhase.idle:
        position.x = idleX;
        break;
      case SaludCowPhase.done:
        position.x = exitX;
        break;
      case SaludCowPhase.entering:
      case SaludCowPhase.exiting:
        break;
    }
  }

  Future<void> _firstPaint() async {
    assert(game.hasLayout, 'Salud cow needs layout before first paint');

    _displaySize = _cowDisplaySize();

    final jumpAtlas = await game.atlasFromAssets(kCowJumpingAtlasAsset);
    final idleAtlas = await game.atlasFromAssets(kCowJumpToIdleAtlasAsset);
    final jumpFrames = saludIndexedFramesFromAtlas(
      jumpAtlas,
      preferredName: kCowAtlasNamePreferred,
      atlasLabelForAssert: kCowJumpingAtlasAsset,
    );
    final jumpToIdleFrames = saludIndexedFramesFromAtlas(
      idleAtlas,
      preferredName: kCowAtlasNamePreferred,
      atlasLabelForAssert: kCowJumpToIdleAtlasAsset,
    );

    _jumpingLoopTemplate = saludSpriteAnim(
      jumpFrames,
      loop: true,
      stepTime: kSaludCowAnimStepTime,
    );
    _enterOnceTemplate = saludComposeEnterWalk(
      jumpFrames: jumpFrames,
      jumpToIdleFrames: jumpToIdleFrames,
      jumpLoops: kCowJumpLoopsOnEnter,
      stepTime: kSaludCowAnimStepTime,
    );

    final idleSprite = await game.loadSprite(kCowStaticPngAsset);
    _staticTemplate = saludSpriteAnim(
      [idleSprite],
      loop: true,
      stepTime: kSaludCowAnimStepTime,
    );

    _animComp = SpriteAnimationComponent(
      animation: _enterOnceTemplate.clone(),
      size: _displaySize,
      anchor: Anchor.bottomCenter,
      position: Vector2(_displaySize.x / 2, _displaySize.y),
    );

    _clipRoot = ClipComponent.rectangle(
      position: Vector2.zero(),
      size: _displaySize.clone(),
      anchor: Anchor.topLeft,
    )..add(_animComp!);

    size.setFrom(_displaySize);
    position.x = startX;
    _phase = SaludCowPhase.entering;
    _enterSequenceDone = false;
    _exitFinishNotified = false;
    add(_clipRoot!);
    _updateClipWindow();

    final enterTicker = _animComp!.animationTicker!;
    enterTicker.reset();
    unawaited(
      enterTicker.completed.then((_) {
        if (!isMounted || !_visualReady || _phase != SaludCowPhase.entering) {
          return;
        }
        _enterSequenceDone = true;
        _useStaticCow();
        _trySettleIdleAtCenter();
      }),
    );

    _visualReady = true;
  }

  Vector2 _cowDisplaySize() => Vector2.all(saludDefaultAnimalDrawPx());

  void _updateClipWindow() {
    if (_clipRoot == null || !enableClip) return;
    final actorLeftX = position.x - (size.x * anchor.x);
    final clipW = (_clipLineX - actorLeftX).clamp(0.0, size.x);
    _clipRoot!.size.setValues(clipW.toDouble(), size.y);
  }

  void _useJumpingLoop() {
    final c = _animComp!;
    c.animation = _jumpingLoopTemplate.clone();
    c.animationTicker!.reset();
  }

  void _useStaticCow() {
    final c = _animComp!;
    c.animation = _staticTemplate.clone();
    c.animationTicker!.reset();
  }

  void _trySettleIdleAtCenter() {
    if (_phase != SaludCowPhase.entering) return;
    if (!_enterSequenceDone) return;
    if (idleX - position.x > _arrive) return;
    position.x = idleX;
    _phase = SaludCowPhase.idle;
    _useStaticCow();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!_visualReady) return;

    final spd = tuning.walkSpeedPixelsPerSecond;

    switch (_phase) {
      case SaludCowPhase.entering:
        position.x = math.min(position.x + spd * dt, idleX);
        _trySettleIdleAtCenter();
        break;
      case SaludCowPhase.exiting:
        position.x = math.min(position.x + spd * dt, exitX);
        if (exitX - position.x <= _arrive) {
          position.x = exitX;
          _phase = SaludCowPhase.done;
          _useStaticCow();
          if (!_exitFinishNotified) {
            _exitFinishNotified = true;
            onExitFinished?.call();
          }
        }
        break;
      case SaludCowPhase.idle:
      case SaludCowPhase.done:
        break;
    }
    _updateClipWindow();
  }

  void _beginExitJumpWalk() {
    _phase = SaludCowPhase.exiting;
    _useJumpingLoop();
  }

  void setTapEnabled(bool enabled) {
    _tapEnabled = enabled;
  }

  bool get isIdle => _phase == SaludCowPhase.idle;

  @override
  void onTapUp(TapUpEvent event) {
    super.onTapUp(event);
    if (_tapEnabled && _phase == SaludCowPhase.idle) {
      onIdleTap();
    }
  }

  void startExit() => _beginExitJumpWalk();
}
