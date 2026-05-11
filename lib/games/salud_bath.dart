import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'bath_scene_object.dart';
import 'bath_toothbrush_paste_animation.dart';
import 'salud_constants.dart';
import 'salud_types.dart';

/// Matches [cepillo.png] resting spot (same for [cepilloConCrema.png]).
const Offset _kSaludCepilloMain = Offset(256.4, 853.4);

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

  /// While Colgate is dragged (until bounce‑back ends), paint it last so it sits above mirror/towel.
  bool _colgateLiftedForStack = false;

  /// Same for [cepilloConCrema.png] after paste interaction.
  bool _cepilloCremaLiftedForStack = false;

  ui.Size? _colgateRaster;
  ui.Size? _cepilloRaster;
  ui.Size? _cepilloCremaRaster;

  bool _pasteOnBrushResolved = false;
  bool _playingPasteAnimation = false;
  bool _cepilloCremaUnlocked = false;

  late final SceneObjectConfig _cepilloCremaConfigModel;

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
    _mkProp(id: 'cepillo', file: 'cepillo.png', main: _kSaludCepilloMain),
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

  static List<SceneObjectConfig> _scene1PaintOrder(
    List<SceneObjectConfig> defs,
    bool colgateOnTop,
    bool cepilloCremaOnTop,
  ) {
    SceneObjectConfig? pick(String id) {
      for (final c in defs) {
        if (c.id == id) return c;
      }
      return null;
    }

    final skip = <String>{};
    if (colgateOnTop) skip.add('colgate');
    if (cepilloCremaOnTop) skip.add('cepilloCrema');

    final mid = defs.where((c) => !skip.contains(c.id)).toList();
    final tail = <SceneObjectConfig>[];
    if (colgateOnTop) {
      final c = pick('colgate');
      if (c != null) tail.add(c);
    }
    if (cepilloCremaOnTop) {
      final c = pick('cepilloCrema');
      if (c != null) tail.add(c);
    }
    return [...mid, ...tail];
  }

  Future<void> _loadBathRasterSizes() async {
    final c = await bathLoadAssetRasterSize('assets/images/bathGame/colgate.png');
    final p = await bathLoadAssetRasterSize('assets/images/bathGame/cepillo.png');
    final pcm = await bathLoadAssetRasterSize('assets/images/bathGame/cepilloConCrema.png');
    if (!mounted) return;
    setState(() {
      _colgateRaster = c;
      _cepilloRaster = p;
      _cepilloCremaRaster = pcm ?? p;
    });
  }

  void _onColgateOverlapRect(Rect? r) {
    if (_pasteOnBrushResolved || _playingPasteAnimation || r == null) return;
    final cep = _cepilloRaster;
    if (cep == null) return;
    const inflate = 40.0;
    final cepRect = Rect.fromLTWH(
      _kSaludCepilloMain.dx - inflate,
      _kSaludCepilloMain.dy - inflate,
      cep.width + 2 * inflate,
      cep.height + 2 * inflate,
    );
    if (!cepRect.overlaps(r)) return;
    _triggerPasteOnBrush();
  }

  void _triggerPasteOnBrush() {
    if (_pasteOnBrushResolved) return;
    setState(() {
      _pasteOnBrushResolved = true;
      _playingPasteAnimation = true;
      _colgateLiftedForStack = false;
    });
    widget.controller.pasteOnBrush();
  }

  void _onPasteAnimationFinished() {
    if (!mounted) return;
    setState(() {
      _playingPasteAnimation = false;
      _cepilloCremaUnlocked = true;
    });
  }

  @override
  void initState() {
    super.initState();
    const m = _kSaludCepilloMain;
    _cepilloCremaConfigModel = SceneObjectConfig(
      id: 'cepilloCrema',
      assetFileName: 'cepilloConCrema.png',
      mainPosition: m,
      startingAnimationPosition: bathDefaultStartBelow(m),
      endAnimationPosition: bathDefaultEndPosition(m),
      draggable: true,
    );
    widget.controller.addListener(_onCtrl);
    unawaited(_loadBathRasterSizes());
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
      duration: const Duration(milliseconds: 900),
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
              for (final cfg in _scene1PaintOrder(
                [
                  for (final p in _scene1Defs)
                    if (!(_pasteOnBrushResolved &&
                        (p.id == 'colgate' || p.id == 'cepillo'))) p,
                  if (_cepilloCremaUnlocked) _cepilloCremaConfigModel,
                ],
                _colgateLiftedForStack,
                _cepilloCremaLiftedForStack,
              ))
                SceneObject(
                  key: ValueKey(cfg.id),
                  config: cfg,
                  exitT: _exitT,
                  enterT: 1,
                  onTap: cfg.tappable ? () {} : null,
                  onDragLiftChanged: cfg.id == 'colgate'
                      ? (lifted) {
                          if (_colgateLiftedForStack != lifted) {
                            setState(() => _colgateLiftedForStack = lifted);
                          }
                        }
                      : cfg.id == 'cepilloCrema'
                      ? (lifted) {
                          if (_cepilloCremaLiftedForStack != lifted) {
                            setState(() => _cepilloCremaLiftedForStack = lifted);
                          }
                        }
                      : null,
                  dragHitBaseSize: cfg.id == 'colgate'
                      ? _colgateRaster
                      : cfg.id == 'cepilloCrema'
                      ? (_cepilloCremaRaster ?? _cepilloRaster)
                      : null,
                  onDragWorldRectChanged:
                      cfg.id == 'colgate' ? _onColgateOverlapRect : null,
                ),
              if (_playingPasteAnimation)
                Positioned.fill(
                  child: AbsorbPointer(
                    child: BathToothbrushPasteAnimator(
                      onFinished: _onPasteAnimationFinished,
                    ),
                  ),
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
