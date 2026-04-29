import 'package:flutter/material.dart';

import '../widgets/menu_back_pill.dart';

/// SALUD mini-screen: stretched background (`paredVerde.png`) and MENÚ back pill.
class SaludOverlay extends StatelessWidget {
  const SaludOverlay({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/images/paredVerde.png',
            fit: BoxFit.fill,
          ),
        ),
        Positioned(
          top: 20,
          right: 16,
          child: MenuBackPill(onPressed: onBack),
        ),
      ],
    );
  }
}
