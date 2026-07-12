import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// On web phone browsers in portrait, rotates [child] 90° so landscape
/// 1980×1080 content fills the tall viewport.
///
/// Enable only after the frog intro — native Android already locks landscape
/// via [SystemChrome]; browsers cannot, so this is the web-only workaround.
class WebLandscapeShell extends StatelessWidget {
  const WebLandscapeShell({
    super.key,
    required this.enabled,
    required this.child,
  });

  /// When false (e.g. during frog intro), [child] is shown without rotation.
  final bool enabled;
  final Widget child;

  /// Tall portrait viewport typical of phones (not short tablets / desktops).
  static bool shouldForceLandscape(Size size) {
    if (!kIsWeb) return false;
    if (size.width <= 0 || size.height <= 0) return false;
    return size.height > size.width * 1.2;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    if (!enabled || !shouldForceLandscape(size)) {
      return child;
    }

    // After a 90° CW rotation, screen height becomes the landscape width.
    final landscapeSize = Size(size.height, size.width);
    final media = MediaQuery.of(context);

    return ColoredBox(
      color: const Color.fromRGBO(28, 49, 132, 1),
      child: Align(
        alignment: Alignment.center,
        child: RotatedBox(
          quarterTurns: 1,
          child: SizedBox(
            width: landscapeSize.width,
            height: landscapeSize.height,
            child: MediaQuery(
              data: media.copyWith(size: landscapeSize),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
