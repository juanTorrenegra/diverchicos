import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';

import '../actors/cow.dart';
import '../widgets/menu_back_pill.dart';
import 'salud_bath.dart';
export 'salud_clip_debug_line.dart' show SaludClipDebugLineComponent;

import 'salud_clip_debug_line.dart';
import 'salud_constants.dart';
import 'salud_intro.dart';
import 'salud_types.dart';

/// Default tuning; see [SaludCowTuning] in `actors/cow.dart`.
const SaludCowTuning kSaludCowTuning = SaludCowTuning();

/// SALUD: intro (door hallway) → white fade → bath scenes.
class SaludOverlay extends StatefulWidget {
  const SaludOverlay({
    super.key,
    required this.onBack,
    this.cowTuning = kSaludCowTuning,
  });

  final VoidCallback onBack;
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

  SaludPlayerAnimal _player = SaludPlayerAnimal.cow;
  SaludCowGame? _cowGame;
  SaludBathSceneController? _bathController;

  bool _showBathScene = false;
  bool _transitionRunning = false;

  @override
  void initState() {
    super.initState();
    _recreateIntroGame();
  }

  void _recreateIntroGame() {
    _cowGame = SaludCowGame(
      tuning: widget.cowTuning,
      onExitFinished: _startBathTransition,
      onAnimalPicked: (picked) => _player = picked,
    );
  }

  @override
  void dispose() {
    _whiteFade.dispose();
    _bathController?.dispose();
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
      _bathController?.dispose();
      _bathController = SaludBathSceneController(animal: _player);
    });
    await _whiteFade.animateBack(0);
    _transitionRunning = false;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(child: _buildSceneLayer()),
        Positioned(
          top: 20,
          right: 16,
          child: MenuBackPill(onPressed: widget.onBack),
        ),
        Positioned.fill(child: _WhiteFadeLayer(controller: _whiteFade)),
      ],
    );
  }

  Widget _buildSceneLayer() {
    final game = _cowGame;
    final bath = _bathController;
    if (_showBathScene && bath != null) {
      return SaludBath(animal: _player, controller: bath);
    }
    if (game != null) {
      return SaludIntro(game: game);
    }
    return const SizedBox.expand();
  }
}

final class _WhiteFadeLayer extends StatelessWidget {
  const _WhiteFadeLayer({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          return ColoredBox(
            color: Color.lerp(
                  Colors.transparent,
                  Colors.white,
                  controller.value,
                ) ??
                Colors.transparent,
          );
        },
      ),
    );
  }
}

/// SALUD hallway intro: fixed viewport with two selectable actors.
final class SaludCowGame extends FlameGame {
  SaludCowGame({
    this.tuning = const SaludCowTuning(),
    this.onExitFinished,
    this.onAnimalPicked,
  }) : super(
         camera: CameraComponent.withFixedResolution(
           width: kSaludCowLogicalWidth,
           height: kSaludCowLogicalHeight,
         ),
       );

  final SaludCowTuning tuning;
  final VoidCallback? onExitFinished;
  final ValueChanged<SaludPlayerAnimal>? onAnimalPicked;

  SaludCowActor? _cowActor;
  SaludCowActor? _catPlaceholderActor;
  SaludClipDebugLineComponent? _debugLine;
  SaludPlayerAnimal? _selected;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _debugLine = _buildDebugLine();
    await world.add(_debugLine!);

    final slots = _DualActorSlots.fromTuning(tuning);

    _cowActor = SaludCowActor(
      tuning: tuning,
      startX: slots.leftStart,
      idleX: slots.leftIdle,
      exitX: tuning.cowExitEndX,
      onIdleTap: () => _onPick(SaludPlayerAnimal.cow),
      onExitFinished: _onChosenExitFinished,
      enableClip: true,
    );
    _catPlaceholderActor = SaludCowActor(
      tuning: tuning,
      startX: slots.rightStart,
      idleX: slots.rightIdle,
      exitX: tuning.cowExitEndX,
      onIdleTap: () => _onPick(SaludPlayerAnimal.cat),
      onExitFinished: _onChosenExitFinished,
      enableClip: true,
    );
    await world.add(_cowActor!);
    await world.add(_catPlaceholderActor!);
  }

  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (!hasLayout) return;
    final logical = camera.viewport.virtualSize;
    camera.viewfinder.position = logical / 2;
    _debugLine?.syncLayout(logical);
    _cowActor?.syncLayout(logical);
    _catPlaceholderActor?.syncLayout(logical);
  }

  SaludClipDebugLineComponent _buildDebugLine() {
    return SaludClipDebugLineComponent(
      tuning: tuning,
      isEnabled: tuning.showClipDebugLine,
    )..priority = 90;
  }

  void _onPick(SaludPlayerAnimal picked) {
    if (_selected != null) return;
    final cow = _cowActor;
    final cat = _catPlaceholderActor;
    if (cow == null || cat == null) return;
    if (!cow.isIdle || !cat.isIdle) return;
    _selected = picked;
    onAnimalPicked?.call(picked);
    cow.setTapEnabled(false);
    cat.setTapEnabled(false);
    if (picked == SaludPlayerAnimal.cow) {
      cow.startExit();
    } else {
      cat.startExit();
    }
  }

  void _onChosenExitFinished() {
    if (_selected == SaludPlayerAnimal.cow) {
      _catPlaceholderActor?.removeFromParent();
      _catPlaceholderActor = null;
    } else if (_selected == SaludPlayerAnimal.cat) {
      _cowActor?.removeFromParent();
      _cowActor = null;
    }
    onExitFinished?.call();
  }
}

final class _DualActorSlots {
  const _DualActorSlots({
    required this.leftStart,
    required this.rightStart,
    required this.leftIdle,
    required this.rightIdle,
  });

  final double leftStart;
  final double rightStart;
  final double leftIdle;
  final double rightIdle;

  factory _DualActorSlots.fromTuning(SaludCowTuning tuning) {
    return _DualActorSlots(
      leftStart: tuning.cowEnterStartX - 220,
      rightStart: tuning.cowEnterStartX - 20,
      leftIdle: tuning.cowIdleCenterX - 200,
      rightIdle: tuning.cowIdleCenterX + 200,
    );
  }
}
