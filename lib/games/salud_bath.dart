import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'bath_scene_object.dart';
import 'salud_constants.dart';
import 'salud_types.dart';

/// Drives bath scenes, transitions, and prop interactions.
class SaludBathSceneController extends ChangeNotifier {
  SaludBathSceneController({this.animal = SaludPlayerAnimal.cow});

  final SaludPlayerAnimal animal;
  int sceneIndex = 1;

  bool _exitScene1Requested = false;

  /// Call when scene 1 gameplay is done — triggers exit animation then scene 2.
  void exitScene1ToScene2() {
    _exitScene1Requested = true;
    notifyListeners();
  }

  /// Consumed once by [SaludBath] to start the exit animation.
  bool consumeExitScene1Request() {
    if (!_exitScene1Requested) return false;
    _exitScene1Requested = false;
    return true;
  }

  /// Scene 1 — water from tap into glass.
  void waterpour() {
    if (kDebugMode) {
      debugPrint('SaludBath: waterpour()');
    }
  }

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

  Future<void> exitFromScene() async {
    if (kDebugMode) {
      debugPrint('SaludBath: exitFromScene()');
    }
  }

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

/// Bath room UI (logical 1920×1080).
class SaludBath extends StatefulWidget {
  const SaludBath({super.key, required this.animal, required this.controller});

  final SaludPlayerAnimal animal;
  final SaludBathSceneController controller;

  @override
  State<SaludBath> createState() => _SaludBathState();
}

class _SaludBathState extends State<SaludBath> with TickerProviderStateMixin {
  AnimationController? _exitCtrl;
  AnimationController? _scene2EnterCtrl;

  /// 0→1 while scene 2 hero/props bounce in; stays 1 after complete.
  double _scene2EnterT = 1;

  double get _exitT => _exitCtrl?.value ?? 0;

  void _tickAnimations() => setState(() {});

  static final List<SceneObjectConfig> _scene1Defs = [
    _mkProp(id: 'sink', file: 'sinkTable.png', main: Offset(0.0, 782.8)),
    _mkProp(id: 'lavamanos', file: 'lavamanos.png', main: Offset(716.5, 779.6)),
    _mkProp(
      id: 'colgate',
      file: 'colgate.png',
      main: Offset(1348.0, 844.8),
      draggable: true,
      scaleIdle: true,
    ),
    _mkProp(id: 'cepillo', file: 'cepillo.png', main: Offset(256.4, 853.4)),
    _mkProp(id: 'grifo', file: 'grifo.png', main: Offset(899.6, 687.6)),
    _mkProp(id: 'vaso', file: 'vaso.png', main: Offset(856.7, 845.9)),
    _mkProp(id: 'espejo', file: 'espejo.png', main: Offset(132.5, 77.9)),
    _mkProp(id: 'toalla', file: 'toalla.png', main: Offset(1452.7, 452.1)),
  ];

  static SceneObjectConfig _mkProp({
    required String id,
    required String file,
    required Offset main,
    bool draggable = false,
    bool tappable = false,
    bool scaleIdle = false,
  }) {
    return SceneObjectConfig(
      id: id,
      assetFileName: file,
      mainPosition: main,
      startingAnimationPosition: bathDefaultStartBelow(main),
      endAnimationPosition: bathDefaultEndPosition(main),
      draggable: draggable,
      tappable: tappable,
      scaleIdle: scaleIdle,
    );
  }

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

  void _onCtrl() {
    if (widget.controller.consumeExitScene1Request()) {
      unawaited(
        _runScene1ExitThenScene2().catchError((Object e, StackTrace st) {
          if (kDebugMode) {
            debugPrint('SaludBath async error: $e');
          }
        }),
      );
    }
    setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onCtrl);
    _exitCtrl?.dispose();
    _scene2EnterCtrl?.dispose();
    super.dispose();
  }

  Future<void> _runScene1ExitThenScene2() async {
    if (!mounted || widget.controller.sceneIndex != 1) return;
    _exitCtrl?.dispose();
    _exitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );
    _exitCtrl!.addListener(_tickAnimations);
    await _exitCtrl!.forward();
    if (!mounted) return;
    _exitCtrl?.removeListener(_tickAnimations);
    _exitCtrl?.dispose();
    _exitCtrl = null;

    _scene2EnterT = 0;
    widget.controller.goToScene(2);
    _scene2EnterCtrl?.dispose();
    _scene2EnterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scene2EnterCtrl!.addListener(() {
      setState(() => _scene2EnterT = _scene2EnterCtrl!.value);
    });
    setState(() {});
    await _scene2EnterCtrl!.forward();
    if (!mounted) return;
    _scene2EnterT = 1;
    _scene2EnterCtrl?.dispose();
    _scene2EnterCtrl = null;
    setState(() {});
  }

  String get _heroAssetPath =>
      'assets/images/${widget.animal == SaludPlayerAnimal.cat ? 'cat' : 'cow'}.png';

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final heroSize = kSaludCowLogicalHeight;
    final heroMain = Offset(
      kSaludCowLogicalWidth / 2 - heroSize / 2,
      kSaludCowLogicalHeight * 0.05,
    );

    return FittedBox(
      fit: BoxFit.fill,
      child: SizedBox(
        width: kSaludCowLogicalWidth,
        height: kSaludCowLogicalHeight,
        child: Stack(
          clipBehavior: Clip.none,
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
            if (c.sceneIndex == 1) ...[
              BathHeroObject(
                key: const ValueKey('bathHeroS1'),
                assetPath: _heroAssetPath,
                baseSize: heroSize,
                mainPosition: heroMain,
                startingAnimationPosition: bathDefaultStartBelow(heroMain),
                endAnimationPosition: bathDefaultEndPosition(heroMain),
                exitT: _exitT,
                enterT: 1,
              ),
              for (final cfg in _scene1Defs)
                SceneObject(
                  key: ValueKey(cfg.id),
                  config: cfg,
                  exitT: _exitT,
                  enterT: 1,
                  onTap: cfg.tappable ? () {} : null,
                ),
            ],
            if (c.sceneIndex >= 2) ...[
              BathHeroObject(
                key: const ValueKey('bathHeroS2'),
                assetPath: _heroAssetPath,
                baseSize: heroSize,
                mainPosition: heroMain,
                startingAnimationPosition: bathDefaultStartBelow(heroMain),
                endAnimationPosition: bathDefaultEndPosition(heroMain),
                exitT: 0,
                enterT: _scene2EnterT,
              ),
              ..._sceneTwoPlaceholder(c),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _sceneTwoPlaceholder(SaludBathSceneController c) {
    return [
      Positioned(
        bottom: 120,
        left: kSaludCowLogicalWidth / 2 - 280,
        child: Text(
          'Escena ${c.sceneIndex} — añade props scene 2 (bounce desde startingAnimationPosition)',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 22),
        ),
      ),
    ];
  }
}
