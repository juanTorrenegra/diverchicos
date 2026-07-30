import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../app_audio.dart';
import '../widgets/match_confetti.dart';
import '../widgets/menu_back_pill.dart';

const List<String> _kFallbackJigsawImages = [
  'assets/images/jigsaw/abeja.jpg',
  'assets/images/jigsaw/bosque.jpg',
  'assets/images/jigsaw/caballo.jpg',
  'assets/images/jigsaw/campo.jpg',
  'assets/images/jigsaw/chigüiro.jpg',
  'assets/images/jigsaw/cocodrilo.jpg',
  'assets/images/jigsaw/colibri.jpg',
  'assets/images/jigsaw/condor.jpg',
  'assets/images/jigsaw/delfines_rosados.jpg',
  'assets/images/jigsaw/delfin_rosado.jpg',
  'assets/images/jigsaw/gato.jpg',
  'assets/images/jigsaw/granja.jpg',
  'assets/images/jigsaw/guacamayas.jpg',
  'assets/images/jigsaw/jaguar.jpg',
  'assets/images/jigsaw/mico.jpg',
  'assets/images/jigsaw/paisaje.jpg',
  'assets/images/jigsaw/perro.jpg',
  'assets/images/jigsaw/serpiente.jpg',
  'assets/images/jigsaw/vaca_y_cabra.jpg',
];

String _jigsawImageDisplayName(String assetPath) {
  final file = assetPath.split('/').last;
  final dot = file.lastIndexOf('.');
  final base = dot > 0 ? file.substring(0, dot) : file;
  return base.replaceAll('_', ' ');
}

class _JigsawLevel {
  const _JigsawLevel({
    required this.imageAsset,
    required this.bgColors,
    required this.cols,
    required this.rows,
    required this.outerShape,
    required this.boardW,
    required this.boardH,
  });

  final String imageAsset;
  final List<Color> bgColors;
  final int cols;
  final int rows;
  final _OuterShape outerShape;
  final double boardW;
  final double boardH;
}

enum _OuterShape { heart, wavyRect }

/// Stroke width for empty-slot board outlines (inner seams + outer edges)
const double kJigsawBoardLineThickness = 10;

/// Opacity of the faint logo preview inside empty receiver slots.
const double kJigsawSlotGhostOpacity = 0.4;

/// Edge connector: flat, outward tab, or inward socket.
enum _JigsawEdge { flat, tab, blank }

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

/// Classic 2×2 heart levels.
const List<_PieceSpec> _kPieces2x2 = [
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

/// 2×3 wavy-rect levels (3 columns × 2 rows).
const List<_PieceSpec> _kPieces2x3 = [
  _PieceSpec(
    id: 0,
    row: 0,
    col: 0,
    top: _JigsawEdge.flat,
    right: _JigsawEdge.tab,
    bottom: _JigsawEdge.tab,
    left: _JigsawEdge.flat,
  ),
  _PieceSpec(
    id: 1,
    row: 0,
    col: 1,
    top: _JigsawEdge.flat,
    right: _JigsawEdge.blank,
    bottom: _JigsawEdge.blank,
    left: _JigsawEdge.blank,
  ),
  _PieceSpec(
    id: 2,
    row: 0,
    col: 2,
    top: _JigsawEdge.flat,
    right: _JigsawEdge.flat,
    bottom: _JigsawEdge.tab,
    left: _JigsawEdge.tab,
  ),
  _PieceSpec(
    id: 3,
    row: 1,
    col: 0,
    top: _JigsawEdge.blank,
    right: _JigsawEdge.blank,
    bottom: _JigsawEdge.flat,
    left: _JigsawEdge.flat,
  ),
  _PieceSpec(
    id: 4,
    row: 1,
    col: 1,
    top: _JigsawEdge.tab,
    right: _JigsawEdge.tab,
    bottom: _JigsawEdge.flat,
    left: _JigsawEdge.tab,
  ),
  _PieceSpec(
    id: 5,
    row: 1,
    col: 2,
    top: _JigsawEdge.blank,
    right: _JigsawEdge.flat,
    bottom: _JigsawEdge.flat,
    left: _JigsawEdge.blank,
  ),
];

/// Overall knob scale relative to a cell.
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
  path.cubicTo(0.50 * w, 0.01 * h, 0.32 * w, 0.00 * h, 0.18 * w, 0.03 * h);
  path.cubicTo(0.05 * w, 0.06 * h, 0.00 * w, 0.18 * h, 0.00 * w, 0.32 * h);
  path.cubicTo(0.00 * w, 0.55 * h, 0.10 * w, 0.78 * h, 0.32 * w, 0.90 * h);
  path.cubicTo(0.42 * w, 0.96 * h, 0.58 * w, 0.96 * h, 0.68 * w, 0.90 * h);
  path.cubicTo(0.90 * w, 0.78 * h, 1.00 * w, 0.55 * h, 1.00 * w, 0.32 * h);
  path.cubicTo(1.00 * w, 0.18 * h, 0.95 * w, 0.06 * h, 0.82 * w, 0.03 * h);
  path.cubicTo(0.68 * w, 0.00 * h, 0.50 * w, 0.01 * h, 0.50 * w, 0.07 * h);
  path.close();
  return path;
}

/// Soft rectangle with long outward curves hugging each side (levels 3–4).
Path _buildWavyRectPath(double width, double height) {
  final w = width;
  final h = height;
  final path = Path();
  // Long bulges sit near each rectangle edge (kept inside the board rect).
  path.moveTo(0.04 * w, 0.07 * h);
  path.cubicTo(0.30 * w, 0.005 * h, 0.70 * w, 0.005 * h, 0.96 * w, 0.07 * h);
  path.cubicTo(0.995 * w, 0.30 * h, 0.995 * w, 0.70 * h, 0.96 * w, 0.93 * h);
  path.cubicTo(0.70 * w, 0.995 * h, 0.30 * w, 0.995 * h, 0.04 * w, 0.93 * h);
  path.cubicTo(0.005 * w, 0.70 * h, 0.005 * w, 0.30 * h, 0.04 * w, 0.07 * h);
  path.close();
  return path;
}

Path _buildOuterPath(_OuterShape shape, double width, double height) {
  switch (shape) {
    case _OuterShape.heart:
      return _buildHeartPath(width, height);
    case _OuterShape.wavyRect:
      return _buildWavyRectPath(width, height);
  }
}

/// Builds a classic jigsaw path for [spec] clipped to the level outer shape.
Path _buildJigsawPiecePath({
  required _PieceSpec spec,
  required double boardW,
  required double boardH,
  required int cols,
  required int rows,
  required _OuterShape outerShape,
}) {
  final cellW = boardW / cols;
  final cellH = boardH / rows;
  final left = spec.col * cellW;
  final top = spec.row * cellH;
  final right = left + cellW;
  final bottom = top + cellH;
  final knob = math.min(cellW, cellH) * kJigsawKnobScale;

  final rectPiece = Path();
  rectPiece.moveTo(left, top);

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

  return Path.combine(
    PathOperation.intersect,
    rectPiece,
    _buildOuterPath(outerShape, boardW, boardH),
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
    required this.cols,
    required this.rows,
    required this.outerShape,
  });

  final _PieceSpec spec;
  final double boardW;
  final double boardH;
  final int cols;
  final int rows;
  final _OuterShape outerShape;

  @override
  Path getClip(Size size) {
    return _buildJigsawPiecePath(
      spec: spec,
      boardW: boardW,
      boardH: boardH,
      cols: cols,
      rows: rows,
      outerShape: outerShape,
    );
  }

  @override
  bool shouldReclip(covariant _JigsawPieceClipper oldClipper) {
    return oldClipper.spec.id != spec.id ||
        oldClipper.boardW != boardW ||
        oldClipper.boardH != boardH ||
        oldClipper.cols != cols ||
        oldClipper.rows != rows ||
        oldClipper.outerShape != outerShape;
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
  const _RopeSpec({required this.anchorXFraction, required this.hangYFraction});

  /// Horizontal hook position as a fraction of screen width (1/6, 2/6, …).
  final double anchorXFraction;

  /// Rest hang depth as a fraction of screen height (higher = hangs lower).
  final double hangYFraction;
}

class _JigsawPuzzleLayerState extends State<JigsawPuzzleLayer>
    with TickerProviderStateMixin {
  static const double _kLogicalW = 1980;
  static const double _kLogicalH = 1080;

  // Board size / layout come from the active [_JigsawLevel].

  static const double _kSnapDistance = 72;
  static const Duration _kDropDelay = Duration(seconds: 1);
  static const Duration _kLevelFadeDuration = Duration(milliseconds: 1600);
  static const Duration _kCannonDuration = Duration(seconds: 4);
  static const int _kSessionLevelCount = 6;

  /// Variable-length pendulum: swings (θ) + bouncy stretch (L).
  static const double _kGravity = 2400.0;
  static const double _kStretch = 140.0;
  static const double _kLenDamp = 3.2;
  static const double _kAngDamp = 0.45;
  static const double _kAttachBias = 48.0;

  /// Fixed hook slots for 4-piece levels.
  static const List<_RopeSpec> _kRopeSlots4 = [
    _RopeSpec(anchorXFraction: 1 / 8, hangYFraction: 0.62),
    _RopeSpec(anchorXFraction: 2 / 8, hangYFraction: 0.40),
    _RopeSpec(anchorXFraction: 6 / 8, hangYFraction: 0.48),
    _RopeSpec(anchorXFraction: 7 / 8, hangYFraction: 0.66),
  ];

  /// Fixed hook slots for 6-piece levels (far left / far right of the board).
  static const List<_RopeSpec> _kRopeSlots6 = [
    _RopeSpec(anchorXFraction: 1 / 18, hangYFraction: 0.58),
    _RopeSpec(anchorXFraction: 2 / 18, hangYFraction: 0.38),
    _RopeSpec(anchorXFraction: 3 / 18, hangYFraction: 0.50),
    _RopeSpec(anchorXFraction: 15 / 18, hangYFraction: 0.46),
    _RopeSpec(anchorXFraction: 16 / 18, hangYFraction: 0.36),
    _RopeSpec(anchorXFraction: 17 / 18, hangYFraction: 0.60),
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
  bool _levelCompleting = false;
  String? _completedImageName;
  List<Color> _completedNameColors = const [];
  bool _sessionReady = false;
  int _levelIndex = 0;
  final List<_JigsawLevel> _sessionLevels = <_JigsawLevel>[];

  AnimationController? _whiteFade;
  int _nextConfettiId = 0;
  final List<_JigsawConfetti> _confettiBursts = <_JigsawConfetti>[];
  int _nextPlaceBurstId = 0;
  final List<_PlaceBurstSpec> _placeBursts = <_PlaceBurstSpec>[];

  final math.Random _rng = math.Random();

  _JigsawLevel get _level => _sessionLevels[_levelIndex];

  double get _boardW => _level.boardW;
  double get _boardH => _level.boardH;
  int get _cols => _level.cols;
  int get _rows => _level.rows;
  _OuterShape get _outerShape => _level.outerShape;
  Offset get _boardOrigin =>
      Offset((_kLogicalW - _boardW) / 2, (_kLogicalH - _boardH) / 2);

  double get _cellW => _boardW / _cols;
  double get _cellH => _boardH / _rows;

  List<_PieceSpec> get _pieces => _cols == 3 ? _kPieces2x3 : _kPieces2x2;

  List<_RopeSpec> get _ropeSlots => _cols == 3 ? _kRopeSlots6 : _kRopeSlots4;

  String get _puzzleImage => _level.imageAsset;

  List<Color> get _bgColors => _level.bgColors;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrapSession());
  }

  Future<bool> _isDecodableImageAsset(String path) async {
    try {
      final data = await rootBundle.load(path);
      if (data.lengthInBytes <= 0) return false;
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      frame.image.dispose();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<String>> _discoverJigsawImages() async {
    final candidates = <String>{..._kFallbackJigsawImages};

    try {
      final manifestJson = await rootBundle.loadString('AssetManifest.json');
      final decoded = jsonDecode(manifestJson);
      if (decoded is Map) {
        for (final key in decoded.keys) {
          if (key is! String) continue;
          final lower = key.toLowerCase();
          if (!lower.startsWith('assets/images/jigsaw/')) continue;
          if (lower.endsWith('.jpg') ||
              lower.endsWith('.jpeg') ||
              lower.endsWith('.png') ||
              lower.endsWith('.webp')) {
            candidates.add(key);
          }
        }
      }
    } catch (_) {
      // Fall back to known filenames below.
    }

    // Keep only assets that actually decode as images.
    final valid = <String>[];
    for (final path in candidates) {
      if (await _isDecodableImageAsset(path)) {
        valid.add(path);
      }
    }

    valid.sort();
    if (valid.isNotEmpty) return valid;

    // Secondary fallback: re-validate known list one-by-one.
    final safeFallback = <String>[];
    for (final path in _kFallbackJigsawImages) {
      if (await _isDecodableImageAsset(path)) {
        safeFallback.add(path);
      }
    }
    if (safeFallback.isNotEmpty) return safeFallback;

    // Last resort: guaranteed menu logo so gameplay still works.
    return const ['assets/images/logoDC.png'];
  }

  List<Color> _randomRadialPalette() {
    const pools = <List<Color>>[
      [
        Color(0xFFFFF8E1),
        Color(0xFFFFD180),
        Color(0xFFFF8F00),
        Color(0xFFE65100),
      ],
      [
        Color(0xFFE8F5E9),
        Color(0xFFA5D6A7),
        Color(0xFF43A047),
        Color(0xFF1B5E20),
      ],
      [
        Color(0xFFE3F2FD),
        Color(0xFF90CAF9),
        Color(0xFF1E88E5),
        Color(0xFF0D47A1),
      ],
      [
        Color(0xFFF3E5F5),
        Color(0xFFCE93D8),
        Color(0xFF8E24AA),
        Color(0xFF4A148C),
      ],
      [
        Color(0xFFFFEBEE),
        Color(0xFFFFAB91),
        Color(0xFFF4511E),
        Color(0xFFBF360C),
      ],
      [
        Color(0xFFE0F7FA),
        Color(0xFF80DEEA),
        Color(0xFF00ACC1),
        Color(0xFF006064),
      ],
      [
        Color(0xFFFFFDE7),
        Color(0xFFFFF176),
        Color(0xFFFBC02D),
        Color(0xFFF57F17),
      ],
      [
        Color(0xFFE8EAF6),
        Color(0xFF9FA8DA),
        Color(0xFF5C6BC0),
        Color(0xFF1A237E),
      ],
    ];
    final palette = pools[_rng.nextInt(pools.length)];
    return List<Color>.from(palette);
  }

  List<String> _pickSessionImages(List<String> all, int count) {
    final copy = List<String>.from(all)..shuffle(_rng);
    if (copy.length >= count) {
      return copy.take(count).toList();
    }
    final out = <String>[];
    while (out.length < count) {
      final block = List<String>.from(copy)..shuffle(_rng);
      for (final img in block) {
        out.add(img);
        if (out.length >= count) break;
      }
    }
    return out;
  }

  Future<void> _bootstrapSession() async {
    final allImages = await _discoverJigsawImages();
    if (!mounted) return;

    final chosen = _pickSessionImages(allImages, _kSessionLevelCount);
    _sessionLevels
      ..clear()
      ..addAll([
        // First two: heart, 4 pieces.
        _JigsawLevel(
          imageAsset: chosen[0],
          bgColors: _randomRadialPalette(),
          cols: 2,
          rows: 2,
          outerShape: _OuterShape.heart,
          boardW: 700,
          boardH: 640,
        ),
        _JigsawLevel(
          imageAsset: chosen[1],
          bgColors: _randomRadialPalette(),
          cols: 2,
          rows: 2,
          outerShape: _OuterShape.heart,
          boardW: 700,
          boardH: 640,
        ),
        // Next two: near-square wavy-rect, 6 pieces.
        _JigsawLevel(
          imageAsset: chosen[2],
          bgColors: _randomRadialPalette(),
          cols: 3,
          rows: 2,
          outerShape: _OuterShape.wavyRect,
          boardW: 920,
          boardH: 820,
        ),
        _JigsawLevel(
          imageAsset: chosen[3],
          bgColors: _randomRadialPalette(),
          cols: 3,
          rows: 2,
          outerShape: _OuterShape.wavyRect,
          boardW: 920,
          boardH: 820,
        ),
        // Last two: bigger heart, 6 pieces.
        _JigsawLevel(
          imageAsset: chosen[4],
          bgColors: _randomRadialPalette(),
          cols: 3,
          rows: 2,
          outerShape: _OuterShape.heart,
          boardW: 980,
          boardH: 860,
        ),
        _JigsawLevel(
          imageAsset: chosen[5],
          bgColors: _randomRadialPalette(),
          cols: 3,
          rows: 2,
          outerShape: _OuterShape.heart,
          boardW: 980,
          boardH: 860,
        ),
      ]);

    _levelIndex = 0;
    _sessionReady = true;
    _resetBoardForNewLevel();
    if (!mounted) return;
    setState(() {});
    _dropTimer?.cancel();
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
    final slots = List<_RopeSpec>.from(_ropeSlots)..shuffle(_rng);
    final pieces = List<_PieceSpec>.from(_pieces)..shuffle(_rng);

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

    for (final spec in _pieces) {
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
        _tilt[id] = _naturalTilt(
          spec,
          math.atan2(attach.dx - anchor.dx, math.max(attach.dy, 1)),
        );
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
      final angAcc =
          -(_kGravity / length) * math.sin(theta) -
          2 * (lenVel / length) * omega -
          _kAngDamp * omega;
      // L'' = L ω² - k (L - rest) + g cosθ - damp L'
      final lenAcc =
          length * omega * omega -
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
      _boardOrigin.dx + spec.col * _cellW,
      _boardOrigin.dy + spec.row * _cellH,
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
    unawaited(AppAudio.instance.stopPairsLevelComplete());
    unawaited(AppAudio.instance.resumeBgm());
    widget.onClose();
  }

  void _onPanStart(int id, DragStartDetails details) {
    if (!_piecesReleased || _levelCompleting || _placed.contains(id)) {
      return;
    }
    unawaited(AppAudio.instance.playGrab());
    setState(() {
      _draggingId = id;
      _onRope[id] = false;
      _velocity[id] = Offset.zero;
    });
  }

  void _onPanUpdate(int id, DragUpdateDetails details) {
    if (_draggingId != id || _levelCompleting) return;
    final fling = details.delta * 62;
    setState(() {
      _piecePos[id] = (_piecePos[id]!) + details.delta;
      _velocity[id] = fling;
    });
  }

  void _onPanEnd(int id) {
    if (_draggingId != id) return;
    final spec = _pieces[id];
    final current = _piecePos[id]!;
    final target = _slotOrigin(spec);
    if ((current - target).distance <= _kSnapDistance) {
      unawaited(AppAudio.instance.playJigsawOnBoard());
      setState(() {
        _draggingId = null;
        _piecePos[id] = target;
        _velocity[id] = Offset.zero;
        _tilt[id] = 0;
        _onRope[id] = false;
        _placed.add(id);
        _placeBursts.add(_PlaceBurstSpec(id: _nextPlaceBurstId++, pieceId: id));
      });
      if (_placed.length >= _pieces.length) {
        unawaited(_onLevelComplete());
      }
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

  void _removeConfetti(int id) {
    if (!mounted) return;
    final before = _confettiBursts.length;
    _confettiBursts.removeWhere((b) => b.id == id);
    if (_confettiBursts.length != before) setState(() {});
  }

  void _removePlaceBurst(int id) {
    if (!mounted) return;
    final before = _placeBursts.length;
    _placeBursts.removeWhere((b) => b.id == id);
    if (_placeBursts.length != before) setState(() {});
  }

  void _spawnFourCannonConfetti() {
    // Four even fans from the middle-bottom of the screen.
    final origin = Offset(_kLogicalW * 0.5, _kLogicalH + 8);
    const fans = <(double, double)>[
      (-math.pi * 0.95, -math.pi * 0.72),
      (-math.pi * 0.72, -math.pi * 0.50),
      (-math.pi * 0.50, -math.pi * 0.28),
      (-math.pi * 0.28, -math.pi * 0.05),
    ];
    _confettiBursts
      ..clear()
      ..addAll([
        for (final fan in fans)
          _JigsawConfetti(
            id: _nextConfettiId++,
            origin: origin,
            angleMin: fan.$1,
            angleMax: fan.$2,
          ),
      ]);
  }

  List<Color> _randomColorizeColors() {
    Color bright() {
      // Keep saturation/value high so the title stays readable and playful.
      final hue = _rng.nextDouble() * 360.0;
      return HSVColor.fromAHSV(
        1,
        hue,
        0.75 + _rng.nextDouble() * 0.25,
        1,
      ).toColor();
    }

    return [for (var i = 0; i < 5; i++) bright()];
  }

  Future<void> _onLevelComplete() async {
    if (!mounted || _levelCompleting || _exitingToMenu) return;
    _levelCompleting = true;
    _completedImageName = _jigsawImageDisplayName(_puzzleImage);
    _completedNameColors = _randomColorizeColors();
    _draggingId = null;
    _dropTimer?.cancel();
    _physicsTicker?.dispose();
    _physicsTicker = null;

    unawaited(AppAudio.instance.pauseBgm());
    unawaited(AppAudio.instance.playPairsLevelComplete());

    _spawnFourCannonConfetti();
    setState(() {});
    await Future<void>.delayed(_kCannonDuration);
    if (!mounted || _exitingToMenu) return;

    _confettiBursts.clear();
    setState(() {});

    _whiteFade?.dispose();
    _whiteFade = AnimationController(
      vsync: this,
      duration: _kLevelFadeDuration,
    );
    setState(() {});
    await _whiteFade!.forward();
    if (!mounted || _exitingToMenu) return;

    unawaited(AppAudio.instance.stopPairsLevelComplete());

    final isLastLevel = _levelIndex >= _sessionLevels.length - 1;
    if (isLastLevel) {
      unawaited(AppAudio.instance.resumeBgm());
      _exitToMenu();
      return;
    }

    _levelIndex++;
    _resetBoardForNewLevel();
    setState(() {});

    await _whiteFade!.reverse();
    if (!mounted || _exitingToMenu) return;

    unawaited(AppAudio.instance.resumeBgm());
    _levelCompleting = false;
    _dropTimer?.cancel();
    _dropTimer = Timer(_kDropDelay, _startDrop);
  }

  void _resetBoardForNewLevel() {
    _placed.clear();
    _draggingId = null;
    _piecesReleased = false;
    _completedImageName = null;
    _completedNameColors = const [];
    _piecePos.clear();
    _velocity.clear();
    _anchors.clear();
    _restLength.clear();
    _theta.clear();
    _omega.clear();
    _length.clear();
    _lenVel.clear();
    _onRope.clear();
    _tilt.clear();
    _ropeByPiece.clear();
    _confettiBursts.clear();
    _placeBursts.clear();
    _layoutRopes();
  }

  @override
  void dispose() {
    _dropTimer?.cancel();
    _physicsTicker?.dispose();
    _whiteFade?.dispose();
    unawaited(AppAudio.instance.stopPairsLevelComplete());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_sessionReady || _sessionLevels.isEmpty) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    final ropeSegments = <(Offset, Offset)>[];
    if (_piecesReleased) {
      for (final spec in _pieces) {
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
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 1.15,
                        colors: _bgColors,
                        stops: const [0.0, 0.32, 0.68, 1.0],
                      ),
                    ),
                  ),
                ),

                // Soft heart board behind the slots.
                Positioned(
                  left: _boardOrigin.dx,
                  top: _boardOrigin.dy,
                  width: _boardW,
                  height: _boardH,
                  child: IgnorePointer(
                    child: CustomPaint(
                      size: Size(_boardW, _boardH),
                      painter: _OuterBoardFillPainter(shape: _outerShape),
                    ),
                  ),
                ),
                ..._pieces.map(_buildEmptySlot),

                // Place-confirm sparks sit under the pieces so they read as
                // border emission from behind the placed tile.
                if (_placeBursts.isNotEmpty)
                  Positioned(
                    left: _boardOrigin.dx,
                    top: _boardOrigin.dy,
                    width: _boardW,
                    height: _boardH,
                    child: IgnorePointer(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          for (final burst in _placeBursts)
                            Positioned.fill(
                              key: ValueKey('place_burst_${burst.id}'),
                              child: _JigsawPlaceBurst(
                                piecePath: _buildJigsawPiecePath(
                                  spec: _pieces[burst.pieceId],
                                  boardW: _boardW,
                                  boardH: _boardH,
                                  cols: _cols,
                                  rows: _rows,
                                  outerShape: _outerShape,
                                ),
                                onComplete: () => _removePlaceBurst(burst.id),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                ..._pieces
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
                  ..._pieces
                      .where((s) => !_placed.contains(s.id))
                      .map(_buildDraggablePiece),

                for (final burst in _confettiBursts)
                  Positioned.fill(
                    key: ValueKey('jigsaw_confetti_${burst.id}'),
                    child: MatchConfettiBurst(
                      origin: burst.origin,
                      particleCount: 120,
                      duration: _kCannonDuration,
                      colors: const [
                        Color(0xFFFFEB3B),
                        Color(0xFFFFF176),
                        Color(0xFFFFD54F),
                        Color(0xFFFFC107),
                        Color(0xFFFFB300),
                        Color(0xFFFFEE58),
                      ],
                      angleMin: burst.angleMin,
                      angleMax: burst.angleMax,
                      speedMin: 280,
                      speedMax: 560,
                      upwardBoost: 120,
                      gravity: 160,
                      useStars: true,
                      starSizeMin: 32,
                      starSizeMax: 68,
                      onComplete: () => _removeConfetti(burst.id),
                    ),
                  ),

                if (_completedImageName != null &&
                    _completedNameColors.length >= 2)
                  Positioned(
                    left: 40,
                    right: 40,
                    top: _kLogicalH * 4 / 6,
                    child: IgnorePointer(
                      child: Center(
                        child: AnimatedTextKit(
                          isRepeatingAnimation: true,
                          repeatForever: true,
                          animatedTexts: [
                            ColorizeAnimatedText(
                              _completedImageName!,
                              textAlign: TextAlign.center,
                              textStyle: const TextStyle(
                                fontFamily: 'Arista',
                                fontSize: 210,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 1.2,
                                height: 1.05,
                                shadows: [
                                  Shadow(
                                    color: Color(0x99000000),
                                    blurRadius: 10,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                              colors: _completedNameColors,
                              speed: const Duration(milliseconds: 1800),
                            ),
                          ],
                        ),
                      ),
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

  Widget _buildEmptySlot(_PieceSpec spec) {
    if (_placed.contains(spec.id)) return const SizedBox.shrink();
    // Pad the layer so thick strokes are not clipped on the outer board edges.
    final pad = kJigsawBoardLineThickness;
    return Positioned(
      left: _boardOrigin.dx - pad,
      top: _boardOrigin.dy - pad,
      width: _boardW + pad * 2,
      height: _boardH + pad * 2,
      child: IgnorePointer(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: pad,
              top: pad,
              width: _boardW,
              height: _boardH,
              child: ClipPath(
                clipper: _JigsawPieceClipper(
                  spec: spec,
                  boardW: _boardW,
                  boardH: _boardH,
                  cols: _cols,
                  rows: _rows,
                  outerShape: _outerShape,
                ),
                child: Stack(
                  children: [
                    ColoredBox(color: Colors.black.withValues(alpha: 0.10)),
                    Opacity(
                      opacity: kJigsawSlotGhostOpacity,
                      child: ColorFiltered(
                        colorFilter: const ColorFilter.matrix([
                          0.2126,
                          0.7152,
                          0.0722,
                          0,
                          0,
                          0.2126,
                          0.7152,
                          0.0722,
                          0,
                          0,
                          0.2126,
                          0.7152,
                          0.0722,
                          0,
                          0,
                          0,
                          0,
                          0,
                          1,
                          0,
                        ]),
                        child: Image.asset(
                          _puzzleImage,
                          width: _boardW,
                          height: _boardH,
                          fit: BoxFit.fill,
                        ),
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
              width: _boardW,
              height: _boardH,
              child: CustomPaint(
                size: Size(_boardW, _boardH),
                painter: _JigsawOutlinePainter(
                  spec: spec,
                  boardW: _boardW,
                  boardH: _boardH,
                  cols: _cols,
                  rows: _rows,
                  outerShape: _outerShape,
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
      left: _boardOrigin.dx,
      top: _boardOrigin.dy,
      width: _boardW,
      height: _boardH,
      child: IgnorePointer(
        child: ClipPath(
          clipper: _JigsawPieceClipper(
            spec: spec,
            boardW: _boardW,
            boardH: _boardH,
            cols: _cols,
            rows: _rows,
            outerShape: _outerShape,
          ),
          child: Image.asset(
            _puzzleImage,
            width: _boardW,
            height: _boardH,
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
    final alignX = (attachInWidget.dx / _boardW) * 2 - 1;
    final alignY = (attachInWidget.dy / _boardH) * 2 - 1;

    return Positioned(
      left: imageOrigin.dx,
      top: imageOrigin.dy,
      width: _boardW,
      height: _boardH,
      child: Transform.rotate(
        angle: tilt,
        alignment: Alignment(alignX, alignY),
        child: ClipPath(
          clipper: _JigsawPieceClipper(
            spec: spec,
            boardW: _boardW,
            boardH: _boardH,
            cols: _cols,
            rows: _rows,
            outerShape: _outerShape,
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
                _puzzleImage,
                width: _boardW,
                height: _boardH,
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

class _PlaceBurstSpec {
  const _PlaceBurstSpec({required this.id, required this.pieceId});

  final int id;
  final int pieceId;
}

/// White sparks that spawn on the piece outline and fly outward, then fade.
class _JigsawPlaceBurst extends StatefulWidget {
  const _JigsawPlaceBurst({required this.piecePath, this.onComplete});

  final Path piecePath;
  final VoidCallback? onComplete;

  static const Duration kDuration = Duration(milliseconds: 900);

  @override
  State<_JigsawPlaceBurst> createState() => _JigsawPlaceBurstState();
}

class _JigsawPlaceBurstState extends State<_JigsawPlaceBurst>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final List<_PlaceSpark> _sparks;
  double _elapsed = 0;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    final rng = math.Random();
    final border = <Offset>[];
    for (final metric in widget.piecePath.computeMetrics()) {
      final count = (metric.length / 10).ceil().clamp(10, 48);
      for (var i = 0; i < count; i++) {
        final t = metric.getTangentForOffset(metric.length * i / count);
        if (t != null) border.add(t.position);
      }
    }

    Offset center = Offset.zero;
    if (border.isNotEmpty) {
      for (final p in border) {
        center += p;
      }
      center = center / border.length.toDouble();
    }

    // Emit from border points (with a few extras per sample for denser rim).
    _sparks = <_PlaceSpark>[];
    for (final p in border) {
      final extras = 1 + rng.nextInt(2);
      for (var e = 0; e < extras; e++) {
        var dir = p - center;
        final len = dir.distance;
        if (len < 1) {
          final a = rng.nextDouble() * math.pi * 2;
          dir = Offset(math.cos(a), math.sin(a));
        } else {
          dir /= len;
          final tang = Offset(-dir.dy, dir.dx);
          final jittered = dir + tang * ((rng.nextDouble() - 0.5) * 0.35);
          final jLen = jittered.distance;
          if (jLen > 0.01) dir = jittered / jLen;
        }
        final speed = 90.0 + rng.nextDouble() * 160.0;
        _sparks.add(
          _PlaceSpark(
            origin: p + dir * (rng.nextDouble() * 4),
            velocity: dir * speed,
            radius: 2.2 + rng.nextDouble() * 3.4,
            life: 0.55 + rng.nextDouble() * 0.4,
          ),
        );
      }
    }

    _ticker = createTicker((elapsed) {
      if (!mounted || _done) return;
      setState(() {
        _elapsed = elapsed.inMicroseconds / 1e6;
      });
      if (elapsed >= _JigsawPlaceBurst.kDuration) {
        _done = true;
        _ticker.stop();
        widget.onComplete?.call();
      }
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PlaceBurstPainter(sparks: _sparks, elapsed: _elapsed),
    );
  }
}

class _PlaceSpark {
  _PlaceSpark({
    required this.origin,
    required this.velocity,
    required this.radius,
    required this.life,
  });

  final Offset origin;
  final Offset velocity;
  final double radius;
  final double life;
}

class _PlaceBurstPainter extends CustomPainter {
  _PlaceBurstPainter({required this.sparks, required this.elapsed});

  final List<_PlaceSpark> sparks;
  final double elapsed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final s in sparks) {
      final t = (elapsed / s.life).clamp(0.0, 1.0);
      if (t >= 1) continue;
      final pos = s.origin + s.velocity * elapsed;
      final fade = (1 - t);
      final r = s.radius * (0.85 + 0.35 * (1 - t));
      paint.color = Color.fromRGBO(255, 255, 255, fade * fade);
      canvas.drawCircle(pos, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PlaceBurstPainter oldDelegate) =>
      oldDelegate.elapsed != elapsed;
}

class _JigsawConfetti {
  const _JigsawConfetti({
    required this.id,
    required this.origin,
    required this.angleMin,
    required this.angleMax,
  });

  final int id;
  final Offset origin;
  final double angleMin;
  final double angleMax;
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
      canvas.drawCircle(anchor, 14, Paint()..color = const Color(0xFF4E3422));
      canvas.drawCircle(anchor, 8, Paint()..color = const Color(0xFF8D6E4C));
    }
  }

  @override
  bool shouldRepaint(covariant _RopePainter oldDelegate) => true;
}

class _OuterBoardFillPainter extends CustomPainter {
  _OuterBoardFillPainter({required this.shape});

  final _OuterShape shape;

  @override
  void paint(Canvas canvas, Size size) {
    final outline = _buildOuterPath(shape, size.width, size.height);
    canvas.drawPath(
      outline,
      Paint()..color = Colors.black.withValues(alpha: 0.12),
    );
    canvas.drawPath(
      outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = kJigsawBoardLineThickness
        ..color = Colors.white.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(covariant _OuterBoardFillPainter oldDelegate) =>
      oldDelegate.shape != shape;
}

class _JigsawOutlinePainter extends CustomPainter {
  _JigsawOutlinePainter({
    required this.spec,
    required this.boardW,
    required this.boardH,
    required this.cols,
    required this.rows,
    required this.outerShape,
  });

  final _PieceSpec spec;
  final double boardW;
  final double boardH;
  final int cols;
  final int rows;
  final _OuterShape outerShape;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildJigsawPiecePath(
      spec: spec,
      boardW: boardW,
      boardH: boardH,
      cols: cols,
      rows: rows,
      outerShape: outerShape,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = kJigsawBoardLineThickness
      ..color = Colors.white.withValues(alpha: 0.9);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _JigsawOutlinePainter oldDelegate) =>
      oldDelegate.spec.id != spec.id ||
      oldDelegate.cols != cols ||
      oldDelegate.rows != rows ||
      oldDelegate.outerShape != outerShape;
}
