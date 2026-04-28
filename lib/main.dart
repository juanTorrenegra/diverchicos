import 'dart:async';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    unawaited(_setPortraitIntroOrientation());
    if (_started) {
      _game = _createGame();
    }
  }

  bool get _isAndroidOnly =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> _setPortraitIntroOrientation() async {
    if (!_isAndroidOnly) {
      return;
    }
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]);
  }

  Future<void> _setLandscapeOrientation() async {
    if (!_isAndroidOnly) {
      return;
    }
    await SystemChrome.setPreferredOrientations(const [
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

  void _startExperience() {
    if (_started) {
      return;
    }
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

  List<_MenuGameCardData> _cards() {
    return [
      _MenuGameCardData(title: 'ANIMALES', onTap: onAnimals),
      _MenuGameCardData(title: 'KIDS', onTap: onKids),
      const _MenuGameCardData(title: 'SALUD'),
      const _MenuGameCardData(title: 'EXPLORACION'),
      const _MenuGameCardData(title: 'ROMPECABEZAS'),
      const _MenuGameCardData(title: 'RESOLUCION DE PROBLEMAS'),
      const _MenuGameCardData(title: 'TAREAS DEL HOGAR'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final cards = _cards();
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
              constraints: const BoxConstraints(maxWidth: 900),
              child: CarouselSlider.builder(
                itemCount: cards.length,
                options: CarouselOptions(
                  height: 300,
                  enlargeCenterPage: true,
                  enableInfiniteScroll: false,
                  viewportFraction: 0.62,
                ),
                itemBuilder: (context, index, realIndex) {
                  return _MenuGameCard(data: cards[index]);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuGameCardData {
  const _MenuGameCardData({required this.title, this.onTap});

  final String title;
  final VoidCallback? onTap;
}

class _MenuGameCard extends StatelessWidget {
  const _MenuGameCard({required this.data});

  final _MenuGameCardData data;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: data.onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF80DEEA), Color(0xFF0097A7)],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x55000000),
                blurRadius: 12,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              const Positioned.fill(
                child: Center(
                  child: Icon(
                    Icons.image_outlined,
                    size: 72,
                    color: Color(0xCCFFFFFF),
                  ),
                ),
              ),
              if (data.onTap == null)
                const Positioned(
                  top: 12,
                  right: 12,
                  child: _SoonBadge(),
                ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Text(
                  data.title,
                  maxLines: 2,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    letterSpacing: 1,
                    shadows: [
                      Shadow(
                        color: Colors.black54,
                        blurRadius: 4,
                        offset: Offset(1, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SoonBadge extends StatelessWidget {
  const _SoonBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xCC1A237E),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          'PROXIMO',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 11,
            letterSpacing: 0.7,
          ),
        ),
      ),
    );
  }
}
