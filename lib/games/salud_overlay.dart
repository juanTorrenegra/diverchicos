import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../widgets/menu_back_pill.dart';
import 'salud_cow_game.dart';

/// Cow scene uses a **fixed logical size** in Flame (`kSaludCowLogicalWidth`×`kSaludCowLogicalHeight`),
/// then [FittedBox] + [BoxFit.fill] so the canvas **stretches** with the overlay like `paredVerde.png`.
///
/// Tune positions in **logical pixels**: edit parameters inside [SaludCowTuning] in
/// `salud_cow_game.dart` (each is commented there).
const SaludCowTuning kSaludCowTuning = SaludCowTuning();

/// SALUD mini-screen: background, animated cow strip, back pill (MENÚ).
class SaludOverlay extends StatefulWidget {
  const SaludOverlay({
    super.key,
    required this.onBack,
    this.cowTuning = kSaludCowTuning,
  });

  final VoidCallback onBack;

  /// Start X, idle X, exit X (`enterStartXFraction` … `idleCenterXFraction` … `exitEndXFraction`).
  final SaludCowTuning cowTuning;

  @override
  State<SaludOverlay> createState() => _SaludOverlayState();
}

class _SaludOverlayState extends State<SaludOverlay> {
  late final SaludCowGame _cowGame =
      SaludCowGame(tuning: widget.cowTuning);

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
              child: GameWidget<SaludCowGame>(
                game: _cowGame,
                backgroundBuilder: (_) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
        Positioned(
          top: 20,
          right: 16,
          child: MenuBackPill(onPressed: widget.onBack),
        ),
      ],
    );
  }
}
