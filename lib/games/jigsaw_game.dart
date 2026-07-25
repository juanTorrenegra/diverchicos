import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../widgets/menu_back_pill.dart';

const String kJigsawLogoAsset = 'assets/images/logoDC.png';

/// Stroke width for empty-slot board outlines (inner seams + outer edges).
const double kJigsawBoardLineThickness = 10;

/// Opacity of the faint logo preview inside empty receiver slots.
const double kJigsawSlotGhostOpacity = 0.4;

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

/// Overall knob scale relative to a half-board cell.
const double kJigsawKnobScale = 0.24;

/// Half-width of the narrow neck where the knob meets the edge (smaller = skinnier stem).
/// Keep this clearly smaller than [kJigsawKnobBulbRatio] for a waist, not a triangle.
const double kJigsawKnobNeckRatio = 0.28;

/// How far the stem travels before the bulb (relative to knob size).
const double kJigsawKnobStemRatio = 0.22;

/// Bulb radius at the tip (relative to knob size) — larger = rounder head.
const double kJigsawKnobBulbRatio = 0.44;

/// Outer silhouette of the assembled puzzle (and each piece's outer rim).
Path _buildHeartPath(double width, double height) {
  final w = width;
  final h = height;
  final path = Path();
  // Apple-heart: shallow top cleft, rounded bottom (no pointed tip).
  path.moveTo(0.50 * w, 0.07 * h);
  // Left top lobe (cleft sits close to the top).
  path.cubicTo(0.50 * w, 0.01 * h, 0.32 * w, 0.00 * h, 0.18 * w, 0.03 * h);
  path.cubicTo(0.05 * w, 0.06 * h, 0.00 * w, 0.18 * h, 0.00 * w, 0.32 * h);
  // Left side into a full rounded apple bottom.
  path.cubicTo(0.00 * w, 0.55 * h, 0.10 * w, 0.78 * h, 0.32 * w, 0.90 * h);
  path.cubicTo(0.42 * w, 0.96 * h, 0.58 * w, 0.96 * h, 0.68 * w, 0.90 * h);
  // Right side back up.
  path.cubicTo(0.90 * w, 0.78 * h, 1.00 * w, 0.55 * h, 1.00 * w, 0.32 * h);
  path.cubicTo(1.00 * w, 0.18 * h, 0.95 * w, 0.06 * h, 0.82 * w, 0.03 * h);
  path.cubicTo(0.68 * w, 0.00 * h, 0.50 * w, 0.01 * h, 0.50 * w, 0.07 * h);
  path.close();
  return path;
}

/// Builds a classic jigsaw path for [spec] inside a heart-shaped board.
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
  final knob = math.min(cellW, cellH) * kJigsawKnobScale;

  final rectPiece = Path();
  rectPiece.moveTo(left, top);

  // Same knob shape on every side: built in a local frame, then mapped.
  _addEdge(
    rectPiece,
    from: Offset(left, top),
    to: Offset(right, top),
    outward: const Offset(0, -1),
    edge: spec.top,
    knob: knob,
  );
  _addEdge(
    rectPiece,
    from: Offset(right, top),
    to: Offset(right, bottom),
    outward: const Offset(1, 0),
    edge: spec.right,
    knob: knob,
  );
  _addEdge(
    rectPiece,
    from: Offset(right, bottom),
    to: Offset(left, bottom),
    outward: const Offset(0, 1),
    edge: spec.bottom,
    knob: knob,
  );
  _addEdge(
    rectPiece,
    from: Offset(left, bottom),
    to: Offset(left, top),
    outward: const Offset(-1, 0),
    edge: spec.left,
    knob: knob,
  );
  rectPiece.close();

  // Clip the rectangular cell to the heart so outer borders follow the heart.
  return Path.combine(
    PathOperation.intersect,
    rectPiece,
    _buildHeartPath(boardW, boardH),
  );
}

/// Adds one board edge. Knob geometry is authored once in local (along, out)
/// coordinates and mapped with [from]/[to]/[outward] so every side matches.
void _addEdge(
  Path path, {
  required Offset from,
  required Offset to,
  required Offset outward,
  required _JigsawEdge edge,
  required double knob,
}) {
  final delta = to - from;
  final span = delta.distance;
  if (edge == _JigsawEdge.flat || span < 1) {
    path.lineTo(to.dx, to.dy);
    return;
  }

  final along = Offset(delta.dx / span, delta.dy / span);
  final out = edge == _JigsawEdge.tab
      ? outward
      : Offset(-outward.dx, -outward.dy);
  final mid = Offset((from.dx + to.dx) / 2, (from.dy + to.dy) / 2);

  final neck = knob * kJigsawKnobNeckRatio;
  final stem = knob * kJigsawKnobStemRatio;
  final bulbR = knob * kJigsawKnobBulbRatio;

  Offset map(double alongLocal, double outLocal) {
    return Offset(
      mid.dx + along.dx * alongLocal + out.dx * outLocal,
      mid.dy + along.dy * alongLocal + out.dy * outLocal,
    );
  }

  // Local frame: travel is +along, knob grows in +out.
  // Neck on the edge, rounded waist, then a round bulb.
  final neckL = map(-neck, 0);
  final neckR = map(neck, 0);
  final center = map(0, stem + bulbR);

  // Angle from the outward tip toward the edge (past the equator ≈ π/2).
  const attach = 1.95;
  final enter = map(
    -bulbR * math.sin(attach),
    stem + bulbR + bulbR * math.cos(attach),
  );
  final exit = map(
    bulbR * math.sin(attach),
    stem + bulbR + bulbR * math.cos(attach),
  );
  final enterAng = math.atan2(enter.dy - center.dy, enter.dx - center.dx);
  final exitAng = math.atan2(exit.dy - center.dy, exit.dx - center.dx);

  path.lineTo(neckL.dx, neckL.dy);

  // Rounded waist: stay narrow, then flare into the bulb.
  final c1 = map(-neck * 0.85, stem * 0.35);
  final c2 = map(-bulbR * 0.55, stem + bulbR * 0.15);
  path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, enter.dx, enter.dy);

  // Arc through the outward tip (not the short chord back through the neck).
  var sweep = exitAng - enterAng;
  while (sweep <= -math.pi) {
    sweep += 2 * math.pi;
  }
  while (sweep > math.pi) {
    sweep -= 2 * math.pi;
  }
  final tip = map(0, stem + 2 * bulbR);
  Offset arcMid(double s) => Offset(
    center.dx + bulbR * math.cos(enterAng + s / 2),
    center.dy + bulbR * math.sin(enterAng + s / 2),
  );
  final longSweep = sweep >= 0 ? sweep - 2 * math.pi : sweep + 2 * math.pi;
  if ((arcMid(longSweep) - tip).distance < (arcMid(sweep) - tip).distance) {
    sweep = longSweep;
  }
  path.arcTo(
    Rect.fromCircle(center: center, radius: bulbR),
    enterAng,
    sweep,
    false,
  );

  final c3 = map(bulbR * 0.55, stem + bulbR * 0.15);
  final c4 = map(neck * 0.85, stem * 0.35);
  path.cubicTo(c3.dx, c3.dy, c4.dx, c4.dy, neckR.dx, neckR.dy);
  path.lineTo(to.dx, to.dy);
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
    return _buildJigsawPiecePath(spec: spec, boardW: boardW, boardH: boardH);
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

class _RopeSpec {
  const _RopeSpec({
    required this.anchorXFraction,
    required this.hangYFraction,
  });

  /// Horizontal hook position as a fraction of screen width (1/6, 2/6, …).
  final double anchorXFraction;

  /// Rest hang depth as a fraction of screen height (higher = hangs lower).
  final double hangYFraction;
}

class _JigsawPuzzleLayerState extends State<JigsawPuzzleLayer>
    with TickerProviderStateMixin {
  static const double _kLogicalW = 1980;
  static const double _kLogicalH = 1080;

  /// Puzzle board size — near-square so the heart silhouette reads clearly.
  static const double _kBoardW = 700;
  static const double _kBoardH = 640;
  static const Offset _kBoardOrigin = Offset(
    (_kLogicalW - _kBoardW) / 2,
    (_kLogicalH - _kBoardH) / 2,
  );

  static const double _kSnapDistance = 72;
  static const Duration _kDropDelay = Duration(seconds: 1);

  /// Variable-length pendulum: swings (θ) + bouncy stretch (L).
  static const double _kGravity = 2400.0;
  static const double _kStretch = 140.0;
  static const double _kLenDamp = 3.2;
  static const double _kAngDamp = 0.45;
  static const double _kAttachBias = 48.0;

  /// Fixed hook slots: left 1/8 & 2/8, right 6/8 & 7/8 (pieces are shuffled onto these).
  static const List<_RopeSpec> _kRopeSlots = [
    _RopeSpec(anchorXFraction: 1 / 8, hangYFraction: 0.62), // left, lower
    _RopeSpec(anchorXFraction: 2 / 8, hangYFraction: 0.40), // left, less low
    _RopeSpec(anchorXFraction: 6 / 8, hangYFraction: 0.48), // right, hang low
    _RopeSpec(anchorXFraction: 7 / 8, hangYFraction: 0.66), // right, hanging lower
  ];

  final Map<int, Offset> _piecePos = {};
  final Map<int, double> _restLength = {};
  final Map<int, Offset> _anchors = {};
  /// Cartesian velocity while free-falling / dragging.
  final Map<int, Offset> _velocity = {};
  /// Pendulum state once the rope has caught the piece.
  final Map<int, double> _theta = {}; // 0 = straight down
  final Map<int, double> _omega = {};
  final Map<int, double> _length = {};
  final Map<int, double> _lenVel = {};
  final Map<int, bool> _onRope = {};
  final Map<int, double> _tilt = {};
  final Map<int, _RopeSpec> _ropeByPiece = {};
  final Set<int> _placed = {};
  int? _draggingId;

  Ticker? _physicsTicker;
  Duration _lastTick = Duration.zero;
  Timer? _dropTimer;
  bool _piecesReleased = false;
  bool _exitingToMenu = false;
  final math.Random _rng = math.Random();

  double get _cellW => _kBoardW / 2;
  double get _cellH => _kBoardH / 2;

  @override
  void initState() {
    super.initState();
    _layoutRopes();
    _dropTimer = Timer(_kDropDelay, _startDrop);
  }

  double _attachLocalX(_PieceSpec spec) {
    // Off-center hitch so hanging pieces rest with a little tilt.
    final rope = _ropeByPiece[spec.id];
    final onLeft = (rope?.anchorXFraction ?? 0.5) < 0.5;
    final bias = onLeft ? -_kAttachBias : _kAttachBias;
    return _cellW / 2 + bias;
  }

  Offset _ropeAttach(_PieceSpec spec, Offset pieceTopLeft) {
    return Offset(pieceTopLeft.dx + _attachLocalX(spec), pieceTopLeft.dy);
  }

  Offset _pieceFromAttach(_PieceSpec spec, Offset attach) {
    return Offset(attach.dx - _attachLocalX(spec), attach.dy);
  }

  /// Hitch world position from pendulum polar coords (θ from downward vertical).
  Offset _attachFromPolar(Offset anchor, double length, double theta) {
    return Offset(
      anchor.dx + length * math.sin(theta),
      anchor.dy + length * math.cos(theta),
    );
  }

  void _catchOntoRope(
    int id,
    Offset anchor,
    Offset attach,
    Offset vel,
    double restLen,
  ) {
    final delta = attach - anchor;
    final dist = math.max(delta.distance, 1.0);
    final dir = Offset(delta.dx / dist, delta.dy / dist); // outward
    final tangent = Offset(dir.dy, -dir.dx); // leftward when hanging down
    final vRad = vel.dx * dir.dx + vel.dy * dir.dy;
    final vTan = vel.dx * tangent.dx + vel.dy * tangent.dy;

    _length[id] = dist;
    _lenVel[id] = vRad;
    _theta[id] = math.atan2(delta.dx, math.max(delta.dy, 1.0));
    _omega[id] = vTan / dist;
    _onRope[id] = true;
    // Nudge a little angular energy if almost purely vertical (organic swing).
    if (_omega[id]!.abs() < 0.4) {
      _omega[id] = (_omega[id] ?? 0) + (_rng.nextBool() ? 1.2 : -1.2);
    }
  }

  void _layoutRopes() {
    final slots = List<_RopeSpec>.from(_kRopeSlots)..shuffle(_rng);
    final pieces = List<_PieceSpec>.from(_kPieces)..shuffle(_rng);

    for (var i = 0; i < pieces.length; i++) {
      final spec = pieces[i];
      final rope = slots[i];
      _ropeByPiece[spec.id] = rope;

      final anchor = Offset(rope.anchorXFraction * _kLogicalW, 0);
      final hangY = rope.hangYFraction * _kLogicalH;
      final attachRest = Offset(anchor.dx, hangY);
      final rest = _pieceFromAttach(spec, attachRest);
      _anchors[spec.id] = anchor;
      _restLength[spec.id] = hangY;
      _tilt[spec.id] = 0;
      _onRope[spec.id] = false;
      _theta[spec.id] = 0;
      _omega[spec.id] = 0;
      _length[spec.id] = hangY;
      _lenVel[spec.id] = 0;
      // Start above the screen with a sideways kick so the catch swings.
      final kick = (_rng.nextDouble() * 2 - 1) * 520;
      _piecePos[spec.id] = Offset(
        rest.dx + (_rng.nextDouble() * 2 - 1) * 80,
        -140 - _rng.nextDouble() * 60,
      );
      _velocity[spec.id] = Offset(kick, 350 + _rng.nextDouble() * 200);
    }
  }

  void _startDrop() {
    if (!mounted || _exitingToMenu) return;
    setState(() => _piecesReleased = true);
    _physicsTicker?.dispose();
    _lastTick = Duration.zero;
    _physicsTicker = createTicker(_onPhysicsTick)..start();
  }

  double _naturalTilt(_PieceSpec spec, double theta) {
    final onLeft = (_ropeByPiece[spec.id]?.anchorXFraction ?? 0.5) < 0.5;
    final bias = onLeft ? -0.12 : 0.12;
    return (theta + bias).clamp(-0.95, 0.95);
  }

  void _onPhysicsTick(Duration elapsed) {
    if (!mounted) return;
    final dtMs = _lastTick == Duration.zero
        ? 16.0
        : (elapsed - _lastTick).inMicroseconds / 1000.0;
    _lastTick = elapsed;
    // Sub-step for stable pendulum integration.
    var remaining = (dtMs / 1000.0).clamp(0.0, 1 / 20);
    const subDt = 1 / 120;
    var needsFrame = false;

    while (remaining > 0) {
      final dt = math.min(subDt, remaining);
      remaining -= dt;
      if (_stepPhysics(dt)) needsFrame = true;
    }

    if (!needsFrame) return;
    setState(() {});
  }

  /// One integration step. Returns true if anything moved.
  bool _stepPhysics(double dt) {
    var moved = false;

    for (final spec in _kPieces) {
      final id = spec.id;
      if (_placed.contains(id)) continue;

      if (_draggingId == id) {
        final t = _tilt[id] ?? 0;
        final newT = t * math.pow(0.0004, dt).toDouble();
        if (newT.abs() > 0.002) {
          _tilt[id] = newT;
          moved = true;
        } else if (t.abs() > 0.001) {
          _tilt[id] = 0;
          moved = true;
        }
        continue;
      }

      final anchor = _anchors[id]!;
      final restLen = _restLength[id]!;

      if (_onRope[id] != true) {
        // Free-fall until the rope snaps taut.
        final pos = _piecePos[id]!;
        final vel = _velocity[id] ?? Offset.zero;
        final accel = Offset(
          -_kLenDamp * 0.15 * vel.dx,
          _kGravity - _kLenDamp * 0.15 * vel.dy,
        );
        final newVel = vel + accel * dt;
        final newPos = pos + newVel * dt;
        final attach = _ropeAttach(spec, newPos);
        final dist = (attach - anchor).distance;

        _piecePos[id] = newPos;
        _velocity[id] = newVel;
        _tilt[id] = _naturalTilt(spec, math.atan2(
          attach.dx - anchor.dx,
          math.max(attach.dy, 1),
        ));
        moved = true;

        if (attach.dy > anchor.dy + 20 && dist >= restLen) {
          _catchOntoRope(id, anchor, attach, newVel, restLen);
        }
        continue;
      }

      // --- Variable-length pendulum ---
      var theta = _theta[id] ?? 0.0;
      var omega = _omega[id] ?? 0.0;
      var length = (_length[id] ?? restLen).clamp(40.0, restLen * 2.5);
      var lenVel = _lenVel[id] ?? 0.0;

      // θ'' = -(g/L) sinθ - 2 (L'/L) ω - damp ω
      final angAcc = -( _kGravity / length) * math.sin(theta) -
          2 * (lenVel / length) * omega -
          _kAngDamp * omega;
      // L'' = L ω² - k (L - rest) + g cosθ - damp L'
      final lenAcc = length * omega * omega -
          _kStretch * (length - restLen) +
          _kGravity * math.cos(theta) -
          _kLenDamp * lenVel;

      omega += angAcc * dt;
      theta += omega * dt;
      lenVel += lenAcc * dt;
      length = (length + lenVel * dt).clamp(40.0, restLen * 2.5);

      // Soft settle when nearly still at the bottom.
      if (theta.abs() < 0.012 &&
          omega.abs() < 0.08 &&
          (length - restLen).abs() < 4 &&
          lenVel.abs() < 20) {
        if (theta.abs() > 0.0001 ||
            omega.abs() > 0.0001 ||
            (length - restLen).abs() > 0.1 ||
            lenVel.abs() > 0.1) {
          moved = true;
        }
        theta = 0;
        omega = 0;
        length = restLen;
        lenVel = 0;
      } else {
        moved = true;
      }

      _theta[id] = theta;
      _omega[id] = omega;
      _length[id] = length;
      _lenVel[id] = lenVel;

      final attach = _attachFromPolar(anchor, length, theta);
      _piecePos[id] = _pieceFromAttach(spec, attach);
      // Sync cartesian vel for a clean hand-off if the user grabs mid-swing.
      final dir = Offset(math.sin(theta), math.cos(theta));
      final tan = Offset(dir.dy, -dir.dx);
      _velocity[id] = dir * lenVel + tan * (omega * length);

      final targetTilt = _naturalTilt(spec, theta);
      final curTilt = _tilt[id] ?? targetTilt;
      _tilt[id] = curTilt + (targetTilt - curTilt) * (1 - math.pow(0.01, dt));
      if ((targetTilt - curTilt).abs() > 0.002) moved = true;
    }

    return moved;
  }

  Offset _slotOrigin(_PieceSpec spec) {
    return Offset(
      _kBoardOrigin.dx + spec.col * _cellW,
      _kBoardOrigin.dy + spec.row * _cellH,
    );
  }

  /// Top-left of the full-board image when the piece is drawn at [pieceTopLeft].
  Offset _imageOriginForPiece(_PieceSpec spec, Offset pieceTopLeft) {
    return Offset(
      pieceTopLeft.dx - spec.col * _cellW,
      pieceTopLeft.dy - spec.row * _cellH,
    );
  }

  void _exitToMenu() {
    if (_exitingToMenu) return;
    _exitingToMenu = true;
    widget.onClose();
  }

  void _onPanStart(int id, DragStartDetails details) {
    if (!_piecesReleased || _placed.contains(id)) return;
    setState(() {
      _draggingId = id;
      _onRope[id] = false;
      _velocity[id] = Offset.zero;
    });
  }

  void _onPanUpdate(int id, DragUpdateDetails details) {
    if (_draggingId != id) return;
    final fling = details.delta * 62;
    setState(() {
      _piecePos[id] = (_piecePos[id]!) + details.delta;
      _velocity[id] = fling;
    });
  }

  void _onPanEnd(int id) {
    if (_draggingId != id) return;
    final spec = _kPieces[id];
    final current = _piecePos[id]!;
    final target = _slotOrigin(spec);
    if ((current - target).distance <= _kSnapDistance) {
      setState(() {
        _draggingId = null;
        _piecePos[id] = target;
        _velocity[id] = Offset.zero;
        _tilt[id] = 0;
        _onRope[id] = false;
        _placed.add(id);
      });
    } else {
      // Re-catch on the rope from the release point / fling.
      final anchor = _anchors[id]!;
      final attach = _ropeAttach(spec, current);
      final vel = _velocity[id] ?? Offset.zero;
      final restLen = _restLength[id]!;
      setState(() {
        _draggingId = null;
        if (attach.dy > anchor.dy + 10) {
          _catchOntoRope(id, anchor, attach, vel, restLen);
        } else {
          _onRope[id] = false;
        }
      });
    }
  }

  @override
  void dispose() {
    _dropTimer?.cancel();
    _physicsTicker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ropeSegments = <(Offset, Offset)>[];
    if (_piecesReleased) {
      for (final spec in _kPieces) {
        if (_placed.contains(spec.id)) continue;
        final pos = _piecePos[spec.id];
        final anchor = _anchors[spec.id];
        if (pos == null || anchor == null) continue;
        ropeSegments.add((anchor, _ropeAttach(spec, pos)));
      }
    }

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
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 1.15,
                        colors: [
                          Color(0xFFFF9EC8),
                          Color(0xFFE048A0),
                          Color(0xFF6A1B9A),
                          Color(0xFF2A0A4A),
                        ],
                        stops: [0.0, 0.32, 0.68, 1.0],
                      ),
                    ),
                  ),
                ),

                // Soft heart board behind the slots.
                Positioned(
                  left: _kBoardOrigin.dx,
                  top: _kBoardOrigin.dy,
                  width: _kBoardW,
                  height: _kBoardH,
                  child: IgnorePointer(
                    child: CustomPaint(
                      size: const Size(_kBoardW, _kBoardH),
                      painter: _HeartBoardFillPainter(),
                    ),
                  ),
                ),
                ..._kPieces.map(_buildEmptySlot),
                ..._kPieces
                    .where((s) => _placed.contains(s.id))
                    .map(_buildPlacedPiece),

                // Ropes behind hanging pieces.
                if (ropeSegments.isNotEmpty)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _RopePainter(segments: ropeSegments),
                      ),
                    ),
                  ),

                if (_piecesReleased)
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
    // Pad the layer so thick strokes are not clipped on the outer board edges.
    final pad = kJigsawBoardLineThickness;
    return Positioned(
      left: _kBoardOrigin.dx - pad,
      top: _kBoardOrigin.dy - pad,
      width: _kBoardW + pad * 2,
      height: _kBoardH + pad * 2,
      child: IgnorePointer(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: pad,
              top: pad,
              width: _kBoardW,
              height: _kBoardH,
              child: ClipPath(
                clipper: _JigsawPieceClipper(
                  spec: spec,
                  boardW: _kBoardW,
                  boardH: _kBoardH,
                ),
                child: Stack(
                  children: [
                    ColoredBox(color: Colors.black.withValues(alpha: 0.10)),
                    Opacity(
                      opacity: kJigsawSlotGhostOpacity,
                      child: Image.asset(
                        kJigsawLogoAsset,
                        width: _kBoardW,
                        height: _kBoardH,
                        fit: BoxFit.fill,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Outline painted outside ClipPath so outer edges keep full thickness.
            Positioned(
              left: pad,
              top: pad,
              width: _kBoardW,
              height: _kBoardH,
              child: CustomPaint(
                size: const Size(_kBoardW, _kBoardH),
                painter: _JigsawOutlinePainter(
                  spec: spec,
                  boardW: _kBoardW,
                  boardH: _kBoardH,
                ),
              ),
            ),
          ],
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
    final pieceTopLeft = _piecePos[spec.id]!;
    final imageOrigin = _imageOriginForPiece(spec, pieceTopLeft);
    final elev = _draggingId == spec.id ? 14.0 : 6.0;
    final tilt = _tilt[spec.id] ?? 0.0;
    final attachInWidget = Offset(
      spec.col * _cellW + _attachLocalX(spec),
      spec.row * _cellH,
    );
    final alignX = (attachInWidget.dx / _kBoardW) * 2 - 1;
    final alignY = (attachInWidget.dy / _kBoardH) * 2 - 1;

    return Positioned(
      left: imageOrigin.dx,
      top: imageOrigin.dy,
      width: _kBoardW,
      height: _kBoardH,
      child: Transform.rotate(
        angle: tilt,
        alignment: Alignment(alignX, alignY),
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
      ),
    );
  }
}

class _RopePainter extends CustomPainter {
  _RopePainter({required this.segments});

  final List<(Offset, Offset)> segments;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF6D4C2F)
      ..strokeWidth = 15
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.28)
      ..strokeWidth = 19
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final (anchor, attach) in segments) {
      final mid = Offset(
        (anchor.dx + attach.dx) / 2,
        (anchor.dy + attach.dy) / 2 + (attach - anchor).distance * 0.05,
      );
      final path = Path()
        ..moveTo(anchor.dx, anchor.dy)
        ..quadraticBezierTo(mid.dx, mid.dy, attach.dx, attach.dy);
      canvas.drawPath(path, shadow);
      canvas.drawPath(path, paint);
      canvas.drawCircle(
        anchor,
        14,
        Paint()..color = const Color(0xFF4E3422),
      );
      canvas.drawCircle(
        anchor,
        8,
        Paint()..color = const Color(0xFF8D6E4C),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RopePainter oldDelegate) => true;
}

class _HeartBoardFillPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final heart = _buildHeartPath(size.width, size.height);
    canvas.drawPath(
      heart,
      Paint()..color = Colors.black.withValues(alpha: 0.12),
    );
    canvas.drawPath(
      heart,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = kJigsawBoardLineThickness
        ..color = Colors.white.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(covariant _HeartBoardFillPainter oldDelegate) => false;
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
      ..strokeWidth = kJigsawBoardLineThickness
      ..color = Colors.white.withValues(alpha: 0.9);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _JigsawOutlinePainter oldDelegate) =>
      oldDelegate.spec.id != spec.id;
}
