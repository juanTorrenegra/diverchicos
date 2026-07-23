import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_audio.dart';
import '../games/chicken_path_game.dart';
import '../games/creditos.dart';
import '../games/grid_puzzle.dart';
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
                      Positioned(
                        left: w / 9,
                        top: h / 7.5,
                        width: w / 5,
                        child: Image.asset(
                          'assets/images/colorFriendsDiverchicos.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      Positioned(
                        left: w / 20,
                        top: h / 3,
                        width: w / 3,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            MenuCircleGrid(gridWidth: w / 3, items: cards),
                            SizedBox(height: h / 14),
                            GestureDetector(
                              onTap: _openCreditos,
                              child: Image.asset(
                                MenuIcons.creditosPng,
                                fit: BoxFit.contain,
                                width: w / 5,
                              ),
                            ),
                          ],
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
  static double sideCardLeftShiftFactor = 0.09;
  static double sideCardOpacity = 0.82;
  static double maxTiltRadians = 0.10;
  static double curveVerticalOffsetFactor = 0.02;
  static double laneLeftSpacerFactor = 0.16;
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
  late final PageController _controller = PageController(
    viewportFraction: MenuCarouselTuning.pageViewportFraction,
    initialPage: 10000,
  );
  double _page = 10000;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final p = _controller.page;
      if (p != null && mounted) {
        setState(() => _page = p);
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
                      1 - (1 - MenuCarouselTuning.sideCardScale) * distance;
                  final opacity =
                      1 - (1 - MenuCarouselTuning.sideCardOpacity) * distance;

                  final dx = -leftShift * distance;
                  final dy = delta.sign * curveOffsetY * distance;
                  final tilt =
                      delta.sign * MenuCarouselTuning.maxTiltRadians * distance;

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

class _MoveCircleSelectionIntent extends Intent {
  const _MoveCircleSelectionIntent(this.deltaRow, this.deltaCol);

  final int deltaRow;
  final int deltaCol;
}

class _ActivateCircleIntent extends Intent {
  const _ActivateCircleIntent();
}

/// Circle quick-actions beside the main-menu carousel.
class MenuCircleGrid extends StatefulWidget {
  const MenuCircleGrid({
    super.key,
    required this.gridWidth,
    required this.items,
  });

  final double gridWidth;
  final List<MenuGameCardData> items;

  @override
  State<MenuCircleGrid> createState() => _MenuCircleGridState();
}

class _MenuCircleGridState extends State<MenuCircleGrid> {
  static const double _kCircleSizeScale = 0.972;
  static const double _kHighlightScale = 1.08;

  final FocusNode _focusNode = FocusNode(debugLabel: 'menu-circle-grid');
  int _selectedIndex = 0;
  int? _hoveredIndex;

  int get _activeIndex => _hoveredIndex ?? _selectedIndex;
  int get _count => widget.items.length;

  void _moveSelection(int deltaRow, int deltaCol) {
    if (_count == 3) {
      int? next;
      switch (_selectedIndex) {
        case 0:
          if (deltaRow > 0) next = 1;
          if (deltaCol > 0) next = 2;
        case 1:
          if (deltaRow < 0) next = 0;
          if (deltaCol > 0) next = 2;
        case 2:
          if (deltaRow < 0) next = 0;
          if (deltaCol < 0) next = 1;
      }
      if (next != null && next != _selectedIndex) {
        setState(() => _selectedIndex = next!);
      }
      return;
    }

    if (_count == 4) {
      const neighbors = <List<int?>>[
        [null, 1, 2, null], // 0: right->1, down->2
        [null, null, 3, 0], // 1: down->3, left->0
        [0, 3, null, null], // 2: up->0, right->3
        [1, null, null, 2], // 3: up->1, left->2
      ];
      int? next;
      if (deltaCol > 0) next = neighbors[_selectedIndex][1];
      if (deltaCol < 0) next = neighbors[_selectedIndex][3];
      if (deltaRow > 0) next = neighbors[_selectedIndex][2];
      if (deltaRow < 0) next = neighbors[_selectedIndex][0];
      if (next != null && next != _selectedIndex) {
        setState(() => _selectedIndex = next!);
      }
      return;
    }

    if (_count == 5) {
      const neighbors = <List<int?>>[
        [null, 1, 2, null], // 0
        [null, null, 3, 0], // 1
        [0, 3, 4, 1], // 2
        [1, 4, null, 2], // 3
        [2, null, null, 3], // 4
      ];
      int? next;
      if (deltaCol > 0) next = neighbors[_selectedIndex][1];
      if (deltaCol < 0) next = neighbors[_selectedIndex][3];
      if (deltaRow > 0) next = neighbors[_selectedIndex][2];
      if (deltaRow < 0) next = neighbors[_selectedIndex][0];
      if (next != null && next != _selectedIndex) {
        setState(() => _selectedIndex = next!);
      }
    }
  }

  void _activateSelected() {
    final idx = _activeIndex;
    widget.items[idx].onTap?.call();
    if (widget.items[idx].onTap == null) {
      debugPrint('Circle selected (placeholder): $idx');
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxPerRow = _count >= 5 ? 3 : (_count >= 2 ? 2 : 1);
    final circleSize =
        _kCircleSizeScale *
        widget.gridWidth /
        (maxPerRow + 0.22 * (maxPerRow - 1));
    final gap = maxPerRow > 1
        ? (widget.gridWidth - maxPerRow * circleSize) / (maxPerRow - 1)
        : 0.0;

    Widget circleTile(int index) {
      final isHighlighted = index == _activeIndex;
      final isPairs = widget.items[index].imageAsset == MenuIcons.pairsGamePng;
      final imageSize = circleSize * (isPairs ? 0.64 : 0.8);
      return MouseRegion(
        onEnter: (_) {
          if (!_focusNode.hasFocus) _focusNode.requestFocus();
          setState(() {
            _hoveredIndex = index;
            _selectedIndex = index;
          });
        },
        onExit: (_) {
          setState(() => _hoveredIndex = null);
        },
        child: GestureDetector(
          onTap: () {
            if (!_focusNode.hasFocus) {
              _focusNode.requestFocus();
            }
            setState(() => _selectedIndex = index);
            _activateSelected();
          },
          child: SizedBox(
            width: circleSize,
            height: circleSize,
            child: AnimatedScale(
              duration: const Duration(milliseconds: 130),
              curve: Curves.easeOut,
              scale: isHighlighted ? _kHighlightScale : 1.0,
              alignment: Alignment.center,
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
                child: Center(
                  child: widget.items[index].imageAsset != null
                      ? Padding(
                          padding: EdgeInsets.all(circleSize * 0.1),
                          child: ClipOval(
                            child: Image.asset(
                              widget.items[index].imageAsset!,
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
          ),
        ),
      );
    }

    Widget centeredRow(List<int> indices) {
      return SizedBox(
        width: widget.gridWidth,
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

    Widget grid = SizedBox(
      width: widget.gridWidth,
      child: _count == 5
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                centeredRow(const [0, 1]),
                SizedBox(height: gap),
                centeredRow(const [2, 3, 4]),
              ],
            )
          : _count == 4
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                centeredRow(const [0, 1]),
                SizedBox(height: gap),
                centeredRow(const [2, 3]),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_count > 0) centeredRow(const [0]),
                if (_count > 1) ...[
                  SizedBox(height: gap),
                  centeredRow([for (var i = 1; i < _count; i++) i]),
                ],
              ],
            ),
    );

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      child: Shortcuts(
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.arrowLeft):
              _MoveCircleSelectionIntent(0, -1),
          SingleActivator(LogicalKeyboardKey.arrowRight):
              _MoveCircleSelectionIntent(0, 1),
          SingleActivator(LogicalKeyboardKey.arrowUp):
              _MoveCircleSelectionIntent(-1, 0),
          SingleActivator(LogicalKeyboardKey.arrowDown):
              _MoveCircleSelectionIntent(1, 0),
          SingleActivator(LogicalKeyboardKey.enter): _ActivateCircleIntent(),
          SingleActivator(LogicalKeyboardKey.space): _ActivateCircleIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            _MoveCircleSelectionIntent:
                CallbackAction<_MoveCircleSelectionIntent>(
                  onInvoke: (intent) {
                    _moveSelection(intent.deltaRow, intent.deltaCol);
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
          child: grid,
        ),
      ),
    );
  }
}
