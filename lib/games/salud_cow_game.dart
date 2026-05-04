import 'dart:async';
import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame_texturepacker/flame_texturepacker.dart';
import 'package:flutter/painting.dart';

/// World size Flame uses for SALUD cow layout (`FixedResolutionViewport`).
/// Widget size only scales this; all positions below are in these units.
const double kSaludCowLogicalWidth = 1920;
const double kSaludCowLogicalHeight = 1080;

/// LibGDX atlas from TexturePacker (`assets/images/shvaca2.atlas` + `shvaca2.png`).
/// Frames are **256×256** logical size (`offsets` / `orig` in atlas).
///
/// TexturePacker may emit rows named `0` with `index:` lines; that parses to an
/// **empty** [Region.name], not `cow`. [_cowFramesFromAtlas] handles both styles.
const String kShvacaAtlasAsset = 'shvaca2.atlas';

/// When regions are named `cow_01` … in the atlas; otherwise frames are resolved by index.
const String kShvacaAnimationNamePreferred = 'cow';

/// Logical draw size for the cow on screen (square); frames are 256×256 in the atlas.
const double kShvacaDrawSizePx = 600;

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
    // ─── Door-style vertical clip (world X; clip keeps pixels left of line) ───
    this.cowClipLineX =
        1325, // TWEAK: vertical clip line — smaller = reveals more cow to the left

    this.showClipDebugLine = false,
    this.clipDebugLineWidthPx = 2,
    this.clipDebugLineColor = const Color(0xCCFF1744),

    this.walkSpeedPixelsPerSecond =
        240, // TWEAK: horizontal speed in logical px/s for enter & exit walks
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

enum _CowPhase { entering, idle, happy, exiting, done }

/// Transparent strip: walk in → idle (looping atlas) → tap → happy×2 → walk out → idle.
/// Renders at fixed [kSaludCowLogicalWidth]×[kSaludCowLogicalHeight] (letterboxed/scaled).
final class SaludCowGame extends FlameGame {
  SaludCowGame({this.tuning = const SaludCowTuning()})
    : super(
        camera: CameraComponent.withFixedResolution(
          width: kSaludCowLogicalWidth,
          height: kSaludCowLogicalHeight,
        ),
      );

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

/// Ordered frame sprites for the cow strip (TexturePacker `index:` or `cow_*` names).
List<Sprite> _cowFramesFromAtlas(TexturePackerAtlas atlas) {
  List<TexturePackerSprite> pick(String n) =>
      atlas.findSpritesByName(n).toList(growable: false);

  var frames = pick(kShvacaAnimationNamePreferred);
  if (frames.isEmpty) {
    frames = pick('');
  }
  if (frames.isEmpty) {
    frames = List<TexturePackerSprite>.from(atlas.sprites);
  }
  frames.sort((a, b) {
    final ia = a.region.index == -1 ? 0x7FFFFFFF : a.region.index;
    final ib = b.region.index == -1 ? 0x7FFFFFFF : b.region.index;
    return ia.compareTo(ib);
  });
  return List<Sprite>.from(frames);
}

SpriteAnimation _cowLoopFromAtlas(
  TexturePackerAtlas atlas, {
  required bool loop,
}) {
  final frames = _cowFramesFromAtlas(atlas);
  assert(
    frames.isNotEmpty,
    'No frames in $kShvacaAtlasAsset (cow / blank name / atlas.sprites)',
  );
  return SpriteAnimation.spriteList(frames, stepTime: 1 / 24, loop: loop);
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

  ClipComponent? _clipRoot;
  SpriteAnimationComponent? _animComp;

  late SpriteAnimation _loopTemplate;
  late SpriteAnimation _onceTemplate;

  Vector2 _displaySize = Vector2.zero();

  _CowPhase _phase = _CowPhase.entering;

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
    _displaySize = _cowDisplaySize();

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
    assert(game.hasLayout, 'Salud cow needs layout before first paint');

    _displaySize = _cowDisplaySize();

    final atlas = await game.atlasFromAssets(kShvacaAtlasAsset);
    _loopTemplate = _cowLoopFromAtlas(atlas, loop: true);
    _onceTemplate = _cowLoopFromAtlas(atlas, loop: false);

    _animComp = SpriteAnimationComponent(
      animation: _loopTemplate.clone(),
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
    _phase = _CowPhase.entering;
    add(_clipRoot!);
    _updateClipWindow();
    _visualReady = true;
  }

  Vector2 _cowDisplaySize() => Vector2.all(
    kShvacaDrawSizePx.clamp(1, math.max(1, kSaludCowLogicalHeight)),
  );

  void _updateClipWindow() {
    if (_clipRoot == null) return;
    final actorLeftX = position.x - (size.x * anchor.x);
    final clipW = (_clipLineX - actorLeftX).clamp(0.0, size.x);
    _clipRoot!.size.setValues(clipW.toDouble(), size.y);
  }

  void _useLoopingAnim() {
    final c = _animComp!;
    c.animation = _loopTemplate.clone();
    c.animationTicker!.reset();
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
          _useLoopingAnim();
        }
        break;
      case _CowPhase.exiting:
        position.x = math.min(position.x + spd * dt, _exitX);
        if (_exitX - position.x <= _arrive) {
          position.x = _exitX;
          _phase = _CowPhase.done;
          _useLoopingAnim();
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

    final c = _animComp!;
    for (var i = 0; i < 2; i++) {
      c.animation = _onceTemplate.clone();
      final t = c.animationTicker!;
      t.reset();
      await t.completed;
    }

    _phase = _CowPhase.exiting;
    _useLoopingAnim();
  }

  @override
  void onTapUp(TapUpEvent event) {
    super.onTapUp(event);
    if (_phase == _CowPhase.idle) {
      unawaited(_runHappyTwice());
    }
  }
}
