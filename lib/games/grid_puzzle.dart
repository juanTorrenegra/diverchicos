import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:video_player/video_player.dart';

import '../utils/cutscene_instruction_loop.dart';
import '../utils/disable_video_pointer.dart';
import '../widgets/menu_back_pill.dart';
import 'chicken_instruction_audio.dart';

const String kGridPuzzleIntroAsset = 'assets/video/GridPuzzleIntro.mp4';
const String kGridPuzzleEndAsset = 'assets/video/gridPuzzleEnd.mp4';
const String _kAssetBase = 'assets/images/gridPuzzleGame/';

enum RoadDirection { north, south, east, west }

extension _RoadDirectionOps on RoadDirection {
  RoadDirection get opposite => switch (this) {
    RoadDirection.north => RoadDirection.south,
    RoadDirection.south => RoadDirection.north,
    RoadDirection.east => RoadDirection.west,
    RoadDirection.west => RoadDirection.east,
  };
}

enum RoadFigureType {
  straightVertical,
  straightHorizontal,
  cornerTopRight,
  cornerTopLeft,
  cornerBottomRight,
  cornerBottomLeft,
}

extension RoadFigureTypeX on RoadFigureType {
  String get assetPath => switch (this) {
    RoadFigureType.straightVertical => '${_kAssetBase}straightVertical.png',
    RoadFigureType.straightHorizontal => '${_kAssetBase}straightHorizontal.png',
    RoadFigureType.cornerTopRight => '${_kAssetBase}cornerTopRight.png',
    RoadFigureType.cornerTopLeft => '${_kAssetBase}cornerTopLeft.png',
    RoadFigureType.cornerBottomRight => '${_kAssetBase}cornerBottomRight.png',
    RoadFigureType.cornerBottomLeft => '${_kAssetBase}cornerBottomLeft.png',
  };

  Set<RoadDirection> get connections => switch (this) {
    RoadFigureType.straightVertical => {
      RoadDirection.north,
      RoadDirection.south,
    },
    RoadFigureType.straightHorizontal => {
      RoadDirection.east,
      RoadDirection.west,
    },
    RoadFigureType.cornerTopRight => {RoadDirection.north, RoadDirection.east},
    RoadFigureType.cornerTopLeft => {RoadDirection.north, RoadDirection.west},
    RoadFigureType.cornerBottomRight => {
      RoadDirection.south,
      RoadDirection.east,
    },
    RoadFigureType.cornerBottomLeft => {
      RoadDirection.south,
      RoadDirection.west,
    },
  };
}

class _RoadFigureInstance {
  _RoadFigureInstance({
    required this.id,
    required this.type,
    required this.holderIndex,
  });

  final String id;
  final RoadFigureType type;
  final int holderIndex;
  Offset position = Offset.zero;
  int? slotIndex;
}

enum _GirlMotion { idle, walking, success, returning }

class _FallingStar {
  _FallingStar({
    required this.assetPath,
    required this.x,
    required this.rotation,
    required this.fallSpeed,
    required this.spawnMs,
    required this.size,
    required this.spinSpeed,
  });

  final String assetPath;
  final double x;
  final double rotation;
  final double fallSpeed;
  final int spawnMs;
  final double size;
  final double spinSpeed;

  double get startY => -size;

  bool hasSpawned(double elapsedMs) => elapsedMs >= spawnMs;

  double yAt(double elapsedMs) {
    if (!hasSpawned(elapsedMs)) return startY;
    return startY + ((elapsedMs - spawnMs) / 1000) * fallSpeed;
  }

  double rotationAt(double elapsedMs) {
    if (!hasSpawned(elapsedMs)) return rotation;
    return rotation + ((elapsedMs - spawnMs) / 1000) * spinSpeed;
  }
}

/// Fullscreen grid puzzle: intro video, then path-building gameplay.
class GridPuzzleLayer extends StatefulWidget {
  const GridPuzzleLayer({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  State<GridPuzzleLayer> createState() => _GridPuzzleLayerState();
}

class _GridPuzzleLayerState extends State<GridPuzzleLayer>
    with TickerProviderStateMixin {
  static const double _kLogicalW = 1980;
  static const double _kLogicalH = 1080;

  static const Offset _kGridOrigin = Offset(704, 38);
  static const Size _kGridSize = Size(940, 740);
  static const int _kCols = 5;
  static const int _kRows = 4;
  static const Size _kSlotSize = Size(188, 185);

  static const int _kGirlSlot = 0;
  static const int _kPlaneSlot = 19;

  /// Home row for the six road sprites, directly under the puzzle grid.
  static const double _kRoadFiguresY = 844;
  static const double _kSlotCircleSize = 300;
  static const int _kSlotCircleAnimateMs = 2000;
  static const int _kSlotCirclePauseMs = 2000;
  static const int _kSlotCircleCycleMs =
      _kSlotCircleAnimateMs + _kSlotCirclePauseMs;
  static const double _kSlotCircleMaxOpacity = 0.55;
  static const double _kPlayButtonSize = 500;
  static const double _kPlayButtonPeakSize = 700;
  static const double _kPlayButtonGap = 24;
  static const int _kPlayButtonAppearMs = 1000;
  static const int _kPlayButtonGrowMs = 600;
  static const double _kPlayButtonStartScale = 0.01;

  static const List<RoadFigureType> _kFigureTypes = RoadFigureType.values;

  static const List<String> _kStarAssets = [
    'assets/images/cyanStar.png',
    'assets/images/greenStar.png',
    'assets/images/pinkStar.png',
    'assets/images/purpleStar.png',
    'assets/images/whiteStar.png',
    'assets/images/yellowStar.png',
  ];

  static const int _kStarRainDurationMs = 4000;
  static const int _kStarCopiesPerAsset = 20;
  static const int _kWhiteFadeInMs = 2000;
  static const int _kExitFadeMs = 1000;
  static const int _kEndVideoHoldMs = 1000;

  static const double _kIntroFastPlaybackSpeed = 5.0;

  VideoPlayerController? _introController;
  bool _introReady = false;
  bool _introFinished = false;
  bool _introPlaybackBoosted = false;

  VideoPlayerController? _endingController;
  bool _endingReady = false;
  bool _gameplayVisible = true;

  AnimationController? _whiteFade;
  Ticker? _starRainTicker;
  Stopwatch? _starRainStopwatch;
  bool _starRainSpawnComplete = false;
  Completer<void>? _starsFallenCompleter;

  int _nextFigureId = 0;
  late List<_RoadFigureInstance> _figures;
  final Map<int, String> _slotOccupants = {};

  String? _draggingFigureId;
  _GirlMotion _girlMotion = _GirlMotion.idle;
  Offset _girlPosition = _kGridOrigin;

  List<_FallingStar> _fallingStars = const [];
  bool _exitingToMenu = false;
  bool _pathReady = false;

  AnimationController? _slotCirclePulseController;
  AnimationController? _playButtonAppearController;

  final CutsceneInstructionLoop _instructions = CutsceneInstructionLoop();

  void _startGameplayInstructions() {
    unawaited(
      _instructions.start(
        ChickenInstructionAudio.fichasParaCamino,
        interval: const Duration(seconds: 6),
      ),
    );
  }

  Future<void> _stopGameplayInstructions() => _instructions.stop();

  Future<void> _pauseGameplayInstructions() => _instructions.pause();

  @override
  void initState() {
    super.initState();
    _figures = [
      for (var i = 0; i < _kFigureTypes.length; i++)
        _RoadFigureInstance(
          id: _newFigureId(),
          type: _kFigureTypes[i],
          holderIndex: i,
        )..position = _figureHomeForIndex(i),
    ];
    _girlPosition = _slotTopLeft(_kGirlSlot);
    unawaited(_bootstrapIntro());
  }

  String _newFigureId() => 'road_${_nextFigureId++}';

  Offset _slotTopLeft(int slot) {
    final row = slot ~/ _kCols;
    final col = slot % _kCols;
    return _kGridOrigin +
        Offset(col * _kSlotSize.width, row * _kSlotSize.height);
  }

  Offset _figureHomeForIndex(int index) {
    final count = _kFigureTypes.length;
    final leading = (_kLogicalW - count * _kSlotSize.width) / (count + 1);
    final x = leading + index * (_kSlotSize.width + leading);
    return Offset(x, _kRoadFiguresY);
  }

  Offset _slotLocalTopLeft(int slot) {
    final row = slot ~/ _kCols;
    final col = slot % _kCols;
    return Offset(col * _kSlotSize.width, row * _kSlotSize.height);
  }

  bool _isHomeFigure(_RoadFigureInstance figure) => figure.slotIndex == null;

  Iterable<_RoadFigureInstance> get _placedGridFigures sync* {
    for (final figure in _figures) {
      if (figure.slotIndex != null) yield figure;
    }
  }

  Future<void> _releaseVideoPointerCapture() async {
    disableVideoPointerEvents();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (mounted) disableVideoPointerEvents();
  }

  bool _isReservedSlot(int slot) => slot == _kGirlSlot || slot == _kPlaneSlot;

  int? _slotAtPosition(Offset figureTopLeft) {
    final center =
        figureTopLeft + Offset(_kSlotSize.width / 2, _kSlotSize.height / 2);
    final local = center - _kGridOrigin;
    if (local.dx < 0 ||
        local.dy < 0 ||
        local.dx > _kGridSize.width ||
        local.dy > _kGridSize.height) {
      return null;
    }
    final col = (local.dx / _kSlotSize.width).floor().clamp(0, _kCols - 1);
    final row = (local.dy / _kSlotSize.height).floor().clamp(0, _kRows - 1);
    return row * _kCols + col;
  }

  Map<int, RoadFigureType> get _placementTypes {
    final map = <int, RoadFigureType>{};
    for (final figure in _figures) {
      final slot = figure.slotIndex;
      if (slot != null) {
        map[slot] = figure.type;
      }
    }
    return map;
  }

  bool _canTraverse(
    int fromRow,
    int fromCol,
    int toRow,
    int toCol,
    Map<int, RoadFigureType> placements,
  ) {
    final dr = toRow - fromRow;
    final dc = toCol - fromCol;
    if (dr.abs() + dc.abs() != 1) return false;

    late final RoadDirection exitDir;
    if (dr == -1) {
      exitDir = RoadDirection.north;
    } else if (dr == 1) {
      exitDir = RoadDirection.south;
    } else if (dc == 1) {
      exitDir = RoadDirection.east;
    } else {
      exitDir = RoadDirection.west;
    }
    final enterDir = exitDir.opposite;

    final fromSlot = fromRow * _kCols + fromCol;
    final toSlot = toRow * _kCols + toCol;

    if (fromSlot == _kGirlSlot) {
      if (toSlot == _kPlaneSlot) return false;
      final toType = placements[toSlot];
      return toType != null && toType.connections.contains(enterDir);
    }

    if (toSlot == _kPlaneSlot) {
      final fromType = placements[fromSlot];
      return fromType != null && fromType.connections.contains(exitDir);
    }

    final fromType = placements[fromSlot];
    final toType = placements[toSlot];
    if (fromType == null || toType == null) return false;
    return fromType.connections.contains(exitDir) &&
        toType.connections.contains(enterDir);
  }

  List<int>? _findPathToPlane() {
    const goalRow = 3;
    const goalCol = 4;
    final placements = _placementTypes;

    final queue = <List<(int, int)>>[
      [(0, 0)],
    ];
    final visited = <String>{'0,0'};

    while (queue.isNotEmpty) {
      final path = queue.removeAt(0);
      final (row, col) = path.last;
      if (row == goalRow && col == goalCol) {
        return [for (final cell in path) cell.$1 * _kCols + cell.$2];
      }

      const deltas = [(-1, 0), (1, 0), (0, -1), (0, 1)];
      for (final (dr, dc) in deltas) {
        final nr = row + dr;
        final nc = col + dc;
        if (nr < 0 || nc < 0 || nr >= _kRows || nc >= _kCols) continue;
        final key = '$nr,$nc';
        if (visited.contains(key)) continue;
        if (!_canTraverse(row, col, nr, nc, placements)) continue;
        visited.add(key);
        queue.add([...path, (nr, nc)]);
      }
    }
    return null;
  }

  List<int>? _findLongestWalkFromStart() {
    final placements = _placementTypes;
    var best = <int>[_kGirlSlot];

    void visit(int row, int col, List<int> path, Set<String> visited) {
      if (path.length > best.length) {
        best = List<int>.from(path);
      }
      const deltas = [(-1, 0), (1, 0), (0, -1), (0, 1)];
      for (final (dr, dc) in deltas) {
        final nr = row + dr;
        final nc = col + dc;
        if (nr < 0 || nc < 0 || nr >= _kRows || nc >= _kCols) continue;
        final key = '$nr,$nc';
        if (visited.contains(key)) continue;
        if (!_canTraverse(row, col, nr, nc, placements)) continue;
        visit(nr, nc, [...path, nr * _kCols + nc], {...visited, key});
      }
    }

    visit(0, 0, const [_kGirlSlot], {'0,0'});
    return best.length > 1 ? best : null;
  }

  Future<void> _bootstrapIntro() async {
    final c = VideoPlayerController.asset(
      kGridPuzzleIntroAsset,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    try {
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      await c.setLooping(false);
      c.addListener(_onIntroTick);
      await c.play();
      setState(() {
        _introController = c;
        _introReady = true;
      });
    } catch (_) {
      await c.dispose();
      if (mounted) _exitToMenu();
    }
  }

  void _onIntroTick() {
    final v = _introController;
    if (v == null || !mounted) return;
    final value = v.value;
    if (!value.isInitialized || value.hasError) return;
    if (value.isCompleted && !_introFinished) {
      unawaited(v.pause());
      v.removeListener(_onIntroTick);
      _finishIntro();
    }
  }

  void _finishIntro() {
    if (_introFinished) return;
    setState(() => _introFinished = true);
    if (!_instructions.isRunning) {
      _startGameplayInstructions();
    }
    _startSlotCirclePulse();
    unawaited(_releaseVideoPointerCapture());
  }

  void _startSlotCirclePulse() {
    _slotCirclePulseController?.dispose();
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _kSlotCircleCycleMs),
    );
    controller.addListener(() {
      if (mounted) setState(() {});
    });
    _slotCirclePulseController = controller;
    controller.repeat();
  }

  double _slotCircleOpacity() {
    final controller = _slotCirclePulseController;
    if (!_introFinished || controller == null) return 0;

    final elapsedMs = controller.value * _kSlotCircleCycleMs;
    if (elapsedMs >= _kSlotCircleAnimateMs) return 0;

    final t = elapsedMs / _kSlotCircleAnimateMs;
    return math.sin(t * math.pi) * _kSlotCircleMaxOpacity;
  }

  Widget _buildRoadFigureSlotCircles() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (var i = 0; i < _kFigureTypes.length; i++)
          _buildSlotCircleHighlight(i),
      ],
    );
  }

  Widget _buildSlotCircleHighlight(int index) {
    final home = _figureHomeForIndex(index);
    final opacity = _slotCircleOpacity();
    return Positioned(
      left: home.dx + (_kSlotSize.width - _kSlotCircleSize) / 2,
      top: home.dy + (_kSlotSize.height - _kSlotCircleSize) / 2,
      width: _kSlotCircleSize,
      height: _kSlotCircleSize,
      child: IgnorePointer(
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.red.withValues(alpha: opacity),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _speedUpIntro() async {
    if (_introFinished || !_introReady || _introPlaybackBoosted) return;
    final v = _introController;
    if (v == null) return;

    _introPlaybackBoosted = true;
    await v.setPlaybackSpeed(_kIntroFastPlaybackSpeed);
    if (!mounted || _introFinished) return;
    if (!v.value.isPlaying) {
      await v.play();
    }
    setState(() {});
  }

  Widget _buildIntroSkipButton() {
    return Positioned(
      left: 16,
      top: 20,
      child: PointerInterceptor(
        child: Material(
          color: const Color(0xFFFFC107),
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: () => unawaited(_speedUpIntro()),
            borderRadius: BorderRadius.circular(8),
            child: const SizedBox(width: 40, height: 40),
          ),
        ),
      ),
    );
  }

  void _onGridTapped() {
    if (!_introFinished ||
        _draggingFigureId != null ||
        _girlMotion != _GirlMotion.idle) {
      return;
    }

    if (_pathReady) return;

    final fallbackPath = _findLongestWalkFromStart();
    if (fallbackPath != null) {
      unawaited(_walkGirl(fallbackPath, success: false));
    }
  }

  void _updatePathReadyState() {
    if (!mounted || _girlMotion != _GirlMotion.idle) return;
    final ready = _findPathToPlane() != null;
    if (ready == _pathReady) return;
    if (ready) {
      _startPlayButtonAppearAnimation();
    } else {
      _disposePlayButtonAppearAnimation();
    }
    setState(() => _pathReady = ready);
  }

  void _startPlayButtonAppearAnimation() {
    _playButtonAppearController?.dispose();
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _kPlayButtonAppearMs),
    );
    controller.addListener(() {
      if (mounted) setState(() {});
    });
    _playButtonAppearController = controller;
    controller.forward(from: 0);
  }

  void _disposePlayButtonAppearAnimation() {
    _playButtonAppearController?.dispose();
    _playButtonAppearController = null;
  }

  double _playButtonScale() {
    final controller = _playButtonAppearController;
    if (!_pathReady || controller == null) return 1;

    final elapsedMs = controller.value * _kPlayButtonAppearMs;
    final peakScale = _kPlayButtonPeakSize / _kPlayButtonSize;

    if (elapsedMs <= _kPlayButtonGrowMs) {
      final t = elapsedMs / _kPlayButtonGrowMs;
      return _kPlayButtonStartScale +
          (peakScale - _kPlayButtonStartScale) * Curves.easeOut.transform(t);
    }

    final t =
        (elapsedMs - _kPlayButtonGrowMs) /
        (_kPlayButtonAppearMs - _kPlayButtonGrowMs);
    return peakScale + (1 - peakScale) * Curves.easeInOut.transform(t);
  }

  void _clearPathReady() {
    if (!_pathReady) return;
    _disposePlayButtonAppearAnimation();
    setState(() => _pathReady = false);
  }

  void _tryStartGirlWalk() {
    if (!_introFinished ||
        _draggingFigureId != null ||
        _girlMotion != _GirlMotion.idle ||
        !_pathReady) {
      return;
    }

    final pathToPlane = _findPathToPlane();
    if (pathToPlane == null) {
      _clearPathReady();
      return;
    }

    _clearPathReady();
    unawaited(_walkGirl(pathToPlane, success: true));
  }

  Widget _buildPlayButton() {
    if (!_pathReady) return const SizedBox.shrink();

    final top = _kGridOrigin.dy + (_kGridSize.height - _kPlayButtonSize) / 2;
    final left = _kGridOrigin.dx - _kPlayButtonGap - _kPlayButtonSize;

    return Positioned(
      left: left,
      top: top,
      width: _kPlayButtonSize,
      height: _kPlayButtonSize,
      child: Transform.scale(
        scale: _playButtonScale(),
        child: PointerInterceptor(
          child: Material(
            color: const Color.fromARGB(255, 232, 6, 6),
            elevation: 8,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: _tryStartGirlWalk,
              customBorder: const CircleBorder(),
              child: const Center(
                child: Icon(
                  Icons.play_arrow_rounded,
                  size: 440,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _walkGirl(List<int> path, {required bool success}) async {
    setState(() {
      _girlMotion = _GirlMotion.walking;
      _girlPosition = _slotTopLeft(path.first);
    });

    for (var i = 1; i < path.length; i++) {
      await _animateGirlTo(_slotTopLeft(path[i]));
      if (!mounted) return;
    }

    if (!mounted) return;
    if (success && path.last == _kPlaneSlot) {
      unawaited(_pauseGameplayInstructions());
      setState(() => _girlMotion = _GirlMotion.success);
      unawaited(_runSuccessSequence());
      return;
    }

    await _walkGirlAndReturn(path);
  }

  Future<void> _runSuccessSequence() async {
    await _stopGameplayInstructions();
    await Future<void>.delayed(const Duration(seconds: 1));
    if (!mounted || _girlMotion != _GirlMotion.success) return;

    _startStarRain();
    _whiteFade?.dispose();
    _whiteFade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _kWhiteFadeInMs),
    );
    setState(() {});

    await _whiteFade!.forward();
    if (!mounted) return;

    await _hideGameplayAndLoadEndVideo();
    if (!mounted) return;

    await Future<void>.delayed(
      Duration(
        milliseconds: math.max(
          0,
          _kStarRainDurationMs -
              (_starRainStopwatch?.elapsedMilliseconds ?? _kStarRainDurationMs),
        ),
      ),
    );
    if (!mounted) return;

    _starRainSpawnComplete = true;
    _pruneOffscreenStars();
    if (_fallingStars.isEmpty) {
      _stopStarRainTicker();
    } else {
      _starsFallenCompleter = Completer<void>();
      await _starsFallenCompleter!.future;
    }
    if (!mounted) return;

    await _whiteFade!.reverse();
    if (!mounted) return;
    _whiteFade?.dispose();
    _whiteFade = null;
    setState(() {});

    await _playEndVideo();
    if (!mounted) return;

    _whiteFade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _kExitFadeMs),
    );
    setState(() {});
    await _whiteFade!.forward();
    if (!mounted) return;
    _exitToMenu();
  }

  Future<void> _hideGameplayAndLoadEndVideo() async {
    final intro = _introController;
    _introController = null;
    _introReady = false;
    if (intro != null) {
      intro.removeListener(_onIntroTick);
      await intro.dispose();
    }

    final end = VideoPlayerController.asset(
      kGridPuzzleEndAsset,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    try {
      await end.initialize();
      if (!mounted) {
        await end.dispose();
        return;
      }
      await end.setLooping(false);
      await end.seekTo(Duration.zero);
      await end.pause();
      if (!mounted) {
        await end.dispose();
        return;
      }
      setState(() {
        _gameplayVisible = false;
        _endingController = end;
        _endingReady = true;
      });
      unawaited(_releaseVideoPointerCapture());
    } catch (_) {
      await end.dispose();
      if (mounted) _exitToMenu();
    }
  }

  Future<void> _playEndVideo() async {
    final end = _endingController;
    if (end == null || !_endingReady) return;

    final completer = Completer<void>();
    void onTick() {
      final value = end.value;
      if (!value.isInitialized || value.hasError) return;
      if (value.isCompleted) {
        end.removeListener(onTick);
        if (!completer.isCompleted) completer.complete();
      }
    }

    end.addListener(onTick);
    await end.play();
    if (mounted) setState(() {});
    await completer.future;
    await end.pause();
    final duration = end.value.duration;
    if (duration > Duration.zero) {
      await end.seekTo(duration);
    }
    if (mounted) setState(() {});
    await Future<void>.delayed(const Duration(milliseconds: _kEndVideoHoldMs));
  }

  void _startStarRain() {
    final random = math.Random();
    final stars = <_FallingStar>[];
    final totalStars = _kStarAssets.length * _kStarCopiesPerAsset;
    var starIndex = 0;

    for (final asset in _kStarAssets) {
      for (var copy = 0; copy < _kStarCopiesPerAsset; copy++) {
        final size = (34 + random.nextDouble() * 52) * 4;
        final spawnProgress = starIndex / (totalStars - 1);
        final spawnMs =
            (math.pow(spawnProgress, 1.65) * (_kStarRainDurationMs - 350))
                .round() +
            random.nextInt(120);
        stars.add(
          _FallingStar(
            assetPath: asset,
            x: random.nextDouble() * (_kLogicalW - size),
            rotation: random.nextDouble() * math.pi * 2,
            fallSpeed: 220 + random.nextDouble() * 180,
            spawnMs: spawnMs,
            size: size,
            spinSpeed: (random.nextDouble() - 0.5) * 1.8,
          ),
        );
        starIndex++;
      }
    }

    _stopStarRainTicker();
    _starRainSpawnComplete = false;
    _starsFallenCompleter = null;
    _starRainStopwatch = Stopwatch()..start();
    _starRainTicker = createTicker(_onStarRainTick)..start();

    setState(() => _fallingStars = stars);
  }

  void _onStarRainTick(Duration _) {
    if (!mounted || _starRainStopwatch == null) return;
    _pruneOffscreenStars();
    if (_starRainSpawnComplete && _fallingStars.isEmpty) {
      _stopStarRainTicker();
      final completer = _starsFallenCompleter;
      if (completer != null && !completer.isCompleted) {
        completer.complete();
      }
    }
    setState(() {});
  }

  void _pruneOffscreenStars() {
    final elapsed = _starRainStopwatch?.elapsedMilliseconds.toDouble() ?? 0;
    _fallingStars = _fallingStars.where((star) {
      if (!star.hasSpawned(elapsed)) {
        return !_starRainSpawnComplete;
      }
      return star.yAt(elapsed) < _kLogicalH + star.size;
    }).toList();
  }

  void _stopStarRainTicker() {
    _starRainTicker?.dispose();
    _starRainTicker = null;
    _starRainStopwatch?.stop();
    _starRainStopwatch = null;
    _fallingStars = const [];
  }

  double get _starRainElapsedMs =>
      _starRainStopwatch?.elapsedMilliseconds.toDouble() ?? 0;

  Widget _buildStarRain() {
    if (_fallingStars.isEmpty && _starRainStopwatch == null) {
      return const SizedBox.shrink();
    }

    final elapsedMs = _starRainElapsedMs;
    return Positioned.fill(
      child: ClipRect(
        child: IgnorePointer(
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              for (final star in _fallingStars)
                if (star.hasSpawned(elapsedMs) &&
                    star.yAt(elapsedMs) < _kLogicalH + star.size)
                  Positioned(
                    left: star.x,
                    top: star.yAt(elapsedMs),
                    width: star.size,
                    height: star.size,
                    child: Transform.rotate(
                      angle: star.rotationAt(elapsedMs),
                      child: Image.asset(
                        star.assetPath,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.star_rounded,
                            size: star.size,
                            color: Colors.amber,
                          );
                        },
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWhiteFadeOverlay() {
    final ctrl = _whiteFade;
    if (ctrl == null) return const SizedBox.shrink();
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: ctrl,
          builder: (context, child) {
            final t = ctrl.value.clamp(0.0, 1.0);
            return ColoredBox(color: Color.fromRGBO(255, 255, 255, t));
          },
        ),
      ),
    );
  }

  Future<void> _walkGirlAndReturn(List<int> path) async {
    if (!mounted) return;
    setState(() => _girlMotion = _GirlMotion.returning);

    for (var i = path.length - 2; i >= 0; i--) {
      await _animateGirlTo(_slotTopLeft(path[i]));
      if (!mounted) return;
    }

    if (!mounted) return;
    setState(() {
      _girlMotion = _GirlMotion.idle;
      _girlPosition = _slotTopLeft(_kGirlSlot);
    });
    _updatePathReadyState();
  }

  Future<void> _animateGirlTo(Offset target) async {
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    final animation = CurvedAnimation(
      parent: controller,
      curve: Curves.easeInOut,
    );
    final begin = _girlPosition;
    controller.addListener(() {
      if (!mounted) return;
      setState(() {
        _girlPosition = Offset.lerp(begin, target, animation.value)!;
      });
    });
    await controller.forward();
    controller.dispose();
  }

  Future<void> _animateFigureTo(
    _RoadFigureInstance figure,
    Offset target,
  ) async {
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    final animation = CurvedAnimation(
      parent: controller,
      curve: Curves.easeOutBack,
    );
    final begin = figure.position;
    controller.addListener(() {
      if (!mounted) return;
      setState(() {
        figure.position = Offset.lerp(begin, target, animation.value)!;
      });
    });
    await controller.forward();
    controller.dispose();
  }

  _RoadFigureInstance? _figureById(String id) {
    for (final figure in _figures) {
      if (figure.id == id) return figure;
    }
    return null;
  }

  void _spawnHolderCopy(RoadFigureType type) {
    final index = _kFigureTypes.indexOf(type);
    _figures.add(
      _RoadFigureInstance(id: _newFigureId(), type: type, holderIndex: index)
        ..position = _figureHomeForIndex(index),
    );
  }

  Future<void> _onFigureReleased(String id) async {
    final figure = _figureById(id);
    if (figure == null) return;

    final targetSlot = _slotAtPosition(figure.position);
    final wasOnGrid = figure.slotIndex != null;
    final previousSlot = figure.slotIndex;

    if (targetSlot == null ||
        _isReservedSlot(targetSlot) ||
        (_slotOccupants.containsKey(targetSlot) &&
            _slotOccupants[targetSlot] != id)) {
      if (wasOnGrid && previousSlot != null) {
        _slotOccupants.remove(previousSlot);
        figure.slotIndex = null;
      }
      setState(() => _draggingFigureId = null);
      await _animateFigureTo(figure, _figureHomeForIndex(figure.holderIndex));
      if (mounted) {
        setState(() {});
        _updatePathReadyState();
      }
      return;
    }

    if (wasOnGrid && previousSlot != null && previousSlot != targetSlot) {
      _slotOccupants.remove(previousSlot);
    }

    figure.slotIndex = targetSlot;
    _slotOccupants[targetSlot] = id;
    setState(() => _draggingFigureId = null);
    await _animateFigureTo(figure, _slotTopLeft(targetSlot));

    if (!wasOnGrid && mounted) {
      setState(() => _spawnHolderCopy(figure.type));
    } else if (mounted) {
      setState(() {});
    }
    _updatePathReadyState();
  }

  void _exitToMenu() {
    if (_exitingToMenu) return;
    _exitingToMenu = true;
    unawaited(_stopGameplayInstructions());
    restoreAppPointerEvents();
    widget.onClose();
  }

  @override
  void dispose() {
    unawaited(_instructions.dispose());
    restoreAppPointerEvents();
    _stopStarRainTicker();
    _whiteFade?.dispose();
    _slotCirclePulseController?.dispose();
    _disposePlayButtonAppearAnimation();
    _introController?.removeListener(_onIntroTick);
    _introController?.dispose();
    _endingController?.dispose();
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
            child: ClipRect(
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  if (_gameplayVisible &&
                      _introReady &&
                      _introController != null &&
                      !_introFinished) ...[
                    Positioned.fill(child: VideoPlayer(_introController!)),
                    if (!_introPlaybackBoosted) _buildIntroSkipButton(),
                  ],
                  if (_gameplayVisible &&
                      _introReady &&
                      _introController != null &&
                      _introFinished)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: VideoPlayer(_introController!),
                      ),
                    ),
                  if (_gameplayVisible && _introFinished)
                    Positioned.fill(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          _buildGridArea(),
                          _buildPlayButton(),
                          _buildPlane(),
                          _buildGirl(),
                          _buildRoadFigureSlotCircles(),
                          _buildRoadFigureRow(),
                        ],
                      ),
                    )
                  else if (!_introReady && _gameplayVisible)
                    const ColoredBox(color: Colors.black),
                  if (_endingReady && _endingController != null)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: VideoPlayer(_endingController!),
                      ),
                    ),
                  _buildWhiteFadeOverlay(),
                  _buildStarRain(),
                  if (_girlMotion == _GirlMotion.idle ||
                      _girlMotion == _GirlMotion.walking)
                    GameLogicalBackPill(onPressed: _exitToMenu),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  _RoadFigureInstance? _homeFigureForSlot(int index) {
    final type = _kFigureTypes[index];
    _RoadFigureInstance? selected;
    for (final figure in _figures) {
      if (figure.type != type || !_isHomeFigure(figure)) continue;
      selected = figure;
    }
    return selected;
  }

  Widget _buildRoadFigureRow() {
    return Positioned(
      left: 0,
      top: _kRoadFiguresY,
      width: _kLogicalW,
      height: _kSlotSize.height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (var i = 0; i < _kFigureTypes.length; i++)
            SizedBox(
              width: _kSlotSize.width,
              height: _kSlotSize.height,
              child: _buildHomeFigureSlot(i),
            ),
        ],
      ),
    );
  }

  Widget _buildHomeFigureSlot(int index) {
    final figure = _homeFigureForSlot(index);
    if (figure == null) return const SizedBox.shrink();

    final home = _figureHomeForIndex(index);
    final dragOffset = figure.id == _draggingFigureId
        ? figure.position - home
        : Offset.zero;

    return Transform.translate(
      offset: dragOffset,
      child: _buildFigureGesture(figure, homePosition: home),
    );
  }

  Widget _buildGridArea() {
    return Positioned(
      left: _kGridOrigin.dx,
      top: _kGridOrigin.dy,
      width: _kGridSize.width,
      height: _kGridSize.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _onGridTapped,
            child: Stack(
              children: [
                for (var slot = 0; slot < _kCols * _kRows; slot++)
                  if (!_isReservedSlot(slot))
                    Positioned(
                      left: _slotLocalTopLeft(slot).dx,
                      top: _slotLocalTopLeft(slot).dy,
                      width: _kSlotSize.width,
                      height: _kSlotSize.height,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0x22000000),
                          border: Border.all(
                            color: const Color(0x55FFFFFF),
                            width: 1,
                          ),
                        ),
                      ),
                    ),
              ],
            ),
          ),
          for (final figure in _placedGridFigures)
            Positioned(
              left: _slotLocalTopLeft(figure.slotIndex!).dx,
              top: _slotLocalTopLeft(figure.slotIndex!).dy,
              width: _kSlotSize.width,
              height: _kSlotSize.height,
              child: Transform.translate(
                offset: figure.id == _draggingFigureId
                    ? figure.position - _slotTopLeft(figure.slotIndex!)
                    : Offset.zero,
                child: _buildFigureGesture(figure, homePosition: null),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGirl() {
    return Positioned(
      left: _girlPosition.dx,
      top: _girlPosition.dy,
      width: _kSlotSize.width,
      height: _kSlotSize.height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _pathReady ? _tryStartGirlWalk : null,
        child: Image.asset(
          '${_kAssetBase}girl.png',
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const ColoredBox(color: Color(0xFFFF80AB));
          },
        ),
      ),
    );
  }

  Widget _buildPlane() {
    final pos = _slotTopLeft(_kPlaneSlot);
    return Positioned(
      left: pos.dx,
      top: pos.dy,
      width: _kSlotSize.width,
      height: _kSlotSize.height,
      child: IgnorePointer(
        child: Image.asset(
          '${_kAssetBase}paperPlane.png',
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const ColoredBox(color: Color(0xFF80D8FF));
          },
        ),
      ),
    );
  }

  Widget _buildFigureGesture(
    _RoadFigureInstance figure, {
    required Offset? homePosition,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) {
        if (_girlMotion != _GirlMotion.idle) return;
        if (homePosition != null) {
          figure.position = homePosition;
        } else {
          final slot = figure.slotIndex;
          if (slot != null) {
            figure.position = _slotTopLeft(slot);
            _slotOccupants.remove(slot);
          }
        }
        setState(() {
          _draggingFigureId = figure.id;
          if (figure.slotIndex != null) {
            _disposePlayButtonAppearAnimation();
            _pathReady = false;
          }
        });
      },
      onPanUpdate: (details) {
        if (_draggingFigureId != figure.id) return;
        setState(() {
          figure.position += details.delta;
        });
      },
      onPanEnd: (_) => unawaited(_onFigureReleased(figure.id)),
      onPanCancel: () => unawaited(_onFigureReleased(figure.id)),
      child: SizedBox(
        width: _kSlotSize.width,
        height: _kSlotSize.height,
        child: Image.asset(
          figure.type.assetPath,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xAAFFC107),
                border: Border.all(color: Colors.white),
              ),
              child: Center(
                child: Text(
                  figure.type.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10, color: Colors.black),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
