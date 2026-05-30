import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

/// Top-right styled **MENÚ** pill: native uses screen/12; web uses screen/24 (smaller in browser).
/// Label scales from pill size so it does not clip.
class MenuBackPill extends StatelessWidget {
  const MenuBackPill({
    super.key,
    required this.onPressed,
    this.layoutSize,
  });

  final VoidCallback onPressed;

  /// When set, pill size is derived from this frame instead of [MediaQuery].
  final Size? layoutSize;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.sizeOf(context);
    final frame = layoutSize ?? mq;
    final divisor = kIsWeb ? 24.0 : 12.0;
    final pillW = frame.width / divisor;
    final pillH = frame.height / divisor;
    final fontMin = kIsWeb ? 8.0 : 10.0;
    final fontSize = (math.min(pillW, pillH) * 0.42).clamp(fontMin, 32.0);

    return SizedBox(
      width: pillW,
      height: pillH,
      child: FilledButton(
        style: FilledButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: const StadiumBorder(),
          backgroundColor: const Color(0xCC1A237E),
          foregroundColor: Colors.white,
        ),
        onPressed: onPressed,
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                'MENÚ',
                maxLines: 1,
                overflow: TextOverflow.visible,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Back pill anchored to the top-right of the fixed **1980×1080** game frame.
class GameLogicalBackPill extends StatelessWidget {
  const GameLogicalBackPill({
    super.key,
    required this.onPressed,
    this.top = 20,
    this.right = 16,
  });

  static const Size kLogicalSize = Size(1980, 1080);

  final VoidCallback onPressed;
  final double top;
  final double right;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      right: right,
      child: PointerInterceptor(
        child: MenuBackPill(
          onPressed: onPressed,
          layoutSize: kLogicalSize,
        ),
      ),
    );
  }
}
