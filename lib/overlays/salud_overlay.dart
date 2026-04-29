import 'package:flutter/material.dart';

/// SALUD mini-screen: stretched background (`paredVerde.png`) and MENÚ back pill.
class SaludOverlay extends StatelessWidget {
  const SaludOverlay({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
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
          child: SizedBox(
            width: size.width / 10,
            height: size.height / 10,
            child: FilledButton(
              style: FilledButton.styleFrom(
                shape: const StadiumBorder(),
                backgroundColor: const Color(0xCC1A237E),
                foregroundColor: Colors.white,
              ),
              onPressed: onBack,
              child: const Text('MENÚ'),
            ),
          ),
        ),
      ],
    );
  }
}
