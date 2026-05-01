import 'dart:async';
import 'dart:ui' as ui;

import 'package:flame/extensions.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';

import 'app_audio.dart';
import 'frog_intro.dart';

/// Shell + menus + gameplay phases. Frog splash is [transition]; overlays drive [menu]/[playing].
enum GameState {
  menu,

  /// Drag-and-drop or other active mini-game.
  playing,

  /// Educational VO + animation (planned shapes game).
  cutscene,

  /// Waiting after level success before next action.
  levelComplete,

  /// Frog splash, loading fades, navigations — non-interactive overlays.
  transition,
}

/// Shell game: frog intro on canvas → main menu overlay; forwards kids mode replay.
///
/// Extend [gameState] for the planned fourth-button shapes game (`playing`/`cutscene`/`levelComplete`).
class DiverchicosGame extends FlameGame {
  DiverchicosGame({
    this.onIntroCompleted,
    this.onIntroRequestedPortrait,
    this.onLandscapeRequested,
  }) : super() {
    _frog = FrogIntroController(
      images: images,
      onIntroVoiceStart: () =>
          unawaited(AppAudio.instance.playIntroOnce()),
      onOpenMainMenuAndLandscapeAndBgm: _openMainMenuFromIntro,
    );
  }

  final VoidCallback? onIntroCompleted;
  final VoidCallback? onIntroRequestedPortrait;
  final VoidCallback? onLandscapeRequested;

  late final FrogIntroController _frog;

  /// Current high-level phase; frog completion sets [menu].
  GameState gameState = GameState.transition;

  void _openMainMenuFromIntro() {
    gameState = GameState.menu;
    overlays.add('mainMenu');
    onIntroCompleted?.call();
    onLandscapeRequested?.call();
    unawaited(AppAudio.instance.playMenuLoop());
  }

  /// Call when navigating from main menu into a mini-game overlay.
  void notifyEnteredMiniGame() {
    gameState = GameState.playing;
  }

  /// Call when closing mini-game overlays back to the main menu.
  void notifyReturnedToMainMenu() {
    gameState = GameState.menu;
  }

  @override
  ui.Color backgroundColor() =>
      const ui.Color.fromRGBO(0, 158, 233, 1);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await _frog.onLoad();
    gameState = GameState.transition;
    _frog.updateSizesForViewport(size);
  }

  void startKidsMode() {
    overlays.remove('mainMenu');
    onIntroRequestedPortrait?.call();
    gameState = GameState.transition;
    _frog.resetForKidsReplay();
    unawaited(AppAudio.instance.stopBgm());
  }

  void exitKidsMode() {
    overlays.remove('kidsBack');
    onLandscapeRequested?.call();
    _frog.markClosedUntilNextKidsReplay();
    overlays.add('mainMenu');
    gameState = GameState.menu;
    unawaited(AppAudio.instance.playMenuLoop());
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _frog.updateSizesForViewport(size);
  }

  @override
  void update(double dt) {
    if (!_frog.assetsReady || _frog.introFinishedShowing) {
      super.update(dt);
      return;
    }
    _frog.updateTimeline(dt);
  }

  @override
  void render(ui.Canvas canvas) {
    if (_frog.assetsReady && !_frog.introFinishedShowing) {
      _frog.render(canvas, size);
      return;
    }
    super.render(canvas);
  }
}
