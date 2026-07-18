import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Lightweight particle confetti / star burst for match celebrations.
///
/// Draws shapes with a ticker — no image assets.
class MatchConfettiBurst extends StatefulWidget {
  const MatchConfettiBurst({
    super.key,
    required this.origin,
    this.particleCount = 96,
    this.duration = kMatchBurstDuration,
    this.colors,
    this.angleMin,
    this.angleMax,
    this.speedMin = 220,
    this.speedMax = 540,
    this.upwardBoost = 140,
    this.gravity = 520,
    this.useStars = false,
    this.starSizeMin = 14,
    this.starSizeMax = 28,
    this.onComplete,
  });

  /// Bottom cannon: yellow stars shooting upward.
  const MatchConfettiBurst.cannonBottom({
    super.key,
    required this.origin,
    this.particleCount = 135,
    this.duration = const Duration(seconds: 9),
    this.speedMin = 280,
    this.speedMax = 560,
    this.upwardBoost = 120,
    this.gravity = 160,
    this.onComplete,
  })  : colors = _kYellowPalette,
        angleMin = -math.pi * 0.88,
        angleMax = -math.pi * 0.12,
        useStars = true,
        starSizeMin = 36,
        starSizeMax = 72;

  /// Mid-screen cannon: yellow stars shooting upward (same cone as bottom).
  const MatchConfettiBurst.cannonTop({
    super.key,
    required this.origin,
    this.particleCount = 135,
    this.duration = const Duration(seconds: 9),
    this.speedMin = 280,
    this.speedMax = 560,
    this.upwardBoost = 120,
    this.gravity = 160,
    this.onComplete,
  })  : colors = _kYellowPalette,
        angleMin = -math.pi * 0.88,
        angleMax = -math.pi * 0.12,
        useStars = true,
        starSizeMin = 36,
        starSizeMax = 72;

  /// Duration of the normal pair-match confetti burst.
  static const Duration kMatchBurstDuration = Duration(milliseconds: 2200);

  static const List<Color> _kYellowPalette = [
    Color(0xFFFFEB3B),
    Color(0xFFFFF176),
    Color(0xFFFFD54F),
    Color(0xFFFFC107),
    Color(0xFFFFB300),
    Color(0xFFFFEE58),
  ];

  static const List<Color> _kDefaultPalette = [
    Color(0xFFFFEB3B),
    Color(0xFFFF5722),
    Color(0xFF4CAF50),
    Color(0xFF2196F3),
    Color(0xFFE91E63),
    Color(0xFF9C27B0),
    Color(0xFF00BCD4),
    Color(0xFFFF9800),
  ];

  final Offset origin;
  final int particleCount;
  final Duration duration;
  final List<Color>? colors;
  final double? angleMin;
  final double? angleMax;
  final double speedMin;
  final double speedMax;
  final double upwardBoost;
  final double gravity;
  final bool useStars;
  final double starSizeMin;
  final double starSizeMax;
  final VoidCallback? onComplete;

  @override
  State<MatchConfettiBurst> createState() => _MatchConfettiBurstState();
}

class _MatchConfettiBurstState extends State<MatchConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final List<_ConfettiParticle> _particles;
  double _elapsedSeconds = 0;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    final rng = math.Random();
    final palette = widget.colors ?? MatchConfettiBurst._kDefaultPalette;
    final hasCone = widget.angleMin != null && widget.angleMax != null;
    final a0 = widget.angleMin ?? 0;
    final a1 = widget.angleMax ?? (math.pi * 2);

    _particles = List<_ConfettiParticle>.generate(widget.particleCount, (_) {
      final angle = hasCone
          ? a0 + rng.nextDouble() * (a1 - a0)
          : rng.nextDouble() * math.pi * 2;
      final speed =
          widget.speedMin + rng.nextDouble() * (widget.speedMax - widget.speedMin);
      final starSize = widget.starSizeMin +
          rng.nextDouble() * (widget.starSizeMax - widget.starSizeMin);
      return _ConfettiParticle(
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed - widget.upwardBoost,
        color: palette[rng.nextInt(palette.length)],
        width: widget.useStars ? starSize : 6 + rng.nextDouble() * 8,
        height: widget.useStars ? starSize : 10 + rng.nextDouble() * 12,
        spin: (rng.nextDouble() - 0.5) * (widget.useStars ? 4 : 7),
        rotation: rng.nextDouble() * math.pi,
      );
    });
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    if (_finished) return;
    final t = elapsed.inMicroseconds / 1e6;
    final life = widget.duration.inMicroseconds / 1e6;
    if (t >= life) {
      _finished = true;
      _ticker.stop();
      widget.onComplete?.call();
      return;
    }
    setState(() => _elapsedSeconds = t);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _ConfettiPainter(
          origin: widget.origin,
          particles: _particles,
          elapsed: _elapsedSeconds,
          life: widget.duration.inMicroseconds / 1e6,
          gravity: widget.gravity,
          useStars: widget.useStars,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _ConfettiParticle {
  _ConfettiParticle({
    required this.vx,
    required this.vy,
    required this.color,
    required this.width,
    required this.height,
    required this.spin,
    required this.rotation,
  });

  final double vx;
  final double vy;
  final Color color;
  final double width;
  final double height;
  final double spin;
  double rotation;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({
    required this.origin,
    required this.particles,
    required this.elapsed,
    required this.life,
    required this.gravity,
    required this.useStars,
  });

  final Offset origin;
  final List<_ConfettiParticle> particles;
  final double elapsed;
  final double life;
  final double gravity;
  final bool useStars;

  @override
  void paint(Canvas canvas, Size size) {
    final fade = (1.0 - (elapsed / life)).clamp(0.0, 1.0);
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      final x = origin.dx + p.vx * elapsed;
      final y = origin.dy + p.vy * elapsed + 0.5 * gravity * elapsed * elapsed;
      final rot = p.rotation + p.spin * elapsed;

      paint.color = p.color.withValues(alpha: fade);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rot);
      if (useStars) {
        canvas.drawPath(_starPath(p.width / 2), paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: p.width,
              height: p.height,
            ),
            const Radius.circular(2),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  Path _starPath(double radius) {
    const points = 5;
    final path = Path();
    final inner = radius * 0.42;
    for (var i = 0; i < points * 2; i++) {
      final r = i.isEven ? radius : inner;
      final a = -math.pi / 2 + i * math.pi / points;
      final x = math.cos(a) * r;
      final y = math.sin(a) * r;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.elapsed != elapsed;
}
