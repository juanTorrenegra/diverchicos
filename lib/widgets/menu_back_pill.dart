import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Top-right styled **MENÚ** pill: native uses screen/12; web uses screen/24 (smaller in browser).
/// Label scales from pill size so it does not clip..
class MenuBackPill extends StatelessWidget {
  const MenuBackPill({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.sizeOf(context);
    final divisor = kIsWeb ? 24.0 : 12.0;
    final pillW = mq.width / divisor;
    final pillH = mq.height / divisor;
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
