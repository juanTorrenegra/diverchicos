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

class _SaludOverlayState extends State<SaludOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _whiteFade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
    reverseDuration: const Duration(milliseconds: 520),
  );
  SaludCowGame? _cowGame;
  bool _showBathScene = false;
  bool _transitionRunning = false;

  @override
  void initState() {
    super.initState();
    _cowGame = SaludCowGame(
      tuning: widget.cowTuning,
      onExitFinished: _startBathTransition,
    );
  }

  @override
  void dispose() {
    _whiteFade.dispose();
    super.dispose();
  }

  Future<void> _startBathTransition() async {
    if (_transitionRunning || !mounted) return;
    _transitionRunning = true;
    await _whiteFade.animateTo(1);
    if (!mounted) return;
    setState(() {
      _cowGame = null;
      _showBathScene = true;
    });
    await _whiteFade.animateBack(0);
    _transitionRunning = false;
  }

  Widget _buildCowScene() {
    final game = _cowGame;
    if (game == null) return const SizedBox.expand();
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
                game: game,
                backgroundBuilder: (_) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBathScene() {
    final logicalCowSize =
        (kSaludCowLogicalHeight * 0.38).clamp(280, 760).toDouble();
    return FittedBox(
      fit: BoxFit.fill,
      child: SizedBox(
        width: kSaludCowLogicalWidth,
        height: kSaludCowLogicalHeight,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/bathGame/bathWall.png',
                fit: BoxFit.fill,
                errorBuilder: (context, error, stackTrace) {
                  return const ColoredBox(color: Color(0xFFB3E5FC));
                },
              ),
            ),
            Center(
              child: SizedBox.square(
                dimension: logicalCowSize,
                child: Image.asset(
                  'assets/images/cow.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: _showBathScene ? _buildBathScene() : _buildCowScene(),
        ),
        Positioned(
          top: 20,
          right: 16,
          child: MenuBackPill(onPressed: widget.onBack),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _whiteFade,
              builder: (_, __) {
                return ColoredBox(
                  color: Color.lerp(
                        Colors.transparent,
                        Colors.white,
                        _whiteFade.value,
                      ) ??
                      Colors.transparent,
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
