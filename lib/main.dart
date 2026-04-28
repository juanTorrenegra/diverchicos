import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = constraints.maxHeight;
              return Stack(
                children: [
                  Positioned.fill(
                    child: Center(child: _MenuCarousel(cards: cards)),
                  ),
                  Positioned(
                    left: w / 11,
                    top: h / 6,
                    width: w / 5,
                    child: Image.asset(
                      'assets/images/colorFriendsDiverchicos.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  Positioned(
                    left: w / 20,
                    top: h / 2.25,
                    width: w / 3,
                    child: _MenuCircleGrid(
                      gridWidth: w / 3,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MoveCircleSelectionIntent extends Intent {
  const _MoveCircleSelectionIntent(this.delta);
  final int delta;
}

class _ActivateCircleIntent extends Intent {
  const _ActivateCircleIntent();
}

class _MenuCircleGrid extends StatefulWidget {
  const _MenuCircleGrid({required this.gridWidth});

  final double gridWidth;

  @override
  State<_MenuCircleGrid> createState() => _MenuCircleGridState();
}

class _MenuCircleGridState extends State<_MenuCircleGrid> {
  static const int _columns = 3;
  static const int _count = 6;
  final FocusNode _focusNode = FocusNode(debugLabel: 'menu-circle-grid');
  int _selectedIndex = 0;
  int? _hoveredIndex;

  int get _activeIndex => _hoveredIndex ?? _selectedIndex;

  void _moveSelection(int delta) {
    final next = (_selectedIndex + delta).clamp(0, _count - 1);
    if (next != _selectedIndex) {
      setState(() {
        _selectedIndex = next;
      });
    }
  }

  void _activateSelected() {
    final idx = _activeIndex;
    debugPrint('Circle selected: $idx');
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = widget.gridWidth / 18;
    final circleSize = (widget.gridWidth - spacing * 2) / _columns;
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      child: Shortcuts(
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(
            LogicalKeyboardKey.arrowLeft,
          ): _MoveCircleSelectionIntent(-1),
          SingleActivator(
            LogicalKeyboardKey.arrowRight,
          ): _MoveCircleSelectionIntent(1),
          SingleActivator(LogicalKeyboardKey.arrowUp): _MoveCircleSelectionIntent(
            -3,
          ),
          SingleActivator(
            LogicalKeyboardKey.arrowDown,
          ): _MoveCircleSelectionIntent(3),
          SingleActivator(LogicalKeyboardKey.enter): _ActivateCircleIntent(),
          SingleActivator(LogicalKeyboardKey.space): _ActivateCircleIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            _MoveCircleSelectionIntent: CallbackAction<_MoveCircleSelectionIntent>(
              onInvoke: (intent) {
                _moveSelection(intent.delta);
                return null;
              },
            ),
            _ActivateCircleIntent: CallbackAction<_ActivateCircleIntent>(
              onInvoke: (intent) {
                _activateSelected();
                return null;
              },
            ),
          },
          child: SizedBox(
            width: widget.gridWidth,
            child: Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: List.generate(_count, (index) {
                final isHighlighted = index == _activeIndex;
                return MouseRegion(
                  onEnter: (_) {
                    if (!_focusNode.hasFocus) {
                      _focusNode.requestFocus();
                    }
                    setState(() {
                      _hoveredIndex = index;
                      _selectedIndex = index;
                    });
                  },
                  onExit: (_) {
                    setState(() {
                      _hoveredIndex = null;
                    });
                  },
                  child: GestureDetector(
                    onTap: () {
                      if (!_focusNode.hasFocus) {
                        _focusNode.requestFocus();
                      }
                      setState(() {
                        _selectedIndex = index;
                      });
                      _activateSelected();
                    },
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 130),
                      curve: Curves.easeOut,
                      scale: isHighlighted ? 1.12 : 1.0,
                      child: SizedBox(
                        width: circleSize,
                        height: circleSize,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0x66FFFFFF),
                            border: Border.all(
                              color: isHighlighted
                                  ? const Color(0xFFFFFFAA)
                                  : Colors.white,
                              width: isHighlighted ? 4 : 3,
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.add_photo_alternate_outlined,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tweak these values to adjust card size, spacing, and animation.
class _MenuCarouselTuning {
  // Big center card dimensions (requested: half width and half height).
  static double mainCardWidthFactor = 0.5;
  static double mainCardHeightFactor = 0.5;

  // Side cards scale (0.70 => 30% smaller than the center card).
  static double sideCardScale = 0.70;

  // Distance between cards when scrolling vertically.
  // Lower value = more overlap, higher value = more gap.
  static double pageViewportFraction = 0.50;

  // Shift side cards to the left to fake a curved circular lane.
  static double sideCardLeftShiftFactor = 0.09;

  // Additional visual tuning.
  static double sideCardOpacity = 0.82;
  static double maxTiltRadians = 0.10;
  static double curveVerticalOffsetFactor = 0.02;
  static double laneLeftSpacerFactor = 0.16;
  static double laneRightPaddingFactor = 0.02;

  static double cardBorderRadius(Size screen) => screen.width / 22;
}

class _MenuCarousel extends StatefulWidget {
  const _MenuCarousel({required this.cards});

  final List<_MenuGameCardData> cards;

  @override
  State<_MenuCarousel> createState() => _MenuCarouselState();
}

class _MenuCarouselState extends State<_MenuCarousel> {
  late final PageController _controller = PageController(
    viewportFraction: _MenuCarouselTuning.pageViewportFraction,
    initialPage: 10000,
  );
  double _page = 10000;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final p = _controller.page;
      if (p != null && mounted) {
        setState(() {
          _page = p;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final laneWidth = constraints.maxWidth;
        final laneHeight = constraints.maxHeight;
        final laneSize = Size(laneWidth, laneHeight);

        final mainCardW = laneWidth * _MenuCarouselTuning.mainCardWidthFactor;
        final mainCardH = laneHeight * _MenuCarouselTuning.mainCardHeightFactor;
        final curveOffsetY =
            laneHeight * _MenuCarouselTuning.curveVerticalOffsetFactor;
        final leftShift =
            laneWidth * _MenuCarouselTuning.sideCardLeftShiftFactor;
        final laneLeftSpacer =
            laneWidth * _MenuCarouselTuning.laneLeftSpacerFactor;
        final laneRightPadding =
            laneWidth * _MenuCarouselTuning.laneRightPaddingFactor;

        return SizedBox(
          width: laneWidth,
          height: laneHeight,
          child: Padding(
            padding: EdgeInsets.only(
              left: laneLeftSpacer,
              right: laneRightPadding,
            ),
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.mouse,
                  PointerDeviceKind.trackpad,
                  PointerDeviceKind.stylus,
                },
              ),
              child: PageView.builder(
                controller: _controller,
                scrollDirection: Axis.vertical,
                padEnds: true,
                clipBehavior: Clip.none,
                itemBuilder: (context, index) {
                  final card = widget.cards[index % widget.cards.length];
                  final delta = index - _page;
                  final distance = delta.abs().clamp(0.0, 1.0);

                  final scale =
                      1 - (1 - _MenuCarouselTuning.sideCardScale) * distance;
                  final opacity =
                      1 - (1 - _MenuCarouselTuning.sideCardOpacity) * distance;

                  final dx = -leftShift * distance;
                  final dy = delta.sign * curveOffsetY * distance;
                  final tilt =
                      delta.sign *
                      _MenuCarouselTuning.maxTiltRadians *
                      distance;

                  return Align(
                    alignment: Alignment.centerRight,
                    child: Transform.translate(
                      offset: Offset(dx, dy),
                      child: Transform.rotate(
                        angle: tilt,
                        child: Transform.scale(
                          scale: scale,
                          child: Opacity(
                            opacity: opacity,
                            child: SizedBox(
                              width: mainCardW,
                              height: mainCardH,
                              child: _MenuGameCard(
                                data: card,
                                borderRadius:
                                    _MenuCarouselTuning.cardBorderRadius(
                                      laneSize,
                                    ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MenuGameCardData {
  const _MenuGameCardData({required this.title, this.onTap});

  final String title;
  final VoidCallback? onTap;
}

class _MenuGameCard extends StatelessWidget {
  const _MenuGameCard({required this.data, required this.borderRadius});

  final _MenuGameCardData data;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(borderRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: data.onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: Colors.white, width: 20),
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
                const Positioned(top: 12, right: 12, child: _SoonBadge()),
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
