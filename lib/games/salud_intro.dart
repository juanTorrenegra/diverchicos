import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'salud_constants.dart';

/// Hallway in front of the bath: [paredVerde.png] + Flame intro game layer.
class SaludIntro extends StatelessWidget {
  const SaludIntro({
    super.key,
    required this.game,
  });

  final FlameGame game;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/images/paredVerde.png',
            fit: BoxFit.fill,
          ),
        ),
        Positioned.fill(
          child: FittedBox(
            fit: BoxFit.fill,
            child: SizedBox(
              width: kSaludCowLogicalWidth,
              height: kSaludCowLogicalHeight,
              child: GameWidget<FlameGame>(
                key: ObjectKey(game),
                game: game,
                backgroundBuilder: (_) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
