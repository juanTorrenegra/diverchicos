import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_audio.dart';
import 'diverchicos_game.dart';
import 'menu/main_menu_overlay.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _hideAndroidStatusBarForGame();
  runApp(const DiverchicosApp());
}

/// Hide status/navigation chrome on Android so the game uses full screen
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
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
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
      onIntroRequestedPortrait: () => unawaited(_setPortraitIntroOrientation()),
      onLandscapeRequested: () => unawaited(_setLandscapeOrientation()),
    );
  }

  Future<void> _startExperience() async {
    if (_started) return;
    // Web audio must be warmed up from the very first user tap, otherwise
    // subsequent play/resume calls can be blocked by the browser.
    await AppAudio.instance.webWarmUpOnFirstTap();
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
              onTap: () => unawaited(_startExperience()),
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
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5E35B1)),
      ),
      home: GameWidget(
        game: game,
        backgroundBuilder: (context) =>
            const ColoredBox(color: Color.fromRGBO(28, 49, 132, 1)),
        overlayBuilderMap: {
          'mainMenu': (BuildContext context, game) {
            return Positioned.fill(child: MainMenuOverlay());
          },
        },
      ),
    );
  }
}
