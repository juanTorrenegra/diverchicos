import 'dart:async';
import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame_texturepacker/flame_texturepacker.dart';
import 'package:flutter/painting.dart';

import '../games/salud_constants.dart';
import 'cow.dart';
import 'salud_animal_common.dart';

// Static + atlas keys for the cat (swap paths when `catAnimations/` atlases exist).
const String kCatStaticPngAsset = 'cat.png';

/// Reuses cow jump atlases until cat-specific strips are added in assets
const String kCatJumpingAtlasAsset = kCowJumpingAtlasAsset;
const String kCatJumpToIdleAtlasAsset = kCowJumpToIdleAtlasAsset;
const String kCatAtlasNamePreferred = kCowAtlasNamePreferred;

enum SaludCatPhase { entering, idle, exiting, done }

/// Same pipeline as [SaludCowActor], with cat static frame and shared atlas paths.
final class SaludCatActor extends PositionComponent
    with HasGameReference<FlameGame>, TapCallbacks {
  SaludCatActor({required this.tuning, this.onExitFinished})
    : super(anchor: Anchor.bottomCenter);

  final SaludCowTuning tuning;
  final VoidCallback? onExitFinished;

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

  SaludCatPhase _phase = SaludCatPhase.entering;
  bool _exitFinishNotified = false;

  double _startX = 0;
  double _idleX = 0;
  double _exitX = 0;
  double _clipLineX = 0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
  }

  void syncLayout(Vector2 logicalSize) {
    _startX = tuning.cowEnterStartX;
    _idleX = tuning.cowIdleCenterX;
    _exitX = tuning.cowExitEndX;
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
    _displaySize = _animalDisplaySize();

    position.y = tuning.cowFeetBaselineY;
    _startX = tuning.cowEnterStartX;
    _idleX = tuning.cowIdleCenterX;
    _exitX = tuning.cowExitEndX;
    _clipLineX = tuning.cowClipLineX;

    _animComp?.size.setFrom(_displaySize);
    _clipRoot?.size.setFrom(_displaySize);
    size.setValues(_displaySize.x, _displaySize.y);
    _updateClipWindow();

    switch (_phase) {
      case SaludCatPhase.idle:
        position.x = _idleX;
        break;
      case SaludCatPhase.done:
        position.x = _exitX;
        break;
      case SaludCatPhase.entering:
      case SaludCatPhase.exiting:
        break;
    }
  }

  Future<void> _firstPaint() async {
    assert(game.hasLayout, 'Salud cat needs layout before first paint');

    _displaySize = _animalDisplaySize();

    final jumpAtlas = await game.atlasFromAssets(kCatJumpingAtlasAsset);
    final idleAtlas = await game.atlasFromAssets(kCatJumpToIdleAtlasAsset);
    final jumpFrames = saludIndexedFramesFromAtlas(
      jumpAtlas,
      preferredName: kCatAtlasNamePreferred,
      atlasLabelForAssert: kCatJumpingAtlasAsset,
    );
    final jumpToIdleFrames = saludIndexedFramesFromAtlas(
      idleAtlas,
      preferredName: kCatAtlasNamePreferred,
      atlasLabelForAssert: kCatJumpToIdleAtlasAsset,
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

    final idleSprite = await game.loadSprite(kCatStaticPngAsset);
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
    position.x = _startX;
    _phase = SaludCatPhase.entering;
    _enterSequenceDone = false;
    _exitFinishNotified = false;
    add(_clipRoot!);
    _updateClipWindow();

    final enterTicker = _animComp!.animationTicker!;
    enterTicker.reset();
    unawaited(
      enterTicker.completed.then((_) {
        if (!isMounted || !_visualReady || _phase != SaludCatPhase.entering) {
          return;
        }
        _enterSequenceDone = true;
        _useStaticCat();
        _trySettleIdleAtCenter();
      }),
    );

    _visualReady = true;
  }

  Vector2 _animalDisplaySize() => Vector2.all(saludDefaultAnimalDrawPx());

  void _updateClipWindow() {
    if (_clipRoot == null) return;
    final actorLeftX = position.x - (size.x * anchor.x);
    final clipW = (_clipLineX - actorLeftX).clamp(0.0, size.x);
    _clipRoot!.size.setValues(clipW.toDouble(), size.y);
  }

  void _useJumpingLoop() {
    final c = _animComp!;
    c.animation = _jumpingLoopTemplate.clone();
    c.animationTicker!.reset();
  }

  void _useStaticCat() {
    final c = _animComp!;
    c.animation = _staticTemplate.clone();
    c.animationTicker!.reset();
  }

  void _trySettleIdleAtCenter() {
    if (_phase != SaludCatPhase.entering) return;
    if (!_enterSequenceDone) return;
    if (_idleX - position.x > _arrive) return;
    position.x = _idleX;
    _phase = SaludCatPhase.idle;
    _useStaticCat();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!_visualReady) return;

    final spd = tuning.walkSpeedPixelsPerSecond;

    switch (_phase) {
      case SaludCatPhase.entering:
        position.x = math.min(position.x + spd * dt, _idleX);
        _trySettleIdleAtCenter();
        break;
      case SaludCatPhase.exiting:
        position.x = math.min(position.x + spd * dt, _exitX);
        if (_exitX - position.x <= _arrive) {
          position.x = _exitX;
          _phase = SaludCatPhase.done;
          _useStaticCat();
          if (!_exitFinishNotified) {
            _exitFinishNotified = true;
            onExitFinished?.call();
          }
        }
        break;
      case SaludCatPhase.idle:
      case SaludCatPhase.done:
        break;
    }
    _updateClipWindow();
  }

  void _beginExitJumpWalk() {
    _phase = SaludCatPhase.exiting;
    _useJumpingLoop();
  }

  @override
  void onTapUp(TapUpEvent event) {
    super.onTapUp(event);
    if (_phase == SaludCatPhase.idle) {
      _beginExitJumpWalk();
    }
  }
}
