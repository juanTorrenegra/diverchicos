import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

/// Repeating voice-over while a cutscene waits for input.
///
/// Call [start] when the clip finishes (e.g. intro video on last frame).
/// Call [stop] when the player acts or the scene tears down.
class CutsceneInstructionLoop {
  CutsceneInstructionLoop({this.interval = const Duration(seconds: 3)});

  final Duration interval;

  AudioPlayer? _player;
  StreamSubscription<void>? _completeSub;
  String? _asset;
  bool _running = false;

  bool get isRunning => _running;

  /// Plays [asset] to completion, waits [interval], then repeats until [stop].
  ///
  /// [asset] is relative to `assets/` (e.g. `audio/salud/foo.mp3`).
  Future<void> start(String asset) async {
    if (_running && _asset == asset) return;
    await stop();

    _asset = asset;
    _running = true;

    final player = AudioPlayer();
    _player = player;

    _completeSub = player.onPlayerComplete.listen((_) {
      unawaited(_scheduleReplay());
    });

    await _playFromStart();
  }

  Future<void> _playFromStart() async {
    if (!_running) return;
    final player = _player;
    final asset = _asset;
    if (player == null || asset == null) return;

    try {
      await player.setReleaseMode(ReleaseMode.stop);
      if (player.source == null) {
        await player.setSource(AssetSource(asset));
        await player.resume();
      } else {
        await player.seek(Duration.zero);
        await player.resume();
      }
    } catch (_) {
      try {
        await player.play(AssetSource(asset));
      } catch (_) {}
    }
  }

  Future<void> _scheduleReplay() async {
    if (!_running) return;
    await Future<void>.delayed(interval);
    if (!_running) return;
    await _playFromStart();
  }

  Future<void> stop() async {
    if (!_running && _player == null) return;

    _running = false;
    _asset = null;

    await _completeSub?.cancel();
    _completeSub = null;

    final player = _player;
    _player = null;
    if (player != null) {
      try {
        await player.stop();
        await player.dispose();
      } catch (_) {}
    }
  }
}
