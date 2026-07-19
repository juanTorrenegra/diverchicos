import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:video_player/video_player.dart';

import '../app_audio.dart';
import '../utils/cutscene_instruction_loop.dart';
import '../utils/game_debug.dart';
import '../widgets/diverchicos_loading_screen.dart';
import '../widgets/match_confetti.dart';
import '../widgets/menu_back_pill.dart';
import 'pairs_instruction_audio.dart';

const String kPairsBackgroundVideoAsset =
    'assets/video/pairs/pairsGreenBG.mp4';

const String _kPairsImageBase = 'assets/images/pairs/';
const String kPairsBackCardAsset = '${_kPairsImageBase}backCard.png';

/// **Base card size** (levels 4–5). Levels 1–3 use [kPairsEarlyLevelCardScale].
/// Coordinates use the 1980×1080 logical game frame (see [_kLogicalW] / [_kLogicalH]).
const double kPairsCardWidth = 160;
const double kPairsCardHeight = 220;

/// Levels 1–3 render cards at base size × this factor (70% bigger → 1.7×).
const double kPairsEarlyLevelCardScale = 1.7;

/// Minimum gap between cards; early levels expand spacing to fill more of the screen.
const double kPairsGridGap = 28;

const double _kLogicalW = 1980;
const double _kLogicalH = 1080;

const List<String> kPairsAnimalAssets = [
  '${_kPairsImageBase}canvaBabilla.png',
  '${_kPairsImageBase}canvaChiguiro.png',
  '${_kPairsImageBase}canvaDelfinRosado.png',
  '${_kPairsImageBase}canvaGuacamaya.png',
  '${_kPairsImageBase}canvaJaguar.png',
  '${_kPairsImageBase}canvaMonkey.png',
  '${_kPairsImageBase}canvaOsoAnteojos.png',
  '${_kPairsImageBase}canvaOsoHormiguero.png',
  '${_kPairsImageBase}canvaRana.png',
];

class _PairsLevelConfig {
  const _PairsLevelConfig({
    required this.pairCount,
    required this.cols,
    required this.rows,
  });

  final int pairCount;
  final int cols;
  final int rows;

  int get cardCount => pairCount * 2;
}

const List<_PairsLevelConfig> _kLevels = [
  _PairsLevelConfig(pairCount: 2, cols: 2, rows: 2),
  _PairsLevelConfig(pairCount: 3, cols: 3, rows: 2),
  _PairsLevelConfig(pairCount: 4, cols: 4, rows: 2),
  _PairsLevelConfig(pairCount: 6, cols: 4, rows: 3),
  _PairsLevelConfig(pairCount: 9, cols: 6, rows: 3),
];

enum _PairsPhase { loading, dealing, flipAll, playing, levelTransition, complete }

class _PairCardModel {
  _PairCardModel({
    required this.id,
    required this.animalAsset,
    required this.gridPosition,
  });

  final String id;
  final String animalAsset;
  final Offset gridPosition;

  Offset position = Offset.zero;
  double scale = 1;
  double flipAngle = 0;
  bool faceUp = true;
  bool placed = false;
  bool matched = false;
}

class _ActiveConfetti {
  const _ActiveConfetti({
    required this.id,
    required this.origin,
    this.cannon = false,
  });

  final int id;
  final Offset origin;
  final bool cannon;
}

/// Memory-style pairs board with five levels and match-two gameplay.
class PairsLayer extends StatefulWidget {
  const PairsLayer({
    super.key,
    required this.onClose,
    this.onLoadError,
  });

  final VoidCallback onClose;
  final void Function(String message)? onLoadError;

  @override
  State<PairsLayer> createState() => _PairsLayerState();
}

class _PairsLayerState extends State<PairsLayer> with TickerProviderStateMixin {
  static const Duration _kInitialDelay = Duration(seconds: 1);
  static const Duration _kMoveDuration = Duration(milliseconds: 350);
  static const Duration _kPulseDuration = Duration(milliseconds: 750);
  static const Duration _kPreFlipDelay = Duration(seconds: 1);
  static const Duration _kFlipDuration = Duration(milliseconds: 300);
  static const Duration _kMismatchDelay = Duration(seconds: 1);
  static const Duration _kLevelFadeDuration = Duration(milliseconds: 1600);
  static const Duration _kLevelCannonDuration = Duration(seconds: 9);

  final math.Random _rng = math.Random();

  VideoPlayerController? _bgController;
  bool _bgReady = false;
  bool _exitingToMenu = false;

  _PairsPhase _phase = _PairsPhase.loading;
  int _levelIndex = 0;
  List<_PairCardModel> _cards = [];
  int _nextCardId = 0;

  _PairCardModel? _firstSelection;
  bool _isResolving = false;
  int _matchedPairCount = 0;

  AnimationController? _whiteFade;

  final Map<String, AnimationController> _flipControllers =
      <String, AnimationController>{};

  int _nextConfettiId = 0;
  final List<_ActiveConfetti> _confettiBursts = <_ActiveConfetti>[];

  final CutsceneInstructionLoop _instructions = CutsceneInstructionLoop();

  @override
  void initState() {
    super.initState();
    GameDebug.log('Pairs', 'initState — layer mounted');
  }

  void _startGameplayInstructions() {
    unawaited(
      _instructions.start(
        PairsInstructionAudio.volteaCartas,
        interval: const Duration(seconds: 15),
      ),
    );
  }

  Future<void> _stopGameplayInstructions() => _instructions.stop();

  _PairsLevelConfig get _currentLevel => _kLevels[_levelIndex];

  double get _cardWidth =>
      _levelIndex < 3 ? kPairsCardWidth * kPairsEarlyLevelCardScale : kPairsCardWidth;

  double get _cardHeight =>
      _levelIndex < 3 ? kPairsCardHeight * kPairsEarlyLevelCardScale : kPairsCardHeight;

  Offset get _stackPosition => Offset(
        _kLogicalW / 2 - _cardWidth / 2,
        _kLogicalH + _cardHeight * 0.35,
      );

  Offset get _centerPosition => Offset(
        _kLogicalW / 2 - _cardWidth / 2,
        _kLogicalH / 2 - _cardHeight / 2,
      );


  List<_PairCardModel> _buildCardsForLevel(int levelIndex) {
    final level = _kLevels[levelIndex];
    final positions = _gridPositions(level);
    final animals = _shuffledPairsForLevel(level.pairCount);

    return [
      for (var i = 0; i < animals.length; i++)
        _PairCardModel(
          id: 'card_${_nextCardId++}',
          animalAsset: animals[i],
          gridPosition: positions[i],
        ),
    ];
  }

  List<String> _shuffledPairsForLevel(int pairCount) {
    final pool = List<String>.from(kPairsAnimalAssets)..shuffle(_rng);
    final selected = pool.take(pairCount).toList();
    final deck = <String>[...selected, ...selected]..shuffle(_rng);
    return deck;
  }

  List<Offset> _gridPositions(_PairsLevelConfig level) {
    final cols = level.cols;
    final rows = level.rows;

    final targetFillW = level.pairCount <= 2
        ? 0.62
        : level.pairCount <= 3
            ? 0.72
            : 0.88;
    final targetFillH = level.pairCount <= 2
        ? 0.68
        : level.pairCount <= 3
            ? 0.74
            : 0.80;

    final availW = _kLogicalW * targetFillW;
    final availH = _kLogicalH * targetFillH;

    final gapX = cols > 1
        ? math.max(
            kPairsGridGap,
            (availW - cols * _cardWidth) / (cols - 1),
          )
        : 0.0;
    final gapY = rows > 1
        ? math.max(
            kPairsGridGap,
            (availH - rows * _cardHeight) / (rows - 1),
          )
        : 0.0;

    final totalW = cols * _cardWidth + (cols - 1) * gapX;
    final totalH = rows * _cardHeight + (rows - 1) * gapY;
    final startX = (_kLogicalW - totalW) / 2;
    final startY = (_kLogicalH - totalH) / 2 + 20;

    return [
      for (var row = 0; row < rows; row++)
        for (var col = 0; col < cols; col++)
          Offset(
            startX + col * (_cardWidth + gapX),
            startY + row * (_cardHeight + gapY),
          ),
    ];
  }

  Future<void> _bootstrapBackground(LoadProgressCallback reportProgress) async {
    GameDebug.log('Pairs', 'bootstrap background video start');
    reportProgress(0.1);
    final c = VideoPlayerController.asset(
      kPairsBackgroundVideoAsset,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    reportProgress(0.25);
    try {
      await c.initialize().timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw TimeoutException('pairs bg init timeout'),
      );
      reportProgress(0.85);
      if (!mounted) {
        await c.dispose();
        return;
      }
      await c.setLooping(true);
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() {
        _bgController = c;
        _bgReady = true;
      });
      reportProgress(1);
      GameDebug.log('Pairs', 'background video ready');
    } catch (e, st) {
      await c.dispose();
      GameDebug.log(
        'Pairs',
        'background video FAILED — using solid fallback (game continues)',
        e,
        st,
      );
      widget.onLoadError?.call(
        'Video de fondo no disponible en este dispositivo. Continuando…',
      );
      if (mounted) {
        setState(() {
          _bgController = null;
          _bgReady = false;
        });
      }
      reportProgress(1);
    }
  }

  void _startAfterReveal() {
    GameDebug.log(
      'Pairs',
      'onRevealed — bgReady=$_bgReady controller=${_bgController != null}',
    );
    final c = _bgController;
    if (c != null) {
      unawaited(() async {
        try {
          await c.play();
          GameDebug.log('Pairs', 'background video play() ok');
        } catch (e, st) {
          GameDebug.log('Pairs', 'background play() failed', e, st);
        }
      }());
    }
    unawaited(_startLevel(skipInitialDelay: false));
  }

  Future<void> _startLevel({required bool skipInitialDelay}) async {
    _firstSelection = null;
    _isResolving = false;
    _matchedPairCount = 0;

    _cards = _buildCardsForLevel(_levelIndex);
    for (final card in _cards) {
      card.position = _stackPosition;
    }
    if (mounted) setState(() {});

    await _runLevelIntroSequence(skipInitialDelay: skipInitialDelay);
  }

  Future<void> _runLevelIntroSequence({required bool skipInitialDelay}) async {
    setState(() => _phase = _PairsPhase.dealing);

    if (!skipInitialDelay) {
      await Future<void>.delayed(_kInitialDelay);
      if (!mounted) return;
    }

    for (final card in _cards) {
      await _dealCard(card);
      if (!mounted) return;
    }

    await Future<void>.delayed(_kPreFlipDelay);
    if (!mounted) return;

    await _flipAllFaceDown();
    if (!mounted) return;

    setState(() => _phase = _PairsPhase.playing);
    _startGameplayInstructions();
  }

  Future<void> _dealCard(_PairCardModel card) async {
    await _animateCard(
      card,
      to: _centerPosition,
      scale: 1,
      duration: _kMoveDuration,
      curve: Curves.easeOutCubic,
    );
    if (!mounted) return;

    await _pulseAtCenter(card);
    if (!mounted) return;

    await _animateCard(
      card,
      to: card.gridPosition,
      scale: 1,
      duration: _kMoveDuration,
      curve: Curves.easeInOutCubic,
    );
    if (!mounted) return;

    card.placed = true;
    setState(() {});
  }

  Future<void> _pulseAtCenter(_PairCardModel card) async {
    final controller = AnimationController(
      vsync: this,
      duration: _kPulseDuration,
    );
    final scaleTween = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1, end: 2)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 2, end: 1)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
    ]);

    void tick() {
      card.scale = scaleTween.evaluate(controller);
      setState(() {});
    }

    controller.addListener(tick);
    await controller.forward();
    controller.removeListener(tick);
    controller.dispose();
    card.scale = 1;
    if (mounted) setState(() {});
  }

  Future<void> _animateCard(
    _PairCardModel card, {
    required Offset to,
    required double scale,
    required Duration duration,
    required Curve curve,
  }) async {
    final from = card.position;
    final fromScale = card.scale;
    final controller = AnimationController(vsync: this, duration: duration);
    final positionTween = Tween<Offset>(begin: from, end: to).animate(
      CurvedAnimation(parent: controller, curve: curve),
    );
    final scaleTween = Tween<double>(begin: fromScale, end: scale).animate(
      CurvedAnimation(parent: controller, curve: curve),
    );

    void tick() {
      card.position = positionTween.value;
      card.scale = scaleTween.value;
      setState(() {});
    }

    controller.addListener(tick);
    await controller.forward();
    controller.removeListener(tick);
    controller.dispose();
  }

  Future<void> _flipAllFaceDown() async {
    setState(() => _phase = _PairsPhase.flipAll);

    final controller = AnimationController(
      vsync: this,
      duration: _kFlipDuration,
    );

    void tick() {
      final angle = controller.value * math.pi;
      for (final card in _cards) {
        if (card.matched) continue;
        card.flipAngle = angle;
        card.faceUp = angle < math.pi / 2;
      }
      setState(() {});
    }

    controller.addListener(tick);
    await controller.forward();
    controller.removeListener(tick);
    controller.dispose();

    for (final card in _cards) {
      if (card.matched) continue;
      card.flipAngle = math.pi;
      card.faceUp = false;
    }
    if (mounted) setState(() {});
  }

  void _disposeFlipControllers() {
    for (final c in _flipControllers.values) {
      c.dispose();
    }
    _flipControllers.clear();
  }

  AnimationController _flipControllerFor(_PairCardModel card) {
    return _flipControllers.putIfAbsent(
      card.id,
      () => AnimationController(
        vsync: this,
        duration: _kFlipDuration,
        value: card.faceUp ? 0 : 1,
      ),
    );
  }

  Future<void> _flipCardTo(_PairCardModel card, {required bool faceUp}) async {
    final controller = _flipControllerFor(card);

    void tick() {
      final angle = controller.value * math.pi;
      card.flipAngle = angle;
      card.faceUp = angle < math.pi / 2;
      setState(() {});
    }

    controller.removeListener(tick);
    controller.addListener(tick);

    if (faceUp) {
      await controller.reverse(from: controller.value);
    } else {
      await controller.forward(from: controller.value);
    }

    controller.removeListener(tick);
    card.flipAngle = faceUp ? 0 : math.pi;
    card.faceUp = faceUp;
    if (mounted) setState(() {});
  }

  Future<void> _onCardTapped(_PairCardModel card) async {
    if (_phase != _PairsPhase.playing || _isResolving) return;
    if (card.matched || card.faceUp) return;

    await _flipCardTo(card, faceUp: true);
    if (!mounted || _phase != _PairsPhase.playing) return;

    final first = _firstSelection;
    if (first == null) {
      setState(() => _firstSelection = card);
      return;
    }

    if (first.id == card.id) return;

    _firstSelection = null;
    _isResolving = true;

    if (first.animalAsset == card.animalAsset) {
      first.matched = true;
      card.matched = true;
      _matchedPairCount++;
      _isResolving = false;
      unawaited(AppAudio.instance.playPairsMatch());
      _spawnMatchConfetti(first, card);
      setState(() {});

      if (_matchedPairCount >= _currentLevel.pairCount) {
        unawaited(_onLevelComplete());
      }
      return;
    }

    await Future<void>.delayed(_kMismatchDelay);
    if (!mounted) return;

    await Future.wait([
      _flipCardTo(first, faceUp: false),
      _flipCardTo(card, faceUp: false),
    ]);

    _isResolving = false;
    if (mounted) setState(() {});
  }

  void _spawnMatchConfetti(_PairCardModel a, _PairCardModel b) {
    final centerA = Offset(
      a.position.dx + _cardWidth / 2,
      a.position.dy + _cardHeight / 2,
    );
    final centerB = Offset(
      b.position.dx + _cardWidth / 2,
      b.position.dy + _cardHeight / 2,
    );
    _confettiBursts.add(
      _ActiveConfetti(id: _nextConfettiId++, origin: centerA),
    );
    _confettiBursts.add(
      _ActiveConfetti(id: _nextConfettiId++, origin: centerB),
    );
  }

  void _removeConfetti(int id) {
    if (!mounted) return;
    final before = _confettiBursts.length;
    _confettiBursts.removeWhere((b) => b.id == id);
    if (_confettiBursts.length != before) setState(() {});
  }

  void _spawnLevelCannonConfetti() {
    // Three yellow star cannons along the bottom, shooting upward.
    final left = Offset(_kLogicalW * 0.2, _kLogicalH + 10);
    final center = Offset(_kLogicalW * 0.5, _kLogicalH + 10);
    final right = Offset(_kLogicalW * 0.8, _kLogicalH + 10);
    _confettiBursts.addAll([
      _ActiveConfetti(id: _nextConfettiId++, origin: left, cannon: true),
      _ActiveConfetti(id: _nextConfettiId++, origin: center, cannon: true),
      _ActiveConfetti(id: _nextConfettiId++, origin: right, cannon: true),
    ]);
  }

  Future<void> _onLevelComplete() async {
    if (!mounted || _phase != _PairsPhase.playing) return;

    unawaited(_stopGameplayInstructions());
    setState(() => _phase = _PairsPhase.levelTransition);

    unawaited(AppAudio.instance.pauseBgm());
    unawaited(AppAudio.instance.playPairsLevelComplete());

    _spawnLevelCannonConfetti();
    setState(() {});
    await Future<void>.delayed(_kLevelCannonDuration);
    if (!mounted) return;

    _confettiBursts.clear();
    setState(() {});

    final isLastLevel = _levelIndex >= _kLevels.length - 1;

    _whiteFade ??= AnimationController(
      vsync: this,
      duration: _kLevelFadeDuration,
    );
    _whiteFade!.duration = _kLevelFadeDuration;
    _whiteFade!.value = 0;
    await _whiteFade!.forward();
    if (!mounted) return;

    unawaited(AppAudio.instance.stopPairsLevelComplete());

    _disposeFlipControllers();
    _firstSelection = null;
    _isResolving = false;

    if (isLastLevel) {
      setState(() => _phase = _PairsPhase.complete);
      await _whiteFade!.reverse();
      if (!mounted) return;
      unawaited(AppAudio.instance.resumeBgm());
      return;
    }

    _levelIndex++;
    setState(() => _cards = []);

    await _whiteFade!.reverse();
    if (!mounted) return;

    unawaited(AppAudio.instance.resumeBgm());
    unawaited(_startLevel(skipInitialDelay: true));
  }

  void _exitToMenu() {
    if (_exitingToMenu) return;
    _exitingToMenu = true;
    unawaited(AppAudio.instance.stopPairsLevelComplete());
    unawaited(AppAudio.instance.stopPairsMatch());
    unawaited(AppAudio.instance.resumeBgm());
    widget.onClose();
  }

  @override
  void dispose() {
    unawaited(_instructions.dispose());
    unawaited(AppAudio.instance.stopPairsLevelComplete());
    unawaited(AppAudio.instance.stopPairsMatch());
    _disposeFlipControllers();
    _whiteFade?.dispose();
    _bgController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DiverchicosLoadingScreen(
      load: _bootstrapBackground,
      useFrogVideo: false,
      showLogo: false,
      debugArea: 'PairsLoad',
      onRevealed: _startAfterReveal,
      child: _buildViewport(),
    );
  }

  Widget _buildViewport() {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: FittedBox(
          fit: BoxFit.fill,
          child: SizedBox(
            width: _kLogicalW,
            height: _kLogicalH,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                if (_bgReady && _bgController != null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: VideoPlayer(_bgController!),
                    ),
                  )
                else
                  const ColoredBox(color: kGameVideoFallbackGreen),
                for (final card in _cards) _buildCard(card),
                for (final burst in _confettiBursts)
                  Positioned.fill(
                    key: ValueKey('confetti_${burst.id}'),
                    child: burst.cannon
                        ? MatchConfettiBurst.cannonBottom(
                            origin: burst.origin,
                            duration: _kLevelCannonDuration,
                            onComplete: () => _removeConfetti(burst.id),
                          )
                        : MatchConfettiBurst(
                            origin: burst.origin,
                            onComplete: () => _removeConfetti(burst.id),
                          ),
                  ),
                if (_whiteFade != null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _whiteFade!,
                        builder: (context, child) {
                          final t = _whiteFade!.value.clamp(0.0, 1.0);
                          return ColoredBox(
                            color: Color.fromRGBO(255, 255, 255, t),
                          );
                        },
                      ),
                    ),
                  ),
                GameLogicalBackPill(onPressed: _exitToMenu),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(_PairCardModel card) {
    final baseW = _cardWidth;
    final baseH = _cardHeight;
    final w = baseW * card.scale;
    final h = baseH * card.scale;
    final canTap = _phase == _PairsPhase.playing &&
        !card.matched &&
        !card.faceUp &&
        !_isResolving;

    return Positioned(
      left: card.position.dx + (baseW - w) / 2,
      top: card.position.dy + (baseH - h) / 2,
      width: w,
      height: h,
      child: PointerInterceptor(
        child: GestureDetector(
          onTap: canTap ? () => unawaited(_onCardTapped(card)) : null,
          child: _FlipCardFace(
            flipAngle: card.flipAngle,
            width: w,
            height: h,
            animalAsset: card.animalAsset,
          ),
        ),
      ),
    );
  }
}

class _FlipCardFace extends StatelessWidget {
  const _FlipCardFace({
    required this.flipAngle,
    required this.width,
    required this.height,
    required this.animalAsset,
  });

  final double flipAngle;
  final double width;
  final double height;
  final String animalAsset;

  @override
  Widget build(BuildContext context) {
    final showFront = flipAngle < math.pi / 2;
    final angle = showFront ? flipAngle : flipAngle - math.pi;

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001)
        ..rotateY(angle),
      child: showFront
          ? _PairsCardFront(
              width: width,
              height: height,
              animalAsset: animalAsset,
            )
          : Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()..rotateY(math.pi),
              child: _PairsCardBack(width: width, height: height),
            ),
    );
  }
}

class _PairsCardFront extends StatelessWidget {
  const _PairsCardFront({
    required this.width,
    required this.height,
    required this.animalAsset,
  });

  final double width;
  final double height;
  final String animalAsset;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(width * 0.08),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x44000000),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(width * 0.12),
            child: Image.asset(
              animalAsset,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}

class _PairsCardBack extends StatelessWidget {
  const _PairsCardBack({
    required this.width,
    required this.height,
  });

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      kPairsBackCardAsset,
      width: width,
      height: height,
      fit: BoxFit.fill,
    );
  }
}
