import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../actors/cow.dart';

/// Door-style vertical strip for debugging clip (`SaludCowTuning.cowClipLineX`).
final class SaludClipDebugLineComponent extends PositionComponent {
  SaludClipDebugLineComponent({required this.tuning, required this.isEnabled})
    : super(anchor: Anchor.topLeft);

  final SaludCowTuning tuning;
  final bool isEnabled;
  final Paint _paint = Paint();

  void syncLayout(Vector2 logicalSize) {
    final w = tuning.clipDebugLineWidthPx.clamp(1, 12).toDouble();
    size.setValues(w, logicalSize.y);
    position.setValues(tuning.cowClipLineX - (w / 2), 0);
    _paint.color = tuning.clipDebugLineColor;
  }

  @override
  void render(Canvas canvas) {
    if (!isEnabled) return;
    canvas.drawRect(size.toRect(), _paint);
  }
}
