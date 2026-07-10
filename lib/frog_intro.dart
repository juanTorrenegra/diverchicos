import 'package:flutter/material.dart';

import 'widgets/frog_loader.dart';

/// Full-screen frog splash shown before the main menu.
///
/// Plays the frog jump twice, then hands off to the main menu via [onFinished].
class FrogIntroOverlay extends StatelessWidget {
  const FrogIntroOverlay({
    super.key,
    required this.onIntroVoiceStart,
    required this.onFinished,
  });

  final VoidCallback onIntroVoiceStart;
  final VoidCallback onFinished;

  @override
  Widget build(BuildContext context) {
    return FrogLoader(
      jumpCount: 2,
      pauseBetweenJumps: const Duration(seconds: 1),
      onFirstJump: onIntroVoiceStart,
      onAllJumpsComplete: onFinished,
      showProgress: false,
    );
  }
}
