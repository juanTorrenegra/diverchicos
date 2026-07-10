import 'dart:async';
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';

import 'app_audio.dart';

/// Overlay key for the frog splash shown before the main menu.
const String kFrogIntroOverlay = 'frogIntro';

/// Overlay key for the main menu.
const String kMainMenuOverlay = 'mainMenu';

/// Shell + menus + gameplay phases. Frog splash is [transition]; overlays drive [menu]/[playing]..
enum GameState {
  menu,

  /// Drag-and-drop or other active mini-game
  playing,

  /// Educational VO + animation (planned shapes game).
  cutscene,

  /// Waiting after level success before next action.
  levelComplete,

  /// Frog splash, loading fades, navigations — non-interactive overlays.
  transition,
}

/// Shell game: frog intro overlay → main menu overlay.
///
/// Extend [gameState] for the planned fourth-button shapes game (`playing`/`cutscene`/`levelComplete`).
class DiverchicosGame extends FlameGame {
  DiverchicosGame({
    this.onIntroCompleted,
    this.onIntroRequestedPortrait,
    this.onLandscapeRequested,
  }) : super();

  final VoidCallback? onIntroCompleted;
  final VoidCallback? onIntroRequestedPortrait;
  final VoidCallback? onLandscapeRequested;

  /// Current high-level phase; frog completion sets [menu].
  GameState gameState = GameState.transition;

  void _openMainMenuFromIntro() {
    gameState = GameState.menu;
    overlays.add(kMainMenuOverlay);
    onIntroCompleted?.call();
    onLandscapeRequested?.call();
    unawaited(AppAudio.instance.playMenuLoop());
  }

  /// Called by [FrogIntroOverlay] when the first jump begins.
  void handleFrogIntroVoiceStart() {
    unawaited(AppAudio.instance.playIntroOnce());
  }

  /// Called by [FrogIntroOverlay] once the frog has jumped twice.
  void handleFrogIntroFinished() {
    if (!overlays.isActive(kFrogIntroOverlay)) return;
    overlays.remove(kFrogIntroOverlay);
    _openMainMenuFromIntro();
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
  ui.Color backgroundColor() => const ui.Color.fromRGBO(0, 158, 233, 1);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    gameState = GameState.transition;
    overlays.add(kFrogIntroOverlay);
  }
}
