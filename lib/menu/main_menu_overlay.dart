import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_audio.dart';

/// Main gradient menu: vertical carousel + logo + circle quick-launch grid.
class MainMenuOverlay extends StatelessWidget {
  const MainMenuOverlay({
    super.key,
    required this.onAnimals,
    required this.onKids,
    required this.onSalud,
  });

  final VoidCallback onAnimals;
  final VoidCallback onKids;
  final VoidCallback onSalud;

  List<MenuGameCardData> _cards() {
    return [
      MenuGameCardData(title: 'ANIMALES', onTap: onAnimals),
      MenuGameCardData(title: 'KIDS', onTap: onKids),
      MenuGameCardData(title: 'SALUD', onTap: onSalud),
      const MenuGameCardData(title: 'EXPLORACION'),
      const MenuGameCardData(title: 'ROMPECABEZAS'),
      const MenuGameCardData(title: 'RESOLUCION DE PROBLEMAS'),
      const MenuGameCardData(title: 'TAREAS DEL HOGAR'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final cards = _cards();
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (_) {
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
                    child: Center(child: MenuCarousel(cards: cards)),
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
                    child: MenuCircleGrid(
                      gridWidth: w / 3,
                      items: cards.take(6).toList(),
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

        final mainCardW =
            laneWidth * MenuCarouselTuning.mainCardWidthFactor;
        final mainCardH =
            laneHeight * MenuCarouselTuning.mainCardHeightFactor;
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
                  final card =
                      widget.cards[index % widget.cards.length];
                  final delta = index - _page;
                  final distance = delta.abs().clamp(0.0, 1.0);

                  final scale =
                      1 -
                      (1 - MenuCarouselTuning.sideCardScale) * distance;
                  final opacity =
                      1 -
                      (1 - MenuCarouselTuning.sideCardOpacity) *
                          distance;

                  final dx = -leftShift * distance;
                  final dy = delta.sign * curveOffsetY * distance;
                  final tilt =
                      delta.sign *
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
        );
      },
    );
  }
}

/// Data model for carousel cards and circle grid items.
class MenuGameCardData {
  const MenuGameCardData({required this.title, this.onTap});

  final String title;
  final VoidCallback? onTap;
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
  const _MoveCircleSelectionIntent(this.delta);
  final int delta;
}

class _ActivateCircleIntent extends Intent {
  const _ActivateCircleIntent();
}

/// 6 circle quick-actions linked to first six [MenuGameCardData] entries.
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
  static const int _columns = 3;
  final FocusNode _focusNode = FocusNode(debugLabel: 'menu-circle-grid');
  int _selectedIndex = 0;
  int? _hoveredIndex;

  int get _activeIndex => _hoveredIndex ?? _selectedIndex;
  int get _count => widget.items.length;

  void _moveSelection(int delta) {
    final next = (_selectedIndex + delta).clamp(0, _count - 1);
    if (next != _selectedIndex) {
      setState(() => _selectedIndex = next);
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
            _MoveCircleSelectionIntent:
                CallbackAction<_MoveCircleSelectionIntent>(
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
              children:
                  List.generate(widget.items.length, (index) {
                final isHighlighted = index == _activeIndex;
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
