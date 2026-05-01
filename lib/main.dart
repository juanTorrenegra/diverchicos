import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_audio.dart';
import 'diverchicos_game.dart';
import 'games/animals_game.dart';
import 'games/salud_overlay.dart';
import 'menu/main_menu_overlay.dart';
import 'widgets/menu_back_pill.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _hideAndroidStatusBarForGame();
  runApp(const DiverchicosApp());
}

/// Hide status/navigation chrome on Android so the game uses full screen.
void _hideAndroidStatusBarForGame() {
  if (kIsWeb) return;
  if (defaultTargetPlatform != TargetPlatform.android) return;
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
    overlays: [],
  );
}

class DiverchicosApp extends StatefulWidget {
  const DiverchicosApp({super.key});

  @override
  State<DiverchicosApp> createState() => _DiverchicosAppState();
}

class _DiverchicosAppState extends State<DiverchicosApp> {
  final bool _needsWebTapToStart = kIsWeb;
  bool _started = !kIsWeb;
  DiverchicosGame? _game;

  @override
  void initState() {
    super.initState();
    unawaited(_setPortraitIntroOrientation());
    if (_started) {
      _game = _createGame();
    }
  }

  bool get _isAndroidOnly =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> _setPortraitIntroOrientation() async {
    if (!_isAndroidOnly) return;
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  }

  Future<void> _setLandscapeOrientation() async {
    if (!_isAndroidOnly) return;
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  DiverchicosGame _createGame() {
    return DiverchicosGame(
      onIntroCompleted: () => unawaited(_setLandscapeOrientation()),
      onIntroRequestedPortrait: () =>
          unawaited(_setPortraitIntroOrientation()),
      onLandscapeRequested: () => unawaited(_setLandscapeOrientation()),
    );
  }

  void _startExperience() {
    if (_started) return;
    setState(() {
      _started = true;
      _game = _createGame();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_needsWebTapToStart && !_started) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color.fromRGBO(0, 158, 233, 1),
          body: SizedBox.expand(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _startExperience,
              child: const Center(
                child: Text(
                  'TOCA PARA EMPEZAR',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final game = _game!;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme:
            ColorScheme.fromSeed(seedColor: const Color(0xFF5E35B1)),
      ),
      home: GameWidget(
        game: game,
        backgroundBuilder: (context) =>
            const ColoredBox(color: Color.fromRGBO(28, 49, 132, 1)),
        overlayBuilderMap: {
          'mainMenu': (BuildContext context, game) {
            return Positioned.fill(
              child: MainMenuOverlay(
                onAnimals: () {
                  unawaited(AppAudio.instance.playAnimalsLoop());
                  (game as DiverchicosGame)
                    ..notifyEnteredMiniGame()
                    ..overlays.remove('mainMenu')
                    ..overlays.add('animals');
                },
                onKids: () {
                  final g = game as DiverchicosGame;
                  g.startKidsMode();
                  g.overlays.add('kidsBack');
                },
                onSalud: () {
                  unawaited(AppAudio.instance.playPreschoolerLoop());
                  (game as DiverchicosGame)
                    ..notifyEnteredMiniGame()
                    ..overlays.remove('mainMenu')
                    ..overlays.add('salud');
                },
              ),
            );
          },
          'animals': (BuildContext context, game) {
            return Positioned.fill(
              child: AnimalsFlutterOverlay(
                onBack: () {
                  unawaited(AppAudio.instance.playMenuLoop());
                  (game as DiverchicosGame)
                    ..notifyReturnedToMainMenu()
                    ..overlays.remove('animals')
                    ..overlays.add('mainMenu');
                },
              ),
            );
          },
          'kidsBack': (BuildContext context, game) {
            return Positioned.fill(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 20, right: 16),
                  child: MenuBackPill(
                    onPressed: () =>
                        (game as DiverchicosGame).exitKidsMode(),
                  ),
                ),
              ),
            );
          },
          'salud': (BuildContext context, game) {
            return Positioned.fill(
              child: SaludOverlay(
                onBack: () {
                  unawaited(AppAudio.instance.playMenuLoop());
                  (game as DiverchicosGame)
                    ..notifyReturnedToMainMenu()
                    ..overlays.remove('salud')
                    ..overlays.add('mainMenu');
                },
              ),
            );
          },
        },
      ),
    );
  }
}
