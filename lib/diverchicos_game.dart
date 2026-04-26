import 'dart:async';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/extensions.dart';
import 'package:flame/game.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart';

// Flame's Images use prefix "assets/images/" — keys are paths *inside* that folder.
const String kAnimalsFilePrefix = '';

/// Intro is drawn in [render] in **screen space** (same as [size]), not via
/// [World]/[CameraComponent], so it always appears on top of the clear color.
/// After the sequence, [overlays.add] shows the main menu. [AnimalsGame] uses
/// the default camera with world (0,0) at the top-left of the play area.
class DiverchicosGame extends FlameGame {
  DiverchicosGame();

  final Paint _introBgPaint = Paint()..color = const Color(0xFF448AFF);
  bool _assetsReady = false;
  bool _introFinished = false;

  Sprite? _staticFrog;
  SpriteAnimation? _jumpAnim;
  SpriteAnimationTicker? _jumpTicker;
  Vector2 _frogDrawSize = Vector2.zero();

  _IntroPhase _phase = _IntroPhase.loading;
  double _staticWait = 0;

  late final TextPainter _titleTp = TextPainter(
    text: const TextSpan(
      text: 'DIVERCHICOS',
      style: TextStyle(
        color: Colors.white,
        fontSize: 28,
        fontWeight: FontWeight.w800,
        letterSpacing: 2,
      ),
    ),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
  );

  @override
  Color backgroundColor() => const Color(0xFF1565C0);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    const jumpFolder = 'frogAnimations/jump';
    final framePaths = List<String>.generate(
      32,
      (i) => '$jumpFolder/${(i + 1).toString().padLeft(4, '0')}.png',
    );
    await images.loadAll([...framePaths, 'frog.png']);
    final jumpSprites = <Sprite>[];
    for (final p in framePaths) {
      jumpSprites.add(Sprite(images.fromCache(p)));
    }
    _staticFrog = Sprite(images.fromCache('frog.png'));
    final firstSize = jumpSprites.first.srcSize;
    _frogDrawSize = firstSize * 0.5;
    _jumpAnim = SpriteAnimation.spriteList(
      jumpSprites,
      stepTime: 1 / 32,
      loop: false,
    );
    _jumpTicker = _jumpAnim!.createTicker();
    _assetsReady = true;
    _phase = _IntroPhase.firstStatic;
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _titleTp.layout(maxWidth: size.x);
  }

  void _goToMainMenu() {
    _introFinished = true;
    overlays.add('mainMenu');
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
          t.reset();
          t.update(0);
          _phase = _IntroPhase.firstJump;
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
          _goToMainMenu();
        }
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
    final s = size;
    if (s.x == 0 || s.y == 0) {
      return;
    }
    canvas.drawRect(Offset.zero & Size(s.x, s.y), _introBgPaint);
    final cx = s.x / 2;
    final cy = s.y / 2 - 40;
    final pos = Vector2(cx, cy);

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
          anchor: Anchor.center,
        );
        break;
      case _IntroPhase.firstJump:
      case _IntroPhase.secondJump:
        _jumpTicker!.getSprite().render(
          canvas,
          position: pos,
          size: _frogDrawSize,
          anchor: Anchor.center,
        );
    }

    _titleTp.layout(maxWidth: s.x);
    _titleTp.paint(
      canvas,
      Offset(
        (s.x - _titleTp.width) / 2,
        cy + _frogDrawSize.y / 2 + 20,
      ),
    );
  }
}

enum _IntroPhase {
  loading,
  firstStatic,
  firstJump,
  secondStatic,
  secondJump,
  thirdStatic,
}

// --- Animals: separate game, shown inside the "animals" overlay ---

class AnimalsGame extends FlameGame {
  AnimalsGame({required this.onBack}) : super();

  final void Function() onBack;

  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    // World (0,0) at top-left; same convention as a full-screen 2D layout.
    if (size.x > 0 && size.y > 0) {
      camera.viewfinder.position = size / 2;
    }
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    world.add(AnimalsPlayRoot(onBack: onBack));
  }
}

class AnimalsPlayRoot extends Component with HasGameReference<AnimalsGame> {
  AnimalsPlayRoot({required this.onBack});

  final void Function() onBack;

  static const _files = <String>['bear', 'chicken', 'cow', 'dog', 'frog'];
  bool _sceneBuilt = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await game.images
        .loadAll(_files.map((e) => '$kAnimalsFilePrefix$e.png').toList());
  }

  @override
  void onMount() {
    super.onMount();
    // [onLoad] can finish before the component is mounted. The old
    // _layoutWhenReady only waited while (isMounted && !hasLayout), so if
    // `isMounted` was still false, it exited at `if (!isMounted) return` and
    // never added the world content.
    _ensureScene();
  }

  Future<void> _ensureScene() async {
    if (_sceneBuilt) {
      return;
    }
    while (!isMounted) {
      await Future<void>.delayed(const Duration(milliseconds: 8));
    }
    while (isMounted && !game.hasLayout) {
      await Future<void>.delayed(const Duration(milliseconds: 8));
    }
    if (!isMounted) {
      return;
    }
    _sceneBuilt = true;
    _buildScene(game.size);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (!isMounted) {
      return;
    }
    if (_sceneBuilt) {
      _buildScene(size);
    }
  }

  void _buildScene(Vector2 size) {
    if (size.x <= 0 || size.y <= 0) {
      return;
    }
    final w = size.x;
    final h = size.y;
    const pad = 24.0;
    const maxSide = 120.0;

    // Replace prior layout (resize / rebuild).
    for (final c in game.world.children.toList()) {
      if (c is! AnimalsPlayRoot) {
        c.removeFromParent();
      }
    }

    game.world
      ..add(
        GreenGradientBackdrop(
          size: Vector2(size.x, size.y),
        )..priority = -2,
      )
      ..add(
        _BackPill(
          onTap: onBack,
          right: 16,
          top: 16,
          screenW: w,
        )..priority = 2,
      );

    final positions = <Vector2>[
      Vector2(pad, pad),
      Vector2(w - pad, pad),
      Vector2(pad, h - pad),
      Vector2(w - pad, h - pad),
      Vector2(w / 2, h / 2),
    ];
    for (var i = 0; i < _files.length; i++) {
      final name = _files[i];
      final sprite = Sprite(
        game.images.fromCache('$kAnimalsFilePrefix$name.png'),
      );
      final src = sprite.srcSize;
      var display = src;
      if (src.x > maxSide || src.y > maxSide) {
        final s = maxSide / (src.x > src.y ? src.x : src.y);
        display = src * s;
      }
      final p = Vector2.copy(positions[i]);
      if (i < 4) {
        p.x += (i == 0 || i == 2) ? display.x / 2 : -display.x / 2;
        p.y += (i == 0 || i == 1) ? display.y / 2 : -display.y / 2;
      }
      final d = DraggableAnimal(
        sprite: sprite,
        size: display,
        position: p,
        anchor: Anchor.center,
      )..priority = 1;
      game.world.add(d);
    }
  }
}

class GreenGradientBackdrop extends PositionComponent {
  GreenGradientBackdrop({required Vector2 size})
    : super(anchor: Anchor.topLeft, position: Vector2.zero(), size: size);
  @override
  void render(Canvas canvas) {
    final rect = size.toRect();
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFA5D6A7), Color(0xFF2E7D32)],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }
}

class _BackPill extends PositionComponent
    with TapCallbacks, HasGameReference<AnimalsGame> {
  _BackPill({
    required this.onTap,
    required this.right,
    required this.top,
    required this.screenW,
  }) : _label = TextComponent(
         text: 'MENÚ',
         anchor: Anchor.center,
         textRenderer: TextPaint(
           style: const TextStyle(
             color: Colors.white,
             fontSize: 16,
             fontWeight: FontWeight.w600,
           ),
         ),
       );
  final void Function() onTap;
  final double right;
  final double top;
  final double screenW;
  final TextComponent _label;
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    const w = 108.0;
    const h = 44.0;
    size = Vector2(w, h);
    anchor = Anchor.topRight;
    _label.position = size / 2;
    add(_label);
    position = Vector2(screenW - right, top);
  }
  @override
  void onGameResize(Vector2 gameSize) {
    super.onGameResize(gameSize);
    position = Vector2(gameSize.x - right, top);
  }
  @override
  void onTapUp(TapUpEvent event) {
    onTap();
  }
}

class DraggableAnimal extends SpriteComponent with DragCallbacks {
  DraggableAnimal({
    required super.sprite,
    required super.size,
    super.position,
    super.anchor,
  });
  @override
  void onDragUpdate(DragUpdateEvent event) {
    position += event.localDelta;
  }
}
