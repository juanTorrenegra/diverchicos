import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:video_player/video_player.dart';

import '../utils/disable_video_pointer.dart';
import '../utils/alternating_instruction_loop.dart';
import '../widgets/menu_back_pill.dart';
import 'chicken_instruction_audio.dart';

const String kChickenIntroAsset = 'assets/video/chicken/chickenIntro.mp4';
const String _kVideoBase = 'assets/video/chicken/';
const String kChickenEndingAsset = '${_kVideoBase}chickenEnding.mp4';
const String _kAssetBase = 'assets/images/chicken/';
const String kChickenGenAsset = '${_kAssetBase}gen.png';
const String kChickenSpriteAsset = '${_kAssetBase}chicken.png';
const String kChickenRockAsset = '${_kAssetBase}rock.png';
const String kChickenBushAsset = '${_kAssetBase}bush.png';

enum _ChickenPhase { intro, levelVideo, gameplay, transitionVideo, endingVideo }

enum _RoadDirection { north, south, east, west }

enum _ObstacleType { rock, bush } //...

extension _RoadDirectionOps on _RoadDirection {
  _RoadDirection get opposite => switch (this) {
    _RoadDirection.north => _RoadDirection.south,
    _RoadDirection.south => _RoadDirection.north,
    _RoadDirection.east => _RoadDirection.west,
    _RoadDirection.west => _RoadDirection.east,
  };
}

enum ChickenRoadFigureType {
  straightVertical,
  straightHorizontal,
  cornerTopRight,
  cornerTopLeft,
  cornerBottomRight,
  cornerBottomLeft,
}

extension _ChickenRoadFigureTypeX on ChickenRoadFigureType {
  String get assetPath => switch (this) {
    ChickenRoadFigureType.straightVertical =>
      '${_kAssetBase}straightVertical.png',
    ChickenRoadFigureType.straightHorizontal =>
      '${_kAssetBase}straightHorizontal.png',
    ChickenRoadFigureType.cornerTopRight => '${_kAssetBase}cornerTopRight.png',
    ChickenRoadFigureType.cornerTopLeft => '${_kAssetBase}cornerTopLeft.png',
    ChickenRoadFigureType.cornerBottomRight =>
      '${_kAssetBase}cornerBottomRight.png',
    ChickenRoadFigureType.cornerBottomLeft =>
      '${_kAssetBase}cornerBottomLeft.png',
  };

  Set<_RoadDirection> get connections => switch (this) {
    ChickenRoadFigureType.straightVertical => {
      _RoadDirection.north,
      _RoadDirection.south,
    },
    ChickenRoadFigureType.straightHorizontal => {
      _RoadDirection.east,
      _RoadDirection.west,
    },
    ChickenRoadFigureType.cornerTopRight => {
      _RoadDirection.north,
      _RoadDirection.east,
    },
    ChickenRoadFigureType.cornerTopLeft => {
      _RoadDirection.north,
      _RoadDirection.west,
    },
    ChickenRoadFigureType.cornerBottomRight => {
      _RoadDirection.south,
      _RoadDirection.east,
    },
    ChickenRoadFigureType.cornerBottomLeft => {
      _RoadDirection.south,
      _RoadDirection.west,
    },
  };
}

enum _GenMotion { idle, walking, success, returning }

class _ChickenLevelConfig {
  const _ChickenLevelConfig({
    required this.cols,
    required this.rows,
    required this.gridSize,
    required this.gridOriginY,
    required this.genSlot,
    required this.chickenSlot,
    required this.levelVideoAsset,
    this.transitionVideoAsset,
    this.obstacles = const {},
  });

  final int cols;
  final int rows;
  final Size gridSize;
  final double gridOriginY;
  final int genSlot;
  final int chickenSlot;
  final String levelVideoAsset;
  final String? transitionVideoAsset;
  final Map<int, _ObstacleType> obstacles;

  Size gridSlotSize(double logicalW) =>
      Size(gridSize.width / cols, gridSize.height / rows);

  Offset gridOrigin(double logicalW) =>
      Offset((logicalW - gridSize.width) / 2, gridOriginY);

  Set<int> get reservedSlots => {genSlot, chickenSlot, ...obstacles.keys};
}

class _RoadFigureInstance {
  _RoadFigureInstance({
    required this.id,
    required this.type,
    required this.holderIndex,
  });

  final String id;
  final ChickenRoadFigureType type;
  final int holderIndex;
  Offset position = Offset.zero;
  int? slotIndex;
}

/// Chicken path: intro → (level video → gameplay → transition)* for 5 levels.
class ChickenPathLayer extends StatefulWidget {
  const ChickenPathLayer({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  State<ChickenPathLayer> createState() => _ChickenPathLayerState();
}

class _ChickenPathLayerState extends State<ChickenPathLayer>
    with TickerProviderStateMixin {
  static const double _kLogicalW = 1980;
  static const double _kLogicalH = 1080;

  static const Size _kRoadSlotSize = Size(188, 185);
  static const double _kRoadFiguresY = 844;
  static const double _kSlotCircleSize = 250;
  static const int _kSlotCircleAnimateMs = 2000;
  static const int _kSlotCirclePauseMs = 2000;
  static const int _kSlotCircleCycleMs =
      _kSlotCircleAnimateMs + _kSlotCirclePauseMs;
  static const double _kSlotCircleMaxOpacity = 0.55;
  static const Color _kGridBackground = Color(0xFF51A160);

  static const List<ChickenRoadFigureType> _kFigureTypes =
      ChickenRoadFigureType.values;

  static const List<_ChickenLevelConfig> _kLevels = [
    _ChickenLevelConfig(
      cols: 2,
      rows: 2,
      gridSize: Size(367, 370),
      gridOriginY: 200,
      genSlot: 0,
      chickenSlot: 3,
      levelVideoAsset: '${_kVideoBase}chickenLevel1.mp4',
      transitionVideoAsset: '${_kVideoBase}chickenTransition1to2.mp4',
    ),
    _ChickenLevelConfig(
      cols: 3,
      rows: 3,
      gridSize: Size(555, 564),
      gridOriginY: 100,
      genSlot: 6,
      chickenSlot: 2,
      levelVideoAsset: '${_kVideoBase}chickenLevel2.mp4',
      transitionVideoAsset: '${_kVideoBase}chickenTransition2to3.mp4',
      obstacles: {4: _ObstacleType.rock},
    ),
    _ChickenLevelConfig(
      cols: 4,
      rows: 4,
      gridSize: Size(740, 752),
      gridOriginY: 100,
      genSlot: 0,
      chickenSlot: 11,
      levelVideoAsset: '${_kVideoBase}chickenLevel3.mp4',
      transitionVideoAsset: '${_kVideoBase}chickenTransition3to4.mp4',
      obstacles: {6: _ObstacleType.bush, 8: _ObstacleType.rock},
    ),
    _ChickenLevelConfig(
      cols: 5,
      rows: 4,
      gridSize: Size(925, 752),
      gridOriginY: 100,
      genSlot: 15,
      chickenSlot: 4,
      levelVideoAsset: '${_kVideoBase}chickenLevel4.mp4',
      transitionVideoAsset: '${_kVideoBase}chickenTransition4to5.mp4',
      obstacles: {
        14: _ObstacleType.bush,
        7: _ObstacleType.bush,
        1: _ObstacleType.rock,
      },
    ),
    _ChickenLevelConfig(
      cols: 6,
      rows: 4,
      gridSize: Size(1110, 752),
      gridOriginY: 100,
      genSlot: 0,
      chickenSlot: 23,
      levelVideoAsset: '${_kVideoBase}chickenLevel5.mp4',
      obstacles: {
        4: _ObstacleType.bush,
        18: _ObstacleType.bush,
        13: _ObstacleType.rock,
        15: _ObstacleType.rock,
      },
    ),
  ];

  _ChickenPhase _phase = _ChickenPhase.intro;
  int _levelIndex = 0;

  _ChickenLevelConfig get _level => _kLevels[_levelIndex];
  int get _cols => _level.cols;
  int get _rows => _level.rows;
  Size get _gridSize => _level.gridSize;
  Offset get _gridOrigin => _level.gridOrigin(_kLogicalW);
  Size get _gridSlotSize => _level.gridSlotSize(_kLogicalW);
  int get _genSlot => _level.genSlot;
  int get _chickenSlot => _level.chickenSlot;

  VideoPlayerController? _introController;
  bool _introReady = false;

  VideoPlayerController? _videoController;
  bool _videoReady = false;
  VoidCallback? _videoOnComplete;
  bool _videoBootstrapInFlight = false;

  int _nextFigureId = 0;
  late List<_RoadFigureInstance> _figures;
  final Map<int, String> _slotOccupants = {};
  String? _draggingFigureId;
  _GenMotion _genMotion = _GenMotion.idle;
  Offset _genPosition = Offset.zero;

  bool _exitingToMenu = false;
  bool _introToLevelStarted = false;

  AnimationController? _slotCirclePulseController;

  final AlternatingInstructionLoop _instructions = AlternatingInstructionLoop();

  void _startLevelInstructions() {
    unawaited(
      _instructions.start(
        ChickenInstructionAudio.levelAlternating,
        interval: const Duration(seconds: 8),
      ),
    );
  }

  Future<void> _stopLevelInstructions() => _instructions.stop();

  Future<void> _pauseLevelInstructions() => _instructions.pause();

  @override
  void initState() {
    super.initState();
    _resetFiguresForLevel();
    unawaited(_bootstrapIntro());
  }

  String _newFigureId() => 'chicken_road_${_nextFigureId++}';

  void _resetFiguresForLevel() {
    _slotOccupants.clear();
    _draggingFigureId = null;
    _genMotion = _GenMotion.idle;
    _figures = [
      for (var i = 0; i < _kFigureTypes.length; i++)
        _RoadFigureInstance(
          id: _newFigureId(),
          type: _kFigureTypes[i],
          holderIndex: i,
        )..position = _figureHomeForIndex(i),
    ];
    _genPosition = _slotTopLeft(_genSlot);
  }

  Offset _slotTopLeft(int slot) {
    final row = slot ~/ _cols;
    final col = slot % _cols;
    return _gridOrigin +
        Offset(col * _gridSlotSize.width, row * _gridSlotSize.height);
  }

  Offset _slotLocalTopLeft(int slot) {
    final row = slot ~/ _cols;
    final col = slot % _cols;
    return Offset(col * _gridSlotSize.width, row * _gridSlotSize.height);
  }

  Offset _figureHomeForIndex(int index) {
    final count = _kFigureTypes.length;
    final leading = (_kLogicalW - count * _kRoadSlotSize.width) / (count + 1);
    final x = leading + index * (_kRoadSlotSize.width + leading);
    return Offset(x, _kRoadFiguresY);
  }

  bool _isHomeFigure(_RoadFigureInstance figure) => figure.slotIndex == null;

  bool _isReservedSlot(int slot) => _level.reservedSlots.contains(slot);

  Iterable<_RoadFigureInstance> get _placedGridFigures sync* {
    for (final figure in _figures) {
      if (figure.slotIndex != null) yield figure;
    }
  }

  Map<int, ChickenRoadFigureType> get _placementTypes {
    final map = <int, ChickenRoadFigureType>{};
    for (final figure in _figures) {
      final slot = figure.slotIndex;
      if (slot != null) map[slot] = figure.type;
    }
    return map;
  }

  bool _canTraverse(
    int fromRow,
    int fromCol,
    int toRow,
    int toCol,
    Map<int, ChickenRoadFigureType> placements,
  ) {
    final dr = toRow - fromRow;
    final dc = toCol - fromCol;
    if (dr.abs() + dc.abs() != 1) return false;

    late final _RoadDirection exitDir;
    if (dr == -1) {
      exitDir = _RoadDirection.north;
    } else if (dr == 1) {
      exitDir = _RoadDirection.south;
    } else if (dc == 1) {
      exitDir = _RoadDirection.east;
    } else {
      exitDir = _RoadDirection.west;
    }
    final enterDir = exitDir.opposite;

    final fromSlot = fromRow * _cols + fromCol;
    final toSlot = toRow * _cols + toCol;

    if (_level.obstacles.containsKey(fromSlot) ||
        _level.obstacles.containsKey(toSlot)) {
      return false;
    }

    if (fromSlot == _genSlot) {
      if (toSlot == _chickenSlot) return false;
      final toType = placements[toSlot];
      return toType != null && toType.connections.contains(enterDir);
    }

    if (toSlot == _chickenSlot) {
      final fromType = placements[fromSlot];
      return fromType != null && fromType.connections.contains(exitDir);
    }

    final fromType = placements[fromSlot];
    final toType = placements[toSlot];
    if (fromType == null || toType == null) return false;
    return fromType.connections.contains(exitDir) &&
        toType.connections.contains(enterDir);
  }

  List<int>? _findPathToChicken() {
    final startRow = _genSlot ~/ _cols;
    final startCol = _genSlot % _cols;
    final goalRow = _chickenSlot ~/ _cols;
    final goalCol = _chickenSlot % _cols;
    final placements = _placementTypes;

    final queue = <List<(int, int)>>[
      [(startRow, startCol)],
    ];
    final visited = <String>{'$startRow,$startCol'};

    while (queue.isNotEmpty) {
      final path = queue.removeAt(0);
      final (row, col) = path.last;
      if (row == goalRow && col == goalCol) {
        return [for (final cell in path) cell.$1 * _cols + cell.$2];
      }

      const deltas = [(-1, 0), (1, 0), (0, -1), (0, 1)];
      for (final (dr, dc) in deltas) {
        final nr = row + dr;
        final nc = col + dc;
        if (nr < 0 || nc < 0 || nr >= _rows || nc >= _cols) continue;
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
    final startRow = _genSlot ~/ _cols;
    final startCol = _genSlot % _cols;
    var best = <int>[_genSlot];

    void visit(int row, int col, List<int> path, Set<String> visited) {
      if (path.length > best.length) best = List<int>.from(path);
      const deltas = [(-1, 0), (1, 0), (0, -1), (0, 1)];
      for (final (dr, dc) in deltas) {
        final nr = row + dr;
        final nc = col + dc;
        if (nr < 0 || nc < 0 || nr >= _rows || nc >= _cols) continue;
        final key = '$nr,$nc';
        if (visited.contains(key)) continue;
        if (!_canTraverse(row, col, nr, nc, placements)) continue;
        visit(nr, nc, [...path, nr * _cols + nc], {...visited, key});
      }
    }

    visit(startRow, startCol, [_genSlot], {'$startRow,$startCol'});
    return best.length > 1 ? best : null;
  }

  void _onGridTapped() {
    if (_phase != _ChickenPhase.gameplay ||
        _draggingFigureId != null ||
        _genMotion != _GenMotion.idle) {
      return;
    }

    final pathToChicken = _findPathToChicken();
    if (pathToChicken != null) {
      unawaited(_walkGen(pathToChicken, success: true));
      return;
    }

    final fallbackPath = _findLongestWalkFromStart();
    if (fallbackPath != null) {
      unawaited(_walkGen(fallbackPath, success: false));
    }
  }

  Future<void> _walkGen(List<int> path, {required bool success}) async {
    setState(() {
      _genMotion = _GenMotion.walking;
      _genPosition = _slotTopLeft(path.first);
    });

    for (var i = 1; i < path.length; i++) {
      await _animateGenTo(_slotTopLeft(path[i]));
      if (!mounted) return;
    }

    if (!mounted) return;
    if (success && path.last == _chickenSlot) {
      unawaited(_pauseLevelInstructions());
      setState(() => _genMotion = _GenMotion.success);
      unawaited(_onLevelComplete());
      return;
    }

    await _walkGenAndReturn(path);
  }

  Future<void> _onLevelComplete() async {
    await _stopLevelInstructions();

    final isLastLevel = _levelIndex >= _kLevels.length - 1;
    if (isLastLevel) {
      await _disposeActiveVideo();
      if (!mounted) return;

      final played = await _bootstrapVideo(
        kChickenEndingAsset,
        phase: _ChickenPhase.endingVideo,
        onComplete: _onEndingVideoComplete,
      );
      if (!played && mounted) {
        await _teardownAndExitToMenu();
      }
      return;
    }

    final transitionAsset = _level.transitionVideoAsset;
    if (transitionAsset == null) return;

    await _disposeActiveVideo();
    if (!mounted) return;

    final advanced = await _bootstrapVideo(
      transitionAsset,
      phase: _ChickenPhase.transitionVideo,
      onComplete: _onTransitionVideoComplete,
    );
    if (!advanced && mounted) {
      unawaited(_advanceToNextLevel());
    }
  }

  void _onEndingVideoComplete() {
    unawaited(_teardownAndExitToMenu());
  }

  Future<void> _teardownAndExitToMenu() async {
    if (_exitingToMenu) return;
    _exitingToMenu = true;

    await _stopLevelInstructions();
    await _disposeIntro();
    await _disposeActiveVideo();
    restoreAppPointerEvents();

    if (mounted) {
      widget.onClose();
    }
  }

  Future<void> _onTransitionVideoComplete() async {
    await _advanceToNextLevel();
  }

  Future<void> _advanceToNextLevel() async {
    if (_levelIndex >= _kLevels.length - 1) return;

    _levelIndex++;
    _resetFiguresForLevel();
    if (!mounted) return;

    final started = await _bootstrapLevelVideo();
    if (!started && mounted) {
      _beginGameplay();
    }
  }

  Future<void> _walkGenAndReturn(List<int> path) async {
    if (!mounted) return;
    setState(() => _genMotion = _GenMotion.returning);

    for (var i = path.length - 2; i >= 0; i--) {
      await _animateGenTo(_slotTopLeft(path[i]));
      if (!mounted) return;
    }

    if (!mounted) return;
    setState(() {
      _genMotion = _GenMotion.idle;
      _genPosition = _slotTopLeft(_genSlot);
    });
  }

  Future<void> _animateGenTo(Offset target) async {
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    final animation = CurvedAnimation(
      parent: controller,
      curve: Curves.easeInOut,
    );
    final begin = _genPosition;
    controller.addListener(() {
      if (!mounted) return;
      setState(() {
        _genPosition = Offset.lerp(begin, target, animation.value)!;
      });
    });
    await controller.forward();
    controller.dispose();
  }

  Future<void> _disposeActiveVideo() async {
    final v = _videoController;
    _videoController = null;
    _videoReady = false;
    _videoOnComplete = null;
    if (v != null) {
      v.removeListener(_onVideoTick);
      await v.dispose();
    }
  }

  Future<bool> _bootstrapVideo(
    String asset, {
    required _ChickenPhase phase,
    required VoidCallback onComplete,
  }) async {
    if (_videoBootstrapInFlight) return false;
    _videoBootstrapInFlight = true;

    await _disposeActiveVideo();
    if (!mounted) {
      _videoBootstrapInFlight = false;
      return false;
    }

    setState(() => _phase = phase);
    _videoOnComplete = onComplete;

    final c = VideoPlayerController.asset(
      asset,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    try {
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        _videoBootstrapInFlight = false;
        return false;
      }
      await c.setLooping(false);
      c.addListener(_onVideoTick);
      await c.play();
      setState(() {
        _videoController = c;
        _videoReady = true;
      });
      _videoBootstrapInFlight = false;
      if (phase == _ChickenPhase.levelVideo) {
        _startLevelInstructions();
      }
      return true;
    } catch (_) {
      await c.dispose();
      _videoOnComplete = null;
      _videoBootstrapInFlight = false;
      return false;
    }
  }

  void _onVideoTick() {
    final v = _videoController;
    if (v == null || !mounted) return;
    final value = v.value;
    if (!value.isInitialized || value.hasError) return;
    if (!value.isCompleted) return;

    unawaited(_finishActiveVideo());
  }

  Future<void> _finishActiveVideo() async {
    final v = _videoController;
    if (v == null) return;

    v.removeListener(_onVideoTick);
    await v.pause();

    final onComplete = _videoOnComplete;
    _videoOnComplete = null;
    onComplete?.call();
  }

  void _skipTransitionVideo() {
    if (_phase != _ChickenPhase.transitionVideo || _videoOnComplete == null) {
      return;
    }
    unawaited(_finishActiveVideo());
  }

  Future<void> _bootstrapIntro() async {
    final c = VideoPlayerController.asset(
      kChickenIntroAsset,
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
      if (mounted) unawaited(_startFirstLevel());
    }
  }

  void _onIntroTick() {
    final v = _introController;
    if (v == null || !mounted || _phase != _ChickenPhase.intro) return;
    final value = v.value;
    if (!value.isInitialized || value.hasError) return;
    if (value.isCompleted) {
      v.removeListener(_onIntroTick);
      unawaited(_startFirstLevel());
    }
  }

  void _skipIntro() {
    if (_phase != _ChickenPhase.intro || _introToLevelStarted) return;
    _introController?.removeListener(_onIntroTick);
    unawaited(_startFirstLevel());
  }

  Future<void> _startFirstLevel() async {
    if (_introToLevelStarted) return;
    _introToLevelStarted = true;
    await _disposeIntro();
    if (!mounted) return;
    final started = await _bootstrapLevelVideo();
    if (!started && mounted) _beginGameplay();
  }

  Future<void> _disposeIntro() async {
    final intro = _introController;
    _introController = null;
    _introReady = false;
    if (intro != null) {
      intro.removeListener(_onIntroTick);
      await intro.dispose();
    }
  }

  Future<bool> _bootstrapLevelVideo() async {
    if (!mounted) return false;

    final started = await _bootstrapVideo(
      _level.levelVideoAsset,
      phase: _ChickenPhase.levelVideo,
      onComplete: _beginGameplay,
    );
    return started;
  }

  void _beginGameplay() {
    if (!mounted || _phase == _ChickenPhase.gameplay) return;
    setState(() => _phase = _ChickenPhase.gameplay);
    if (!_instructions.isRunning) {
      _startLevelInstructions();
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
    if (_phase != _ChickenPhase.gameplay || controller == null) return 0;

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
      left: home.dx + (_kRoadSlotSize.width - _kSlotCircleSize) / 2,
      top: home.dy + (_kRoadSlotSize.height - _kSlotCircleSize) / 2,
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

  Future<void> _releaseVideoPointerCapture() async {
    disableVideoPointerEvents();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (mounted) disableVideoPointerEvents();
  }

  int? _slotAtPosition(Offset figureTopLeft, Size figureSize) {
    final center =
        figureTopLeft + Offset(figureSize.width / 2, figureSize.height / 2);
    final local = center - _gridOrigin;
    if (local.dx < 0 ||
        local.dy < 0 ||
        local.dx > _gridSize.width ||
        local.dy > _gridSize.height) {
      return null;
    }
    final col = (local.dx / _gridSlotSize.width).floor().clamp(0, _cols - 1);
    final row = (local.dy / _gridSlotSize.height).floor().clamp(0, _rows - 1);
    return row * _cols + col;
  }

  _RoadFigureInstance? _figureById(String id) {
    for (final figure in _figures) {
      if (figure.id == id) return figure;
    }
    return null;
  }

  void _spawnHolderCopy(ChickenRoadFigureType type) {
    final index = _kFigureTypes.indexOf(type);
    _figures.add(
      _RoadFigureInstance(id: _newFigureId(), type: type, holderIndex: index)
        ..position = _figureHomeForIndex(index),
    );
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

  Future<void> _onFigureReleased(String id) async {
    final figure = _figureById(id);
    if (figure == null) return;

    final targetSlot = _slotAtPosition(figure.position, _kRoadSlotSize);
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
      if (mounted) setState(() {});
      return;
    }

    if (wasOnGrid && previousSlot != null && previousSlot != targetSlot) {
      _slotOccupants.remove(previousSlot);
    }

    figure.slotIndex = targetSlot;
    _slotOccupants[targetSlot] = id;
    setState(() => _draggingFigureId = null);
    await _animateFigureTo(figure, _slotTopLeft(targetSlot));
    if (!mounted) return;

    if (!wasOnGrid && mounted) {
      setState(() => _spawnHolderCopy(figure.type));
    } else if (mounted) {
      setState(() {});
    }
  }

  _RoadFigureInstance? _homeFigureForSlot(int index) {
    final type = _kFigureTypes[index];
    for (final figure in _figures) {
      if (figure.type == type && _isHomeFigure(figure)) return figure;
    }
    return null;
  }

  void _exitToMenu() {
    if (_exitingToMenu) return;
    _exitingToMenu = true;
    unawaited(_stopLevelInstructions());
    restoreAppPointerEvents();
    widget.onClose();
  }

  @override
  void dispose() {
    unawaited(_instructions.dispose());
    restoreAppPointerEvents();
    _slotCirclePulseController?.dispose();
    _introController?.removeListener(_onIntroTick);
    _introController?.dispose();
    _videoController?.removeListener(_onVideoTick);
    _videoController?.dispose();
    super.dispose();
  }

  Widget _buildGenInGrid() {
    return Positioned(
      left: _genPosition.dx - _gridOrigin.dx,
      top: _genPosition.dy - _gridOrigin.dy,
      width: _gridSlotSize.width,
      height: _gridSlotSize.height,
      child: IgnorePointer(
        child: Image.asset(
          kChickenGenAsset,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const ColoredBox(color: Color(0xFFFFEB3B));
          },
        ),
      ),
    );
  }

  Widget _buildChickenInGrid() {
    final pos = _slotLocalTopLeft(_chickenSlot);
    return Positioned(
      left: pos.dx,
      top: pos.dy,
      width: _gridSlotSize.width,
      height: _gridSlotSize.height,
      child: IgnorePointer(
        child: Image.asset(
          kChickenSpriteAsset,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const ColoredBox(color: Color(0xFFFF9800));
          },
        ),
      ),
    );
  }

  Widget _buildObstacleInGrid(int slot, _ObstacleType type) {
    final pos = _slotLocalTopLeft(slot);
    final asset = switch (type) {
      _ObstacleType.rock => kChickenRockAsset,
      _ObstacleType.bush => kChickenBushAsset,
    };
    final fallback = switch (type) {
      _ObstacleType.rock => const Color(0xFF795548),
      _ObstacleType.bush => const Color(0xFF388E3C),
    };
    return Positioned(
      left: pos.dx,
      top: pos.dy,
      width: _gridSlotSize.width,
      height: _gridSlotSize.height,
      child: IgnorePointer(
        child: Image.asset(
          asset,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return ColoredBox(color: fallback);
          },
        ),
      ),
    );
  }

  Widget _buildFigureGesture(
    _RoadFigureInstance figure, {
    required Offset? homePosition,
    required Size displaySize,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) {
        if (_genMotion != _GenMotion.idle) return;
        if (homePosition != null) {
          figure.position = homePosition;
        } else {
          final slot = figure.slotIndex;
          if (slot != null) {
            figure.position = _slotTopLeft(slot);
            _slotOccupants.remove(slot);
          }
        }
        setState(() => _draggingFigureId = figure.id);
      },
      onPanUpdate: (details) {
        if (_draggingFigureId != figure.id) return;
        setState(() => figure.position += details.delta);
      },
      onPanEnd: (_) => unawaited(_onFigureReleased(figure.id)),
      onPanCancel: () => unawaited(_onFigureReleased(figure.id)),
      child: SizedBox(
        width: displaySize.width,
        height: displaySize.height,
        child: Image.asset(figure.type.assetPath, fit: BoxFit.contain),
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
      child: _buildFigureGesture(
        figure,
        homePosition: home,
        displaySize: _kRoadSlotSize,
      ),
    );
  }

  Widget _buildRoadFigureRow() {
    return Positioned(
      left: 0,
      top: _kRoadFiguresY,
      width: _kLogicalW,
      height: _kRoadSlotSize.height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (var i = 0; i < _kFigureTypes.length; i++)
            SizedBox(
              width: _kRoadSlotSize.width,
              height: _kRoadSlotSize.height,
              child: _buildHomeFigureSlot(i),
            ),
        ],
      ),
    );
  }

  Widget _buildGridArea() {
    return Positioned(
      left: _gridOrigin.dx,
      top: _gridOrigin.dy,
      width: _gridSize.width,
      height: _gridSize.height,
      child: DecoratedBox(
        decoration: const BoxDecoration(color: _kGridBackground),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _onGridTapped,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (var slot = 0; slot < _cols * _rows; slot++)
                if (!_isReservedSlot(slot))
                  Positioned(
                    left: _slotLocalTopLeft(slot).dx,
                    top: _slotLocalTopLeft(slot).dy,
                    width: _gridSlotSize.width,
                    height: _gridSlotSize.height,
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
              for (final entry in _level.obstacles.entries)
                _buildObstacleInGrid(entry.key, entry.value),
              for (final figure in _placedGridFigures)
                Positioned(
                  left: _slotLocalTopLeft(figure.slotIndex!).dx,
                  top: _slotLocalTopLeft(figure.slotIndex!).dy,
                  width: _gridSlotSize.width,
                  height: _gridSlotSize.height,
                  child: Transform.translate(
                    offset: figure.id == _draggingFigureId
                        ? figure.position - _slotTopLeft(figure.slotIndex!)
                        : Offset.zero,
                    child: _buildFigureGesture(
                      figure,
                      homePosition: null,
                      displaySize: _gridSlotSize,
                    ),
                  ),
                ),
              _buildChickenInGrid(),
              _buildGenInGrid(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoSkipButton({
    required Color color,
    required VoidCallback onTap,
  }) {
    return Positioned(
      left: 16,
      top: 20,
      child: PointerInterceptor(
        child: Material(
          color: color,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: const SizedBox(width: 48, height: 48),
          ),
        ),
      ),
    );
  }

  Widget _buildIntroSkipButton() {
    return _buildVideoSkipButton(
      color: const Color(0xFF2196F3),
      onTap: _skipIntro,
    );
  }

  Widget _buildTransitionSkipButton() {
    return _buildVideoSkipButton(
      color: const Color(0xFF4CAF50),
      onTap: _skipTransitionVideo,
    );
  }

  Widget _buildGameplay() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (_videoReady && _videoController != null)
          Positioned.fill(
            child: IgnorePointer(child: VideoPlayer(_videoController!)),
          )
        else
          const ColoredBox(color: Colors.black),
        _buildGridArea(),
        _buildRoadFigureSlotCircles(),
        _buildRoadFigureRow(),
      ],
    );
  }

  Widget _buildMainLayer() {
    if (_phase == _ChickenPhase.intro &&
        _introReady &&
        _introController != null) {
      return VideoPlayer(_introController!);
    }
    if ((_phase == _ChickenPhase.levelVideo ||
            _phase == _ChickenPhase.transitionVideo ||
            _phase == _ChickenPhase.endingVideo) &&
        _videoReady &&
        _videoController != null) {
      return VideoPlayer(_videoController!);
    }
    if (_phase == _ChickenPhase.gameplay) {
      return _buildGameplay();
    }
    return const ColoredBox(color: Colors.black);
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
                Positioned.fill(child: _buildMainLayer()),
                if (_phase == _ChickenPhase.intro &&
                    _introReady &&
                    _introController != null)
                  _buildIntroSkipButton(),
                if (_phase == _ChickenPhase.transitionVideo &&
                    _videoReady &&
                    _videoController != null)
                  _buildTransitionSkipButton(),
                if (_phase != _ChickenPhase.endingVideo)
                  GameLogicalBackPill(onPressed: _exitToMenu),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
