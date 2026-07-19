import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Centralized debug logging + user-visible error feedback for flaky devices.
abstract final class GameDebug {
  static const String tag = 'DIVERCHICOS';

  static void log(String area, String message, [Object? error, StackTrace? st]) {
    final buf = StringBuffer('[$tag][$area] $message');
    if (error != null) buf.write(' | error=$error');
    // ignore: avoid_print — intentional for ADB `adb logcat` on tester devices
    print(buf.toString());
    if (st != null) {
      // ignore: avoid_print
      print('[$tag][$area] stack:\n$st');
    }
  }

  static void snack(
    BuildContext? context,
    String message, {
    Color backgroundColor = const Color(0xCCB71C1C),
  }) {
    if (context == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      log('snack', 'no ScaffoldMessenger: $message');
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  static void logAndSnack(
    BuildContext? context,
    String area,
    String message, [
    Object? error,
    StackTrace? st,
  ]) {
    log(area, message, error, st);
    snack(context, message);
  }
}

/// Soft green fallback when a looping game video cannot decode on the device.
const Color kGameVideoFallbackGreen = Color(0xFF2E7D32);

/// Soft sky fallback for path games when intro/level video fails.
const Color kGameVideoFallbackSky = Color(0xFF81D4FA);
