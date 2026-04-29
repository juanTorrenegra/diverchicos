import 'dart:async';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flame/game.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart';

import 'app_audio.dart';

// Flame Images use prefix "assets/images/" — keys are paths *inside* that folder.

/// Shell game: frog intro drawn in screen space on the main canvas (no overlay).
/// Opens `mainMenu` overlay when done. Kids mode replays intro; see callbacks.
class DiverchicosGame extends FlameGame {
  DiverchicosGame({
    this.onIntroCompleted,
    this.onIntroRequestedPortrait,
    this.onLandscapeRequested,
  });

  final VoidCallback? onIntroCompleted;
  final VoidCallback? onIntroRequestedPortrait;
  final VoidCallback? onLandscapeRequested;

  final Paint _introBgPaint = Paint()..color = Color.fromRGBO(0, 158, 233, 1);
  bool _assetsReady = false;
  bool _introFinished = false;

  Sprite? _staticFrog;
  Sprite? _titleLogo;
  SpriteAnimation? _jumpAnim;
  SpriteAnimationTicker? _jumpTicker;
  Vector2 _frogSourceSize = Vector2.zero();
  Vector2 _frogDrawSize = Vector2.zero();
  Vector2 _titleLogoSize = Vector2.zero();

  _ExperienceMode _mode = _ExperienceMode.intro;
  _IntroPhase _phase = _IntroPhase.loading;
  double _staticWait = 0;

  @override
  Color backgroundColor() => const Color.fromRGBO(0, 158, 233, 1);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
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
    _updateFrogDrawSizeForCurrentScreen();
    _assetsReady = true;
    _phase = _IntroPhase.firstStatic;
  }

  void _updateFrogDrawSizeForCurrentScreen() {
    if (!hasLayout || _frogSourceSize.x <= 0 || _frogSourceSize.y <= 0) {
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

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _updateFrogDrawSizeForCurrentScreen();
  }

  void _goToMainMenu() {
    _introFinished = true;
    overlays.add('mainMenu');
    onIntroCompleted?.call();
    onLandscapeRequested?.call();
    unawaited(AppAudio.instance.playMenuLoop());
  }

  void _playIntroAndEnterFirstJump(SpriteAnimationTicker t) {
    t.reset();
    t.update(0);
    _phase = _IntroPhase.firstJump;
    unawaited(AppAudio.instance.playIntroOnce());
  }

  void startKidsMode() {
    overlays.remove('mainMenu');
    onIntroRequestedPortrait?.call();
    _mode = _ExperienceMode.kids;
    _introFinished = false;
    _phase = _IntroPhase.firstStatic;
    _staticWait = 0;
    _jumpTicker?.reset();
    unawaited(AppAudio.instance.stopBgm());
  }

  void exitKidsMode() {
    overlays.remove('kidsBack');
    onLandscapeRequested?.call();
    _mode = _ExperienceMode.intro;
    _introFinished = true;
    overlays.add('mainMenu');
    unawaited(AppAudio.instance.playMenuLoop());
  }

  @override
  void update(double dt) {
    if (!_assetsReady || _introFinished) {
      super.update(dt);
      return;
    }
    _updateIntro(dt);
  }

  void _updateIntro(double dt) {
    final t = _jumpTicker;
    if (t == null) {
      return;
    }
    switch (_phase) {
      case _IntroPhase.loading:
        break;
      case _IntroPhase.firstStatic:
        _staticWait += dt;
        if (_staticWait >= 1.5) {
          _playIntroAndEnterFirstJump(t);
        }
        break;
      case _IntroPhase.firstJump:
        t.update(dt);
        if (t.done()) {
          _staticWait = 0;
          _phase = _IntroPhase.secondStatic;
        }
        break;
      case _IntroPhase.secondStatic:
        _staticWait += dt;
        if (_staticWait >= 2) {
          t.reset();
          t.update(0);
          _phase = _IntroPhase.secondJump;
        }
        break;
      case _IntroPhase.secondJump:
        t.update(dt);
        if (t.done()) {
          _staticWait = 0;
          _phase = _IntroPhase.thirdStatic;
        }
        break;
      case _IntroPhase.thirdStatic:
        _staticWait += dt;
        if (_staticWait >= 1) {
          if (_mode == _ExperienceMode.kids) {
            t.setToLast();
            _phase = _IntroPhase.holdLastFrame;
          } else {
            _goToMainMenu();
          }
        }
        break;
      case _IntroPhase.holdLastFrame:
        break;
    }
  }

  @override
  void render(ui.Canvas canvas) {
    if (_assetsReady && !_introFinished) {
      _renderIntro(canvas);
      return;
    }
    super.render(canvas);
  }

  void _renderIntro(ui.Canvas canvas) {
    if (_frogDrawSize.x == 0 || _frogDrawSize.y == 0) {
      _updateFrogDrawSizeForCurrentScreen();
    }
    final s = size;
    if (s.x == 0 || s.y == 0) {
      return;
    }
    canvas.drawRect(Offset.zero & Size(s.x, s.y), _introBgPaint);
    final cx = s.x / 2;
    final frogBottomY = s.y * 0.55;
    final pos = Vector2(cx, frogBottomY);

    switch (_phase) {
      case _IntroPhase.loading:
        break;
      case _IntroPhase.firstStatic:
      case _IntroPhase.secondStatic:
      case _IntroPhase.thirdStatic:
        _staticFrog?.render(
          canvas,
          position: pos,
          size: _frogDrawSize,
          anchor: Anchor.bottomCenter,
        );
        break;
      case _IntroPhase.firstJump:
      case _IntroPhase.secondJump:
      case _IntroPhase.holdLastFrame:
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

enum _ExperienceMode { intro, kids }

enum _IntroPhase {
  loading,
  firstStatic,
  firstJump,
  secondStatic,
  secondJump,
  thirdStatic,
  holdLastFrame,
}
