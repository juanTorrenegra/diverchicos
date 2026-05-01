import 'dart:ui' as ui;

import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flame/sprite.dart';

/// Mirrors how the frog intro distinguishes normal launch vs “kids replay” flow.
enum FrogExperienceMode { intro, kids }

enum FrogIntroPhase {
  loading,
  firstStatic,
  firstJump,
  secondStatic,
  secondJump,
  thirdStatic,
  holdLastFrame,
}

/// Draws and drives the frog + logo splash that runs **before** the main menu.
///
/// Owned by [DiverchicosGame]; audio and overlays stay in the shell game.
final class FrogIntroController {
  FrogIntroController({
    required this.images,
    required this.onIntroVoiceStart,
    required this.onOpenMainMenuAndLandscapeAndBgm,
  });

  final Images images;

  /// Fired when the first timed jump triggers (intro VO).
  final void Function() onIntroVoiceStart;

  /// Called when normal intro completes (not kids held frame).
  final void Function() onOpenMainMenuAndLandscapeAndBgm;

  FrogExperienceMode mode = FrogExperienceMode.intro;

  final ui.Paint _introBgPaint = ui.Paint()
    ..color = const ui.Color.fromRGBO(0, 158, 233, 1);

  bool _assetsReady = false;
  FrogIntroPhase _phase = FrogIntroPhase.loading;

  Sprite? _staticFrog;
  Sprite? _titleLogo;
  SpriteAnimation? _jumpAnim;
  SpriteAnimationTicker? _jumpTicker;
  Vector2 _frogSourceSize = Vector2.zero();
  Vector2 _frogDrawSize = Vector2.zero();
  Vector2 _titleLogoSize = Vector2.zero();
  double _staticWait = 0;

  bool introFinishedShowing = false;

  bool get assetsReady => _assetsReady;

  Future<void> onLoad() async {
    const jumpFolder = 'frogAnimations/jump';
    final framePaths = List<String>.generate(
      32,
      (i) => '$jumpFolder/${(i + 1).toString().padLeft(4, '0')}.png',
    );
    await images.loadAll([...framePaths, 'frog.png', 'diverchicos.png']);
    final jumpSprites = <Sprite>[];
    for (final p in framePaths) {
      jumpSprites.add(Sprite(images.fromCache(p)));
    }
    _staticFrog = Sprite(images.fromCache('frog.png'));
    _titleLogo = Sprite(images.fromCache('diverchicos.png'));
    _frogSourceSize = jumpSprites.first.srcSize;
    _jumpAnim = SpriteAnimation.spriteList(
      jumpSprites,
      stepTime: 1 / 32,
      loop: false,
    );
    _jumpTicker = _jumpAnim!.createTicker();
    _assetsReady = true;
    _phase = FrogIntroPhase.firstStatic;
  }

  void updateSizesForViewport(Vector2 size) {
    if (size.x <= 0 ||
        size.y <= 0 ||
        _frogSourceSize.x <= 0 ||
        _frogSourceSize.y <= 0) {
      return;
    }
    final targetW = size.x / 5;
    final ratio = _frogSourceSize.y / _frogSourceSize.x;
    _frogDrawSize = Vector2(targetW, targetW * ratio);
    final logoSrc = _titleLogo?.srcSize;
    if (logoSrc != null && logoSrc.x > 0 && logoSrc.y > 0) {
      final logoW = size.x * 0.55;
      final logoRatio = logoSrc.y / logoSrc.x;
      _titleLogoSize = Vector2(logoW, logoW * logoRatio);
    }
  }

  void resetForKidsReplay() {
    mode = FrogExperienceMode.kids;
    introFinishedShowing = false;
    _phase = FrogIntroPhase.firstStatic;
    _staticWait = 0;
    _jumpTicker?.reset();
  }

  /// Kid mode exited from overlay; frog intro stays dismissed until replay.
  void markClosedUntilNextKidsReplay() {
    mode = FrogExperienceMode.intro;
    introFinishedShowing = true;
  }

  void replayIntroSoundsAndFirstJump(SpriteAnimationTicker t) {
    t.reset();
    t.update(0);
    _phase = FrogIntroPhase.firstJump;
    onIntroVoiceStart();
  }

  void updateTimeline(double dt) {
    final t = _jumpTicker;
    if (t == null) return;
    switch (_phase) {
      case FrogIntroPhase.loading:
        break;
      case FrogIntroPhase.firstStatic:
        _staticWait += dt;
        if (_staticWait >= 1.5) {
          replayIntroSoundsAndFirstJump(t);
        }
        break;
      case FrogIntroPhase.firstJump:
        t.update(dt);
        if (t.done()) {
          _staticWait = 0;
          _phase = FrogIntroPhase.secondStatic;
        }
        break;
      case FrogIntroPhase.secondStatic:
        _staticWait += dt;
        if (_staticWait >= 2) {
          t.reset();
          t.update(0);
          _phase = FrogIntroPhase.secondJump;
        }
        break;
      case FrogIntroPhase.secondJump:
        t.update(dt);
        if (t.done()) {
          _staticWait = 0;
          _phase = FrogIntroPhase.thirdStatic;
        }
        break;
      case FrogIntroPhase.thirdStatic:
        _staticWait += dt;
        if (_staticWait >= 1) {
          if (mode == FrogExperienceMode.kids) {
            t.setToLast();
            _phase = FrogIntroPhase.holdLastFrame;
          } else {
            finishAndOpenMainMenu();
          }
        }
        break;
      case FrogIntroPhase.holdLastFrame:
        break;
    }
  }

  void finishAndOpenMainMenu() {
    introFinishedShowing = true;
    onOpenMainMenuAndLandscapeAndBgm();
  }

  void render(ui.Canvas canvas, Vector2 size) {
    if (!_assetsReady || introFinishedShowing) return;

    if (_frogDrawSize.x == 0 || _frogDrawSize.y == 0) {
      updateSizesForViewport(size);
    }
    if (size.x == 0 || size.y == 0) return;

    canvas.drawRect(
      ui.Offset.zero & ui.Size(size.x, size.y),
      _introBgPaint,
    );
    final cx = size.x / 2;
    final frogBottomY = size.y * 0.55;
    final pos = Vector2(cx, frogBottomY);

    switch (_phase) {
      case FrogIntroPhase.loading:
        break;
      case FrogIntroPhase.firstStatic:
      case FrogIntroPhase.secondStatic:
      case FrogIntroPhase.thirdStatic:
        _staticFrog?.render(
          canvas,
          position: pos,
          size: _frogDrawSize,
          anchor: Anchor.bottomCenter,
        );
        break;
      case FrogIntroPhase.firstJump:
      case FrogIntroPhase.secondJump:
      case FrogIntroPhase.holdLastFrame:
        _jumpTicker!.getSprite().render(
          canvas,
          position: pos,
          size: _frogDrawSize,
          anchor: Anchor.bottomCenter,
        );
    }

    _titleLogo?.render(
      canvas,
      position: Vector2(cx, frogBottomY + 10),
      size: _titleLogoSize,
      anchor: Anchor.topCenter,
    );
  }
}
