import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';

/// World size Flame uses for SALUD cow layout (`FixedResolutionViewport`).
/// Widget size only scales this; all positions below are in these units.
const double kSaludCowLogicalWidth = 1920;
const double kSaludCowLogicalHeight = 1080;

/// Tweaking knobs for [SaludCowGame].  
/// Coordinate system: **origin top-left**, X right, Y down, size [kSaludCowLogicalWidth]×[kSaludCowLogicalHeight].
class SaludCowTuning {
  const SaludCowTuning({
    // ─── Horizontal walk path (world X; cow anchor is bottom **center**) ───
    this.cowEnterStartX =
        -154, // TweAK: walk starts off-screen left (more negative = further left)
    this.cowIdleCenterX =
        538, // TWEAK: X where cow stops idle (walking center ends here)
    this.cowExitEndX =
        1728, // TWEAK: X destination after happy×2 (walk out phase)

    // ─── Vertical baseline (world Y); feet sit on this horizontal line ───
    this.cowFeetBaselineY =
        929, // TWEAK: down = larger Y (toward bottom). ~1080 − bottom_margin

    // ─── Sprite draw size caps (pixels in logical space) ───
    this.cowHeightPx =
        756, // TWEAK: target draw height before aspect ratio clamp
    this.cowMaxDrawWidthPx =
        1056, // TWEAK: limits width indirectly via min(height, width/aspect)

    // ─── Door-style vertical clip (world X; clip keeps pixels left of line) ───
    this.cowClipLineX =
        1325, // TWEAK: vertical clip line — smaller = reveals more cow to the left

    this.showClipDebugLine = false,
    this.clipDebugLineWidthPx = 2,
    this.clipDebugLineColor = const Color(0xCCFF1744),

    this.walkSpeedPixelsPerSecond =
        240, // TWEAK: horizontal speed in logical px/s for enter & exit walks
    this.walkStepSeconds = 0.045,
    this.happyStepSeconds = 0.04,
  });

  final double cowEnterStartX;
  final double cowIdleCenterX;
  final double cowExitEndX;
  final double cowFeetBaselineY;
  final double cowHeightPx;
  final double cowMaxDrawWidthPx;
  final double cowClipLineX;
  final bool showClipDebugLine;
  final double clipDebugLineWidthPx;
  final Color clipDebugLineColor;
  final double walkSpeedPixelsPerSecond;
  final double walkStepSeconds;
  final double happyStepSeconds;

  Iterable<String> walkingAssetKeys() sync* {
    for (var i = 1; i <= SaludCowGame.kWalkingFrames; i++) {
      yield 'cowAnimations/walking/${i.toString().padLeft(4, '0')}.png';
    }
  }

  Iterable<String> happyAssetKeys() sync* {
    for (var i = 1; i <= SaludCowGame.kHappyFrames; i++) {
      yield 'cowAnimations/happyWaveHandsJump/cow.png${i.toString().padLeft(4, '0')}.png';
    }
  }
}

enum _CowPhase { entering, idle, happy, exiting, done }

/// Transparent strip: walk in → idle `cow.png` → tap → happy×2 → walk out → idle.
/// Renders at fixed [kSaludCowLogicalWidth]×[kSaludCowLogicalHeight] (letterboxed/scaled).
final class SaludCowGame extends FlameGame {
  SaludCowGame({this.tuning = const SaludCowTuning()})
    : super(
        camera: CameraComponent.withFixedResolution(
          width: kSaludCowLogicalWidth,
          height: kSaludCowLogicalHeight,
        ),
      );

  static const int kWalkingFrames = 24;
  static const int kHappyFrames = 72;

  final SaludCowTuning tuning;

  SaludCowActor? _actor;
  _ClipDebugLineComponent? _debugLine;

  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _debugLine = _ClipDebugLineComponent(
      tuning: tuning,
      isEnabled: tuning.showClipDebugLine,
    )..priority = 90;
    await world.add(_debugLine!);
    _actor = SaludCowActor(tuning: tuning);
    await world.add(_actor!);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (!hasLayout) return;
    final logical = camera.viewport.virtualSize;
    camera.viewfinder.position = logical / 2;
    _debugLine?.syncLayout(logical);
    _actor?.syncLayout(logical);
  }
}

final class _ClipDebugLineComponent extends PositionComponent {
  _ClipDebugLineComponent({required this.tuning, required this.isEnabled})
    : super(anchor: Anchor.topLeft);

  final SaludCowTuning tuning;
  final bool isEnabled;
  final Paint _paint = Paint();

  void syncLayout(Vector2 logicalSize) {
    final w = tuning.clipDebugLineWidthPx.clamp(1, 12).toDouble();
    size.setValues(w, logicalSize.y);
    position.setValues(tuning.cowClipLineX - (w / 2), 0);
    _paint.color = tuning.clipDebugLineColor;
  }

  @override
  void render(Canvas canvas) {
    if (!isEnabled) return;
    canvas.drawRect(size.toRect(), _paint);
  }
}

final class SaludCowActor extends PositionComponent
    with HasGameReference<SaludCowGame>, TapCallbacks {
  SaludCowActor({required this.tuning}) : super(anchor: Anchor.bottomCenter);

  final SaludCowTuning tuning;

  static const double _arrive = 4;

  bool _visualReady = false;
  bool _resizeScheduled = false;

  Component? _active;
  ClipComponent? _clipRoot;

  SpriteComponent? _idleComp;
  SpriteAnimationComponent? _walkComp;
  SpriteAnimationComponent? _happyComp;

  late SpriteAnimation _walkLoopTemplate;
  late SpriteAnimation _happyOnceTemplate;

  late double _aspect;
  Vector2 _displaySize = Vector2.zero();

  _CowPhase _phase = _CowPhase.entering;

  double _startX = 0;
  double _idleX = 0;
  double _exitX = 0;
  double _clipLineX = 0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final paths = [
      ...tuning.walkingAssetKeys(),
      ...tuning.happyAssetKeys(),
      'cow.png',
    ];
    await game.images.loadAll(paths.toList());

    final idleImg = game.images.fromCache('cow.png');
    final ah = idleImg.height == 0 ? 1.0 : idleImg.height.toDouble();
    _aspect = idleImg.width / ah;
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
    _displaySize = _computeCowDisplaySize();

    position.y = tuning.cowFeetBaselineY;
    _startX = tuning.cowEnterStartX;
    _idleX = tuning.cowIdleCenterX;
    _exitX = tuning.cowExitEndX;
    _clipLineX = tuning.cowClipLineX;

    _idleComp?.size.setFrom(_displaySize);
    _walkComp?.size.setFrom(_displaySize);
    _happyComp?.size.setFrom(_displaySize);
    _clipRoot?.size.setFrom(_displaySize);
    size.setValues(_displaySize.x, _displaySize.y);
    _updateClipWindow();

    switch (_phase) {
      case _CowPhase.idle:
        position.x = _idleX;
        break;
      case _CowPhase.done:
        position.x = _exitX;
        break;
      case _CowPhase.entering:
      case _CowPhase.exiting:
      case _CowPhase.happy:
        break;
    }
  }

  Future<void> _firstPaint() async {
    await game.images.ready();
    assert(game.hasLayout, 'Salud cow needs layout before first paint');

    _displaySize = _computeCowDisplaySize();

    final walkSprites = tuning
        .walkingAssetKeys()
        .map((k) => Sprite(game.images.fromCache(k)))
        .toList(growable: false);
    final hopSprites = tuning
        .happyAssetKeys()
        .map((k) => Sprite(game.images.fromCache(k)))
        .toList(growable: false);

    _walkLoopTemplate = SpriteAnimation.spriteList(
      walkSprites,
      stepTime: tuning.walkStepSeconds,
      loop: true,
    );
    _happyOnceTemplate = SpriteAnimation.spriteList(
      hopSprites,
      stepTime: tuning.happyStepSeconds,
      loop: false,
    );

    _idleComp = SpriteComponent(
      sprite: Sprite(game.images.fromCache('cow.png')),
      size: _displaySize,
      anchor: Anchor.topLeft,
      position: Vector2.zero(),
    );

    _walkComp = SpriteAnimationComponent(
      animation: _walkLoopTemplate.clone(),
      size: _displaySize,
      anchor: Anchor.topLeft,
      position: Vector2.zero(),
    );

    _happyComp = SpriteAnimationComponent(
      animation: _happyOnceTemplate.clone(),
      size: _displaySize,
      anchor: Anchor.topLeft,
      position: Vector2.zero(),
    );

    _clipRoot = ClipComponent.rectangle(
      position: Vector2.zero(),
      size: _displaySize.clone(),
      anchor: Anchor.topLeft,
    );

    size.setFrom(_displaySize);
    position.x = _startX;
    _phase = _CowPhase.entering;
    add(_clipRoot!);
    _setActive(_walkComp!);
    _updateClipWindow();
    _visualReady = true;
  }

  Vector2 _computeCowDisplaySize() {
    final hByHeight = tuning.cowHeightPx;
    final hByWidth = tuning.cowMaxDrawWidthPx / _aspect;
    final h = math.min(hByHeight, hByWidth);
    return Vector2(h * _aspect, h);
  }

  void _setActive(Component c) {
    _active?.removeFromParent();
    _active = c;
    _clipRoot?.add(c);
  }

  void _updateClipWindow() {
    if (_clipRoot == null) return;
    final actorLeftX = position.x - (size.x * anchor.x);
    final clipW = (_clipLineX - actorLeftX).clamp(0.0, size.x);
    _clipRoot!.size.setValues(clipW.toDouble(), size.y);
  }

  void _pickWalk() {
    _walkComp!.animation = _walkLoopTemplate.clone();
    _setActive(_walkComp!);
  }

  void _pickIdle() {
    _setActive(_idleComp!);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!_visualReady) return;

    final spd = tuning.walkSpeedPixelsPerSecond;

    switch (_phase) {
      case _CowPhase.entering:
        position.x = math.min(position.x + spd * dt, _idleX);
        if (_idleX - position.x <= _arrive) {
          position.x = _idleX;
          _phase = _CowPhase.idle;
          _pickIdle();
        }
        break;
      case _CowPhase.exiting:
        position.x = math.min(position.x + spd * dt, _exitX);
        if (_exitX - position.x <= _arrive) {
          position.x = _exitX;
          _phase = _CowPhase.done;
          _pickIdle();
        }
        break;
      case _CowPhase.idle:
      case _CowPhase.happy:
      case _CowPhase.done:
        break;
    }
    _updateClipWindow();
  }

  Future<void> _runHappyTwice() async {
    if (_phase != _CowPhase.idle) return;
    _phase = _CowPhase.happy;

    _setActive(_happyComp!);
    final comp = _happyComp!;

    for (var i = 0; i < 2; i++) {
      comp.animation = _happyOnceTemplate.clone();
      final t = comp.animationTicker!;
      t.reset();
      await t.completed;
    }

    _phase = _CowPhase.exiting;
    _pickWalk();
  }

  @override
  void onTapUp(TapUpEvent event) {
    super.onTapUp(event);
    if (_phase == _CowPhase.idle) {
      unawaited(_runHappyTwice());
    }
  }
}
