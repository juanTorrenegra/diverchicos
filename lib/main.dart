import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_audio.dart';
import 'diverchicos_game.dart'; //.

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DiverchicosApp());
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
    if (_started) {
      _game = DiverchicosGame();
    }
  }

  void _startExperience() {
    if (_started) {
      return;
    }
    setState(() {
      _started = true;
      _game = DiverchicosGame();
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
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5E35B1)),
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
                    ..overlays.remove('mainMenu')
                    ..overlays.add('animals');
                },
                onKids: () {
                  final g = game as DiverchicosGame;
                  g.startKidsMode();
                  g.overlays.add('kidsBack');
                },
              ),
            );
          },
          'animals': (BuildContext context, game) {
            return Positioned.fill(
              child: _AnimalsOverlay(
                onBack: () {
                  unawaited(AppAudio.instance.playMenuLoop());
                  (game as DiverchicosGame)
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
                  child: SizedBox(
                    width: MediaQuery.sizeOf(context).width / 10,
                    height: MediaQuery.sizeOf(context).height / 10,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        shape: const StadiumBorder(),
                        backgroundColor: const Color(0xCC1A237E),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        (game as DiverchicosGame).exitKidsMode();
                      },
                      child: const Text('MENÚ'),
                    ),
                  ),
                ),
              ),
            );
          },
        },
      ),
    );
  }
}

class _AnimalsOverlay extends StatefulWidget {
  const _AnimalsOverlay({required this.onBack});

  final VoidCallback onBack;

  @override
  State<_AnimalsOverlay> createState() => _AnimalsOverlayState();
}

class _AnimalsOverlayState extends State<_AnimalsOverlay> {
  late final AnimalsGame _game = AnimalsGame(onBack: widget.onBack);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF2E7D32),
      child: SizedBox.expand(
        child: GameWidget(
          game: _game,
          backgroundBuilder: (context) => const ColoredBox(color: Colors.red),
        ),
      ),
    );
  }
}

class MainMenuOverlay extends StatelessWidget {
  const MainMenuOverlay({
    super.key,
    required this.onAnimals,
    required this.onKids,
  });

  final VoidCallback onAnimals;
  final VoidCallback onKids;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (_) {
        // On web, autoplay may be blocked until first user interaction.
        unawaited(AppAudio.instance.playMenuLoop());
      },
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF7B1FA2), Color(0xFF4A148C)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF4FC3F7),
                      foregroundColor: const Color(0xFF0D47A1),
                      minimumSize: const Size(220, 56),
                    ),
                    onPressed: onAnimals,
                    child: const Text(
                      'ANIMALS',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF4FC3F7),
                      foregroundColor: const Color(0xFF0D47A1),
                      minimumSize: const Size(220, 56),
                    ),
                    onPressed: onKids,
                    child: const Text(
                      'KIDS',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
