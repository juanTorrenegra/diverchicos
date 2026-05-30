import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../utils/disable_video_pointer.dart';
import '../widgets/menu_back_pill.dart';

const String kGridPuzzleIntroAsset = 'assets/video/GridPuzzleIntro.mp4';
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

  static const List<RoadFigureType> _kFigureTypes = RoadFigureType.values;

  VideoPlayerController? _introController;
  bool _introReady = false;
  bool _introFinished = false;

  int _nextFigureId = 0;
  late List<_RoadFigureInstance> _figures;
  final Map<int, String> _slotOccupants = {};

  String? _draggingFigureId;
  _GirlMotion _girlMotion = _GirlMotion.idle;
  Offset _girlPosition = _kGridOrigin;

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
      if (mounted) widget.onClose();
    }
  }

  void _onIntroTick() {
    final v = _introController;
    if (v == null || !mounted) return;
    final value = v.value;
    if (!value.isInitialized || value.hasError) return;
    if (value.isCompleted && !_introFinished) {
      unawaited(v.pause());
      setState(() => _introFinished = true);
      unawaited(_releaseVideoPointerCapture());
    }
  }

  void _onGridTapped() {
    if (!_introFinished ||
        _draggingFigureId != null ||
        _girlMotion != _GirlMotion.idle) {
      return;
    }

    final pathToPlane = _findPathToPlane();
    if (pathToPlane != null) {
      unawaited(_walkGirl(pathToPlane, success: true));
      return;
    }

    final fallbackPath = _findLongestWalkFromStart();
    if (fallbackPath != null) {
      unawaited(_walkGirl(fallbackPath, success: false));
    }
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
      setState(() => _girlMotion = _GirlMotion.success);
      return;
    }

    await _walkGirlAndReturn(path);
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

    if (!wasOnGrid && mounted) {
      setState(() => _spawnHolderCopy(figure.type));
    } else if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    restoreAppPointerEvents();
    _introController?.removeListener(_onIntroTick);
    _introController?.dispose();
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
              clipBehavior: Clip.none,
              children: [
                if (_introReady && _introController != null && !_introFinished)
                  Positioned.fill(child: VideoPlayer(_introController!)),
                if (_introReady && _introController != null && _introFinished)
                  Positioned.fill(
                    child: IgnorePointer(child: VideoPlayer(_introController!)),
                  ),
                if (_introFinished)
                  Positioned.fill(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _buildGridArea(),
                        _buildPlane(),
                        _buildGirl(),
                        _buildRoadFigureRow(),
                      ],
                    ),
                  )
                else if (!_introReady)
                  const ColoredBox(color: Colors.black),
                GameLogicalBackPill(onPressed: widget.onClose),
              ],
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
      child: IgnorePointer(
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
        setState(() => _draggingFigureId = figure.id);
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
