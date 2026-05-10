import 'dart:async';

import 'package:flutter/material.dart';

import 'salud_constants.dart';

/// Immutable layout + interaction flags for one bath prop or the hero.
///
/// [startingAnimationPosition] / [endAnimationPosition] are used for scene 2 enter /
/// scene‑exit motion toward the nearest edge.
class SceneObjectConfig {
  const SceneObjectConfig({
    required this.id,
    required this.assetFileName,
    required this.mainPosition,
    required this.startingAnimationPosition,
    required this.endAnimationPosition,
    this.draggable = false,
    this.tappable = false,
    this.scaleIdle = false,
    this.isHero = false,
  });

  final String id;
  final String assetFileName;

  /// Gameplay anchor (top‑left of the widget in logical 1920×1080 space).
  final Offset mainPosition;

  /// Scene 2 — bounce in from here toward [mainPosition].
  final Offset startingAnimationPosition;

  /// Scene exit — animate toward here (typically off‑screen).
  final Offset endAnimationPosition;

  final bool draggable;
  final bool tappable;

  /// After 4 s without drag, pulse scale (loop). Enable per prop via [SceneObjectConfig.scaleIdle].
  final bool scaleIdle;

  /// Reserved for hero-only widgets (cow/cat); PNG props use `false`.
  final bool isHero;

  String get assetPath => 'assets/images/bathGame/$assetFileName';
}

/// Static PNG prop: intrinsic size, optional drag + bounce‑back, optional tap.
class SceneObject extends StatefulWidget {
  const SceneObject({
    super.key,
    required this.config,
    this.exitT = 0,
    this.enterT = 1,
    this.onTap,
  });

  final SceneObjectConfig config;
  final double exitT;

  /// Scene 2 entrance progress 0→1 (`startingAnimationPosition` → `mainPosition`).
  final double enterT;

  final VoidCallback? onTap;

  @override
  State<SceneObject> createState() => _SceneObjectState();
}

class _SceneObjectState extends State<SceneObject>
    with TickerProviderStateMixin {
  Offset _dragDelta = Offset.zero;
  bool _dragging = false;

  Timer? _idleTimer;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  AnimationController? _returnCtrl;
  Animation<Offset>? _returnAnim;

  /// Effective anchor for props (not hero): lerp for scene transitions.
  Offset get _baseAnchor {
    final c = widget.config;
    final exitPos = Offset.lerp(c.mainPosition, c.endAnimationPosition, widget.exitT)!;
    return Offset.lerp(c.startingAnimationPosition, exitPos, widget.enterT)!;
  }

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseAnim = Tween<double>(begin: 1, end: 1.5).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _pulseCtrl.addListener(() => setState(() {}));
    if (widget.config.scaleIdle) {
      _scheduleIdleTimer();
    }
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _pulseCtrl.dispose();
    _returnCtrl?.dispose();
    super.dispose();
  }

  void _scheduleIdleTimer() {
    if (!widget.config.scaleIdle) return;
    _idleTimer?.cancel();
    _idleTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted || _dragging || widget.exitT > 0 || widget.enterT < 1) {
        return;
      }
      scaleIdle();
    });
  }

  /// Pulse scale 1 → 1.5 → 1 once; loops via [_scheduleIdleTimer] while idle.
  void scaleIdle() {
    if (!widget.config.scaleIdle || _dragging || widget.exitT > 0) return;
    _pulseCtrl.forward(from: 0).whenComplete(() {
      if (!mounted || _dragging) return;
      _pulseCtrl.reverse(from: 1).whenComplete(() {
        if (!mounted || _dragging) return;
        _scheduleIdleTimer();
      });
    });
  }

  void _stopReturn() {
    _returnCtrl?.dispose();
    _returnCtrl = null;
    _returnAnim = null;
  }

  void _animateReturnToOrigin() {
    _stopReturn();
    final begin = _dragDelta;
    if (begin == Offset.zero) return;

    _returnCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _returnAnim = Tween<Offset>(
      begin: begin,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _returnCtrl!, curve: Curves.elasticOut))
      ..addListener(() {
        setState(() => _dragDelta = _returnAnim!.value);
      });
    _returnCtrl!.forward().whenComplete(() {
      if (mounted) {
        setState(() => _dragDelta = Offset.zero);
      }
      _stopReturn();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.config;
    final pos = _baseAnchor + _dragDelta;
    final canDrag = c.draggable && widget.exitT == 0 && widget.enterT >= 1;
    final idleScale = c.scaleIdle ? _pulseAnim.value : 1.0;
    final scale = (_dragging && canDrag) ? 1.2 : idleScale;

    Widget img = Image.asset(
      c.assetPath,
      fit: BoxFit.none,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stackTrace) {
        return ColoredBox(
          color: Colors.red.withValues(alpha: 0.25),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Text(
              c.assetFileName,
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
        );
      },
    );

    img = Transform.scale(scale: scale, alignment: Alignment.center, child: img);

    if (c.tappable && widget.onTap != null && widget.exitT == 0) {
      img = GestureDetector(onTap: widget.onTap, behavior: HitTestBehavior.opaque, child: img);
    }

    if (canDrag) {
      img = GestureDetector(
        onPanStart: (_) {
          _idleTimer?.cancel();
          _pulseCtrl.stop();
          _pulseCtrl.reset();
          _stopReturn();
          setState(() {
            _dragging = true;
          });
        },
        onPanUpdate: (details) {
          setState(() => _dragDelta += details.delta);
        },
        onPanEnd: (_) {
          setState(() => _dragging = false);
          _animateReturnToOrigin();
          _scheduleIdleTimer();
        },
        onPanCancel: () {
          setState(() => _dragging = false);
          _animateReturnToOrigin();
          _scheduleIdleTimer();
        },
        child: img,
      );
    }

    return Positioned(left: pos.dx, top: pos.dy, child: img);
  }
}

/// Cow / cat hero: drag scales +20%; release bounces back. Idle pulse lives on [SceneObjectConfig.scaleIdle].
class BathHeroObject extends StatefulWidget {
  const BathHeroObject({
    super.key,
    required this.assetPath,
    required this.baseSize,
    required this.mainPosition,
    required this.startingAnimationPosition,
    required this.endAnimationPosition,
    this.exitT = 0,
    this.enterT = 1,
  });

  final String assetPath;
  final double baseSize;
  final Offset mainPosition;
  final Offset startingAnimationPosition;
  final Offset endAnimationPosition;
  final double exitT;
  final double enterT;

  @override
  State<BathHeroObject> createState() => _BathHeroObjectState();
}

class _BathHeroObjectState extends State<BathHeroObject>
    with SingleTickerProviderStateMixin {
  Offset _dragDelta = Offset.zero;
  bool _dragging = false;

  AnimationController? _returnCtrl;
  Animation<Offset>? _returnAnim;

  Offset get _anchor {
    final exitPos = Offset.lerp(
      widget.mainPosition,
      widget.endAnimationPosition,
      widget.exitT,
    )!;
    return Offset.lerp(
      widget.startingAnimationPosition,
      exitPos,
      widget.enterT,
    )!;
  }

  @override
  void dispose() {
    _returnCtrl?.dispose();
    super.dispose();
  }

  void _stopReturn() {
    _returnCtrl?.dispose();
    _returnCtrl = null;
    _returnAnim = null;
  }

  void _bounceBack() {
    _stopReturn();
    final begin = _dragDelta;
    if (begin == Offset.zero) return;
    _returnCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _returnAnim = Tween<Offset>(
      begin: begin,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _returnCtrl!, curve: Curves.elasticOut))
      ..addListener(() => setState(() => _dragDelta = _returnAnim!.value));
    _returnCtrl!.forward().whenComplete(() {
      if (mounted) setState(() => _dragDelta = Offset.zero);
      _stopReturn();
    });
  }

  @override
  Widget build(BuildContext context) {
    final pos = _anchor + _dragDelta;
    final scale = _dragging ? 1.2 : 1.0;

    Widget content = SizedBox(
      width: widget.baseSize,
      height: widget.baseSize,
      child: Image.asset(
        widget.assetPath,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return const Icon(Icons.pets, size: 120, color: Colors.white);
        },
      ),
    );

    content = Transform.scale(scale: scale, alignment: Alignment.center, child: content);

    final canDrag = widget.exitT == 0 && widget.enterT >= 1;

    if (canDrag) {
      content = GestureDetector(
        onPanStart: (_) {
          _stopReturn();
          setState(() => _dragging = true);
        },
        onPanUpdate: (d) => setState(() => _dragDelta += d.delta),
        onPanEnd: (_) {
          setState(() => _dragging = false);
          _bounceBack();
        },
        onPanCancel: () {
          setState(() => _dragging = false);
          _bounceBack();
        },
        child: content,
      );
    }

    return Positioned(left: pos.dx, top: pos.dy, width: widget.baseSize, height: widget.baseSize, child: content);
  }
}

/// Default off‑screen exit toward nearest horizontal edge (cheap heuristic).
Offset bathDefaultEndPosition(Offset main, {double margin = 600}) {
  final cx = main.dx;
  if (cx < kSaludCowLogicalWidth / 2) {
    return Offset(-margin, main.dy);
  }
  return Offset(kSaludCowLogicalWidth + margin - 1, main.dy);
}

/// Scene 2 fake “from below” start for bounce‑in.
Offset bathDefaultStartBelow(Offset main) {
  return Offset(main.dx, kSaludCowLogicalHeight + 400);
}
