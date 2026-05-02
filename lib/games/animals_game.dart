import 'dart:async';
import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/extensions.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// Flame Images use prefix "assets/images/" -— keys are paths inside that folder.
const String kAnimalsFilePrefix = '';

/// Separate Flame game shown inside the `animals` overlay.
class AnimalsGame extends FlameGame {
  AnimalsGame({required this.onBack}) : super();

  final void Function() onBack;

  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
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

/// Flutter wrapper: embeds [AnimalsGame] in a [GameWidget] for overlay use.
class AnimalsFlutterOverlay extends StatefulWidget {
  const AnimalsFlutterOverlay({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<AnimalsFlutterOverlay> createState() => _AnimalsFlutterOverlayState();
}

class _AnimalsFlutterOverlayState extends State<AnimalsFlutterOverlay> {
  late final AnimalsGame _game = AnimalsGame(onBack: widget.onBack);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF2E7D32),
      child: SizedBox.expand(
        child: GameWidget(
          game: _game,
          backgroundBuilder: (context) => const ColoredBox(color: Colors.red),
        ),
      ),
    );
  }
}

/// Root component: loads sprites, lays out backdrop + pills + draggable animals.
class AnimalsPlayRoot extends Component with HasGameReference<AnimalsGame> {
  AnimalsPlayRoot({required this.onBack});

  final void Function() onBack;

  static const _files = <String>['bear', 'chicken', 'cow', 'dog', 'frog'];
  bool _sceneBuilt = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await game.images.loadAll(
      _files.map((e) => '$kAnimalsFilePrefix$e.png').toList(),
    );
  }

  @override
  void onMount() {
    super.onMount();
    _ensureScene();
  }

  Future<void> _ensureScene() async {
    if (_sceneBuilt) return;
    while (!isMounted) {
      await Future<void>.delayed(const Duration(milliseconds: 8));
    }
    while (isMounted && !game.hasLayout) {
      await Future<void>.delayed(const Duration(milliseconds: 8));
    }
    if (!isMounted) return;
    _sceneBuilt = true;
    _buildScene(game.size);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (!isMounted) return;
    if (_sceneBuilt) {
      _buildScene(size);
    }
  }

  void _buildScene(Vector2 size) {
    if (size.x <= 0 || size.y <= 0) return;
    final w = size.x;
    final h = size.y;
    const pad = 24.0;
    const maxSide = 120.0;

    for (final c in game.world.children.toList()) {
      if (c is! AnimalsPlayRoot) {
        c.removeFromParent();
      }
    }

    game.world
      ..add(GreenGradientBackdrop(size: Vector2(size.x, size.y))..priority = -2)
      ..add(
        _AnimalsBackPill(onTap: onBack, right: 16, top: 16, screenW: w)
          ..priority = 2,
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
        final scale = maxSide / (src.x > src.y ? src.x : src.y);
        display = src * scale;
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

/// Green gradient backdrop for the animals play area.
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

/// Top-right «MENÚ» pill matching main menu styling.
class _AnimalsBackPill extends PositionComponent
    with TapCallbacks, HasGameReference<AnimalsGame> {
  _AnimalsBackPill({
    required this.onTap,
    required this.right,
    required this.top,
    required this.screenW,
  }) : _label = TextComponent(
         text: 'MENÚ',
         anchor: Anchor.center,
         textRenderer: TextPaint(
           style: TextStyle(
             color: Colors.white,
             fontSize: 14,
             fontWeight: FontWeight.w600,
           ),
         ),
       );

  final void Function() onTap;
  final double right;
  final double top;
  final double screenW;
  final TextComponent _label;

  Paint get _pillPaint => Paint()..color = const Color(0xCC1A237E);

  void _layoutForGameSize(Vector2 gameSize) {
    final divisor = kIsWeb ? 24.0 : 12.0;
    final pw = gameSize.x / divisor;
    final ph = gameSize.y / divisor;
    size = Vector2(pw, ph);
    _label.position = size / 2;
    final fontMin = kIsWeb ? 8.0 : 10.0;
    final font = (math.min(pw, ph) * 0.42).clamp(fontMin, 32.0).toDouble();
    _label.textRenderer = TextPaint(
      style: TextStyle(
        color: Colors.white,
        fontSize: font,
        fontWeight: FontWeight.w600,
      ),
    );
    position = Vector2(gameSize.x - right, top);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    anchor = Anchor.topRight;
    _layoutForGameSize(game.size);
    add(_label);
  }

  @override
  void onGameResize(Vector2 gameSize) {
    super.onGameResize(gameSize);
    _layoutForGameSize(gameSize);
  }

  @override
  void render(Canvas canvas) {
    final corner = Radius.circular(math.min(size.x, size.y) / 2);
    final r = RRect.fromRectAndRadius(size.toRect(), corner);
    canvas.drawRRect(r, _pillPaint);
    super.render(canvas);
  }

  @override
  void onTapUp(TapUpEvent event) => onTap();
}

/// Draggable animal sprite used in [AnimalsGame].
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
