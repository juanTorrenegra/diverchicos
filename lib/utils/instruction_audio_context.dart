import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Platform audio context for instruction voice-overs that should play over BGM.
///
/// Web uses separate HTML audio elements and already mixes correctly, so no
/// context is applied there.
abstract final class InstructionAudioContext {
  static AudioContext? get mixing => kIsWeb
      ? null
      : AudioContext(
          android: const AudioContextAndroid(
            audioFocus: AndroidAudioFocus.none,
          ),
          iOS: AudioContextIOS(
            options: const {AVAudioSessionOptions.mixWithOthers},
          ),
        );

  static Future<void> applyTo(AudioPlayer player) async {
    final ctx = mixing;
    if (ctx != null) {
      await player.setAudioContext(ctx);
    }
  }
}
