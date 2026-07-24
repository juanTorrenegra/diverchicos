import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../widgets/menu_back_pill.dart';

const String kJigsawBgAsset = 'assets/images/wayuuBg.png';
const String kJigsawLogoAsset = 'assets/images/logoDC.png';

/// Edge connector: flat, outward tab, or inward socket.
enum _JigsawEdge { flat, tab, blank }

/// Classic 2×2 layout:
/// NW right-tab / bottom-blank · NE left-blank / bottom-tab
/// SW top-tab / right-tab · SE top-blank / left-blank
class _PieceSpec {
  const _PieceSpec({
    required this.id,
    required this.row,
    required this.col,
    required this.top,
    required this.right,
    required this.bottom,
    required this.left,
  });

  final int id;
  final int row;
  final int col;
  final _JigsawEdge top;
  final _JigsawEdge right;
  final _JigsawEdge bottom;
  final _JigsawEdge left;
}

const List<_PieceSpec> _kPieces = [
  _PieceSpec(
    id: 0,
    row: 0,
    col: 0,
    top: _JigsawEdge.flat,
    right: _JigsawEdge.tab,
    bottom: _JigsawEdge.blank,
    left: _JigsawEdge.flat,
  ),
  _PieceSpec(
    id: 1,
    row: 0,
    col: 1,
    top: _JigsawEdge.flat,
    right: _JigsawEdge.flat,
    bottom: _JigsawEdge.tab,
    left: _JigsawEdge.blank,
  ),
  _PieceSpec(
    id: 2,
    row: 1,
    col: 0,
    top: _JigsawEdge.tab,
    right: _JigsawEdge.tab,
    bottom: _JigsawEdge.flat,
    left: _JigsawEdge.flat,
  ),
  _PieceSpec(
    id: 3,
    row: 1,
    col: 1,
    top: _JigsawEdge.blank,
    right: _JigsawEdge.flat,
    bottom: _JigsawEdge.flat,
    left: _JigsawEdge.blank,
  ),
];

/// Builds a classic jigsaw path for [spec] inside a [boardW]×[boardH] board.
Path _buildJigsawPiecePath({
  required _PieceSpec spec,
  required double boardW,
  required double boardH,
}) {
  final cellW = boardW / 2;
  final cellH = boardH / 2;
  final left = spec.col * cellW;
  final top = spec.row * cellH;
  final right = left + cellW;
  final bottom = top + cellH;
  final knob = math.min(cellW, cellH) * 0.22;

  final path = Path();
  path.moveTo(left, top);

  _addHorizontalEdge(
    path,
    fromX: left,
    toX: right,
    y: top,
    edge: spec.top,
    outwardPositiveY: false,
    knob: knob,
  );
  _addVerticalEdge(
    path,
    fromY: top,
    toY: bottom,
    x: right,
    edge: spec.right,
    outwardPositiveX: true,
    knob: knob,
  );
  _addHorizontalEdge(
    path,
    fromX: right,
    toX: left,
    y: bottom,
    edge: spec.bottom,
    outwardPositiveY: true,
    knob: knob,
  );
  _addVerticalEdge(
    path,
    fromY: bottom,
    toY: top,
    x: left,
    edge: spec.left,
    outwardPositiveX: false,
    knob: knob,
  );
  path.close();
  return path;
}

void _addHorizontalEdge(
  Path path, {
  required double fromX,
  required double toX,
  required double y,
  required _JigsawEdge edge,
  required bool outwardPositiveY,
  required double knob,
}) {
  final dir = toX >= fromX ? 1.0 : -1.0;
  final span = (toX - fromX).abs();
  if (edge == _JigsawEdge.flat || span < 1) {
    path.lineTo(toX, y);
    return;
  }

  final mid = (fromX + toX) / 2;
  final neck = knob * 0.55;
  final sign = outwardPositiveY ? 1.0 : -1.0;
  final tab = edge == _JigsawEdge.tab ? 1.0 : -1.0;
  final out = sign * tab;

  path.lineTo(mid - dir * neck, y);
  path.cubicTo(
    mid - dir * neck * 0.35,
    y,
    mid - dir * knob * 0.55,
    y + out * knob * 0.35,
    mid - dir * knob * 0.15,
    y + out * knob * 0.75,
  );
  path.arcToPoint(
    Offset(mid + dir * knob * 0.15, y + out * knob * 0.75),
    radius: Radius.circular(knob * 0.55),
    clockwise: outwardPositiveY ? tab > 0 : tab < 0,
  );
  path.cubicTo(
    mid + dir * knob * 0.55,
    y + out * knob * 0.35,
    mid + dir * neck * 0.35,
    y,
    mid + dir * neck,
    y,
  );
  path.lineTo(toX, y);
}

void _addVerticalEdge(
  Path path, {
  required double fromY,
  required double toY,
  required double x,
  required _JigsawEdge edge,
  required bool outwardPositiveX,
  required double knob,
}) {
  final dir = toY >= fromY ? 1.0 : -1.0;
  final span = (toY - fromY).abs();
  if (edge == _JigsawEdge.flat || span < 1) {
    path.lineTo(x, toY);
    return;
  }

  final mid = (fromY + toY) / 2;
  final neck = knob * 0.55;
  final sign = outwardPositiveX ? 1.0 : -1.0;
  final tab = edge == _JigsawEdge.tab ? 1.0 : -1.0;
  final out = sign * tab;

  path.lineTo(x, mid - dir * neck);
  path.cubicTo(
    x,
    mid - dir * neck * 0.35,
    x + out * knob * 0.35,
    mid - dir * knob * 0.55,
    x + out * knob * 0.75,
    mid - dir * knob * 0.15,
  );
  path.arcToPoint(
    Offset(x + out * knob * 0.75, mid + dir * knob * 0.15),
    radius: Radius.circular(knob * 0.55),
    clockwise: outwardPositiveX ? tab < 0 : tab > 0,
  );
  path.cubicTo(
    x + out * knob * 0.35,
    mid + dir * knob * 0.55,
    x,
    mid + dir * neck * 0.35,
    x,
    mid + dir * neck,
  );
  path.lineTo(x, toY);
}

class _JigsawPieceClipper extends CustomClipper<Path> {
  _JigsawPieceClipper({
    required this.spec,
    required this.boardW,
    required this.boardH,
  });

  final _PieceSpec spec;
  final double boardW;
  final double boardH;

  @override
  Path getClip(Size size) {
    return _buildJigsawPiecePath(
      spec: spec,
      boardW: boardW,
      boardH: boardH,
    );
  }

  @override
  bool shouldReclip(covariant _JigsawPieceClipper oldClipper) {
    return oldClipper.spec.id != spec.id ||
        oldClipper.boardW != boardW ||
        oldClipper.boardH != boardH;
  }
}

/// Wayuu-themed 4-piece jigsaw using [logoDC] on [wayuuBg].
class JigsawPuzzleLayer extends StatefulWidget {
  const JigsawPuzzleLayer({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  State<JigsawPuzzleLayer> createState() => _JigsawPuzzleLayerState();
}

class _JigsawPuzzleLayerState extends State<JigsawPuzzleLayer>
    with TickerProviderStateMixin {
  static const double _kLogicalW = 1980;
  static const double _kLogicalH = 1080;

  /// Puzzle board size (logo aspect ≈ 323×216).
  static const double _kBoardW = 720;
  static const double _kBoardH = 720 * 216 / 323;
  static const Offset _kBoardOrigin = Offset(180, (_kLogicalH - _kBoardH) / 2);

  static const double _kSnapDistance = 72;
  static const Duration _kBounceBack = Duration(milliseconds: 720);

  final Map<int, Offset> _piecePos = {};
  final Map<int, Offset> _homePos = {};
  final Set<int> _placed = {};
  int? _draggingId;

  final Map<int, AnimationController> _bounceControllers = {};
  final Map<int, Animation<Offset>> _bounceAnims = {};

  bool _exitingToMenu = false;

  @override
  void initState() {
    super.initState();
    _layoutHomes();
  }

  void _layoutHomes() {
    const trayLeft = 1080.0;
    const trayTop = 160.0;
    const gapX = 36.0;
    const gapY = 28.0;
    final pieceW = _kBoardW / 2;
    final pieceH = _kBoardH / 2;

    for (final spec in _kPieces) {
      final col = spec.id % 2;
      final row = spec.id ~/ 2;
      final home = Offset(
        trayLeft + col * (pieceW + gapX),
        trayTop + row * (pieceH + gapY),
      );
      _homePos[spec.id] = home;
      if (!_placed.contains(spec.id) && !_piecePos.containsKey(spec.id)) {
        _piecePos[spec.id] = home;
      }
    }
  }

  Offset _slotOrigin(_PieceSpec spec) {
    return Offset(
      _kBoardOrigin.dx + spec.col * (_kBoardW / 2),
      _kBoardOrigin.dy + spec.row * (_kBoardH / 2),
    );
  }

  /// Top-left of the full-board image when the piece is drawn at [pieceTopLeft].
  Offset _imageOriginForPiece(_PieceSpec spec, Offset pieceTopLeft) {
    return Offset(
      pieceTopLeft.dx - spec.col * (_kBoardW / 2),
      pieceTopLeft.dy - spec.row * (_kBoardH / 2),
    );
  }

  void _exitToMenu() {
    if (_exitingToMenu) return;
    _exitingToMenu = true;
    widget.onClose();
  }

  void _cancelBounce(int id) {
    final c = _bounceControllers.remove(id);
    _bounceAnims.remove(id);
    c?.dispose();
  }

  void _bounceHome(int id) {
    final home = _homePos[id];
    final from = _piecePos[id];
    if (home == null || from == null) return;
    if ((from - home).distance < 1) {
      setState(() => _piecePos[id] = home);
      return;
    }

    _cancelBounce(id);
    final controller = AnimationController(vsync: this, duration: _kBounceBack);
    final anim = Tween<Offset>(begin: from, end: home).animate(
      CurvedAnimation(parent: controller, curve: Curves.elasticOut),
    );
    controller.addListener(() {
      if (!mounted) return;
      setState(() => _piecePos[id] = anim.value);
    });
    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _cancelBounce(id);
        if (mounted) setState(() => _piecePos[id] = home);
      }
    });
    _bounceControllers[id] = controller;
    _bounceAnims[id] = anim;
    controller.forward(from: 0);
  }

  void _onPanStart(int id, DragStartDetails details) {
    if (_placed.contains(id)) return;
    _cancelBounce(id);
    setState(() => _draggingId = id);
  }

  void _onPanUpdate(int id, DragUpdateDetails details) {
    if (_draggingId != id) return;
    setState(() {
      _piecePos[id] = (_piecePos[id] ?? _homePos[id]!) + details.delta;
    });
  }

  void _onPanEnd(int id) {
    if (_draggingId != id) return;
    _draggingId = null;
    final spec = _kPieces[id];
    final current = _piecePos[id]!;
    final target = _slotOrigin(spec);
    if ((current - target).distance <= _kSnapDistance) {
      setState(() {
        _piecePos[id] = target;
        _placed.add(id);
      });
    } else {
      _bounceHome(id);
    }
  }

  @override
  void dispose() {
    for (final c in _bounceControllers.values) {
      c.dispose();
    }
    _bounceControllers.clear();
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
                Positioned.fill(
                  child: Image.asset(
                    kJigsawBgAsset,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
                // Soft panel behind the board so empty slots read clearly.
                Positioned(
                  left: _kBoardOrigin.dx - 28,
                  top: _kBoardOrigin.dy - 28,
                  width: _kBoardW + 56,
                  height: _kBoardH + 56,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.45),
                        width: 3,
                      ),
                    ),
                  ),
                ),
                ..._kPieces.map(_buildEmptySlot),
                ..._kPieces.where((s) => _placed.contains(s.id)).map(_buildPlacedPiece),
                ..._kPieces
                    .where((s) => !_placed.contains(s.id))
                    .map(_buildDraggablePiece),
                GameLogicalBackPill(onPressed: _exitToMenu),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptySlot(_PieceSpec spec) {
    if (_placed.contains(spec.id)) return const SizedBox.shrink();
    return Positioned(
      left: _kBoardOrigin.dx,
      top: _kBoardOrigin.dy,
      width: _kBoardW,
      height: _kBoardH,
      child: IgnorePointer(
        child: ClipPath(
          clipper: _JigsawPieceClipper(
            spec: spec,
            boardW: _kBoardW,
            boardH: _kBoardH,
          ),
          child: Stack(
            children: [
              ColoredBox(color: Colors.black.withValues(alpha: 0.28)),
              Opacity(
                opacity: 0.22,
                child: Image.asset(
                  kJigsawLogoAsset,
                  width: _kBoardW,
                  height: _kBoardH,
                  fit: BoxFit.fill,
                ),
              ),
              CustomPaint(
                size: const Size(_kBoardW, _kBoardH),
                painter: _JigsawOutlinePainter(
                  spec: spec,
                  boardW: _kBoardW,
                  boardH: _kBoardH,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlacedPiece(_PieceSpec spec) {
    return Positioned(
      left: _kBoardOrigin.dx,
      top: _kBoardOrigin.dy,
      width: _kBoardW,
      height: _kBoardH,
      child: IgnorePointer(
        child: ClipPath(
          clipper: _JigsawPieceClipper(
            spec: spec,
            boardW: _kBoardW,
            boardH: _kBoardH,
          ),
          child: Image.asset(
            kJigsawLogoAsset,
            width: _kBoardW,
            height: _kBoardH,
            fit: BoxFit.fill,
            filterQuality: FilterQuality.medium,
          ),
        ),
      ),
    );
  }

  Widget _buildDraggablePiece(_PieceSpec spec) {
    final pieceTopLeft = _piecePos[spec.id] ?? _homePos[spec.id]!;
    final imageOrigin = _imageOriginForPiece(spec, pieceTopLeft);
    final elev = _draggingId == spec.id ? 14.0 : 6.0;

    return Positioned(
      left: imageOrigin.dx,
      top: imageOrigin.dy,
      width: _kBoardW,
      height: _kBoardH,
      child: ClipPath(
        clipper: _JigsawPieceClipper(
          spec: spec,
          boardW: _kBoardW,
          boardH: _kBoardH,
        ),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (d) => _onPanStart(spec.id, d),
          onPanUpdate: (d) => _onPanUpdate(spec.id, d),
          onPanEnd: (_) => _onPanEnd(spec.id),
          onPanCancel: () => _onPanEnd(spec.id),
          child: DecoratedBox(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: elev,
                  offset: Offset(2, elev / 2),
                ),
              ],
            ),
            child: Image.asset(
              kJigsawLogoAsset,
              width: _kBoardW,
              height: _kBoardH,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ),
      ),
    );
  }
}

class _JigsawOutlinePainter extends CustomPainter {
  _JigsawOutlinePainter({
    required this.spec,
    required this.boardW,
    required this.boardH,
  });

  final _PieceSpec spec;
  final double boardW;
  final double boardH;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildJigsawPiecePath(
      spec: spec,
      boardW: boardW,
      boardH: boardH,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..color = Colors.white.withValues(alpha: 0.75);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _JigsawOutlinePainter oldDelegate) =>
      oldDelegate.spec.id != spec.id;
}
