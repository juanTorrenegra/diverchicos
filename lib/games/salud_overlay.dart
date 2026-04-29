import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../widgets/menu_back_pill.dart';
import 'salud_cow_game.dart';

/// Edit [kSaludCowTuning] to move start / idle / end points without touching mechanics.
///
/// Fractions reference the Flame view (`0`=left edge, `1`=right edge). Feet sit on:
/// `(1 − bottomInsetFraction) × height` from the top.
///
/// Quick tuning:
/// - Lower path: decrease `bottomInsetFraction` (`0.00`..`0.03`)
/// - Higher path: increase `bottomInsetFraction` (`0.06`..`0.12`)
/// - Bigger cow: increase `cowHeightFraction` carefully (`0.40`..`0.46`)
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
          child: GameWidget<SaludCowGame>(
            game: _cowGame,
            backgroundBuilder: (_) => const SizedBox.shrink(),
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
