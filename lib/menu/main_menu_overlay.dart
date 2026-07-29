import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_audio.dart';
import '../games/chicken_path_game.dart';
import '../games/creditos.dart';
import '../games/grid_puzzle.dart';
import '../games/jigsaw_game.dart';
import '../games/pairs.dart';
import '../games/pop_bunny.dart';
import '../games/salud_game.dart';
import '../utils/game_debug.dart';
import '../widgets/menu_back_pill.dart';

const String kFichaTecnicaUrl = 'https://diverchicosfichatecnica.netlify.app/';
/// Asset filename as shipped (note spelling: terriorios.png).
const String kFichaTecnicaImageAsset = 'assets/images/terriorios.png';

class MainMenuOverlay extends StatefulWidget {
  const MainMenuOverlay({super.key});

  @override
  State<MainMenuOverlay> createState() => _MainMenuOverlayState();
}

class _MainMenuOverlayState extends State<MainMenuOverlay>
    with SingleTickerProviderStateMixin {
  bool _showSaludIntro = false;
  bool _showGridPuzzle = false;
  bool _showPopBunny = false;
  bool _showChickenPath = false;
  bool _showPairs = false;
  bool _showJigsaw = false;
  bool _showCreditos = false;
  bool _exitingToMenu = false;
  AnimationController? _saludReturnWhiteFade;

  @override
  void dispose() {
    _saludReturnWhiteFade?.dispose();
    super.dispose();
  }

  /// IMPORTANT (web): Starting audio must happen inside the actual tap/click
  /// call stack. So we synchronously dismiss the game + trigger menu music here,
  /// then run the fade asynchronously.
  void _beginExitMiniGameToMenu({required VoidCallback hideActiveGame}) {
    if (_exitingToMenu) {
      hideActiveGame();
      if (mounted) setState(() {});
      unawaited(AppAudio.instance.returnToMenuMusic());
      return;
    }
    _exitingToMenu = true;

    hideActiveGame();
    if (mounted) setState(() {});

    // Do not await: web can block, and we want this in the gesture callback.
    unawaited(AppAudio.instance.returnToMenuMusic());

    unawaited(_runReturnFade());
  }

  Future<void> _runReturnFade() async {
    _saludReturnWhiteFade?.dispose();
    _saludReturnWhiteFade = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
      value: 1.0,
    );
    if (!mounted) return;
    setState(() {});

    await _saludReturnWhiteFade!.reverse();
    if (!mounted) return;

    _saludReturnWhiteFade?.dispose();
    _saludReturnWhiteFade = null;
    _exitingToMenu = false;
    if (mounted) setState(() {});
  }

  void _returnFromSaludToMenu() =>
      _beginExitMiniGameToMenu(hideActiveGame: () => _showSaludIntro = false);

  void _openSaludGame() {
    GameDebug.log('Menu', 'open SALUD');
    try {
      _exitingToMenu = false;
      _saludReturnWhiteFade?.dispose();
      _saludReturnWhiteFade = null;
      unawaited(AppAudio.instance.playPreschoolerLoop());
      setState(() => _showSaludIntro = true);
    } catch (e, st) {
      GameDebug.logAndSnack(context, 'Menu', 'No se pudo abrir El Baño', e, st);
    }
  }

  void _openGridPuzzle() {
    GameDebug.log('Menu', 'open AVIONES (grid puzzle)');
    try {
      unawaited(AppAudio.instance.playGridPuzzleLoop());
      setState(() => _showGridPuzzle = true);
    } catch (e, st) {
      GameDebug.logAndSnack(context, 'Menu', 'No se pudo abrir Aviones', e, st);
    }
  }

  void _openPopBunny() {
    GameDebug.log('Menu', 'open POP BUNNY');
    try {
      unawaited(AppAudio.instance.stopBgm());
      setState(() => _showPopBunny = true);
    } catch (e, st) {
      GameDebug.log('Menu', 'open pop bunny failed', e, st);
    }
  }

  void _openChickenPath() {
    GameDebug.log('Menu', 'open POLLO LOCO (chicken path)');
    try {
      unawaited(AppAudio.instance.playChickenPathLoop());
      setState(() => _showChickenPath = true);
    } catch (e, st) {
      GameDebug.logAndSnack(
        context,
        'Menu',
        'No se pudo abrir Pollo Loco',
        e,
        st,
      );
    }
  }

  void _openPairs() {
    GameDebug.log('Menu', 'open PARES ANIMALES tapped');
    try {
      unawaited(AppAudio.instance.playPairsLoop());
      setState(() {
        _showPairs = true;
        GameDebug.log('Menu', 'setState _showPairs=true');
      });
    } catch (e, st) {
      GameDebug.logAndSnack(
        context,
        'Menu',
        'No se pudo abrir Pares Animales',
        e,
        st,
      );
    }
  }

  void _returnFromGridPuzzleToMenu() =>
      _beginExitMiniGameToMenu(hideActiveGame: () => _showGridPuzzle = false);

  void _returnFromPopBunnyToMenu() =>
      _beginExitMiniGameToMenu(hideActiveGame: () => _showPopBunny = false);

  void _returnFromChickenPathToMenu() =>
      _beginExitMiniGameToMenu(hideActiveGame: () => _showChickenPath = false);

  void _returnFromPairsToMenu() =>
      _beginExitMiniGameToMenu(hideActiveGame: () => _showPairs = false);

  void _openJigsaw() {
    GameDebug.log('Menu', 'open ROMPECABEZAS (jigsaw)');
    try {
      unawaited(AppAudio.instance.playJigsawLoop());
      setState(() => _showJigsaw = true);
    } catch (e, st) {
      GameDebug.logAndSnack(
        context,
        'Menu',
        'No se pudo abrir Rompecabezas',
        e,
        st,
      );
    }
  }

  void _returnFromJigsawToMenu() =>
      _beginExitMiniGameToMenu(hideActiveGame: () => _showJigsaw = false);

  void _openCreditos() {
    setState(() => _showCreditos = true);
  }

  void _returnFromCreditosToMenu() {
    setState(() => _showCreditos = false);
  }

  bool get _miniGameOpen =>
      _showSaludIntro ||
      _showGridPuzzle ||
      _showPopBunny ||
      _showChickenPath ||
      _showPairs ||
      _showJigsaw ||
      _showCreditos;

  void _exitApp() {
    unawaited(AppAudio.instance.stopBgm());
    SystemNavigator.pop();
  }

  Future<void> _openFichaTecnica() async {
    final uri = Uri.parse(kFichaTecnicaUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  List<MenuGameCardData> _cards() {
    return [
      MenuGameCardData(
        title: 'AVIONES',
        onTap: _openGridPuzzle,
        imageAsset: MenuIcons.gridPuzzleThumbnailPng,
      ),
      MenuGameCardData(
        title: 'CREDITOS',
        onTap: _openCreditos,
        imageAsset: MenuIcons.bunnyPinkPng,
      ),
      MenuGameCardData(
        title: 'POLLO LOCO',
        onTap: _openChickenPath,
        imageAsset: MenuIcons.chickenPng,
      ),
      MenuGameCardData(
        title: 'EL BAÑO',
        onTap: _openSaludGame,
        imageAsset: MenuIcons.saludGamePng,
      ),
      MenuGameCardData(
        title: 'PARES ANIMALES',
        onTap: _openPairs,
        imageAsset: MenuIcons.pairsGamePng,
      ),
      MenuGameCardData(
        title: 'ROMPECABEZAS',
        onTap: _openJigsaw,
        imageAsset: MenuIcons.jigsawPng,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final cards = _cards();
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapDown: (_) {
            unawaited(AppAudio.instance.playMenuLoop());
          },
          child: DecoratedBox(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/mainMenuBG.png'),
                fit: BoxFit.cover,
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
                        child: Center(child: MenuCarousel(cards: cards)),
                      ),
                      // Top: color friends in the middle-left (closer to left edge)
                      Positioned(
                        left: 0,
                        top: 0,
                        height: h * 0.20,
                        width: w * 0.40,
                        child: Padding(
                          padding: EdgeInsets.only(top: h * 0.012),
                          child: Align(
                            alignment: Alignment.center,
                            child: Image.asset(
                              'assets/images/colorFriendsDiverchicos.png',
                              fit: BoxFit.contain,
                              height: h * 0.095 * 1.4 * 1.5,
                            ),
                          ),
                        ),
                      ),
                      // Middle: circles centered in the left half of the screen
                      Positioned(
                        left: 0,
                        top: h * 0.20,
                        width: w * 0.5,
                        height: h * 0.58,
                        child: LayoutBuilder(
                          builder: (context, box) {
                            final gridW = (box.maxWidth * 0.8).clamp(
                              80.0,
                              w / 2.7,
                            );
                            return Center(
                              child: FittedBox(
                                fit: BoxFit.contain,
                                child: SizedBox(
                                  width: gridW,
                                  child: MenuCircleGrid(
                                    gridWidth: gridW,
                                    items: cards,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      // Bottom: créditos centered in the left half
                      Positioned(
                        left: 0,
                        top: h * 0.78,
                        width: w * 0.5,
                        height: h * 0.22,
                        child: LayoutBuilder(
                          builder: (context, box) {
                            return Center(
                              child: GestureDetector(
                                onTap: _openCreditos,
                                child: Image.asset(
                                  MenuIcons.creditosPng,
                                  fit: BoxFit.contain,
                                  width: box.maxWidth * 0.28,
                                  height: box.maxHeight * 0.45,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Positioned(
                        right: w / 28,
                        bottom: h / 28,
                        width: w / 4.2,
                        child: _FichaTecnicaButton(
                          onTap: () => unawaited(_openFichaTecnica()),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        if (_showSaludIntro)
          Positioned.fill(
            child: SaludCowCatIntroLayer(onClose: _returnFromSaludToMenu),
          ),
        if (_showGridPuzzle)
          Positioned.fill(
            child: GridPuzzleLayer(onClose: _returnFromGridPuzzleToMenu),
          ),
        if (_showPopBunny)
          Positioned.fill(
            child: PopBunnyLayer(onClose: _returnFromPopBunnyToMenu),
          ),
        if (_showChickenPath)
          Positioned.fill(
            child: ChickenPathLayer(onClose: _returnFromChickenPathToMenu),
          ),
        if (_showPairs)
          Positioned.fill(
            child: PairsLayer(
              onClose: _returnFromPairsToMenu,
              onLoadError: (message) {
                GameDebug.logAndSnack(context, 'Pairs', message);
              },
            ),
          ),
        if (_showJigsaw)
          Positioned.fill(
            child: JigsawPuzzleLayer(onClose: _returnFromJigsawToMenu),
          ),
        if (_showCreditos)
          Positioned.fill(
            child: CreditosLayer(onClose: _returnFromCreditosToMenu),
          ),
        if (_saludReturnWhiteFade != null)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _saludReturnWhiteFade!,
                builder: (context, child) {
                  final t = _saludReturnWhiteFade!.value.clamp(0.0, 1.0);
                  return ColoredBox(color: Color.fromRGBO(255, 255, 255, t));
                },
              ),
            ),
          ),
        if (!_miniGameOpen)
          Positioned.fill(
            child: Center(
              child: FittedBox(
                fit: BoxFit.fill,
                child: SizedBox(
                  width: GameLogicalExitButton.kLogicalSize.width,
                  height: GameLogicalExitButton.kLogicalSize.height,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      GameLogicalExitButton(onPressed: _exitApp),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Shared paths for main menu carousel + circle thumbnails.
abstract final class MenuIcons {
  static const String gridPuzzleThumbnailPng =
      'assets/images/gridPuzzleThumbnail.png';
  static const String bunnyPinkPng = 'assets/images/bunnyPink.png';
  static const String chickenPng = 'assets/images/chicken/chicken.png';
  static const String saludGamePng = 'assets/images/vaky512x5012.png';
  static const String pairsGamePng = 'assets/images/pairs/canvaJaguar.png';
  static const String jigsawPng = 'assets/images/jigsaw/bruno.jpg';
  static const String creditosPng = 'assets/images/creditos.png';
  static const String fichaTecnicaPng = kFichaTecnicaImageAsset;
}

/// Bottom-right main-menu control that opens the ficha técnica web page.
class _FichaTecnicaButton extends StatelessWidget {
  const _FichaTecnicaButton({required this.onTap});

  final VoidCallback onTap;

  static const List<Shadow> _kRedGlow = [
    Shadow(color: Color(0xFFFF1744), blurRadius: 6),
    Shadow(color: Color(0xE6FF1744), blurRadius: 12),
    Shadow(color: Color(0xB3F44336), blurRadius: 20),
    Shadow(color: Color(0x80E53935), blurRadius: 28),
  ];

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'FICHA TECNICA',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: 1.1,
                  shadows: _kRedGlow,
                ),
              ),
              const SizedBox(height: 8),
              ClipOval(
                child: SizedBox(
                  width: 110,
                  height: 110,
                  child: Image.asset(
                    kFichaTecnicaImageAsset,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const ColoredBox(
                        color: Color(0x33FFFFFF),
                        child: Icon(
                          Icons.description_outlined,
                          size: 56,
                          color: Colors.white,
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'https://diverchicosfichatecnica.netlify.app',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.white,
                  shadows: _kRedGlow,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tweak carousel size, spacing, and animation from here.
class MenuCarouselTuning {
  static double mainCardWidthFactor = 0.5;
  static double mainCardHeightFactor = 0.5;
  static double sideCardScale = 0.70;
  static double pageViewportFraction = 0.50;
  static double sideCardLeftShiftFactor = 0.12;
  static double sideCardOpacity = 0.82;
  static double maxTiltRadians = 0.10;
  static double curveVerticalOffsetFactor = 0.02;
  /// Pulls the carousel lane left so cards nearly meet the circle grid.
  static double laneLeftSpacerFactor = 0.02;
  static double laneRightPaddingFactor = 0.02;

  static const double carouselImageScale = 2.0;

  static double cardBorderRadius(Size screen) => screen.width / 22;
}

class MenuCarousel extends StatefulWidget {
  const MenuCarousel({super.key, required this.cards});

  final List<MenuGameCardData> cards;

  @override
  State<MenuCarousel> createState() => _MenuCarouselState();
}

class _MenuCarouselState extends State<MenuCarousel> {
  static const Duration _kAutoAdvanceInterval = Duration(seconds: 4);
  static const Duration _kIdleResumeDelay = Duration(seconds: 5);
  static const Duration _kAutoAdvanceAnim = Duration(milliseconds: 780);

  late final PageController _controller = PageController(
    viewportFraction: MenuCarouselTuning.pageViewportFraction,
    initialPage: 10000,
  );
  double _page = 10000;

  Timer? _autoAdvanceTimer;
  Timer? _idleResumeTimer;
  bool _programmaticScroll = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final p = _controller.page;
      if (p != null && mounted) {
        setState(() => _page = p);
      }
    });
    _startAutoAdvance();
  }

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    _idleResumeTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startAutoAdvance() {
    _autoAdvanceTimer?.cancel();
    _idleResumeTimer?.cancel();
    _autoAdvanceTimer = Timer.periodic(_kAutoAdvanceInterval, (_) {
      unawaited(_goToNextPage());
    });
  }

  /// Pause auto-rotate while the user browses; resume after [_kIdleResumeDelay].
  void _onUserBrowsing() {
    if (_programmaticScroll) return;
    _autoAdvanceTimer?.cancel();
    _autoAdvanceTimer = null;
    _idleResumeTimer?.cancel();
    _idleResumeTimer = Timer(_kIdleResumeDelay, _startAutoAdvance);
  }

  Future<void> _goToNextPage() async {
    if (!mounted || !_controller.hasClients) return;
    final current = _controller.page ?? _page;
    final next = current.round() + 1;
    _programmaticScroll = true;
    try {
      await _controller.animateToPage(
        next,
        duration: _kAutoAdvanceAnim,
        curve: Curves.easeInOutCubic,
      );
    } finally {
      _programmaticScroll = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final laneWidth = constraints.maxWidth;
        final laneHeight = constraints.maxHeight;
        final laneSize = Size(laneWidth, laneHeight);

        final mainCardW = laneWidth * MenuCarouselTuning.mainCardWidthFactor;
        final mainCardH = laneHeight * MenuCarouselTuning.mainCardHeightFactor;
        final curveOffsetY =
            laneHeight * MenuCarouselTuning.curveVerticalOffsetFactor;
        final leftShift =
            laneWidth * MenuCarouselTuning.sideCardLeftShiftFactor;
        final laneLeftSpacer =
            laneWidth * MenuCarouselTuning.laneLeftSpacerFactor;
        final laneRightPadding =
            laneWidth * MenuCarouselTuning.laneRightPaddingFactor;

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
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (_programmaticScroll) return false;
                  if (notification is ScrollStartNotification ||
                      notification is UserScrollNotification ||
                      notification is OverscrollNotification) {
                    _onUserBrowsing();
                  }
                  return false;
                },
                child: PageView.builder(
                  controller: _controller,
                  scrollDirection: Axis.vertical,
                  padEnds: true,
                  clipBehavior: Clip.none,
                  onPageChanged: (_) {
                    if (!_programmaticScroll) {
                      _onUserBrowsing();
                    }
                  },
                  itemBuilder: (context, index) {
                    final card = widget.cards[index % widget.cards.length];
                    final delta = index - _page;
                    final distance = delta.abs().clamp(0.0, 1.0);

                    final scale =
                        1 - (1 - MenuCarouselTuning.sideCardScale) * distance;
                    final opacity =
                        1 - (1 - MenuCarouselTuning.sideCardOpacity) * distance;

                    final dx = -leftShift * distance;
                    final dy = delta.sign * curveOffsetY * distance;
                    final tilt = delta.sign *
                        MenuCarouselTuning.maxTiltRadians *
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
                                child: MenuGameCard(
                                  data: card,
                                  borderRadius:
                                      MenuCarouselTuning.cardBorderRadius(
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
          ),
        );
      },
    );
  }
}

/// Data model for carousel cards and circle grid items.
class MenuGameCardData {
  const MenuGameCardData({required this.title, this.onTap, this.imageAsset});

  final String title;
  final VoidCallback? onTap;

  /// Optional artwork for carousel + matching circle tile.
  final String? imageAsset;
}

class MenuGameCard extends StatelessWidget {
  const MenuGameCard({
    super.key,
    required this.data,
    required this.borderRadius,
  });

  final MenuGameCardData data;
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
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 24, 28, 56),
                  child: Center(
                    child: Transform.scale(
                      scale: MenuCarouselTuning.carouselImageScale,
                      child: data.imageAsset != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(
                                borderRadius * 0.55,
                              ),
                              child: Image.asset(
                                data.imageAsset!,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(
                                    Icons.image_outlined,
                                    size: 72,
                                    color: Color(0xCCFFFFFF),
                                  );
                                },
                              ),
                            )
                          : const Icon(
                              Icons.image_outlined,
                              size: 72,
                              color: Color(0xCCFFFFFF),
                            ),
                    ),
                  ),
                ),
              ),
              if (data.onTap == null)
                const Positioned(top: 12, right: 12, child: SoonBadge()),
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

class SoonBadge extends StatelessWidget {
  const SoonBadge({super.key});

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

/// Circle quick-actions beside the main-menu carousel (2 rows × 3).
class MenuCircleGrid extends StatelessWidget {
  const MenuCircleGrid({
    super.key,
    required this.gridWidth,
    required this.items,
  });

  final double gridWidth;
  final List<MenuGameCardData> items;

  static const double _kCircleSizeScale = 0.856;
  static const int _kPerRow = 3;

  @override
  Widget build(BuildContext context) {
    final count = items.length;
    final circleSize =
        _kCircleSizeScale * gridWidth / (_kPerRow + 0.10 * (_kPerRow - 1));
    final gap = (gridWidth - _kPerRow * circleSize) / (_kPerRow - 1);
    final rowGap = gap * 0.35;

    Widget circleTile(int index) {
      final item = items[index];
      final isPairs = item.imageAsset == MenuIcons.pairsGamePng;
      final imageSize = circleSize * (isPairs ? 0.64 : 0.8);
      return GestureDetector(
        onTap: item.onTap,
        child: SizedBox(
          width: circleSize,
          height: circleSize,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0x66FFFFFF),
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: Center(
              child: item.imageAsset != null
                  ? Padding(
                      padding: EdgeInsets.all(circleSize * 0.1),
                      child: ClipOval(
                        child: Image.asset(
                          item.imageAsset!,
                          fit: BoxFit.cover,
                          width: imageSize,
                          height: imageSize,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.add_photo_alternate_outlined,
                              color: Colors.white,
                              size: circleSize * 0.38,
                            );
                          },
                        ),
                      ),
                    )
                  : Icon(
                      Icons.add_photo_alternate_outlined,
                      color: Colors.white,
                      size: circleSize * 0.38,
                    ),
            ),
          ),
        ),
      );
    }

    Widget row(List<int> indices) {
      return SizedBox(
        width: gridWidth,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < indices.length; i++) ...[
              if (i > 0) SizedBox(width: gap),
              circleTile(indices[i]),
            ],
          ],
        ),
      );
    }

    final top = [for (var i = 0; i < count && i < 3; i++) i];
    final bottom = [for (var i = 3; i < count && i < 6; i++) i];

    return SizedBox(
      width: gridWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (top.isNotEmpty) row(top),
          if (top.isNotEmpty && bottom.isNotEmpty) SizedBox(height: rowGap),
          if (bottom.isNotEmpty) row(bottom),
        ],
      ),
    );
  }
}
