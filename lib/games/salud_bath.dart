import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'salud_constants.dart';
import 'salud_types.dart';

/// Drives the three bath micro‑scenes (animations & props). Logic is filled in incrementally.
class SaludBathSceneController extends ChangeNotifier {
  SaludBathSceneController({this.animal = SaludPlayerAnimal.cow});

  final SaludPlayerAnimal animal;
  int sceneIndex = 1;

  /// Scene 1 — water from tap into glass.
  void waterpour() {
    // TODO: drive vaso / grifo animations
    if (kDebugMode) {
      debugPrint('SaludBath: waterpour()');
    }
  }

  /// Toothpaste meets toothbrush.
  void pasteOnBrush() {
    if (kDebugMode) {
      debugPrint('SaludBath: pasteOnBrush()');
    }
  }

  void mouthRinse() {
    if (kDebugMode) {
      debugPrint('SaludBath: mouthRinse()');
    }
  }

  /// Clear props toward the nearest screen edge; dispose placeholders.
  Future<void> exitFromScene() async {
    if (kDebugMode) {
      debugPrint('SaludBath: exitFromScene()');
    }
  }

  /// Next wave of props “bounces” in (scene 2).
  Future<void> enterScene() async {
    if (kDebugMode) {
      debugPrint('SaludBath: enterScene()');
    }
  }

  void goToScene(int index) {
    sceneIndex = index;
    notifyListeners();
  }
}

/// Bath room UI: [bathWall] + scene props. Uses same logical 1920×1080 box as intro.
class SaludBath extends StatefulWidget {
  const SaludBath({
    super.key,
    required this.animal,
    required this.controller,
  });

  final SaludPlayerAnimal animal;
  final SaludBathSceneController controller;

  @override
  State<SaludBath> createState() => _SaludBathState();
}

class _SaludBathState extends State<SaludBath> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onCtrl);
  }

  @override
  void didUpdateWidget(covariant SaludBath oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onCtrl);
      widget.controller.addListener(_onCtrl);
    }
  }

  void _onCtrl() => setState(() {});

  @override
  void dispose() {
    widget.controller.removeListener(_onCtrl);
    super.dispose();
  }

  String get _heroPng =>
      widget.animal == SaludPlayerAnimal.cat ? 'cat.png' : 'cow.png';

  @override
  Widget build(BuildContext context) {
    final logicalCowSize =
        (kSaludCowLogicalHeight * 0.38).clamp(280, 760).toDouble();
    final c = widget.controller;

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
                  'assets/images/$_heroPng',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.pets, size: 120, color: Colors.white);
                  },
                ),
              ),
            ),
            if (c.sceneIndex == 1) ..._sceneOneProps(c),
            if (c.sceneIndex >= 2) ..._sceneTwoPlaceholder(c),
          ],
        ),
      ),
    );
  }

  /// Towel, mirror, sink unit, tap, glass, brush, toothpaste (stubs).
  List<Widget> _sceneOneProps(SaludBathSceneController c) {
    return [
      Positioned(
        left: 120,
        top: 140,
        child: Image.asset(
          'assets/images/bathGame/toalla.png',
          width: 220,
          fit: BoxFit.contain,
        ),
      ),
      Positioned(
        right: 200,
        top: 120,
        child: Image.asset(
          'assets/images/bathGame/espejo.png',
          width: 280,
          fit: BoxFit.contain,
        ),
      ),
      Positioned(
        left: 560,
        bottom: 180,
        child: SizedBox(
          width: 800,
          height: 420,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/images/bathGame/sinkTable.png',
                  fit: BoxFit.contain,
                ),
              ),
              Positioned(
                left: 120,
                top: 40,
                child: Image.asset(
                  'assets/images/bathGame/lavamanos.png',
                  width: 360,
                  fit: BoxFit.contain,
                ),
              ),
              Positioned(
                right: 80,
                top: 100,
                child: GestureDetector(
                  onTap: c.waterpour,
                  child: Image.asset(
                    'assets/images/bathGame/grifo.png',
                    width: 120,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Positioned(
                right: 160,
                top: 200,
                child: GestureDetector(
                  onTap: c.waterpour,
                  child: Image.asset(
                    'assets/images/bathGame/vaso.png',
                    width: 100,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Positioned(
                left: 200,
                bottom: 40,
                child: Image.asset(
                  'assets/images/bathGame/cepillo.png',
                  width: 140,
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  List<Widget> _sceneTwoPlaceholder(SaludBathSceneController c) {
    return [
      Positioned(
        bottom: 120,
        left: kSaludCowLogicalWidth / 2 - 200,
        child: Text(
          'Escena ${c.sceneIndex} (placeholder)',
          style: const TextStyle(color: Colors.white70, fontSize: 28),
        ),
      ),
    ];
  }
}
