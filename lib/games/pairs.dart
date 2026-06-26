import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:video_player/video_player.dart';

import '../widgets/menu_back_pill.dart';

const String kPairsBackgroundVideoAsset =
    'assets/video/pairs/pairsGreenBG.mp4';

const String _kPairsImageBase = 'assets/images/pairs/';
const String kPairsBackCardAsset = '${_kPairsImageBase}backCard.png';

/// **Card size** — change these two values to resize every card on screen.
/// Coordinates use the 1980×1080 logical game frame (see [_kLogicalW] / [_kLogicalH]).
const double kPairsCardWidth = 160;
const double kPairsCardHeight = 220;

/// Gap between cards in the 3×3 play grid.
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

enum _PairsPhase { loading, dealing, flipAll, playing }

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
}

/// Memory-style pairs board: intro deal animation, then flip and tap to reveal.
class PairsLayer extends StatefulWidget {
  const PairsLayer({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  State<PairsLayer> createState() => _PairsLayerState();
}

class _PairsLayerState extends State<PairsLayer> with TickerProviderStateMixin {
  static const Duration _kInitialDelay = Duration(seconds: 2);
  static const Duration _kMoveDuration = Duration(milliseconds: 700);
  static const Duration _kPulseDuration = Duration(milliseconds: 1500);
  static const Duration _kPreFlipDelay = Duration(seconds: 2);
  static const Duration _kFlipDuration = Duration(milliseconds: 600);

  VideoPlayerController? _bgController;
  bool _bgReady = false;
  bool _exitingToMenu = false;

  _PairsPhase _phase = _PairsPhase.loading;
  late final List<_PairCardModel> _cards;

  final Map<String, AnimationController> _flipControllers =
      <String, AnimationController>{};

  Offset get _stackPosition => Offset(
        _kLogicalW / 2 - kPairsCardWidth / 2,
        _kLogicalH + kPairsCardHeight * 0.35,
      );

  Offset get _centerPosition => Offset(
        _kLogicalW / 2 - kPairsCardWidth / 2,
        _kLogicalH / 2 - kPairsCardHeight / 2,
      );

  @override
  void initState() {
    super.initState();
    _cards = _buildCards();
    for (final card in _cards) {
      card.position = _stackPosition;
    }
    unawaited(_bootstrapBackground());
  }

  List<_PairCardModel> _buildCards() {
    final positions = _gridPositions();
    return [
      for (var i = 0; i < kPairsAnimalAssets.length; i++)
        _PairCardModel(
          id: 'pair_$i',
          animalAsset: kPairsAnimalAssets[i],
          gridPosition: positions[i],
        ),
    ];
  }

  List<Offset> _gridPositions() {
    const cols = 3;
    const rows = 3;
    final totalW = cols * kPairsCardWidth + (cols - 1) * kPairsGridGap;
    final totalH = rows * kPairsCardHeight + (rows - 1) * kPairsGridGap;
    final startX = (_kLogicalW - totalW) / 2;
    final startY = (_kLogicalH - totalH) / 2 + 36;

    return [
      for (var row = 0; row < rows; row++)
        for (var col = 0; col < cols; col++)
          Offset(
            startX + col * (kPairsCardWidth + kPairsGridGap),
            startY + row * (kPairsCardHeight + kPairsGridGap),
          ),
    ];
  }

  Future<void> _bootstrapBackground() async {
    final c = VideoPlayerController.asset(
      kPairsBackgroundVideoAsset,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    try {
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      await c.setLooping(true);
      await c.play();
      setState(() {
        _bgController = c;
        _bgReady = true;
      });
      unawaited(_runIntroSequence());
    } catch (_) {
      await c.dispose();
      if (mounted) _exitToMenu();
    }
  }

  Future<void> _runIntroSequence() async {
    setState(() => _phase = _PairsPhase.dealing);
    await Future<void>.delayed(_kInitialDelay);
    if (!mounted) return;

    for (var i = 0; i < _cards.length; i++) {
      await _dealCard(_cards[i]);
      if (!mounted) return;
    }

    await Future<void>.delayed(_kPreFlipDelay);
    if (!mounted) return;

    await _flipAllFaceDown();
    if (!mounted) return;

    setState(() => _phase = _PairsPhase.playing);
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
      card.flipAngle = math.pi;
      card.faceUp = false;
    }
    if (mounted) setState(() {});
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

  Future<void> _toggleCard(_PairCardModel card) async {
    if (_phase != _PairsPhase.playing) return;

    final controller = _flipControllerFor(card);
    final goingFaceUp = !card.faceUp;

    void tick() {
      final angle = controller.value * math.pi;
      card.flipAngle = angle;
      card.faceUp = angle < math.pi / 2;
      setState(() {});
    }

    controller.removeListener(tick);
    controller.addListener(tick);

    if (goingFaceUp) {
      await controller.reverse(from: controller.value);
    } else {
      await controller.forward(from: controller.value);
    }

    controller.removeListener(tick);
    card.flipAngle = goingFaceUp ? 0 : math.pi;
    card.faceUp = goingFaceUp;
    if (mounted) setState(() {});
  }

  void _exitToMenu() {
    if (_exitingToMenu) return;
    _exitingToMenu = true;
    widget.onClose();
  }

  @override
  void dispose() {
    for (final c in _flipControllers.values) {
      c.dispose();
    }
    _bgController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                  const ColoredBox(color: Color(0xFF2E7D32)),
                for (final card in _cards) _buildCard(card),
                GameLogicalBackPill(onPressed: _exitToMenu),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(_PairCardModel card) {
    final w = kPairsCardWidth * card.scale;
    final h = kPairsCardHeight * card.scale;
    final canTap = _phase == _PairsPhase.playing;

    return Positioned(
      left: card.position.dx + (kPairsCardWidth - w) / 2,
      top: card.position.dy + (kPairsCardHeight - h) / 2,
      width: w,
      height: h,
      child: PointerInterceptor(
        child: GestureDetector(
          onTap: canTap ? () => unawaited(_toggleCard(card)) : null,
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
