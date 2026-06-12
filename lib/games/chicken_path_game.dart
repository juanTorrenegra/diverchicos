import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:video_player/video_player.dart';

import '../utils/disable_video_pointer.dart';
import '../widgets/menu_back_pill.dart';

const String kChickenIntroAsset = 'assets/video/chicken/chickenIntro.mp4';
const String kChickenLevel1Asset = 'assets/video/chicken/chickenLevel1.mp4';
const String _kAssetBase = 'assets/images/chicken/';
const String kChickenGenAsset = '${_kAssetBase}gen.png';
const String kChickenSpriteAsset = '${_kAssetBase}chicken.png';

enum _ChickenPhase { intro, level1, gameplay }

enum _RoadDirection { north, south, east, west }

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

/// Chicken path: intro video → level-1 video → path-building gameplay.
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

  static const Size _kGridSize = Size(367, 370);
  static const int _kCols = 2;
  static const int _kRows = 2;
  static const Size _kGridSlotSize = Size(367 / 2, 370 / 2);
  static const Size _kRoadSlotSize = Size(188, 185);

  static const int _kGenSlot = 0;
  static const int _kChickenSlot = 3;

  static final Offset _kGridOrigin = Offset(
    (_kLogicalW - _kGridSize.width) / 2,
    200,
  );
  static const double _kRoadFiguresY = 844;
  static const Color _kGridBackground = Color(0xFF51A160);

  static const int _kFigureGlowUpMs = 2000;
  static const int _kFigureGlowDownMs = 2000;
  static const int _kFigureGlowPauseMs = 2000;
  static const int _kFigureGlowCycleMs =
      _kFigureGlowUpMs + _kFigureGlowDownMs + _kFigureGlowPauseMs;
  static const Color _kFigureGlowPink = Color(0xFFFFB7C5);

  static const List<ChickenRoadFigureType> _kFigureTypes =
      ChickenRoadFigureType.values;

  _ChickenPhase _phase = _ChickenPhase.intro;

  VideoPlayerController? _introController;
  bool _introReady = false;

  VideoPlayerController? _level1Controller;
  bool _level1Ready = false;

  int _nextFigureId = 0;
  late List<_RoadFigureInstance> _figures;
  final Map<int, String> _slotOccupants = {};
  String? _draggingFigureId;
  _GenMotion _genMotion = _GenMotion.idle;
  Offset _genPosition = Offset.zero;

  AnimationController? _figureGlowController;
  int _figureGlowIndex = 0;
  bool _exitingToMenu = false;
  bool _introToLevel1Started = false;

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
    _genPosition = _slotTopLeft(_kGenSlot);
    unawaited(_bootstrapIntro());
  }

  String _newFigureId() => 'chicken_road_${_nextFigureId++}';

  Offset _slotTopLeft(int slot) {
    final row = slot ~/ _kCols;
    final col = slot % _kCols;
    return _kGridOrigin +
        Offset(col * _kGridSlotSize.width, row * _kGridSlotSize.height);
  }

  Offset _slotLocalTopLeft(int slot) {
    final row = slot ~/ _kCols;
    final col = slot % _kCols;
    return Offset(col * _kGridSlotSize.width, row * _kGridSlotSize.height);
  }

  Offset _figureHomeForIndex(int index) {
    final count = _kFigureTypes.length;
    final leading = (_kLogicalW - count * _kRoadSlotSize.width) / (count + 1);
    final x = leading + index * (_kRoadSlotSize.width + leading);
    return Offset(x, _kRoadFiguresY);
  }

  bool _isHomeFigure(_RoadFigureInstance figure) => figure.slotIndex == null;

  bool _isReservedSlot(int slot) => slot == _kGenSlot || slot == _kChickenSlot;

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

    final fromSlot = fromRow * _kCols + fromCol;
    final toSlot = toRow * _kCols + toCol;

    if (fromSlot == _kGenSlot) {
      if (toSlot == _kChickenSlot) return false;
      final toType = placements[toSlot];
      return toType != null && toType.connections.contains(enterDir);
    }

    if (toSlot == _kChickenSlot) {
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
    const goalRow = 1;
    const goalCol = 1;
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
    var best = <int>[_kGenSlot];

    void visit(int row, int col, List<int> path, Set<String> visited) {
      if (path.length > best.length) best = List<int>.from(path);
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

    visit(0, 0, const [_kGenSlot], {'0,0'});
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
    if (success && path.last == _kChickenSlot) {
      setState(() => _genMotion = _GenMotion.success);
      return;
    }

    await _walkGenAndReturn(path);
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
      _genPosition = _slotTopLeft(_kGenSlot);
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
      if (mounted) _exitToMenu();
    }
  }

  void _onIntroTick() {
    final v = _introController;
    if (v == null || !mounted || _phase != _ChickenPhase.intro) return;
    final value = v.value;
    if (!value.isInitialized || value.hasError) return;
    if (value.isCompleted) {
      v.removeListener(_onIntroTick);
      unawaited(_bootstrapLevel1());
    }
  }

  void _skipIntro() {
    if (_phase != _ChickenPhase.intro || _introToLevel1Started) return;
    _introController?.removeListener(_onIntroTick);
    unawaited(_bootstrapLevel1());
  }

  Future<void> _bootstrapLevel1() async {
    if (_introToLevel1Started) return;
    _introToLevel1Started = true;

    final intro = _introController;
    _introController = null;
    _introReady = false;
    if (intro != null) {
      intro.removeListener(_onIntroTick);
      await intro.dispose();
    }
    if (!mounted) return;

    setState(() => _phase = _ChickenPhase.level1);

    final c = VideoPlayerController.asset(
      kChickenLevel1Asset,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    try {
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      await c.setLooping(false);
      c.addListener(_onLevel1Tick);
      await c.play();
      setState(() {
        _level1Controller = c;
        _level1Ready = true;
      });
    } catch (_) {
      await c.dispose();
      if (mounted) _beginGameplay();
    }
  }

  void _onLevel1Tick() {
    final v = _level1Controller;
    if (v == null || !mounted || _phase != _ChickenPhase.level1) return;
    final value = v.value;
    if (!value.isInitialized || value.hasError) return;
    if (value.isCompleted) {
      v.removeListener(_onLevel1Tick);
      unawaited(v.pause());
      _beginGameplay();
    }
  }

  void _beginGameplay() {
    if (!mounted || _phase == _ChickenPhase.gameplay) return;
    setState(() => _phase = _ChickenPhase.gameplay);
    _startFigureGlowCycle();
    unawaited(_releaseVideoPointerCapture());
  }

  Future<void> _releaseVideoPointerCapture() async {
    disableVideoPointerEvents();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (mounted) disableVideoPointerEvents();
  }

  void _startFigureGlowCycle() {
    _figureGlowController?.dispose();
    _figureGlowIndex = 0;
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _kFigureGlowCycleMs),
    );
    controller.addListener(() {
      if (mounted) setState(() {});
    });
    controller.addStatusListener((status) {
      if (status != AnimationStatus.completed || !mounted) return;
      setState(() {
        _figureGlowIndex = (_figureGlowIndex + 1) % _kFigureTypes.length;
      });
      controller.forward(from: 0);
    });
    _figureGlowController = controller;
    controller.forward();
  }

  double _figureGlowIntensity(int holderIndex) {
    final controller = _figureGlowController;
    if (_phase != _ChickenPhase.gameplay ||
        controller == null ||
        holderIndex != _figureGlowIndex) {
      return 0;
    }

    final elapsedMs = controller.value * _kFigureGlowCycleMs;
    if (elapsedMs < _kFigureGlowUpMs) {
      return Curves.easeInOut.transform(elapsedMs / _kFigureGlowUpMs);
    }
    if (elapsedMs < _kFigureGlowUpMs + _kFigureGlowDownMs) {
      final t = (elapsedMs - _kFigureGlowUpMs) / _kFigureGlowDownMs;
      return 1.0 - Curves.easeInOut.transform(t);
    }
    return 0;
  }

  Widget _buildFigureGlowWrapper(int holderIndex, Widget child) {
    final glow = _figureGlowIntensity(holderIndex);
    if (glow <= 0) return child;

    final scale = 1.0 + glow * 0.22;
    return Transform.scale(
      scale: scale,
      child: DecoratedBox(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: _kFigureGlowPink.withValues(alpha: glow * 0.95),
              blurRadius: 10 + glow * 34,
              spreadRadius: glow * 14,
            ),
            BoxShadow(
              color: const Color(0xFFFFE4EC).withValues(alpha: glow * 0.75),
              blurRadius: 4 + glow * 18,
              spreadRadius: glow * 6,
            ),
          ],
        ),
        child: child,
      ),
    );
  }

  int? _slotAtPosition(Offset figureTopLeft, Size figureSize) {
    final center =
        figureTopLeft + Offset(figureSize.width / 2, figureSize.height / 2);
    final local = center - _kGridOrigin;
    if (local.dx < 0 ||
        local.dy < 0 ||
        local.dx > _kGridSize.width ||
        local.dy > _kGridSize.height) {
      return null;
    }
    final col = (local.dx / _kGridSlotSize.width).floor().clamp(0, _kCols - 1);
    final row = (local.dy / _kGridSlotSize.height).floor().clamp(0, _kRows - 1);
    return row * _kCols + col;
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
    restoreAppPointerEvents();
    widget.onClose();
  }

  @override
  void dispose() {
    restoreAppPointerEvents();
    _figureGlowController?.dispose();
    _introController?.removeListener(_onIntroTick);
    _introController?.dispose();
    _level1Controller?.removeListener(_onLevel1Tick);
    _level1Controller?.dispose();
    super.dispose();
  }

  Widget _buildGenInGrid() {
    return Positioned(
      left: _genPosition.dx - _kGridOrigin.dx,
      top: _genPosition.dy - _kGridOrigin.dy,
      width: _kGridSlotSize.width,
      height: _kGridSlotSize.height,
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
    final pos = _slotLocalTopLeft(_kChickenSlot);
    return Positioned(
      left: pos.dx,
      top: pos.dy,
      width: _kGridSlotSize.width,
      height: _kGridSlotSize.height,
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

    return _buildFigureGlowWrapper(
      index,
      Transform.translate(
        offset: dragOffset,
        child: _buildFigureGesture(
          figure,
          homePosition: home,
          displaySize: _kRoadSlotSize,
        ),
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
      left: _kGridOrigin.dx,
      top: _kGridOrigin.dy,
      width: _kGridSize.width,
      height: _kGridSize.height,
      child: DecoratedBox(
        decoration: const BoxDecoration(color: _kGridBackground),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _onGridTapped,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (var slot = 0; slot < _kCols * _kRows; slot++)
                if (!_isReservedSlot(slot))
                  Positioned(
                    left: _slotLocalTopLeft(slot).dx,
                    top: _slotLocalTopLeft(slot).dy,
                    width: _kGridSlotSize.width,
                    height: _kGridSlotSize.height,
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
              for (final figure in _placedGridFigures)
                Positioned(
                  left: _slotLocalTopLeft(figure.slotIndex!).dx,
                  top: _slotLocalTopLeft(figure.slotIndex!).dy,
                  width: _kGridSlotSize.width,
                  height: _kGridSlotSize.height,
                  child: Transform.translate(
                    offset: figure.id == _draggingFigureId
                        ? figure.position - _slotTopLeft(figure.slotIndex!)
                        : Offset.zero,
                    child: _buildFigureGesture(
                      figure,
                      homePosition: null,
                      displaySize: _kGridSlotSize,
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

  Widget _buildIntroSkipButton() {
    return Positioned(
      left: 16,
      top: 20,
      child: PointerInterceptor(
        child: Material(
          color: const Color(0xFF2196F3),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: _skipIntro,
            borderRadius: BorderRadius.circular(10),
            child: const SizedBox(width: 48, height: 48),
          ),
        ),
      ),
    );
  }

  Widget _buildGameplay() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (_level1Ready && _level1Controller != null)
          Positioned.fill(
            child: IgnorePointer(child: VideoPlayer(_level1Controller!)),
          )
        else
          const ColoredBox(color: Colors.black),
        _buildGridArea(),
        _buildRoadFigureRow(),
      ],
    );
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
                if (_phase == _ChickenPhase.intro &&
                    _introReady &&
                    _introController != null)
                  Positioned.fill(child: VideoPlayer(_introController!))
                else if (_phase == _ChickenPhase.level1 &&
                    _level1Ready &&
                    _level1Controller != null)
                  Positioned.fill(child: VideoPlayer(_level1Controller!))
                else if (_phase == _ChickenPhase.gameplay)
                  Positioned.fill(child: _buildGameplay())
                else
                  const ColoredBox(color: Colors.black),
                if (_phase == _ChickenPhase.intro &&
                    _introReady &&
                    _introController != null)
                  _buildIntroSkipButton(),
                GameLogicalBackPill(onPressed: _exitToMenu),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
