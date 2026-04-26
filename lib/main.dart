import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'diverchicos_game.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DiverchicosApp());
}

final DiverchicosGame _game = DiverchicosGame();

class DiverchicosApp extends StatelessWidget {
  const DiverchicosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5E35B1)),
      ),
      home: GameWidget(
        game: _game,
        backgroundBuilder: (context) => const ColoredBox(
          color: Color(0xFF448AFF),
        ),
        overlayBuilderMap: {
          'mainMenu': (BuildContext context, game) {
            return Positioned.fill(
              child: MainMenuOverlay(
                onAnimals: () {
                  (game as DiverchicosGame)
                    ..overlays.remove('mainMenu')
                    ..overlays.add('animals');
                },
              ),
            );
          },
          'animals': (BuildContext context, game) {
            return Positioned.fill(
              child: _AnimalsOverlay(
                onBack: () {
                  (game as DiverchicosGame)
                    ..overlays.remove('animals')
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
          backgroundBuilder: (context) =>
              const ColoredBox(color: Color(0xFF2E7D32)),
        ),
      ),
    );
  }
}

class MainMenuOverlay extends StatelessWidget {
  const MainMenuOverlay({super.key, required this.onAnimals});

  final VoidCallback onAnimals;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF7B1FA2),
            Color(0xFF4A148C),
          ],
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
                  onPressed: () {},
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
    );
  }
}
