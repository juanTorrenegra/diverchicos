import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import '../app_audio.dart';

/// Repeating voice-over while a cutscene waits for input.
///
/// Uses one shared instance app-wide so parent/child salud layers do not
/// fight over playback ownership when phase 2 starts.
class CutsceneInstructionLoop {
  factory CutsceneInstructionLoop() => shared;

  CutsceneInstructionLoop._({this.interval = const Duration(seconds: 3)});

  static final CutsceneInstructionLoop shared =
      CutsceneInstructionLoop._();

  final Duration interval;

  static final Map<String, AudioPlayer> _assetPlayers =
      <String, AudioPlayer>{};

  AudioPlayer? _player;
  StreamSubscription<void>? _completeSub;
  String? _asset;
  bool _running = false;
  bool _paused = false;

  bool get isRunning => _running;
  bool get isPaused => _paused;

  /// Plays [asset] to completion, waits [interval], then repeats until [stop].
  ///
  /// [asset] is relative to `assets/` (e.g. `audio/salud/foo.mp3`).
  Future<void> start(String asset) async {
    if (_running && !_paused && _asset == asset) return;

    final previousAsset = _asset;
    await _haltCurrentPlayback(clearAsset: true);

    if (previousAsset != null && previousAsset != asset) {
      final previousPlayer = _assetPlayers[previousAsset];
      if (previousPlayer != null) {
        try {
          await previousPlayer.stop();
        } catch (_) {}
      }
    }

    _asset = asset;
    _running = true;
    _paused = false;

    _player = await _ensurePlayerForAsset(asset);
    _listenForComplete();

    await _playFromStart();
  }

  static Future<AudioPlayer> _ensurePlayerForAsset(String asset) async {
    final existing = _assetPlayers[asset];
    if (existing != null) return existing;

    final player = AudioPlayer();
    await player.setReleaseMode(ReleaseMode.stop);
    await player.setSource(AssetSource(asset));
    _assetPlayers[asset] = player;
    return player;
  }

  void _listenForComplete() {
    final player = _player;
    if (player == null) return;
    _completeSub?.cancel();
    _completeSub = player.onPlayerComplete.listen((_) {
      unawaited(_scheduleReplay());
    });
  }

  Future<void> _playFromStart() async {
    if (!_running || _paused) return;
    final player = _player;
    final asset = _asset;
    if (player == null || asset == null) return;

    await AppAudio.instance.duckBgmForInstructionPlayback();

    try {
      await player.stop();
      await player.setReleaseMode(ReleaseMode.stop);
      await player.play(AssetSource(asset));
    } catch (_) {
      try {
        await player.seek(Duration.zero);
        await player.resume();
      } catch (_) {
        await AppAudio.instance.restoreBgmAfterInstructionPlayback();
      }
    }
  }

  Future<void> _scheduleReplay() async {
    if (!_running || _paused) return;
    await AppAudio.instance.restoreBgmAfterInstructionPlayback();
    await Future<void>.delayed(interval);
    if (!_running || _paused) return;
    await _playFromStart();
  }

  Future<void> _haltCurrentPlayback({required bool clearAsset}) async {
    _running = false;
    _paused = false;
    if (clearAsset) {
      _asset = null;
    }

    await _completeSub?.cancel();
    _completeSub = null;

    final player = _player;
    if (clearAsset) {
      _player = null;
    }
    if (player != null) {
      try {
        await player.stop();
      } catch (_) {}
    }

    await AppAudio.instance.restoreBgmAfterInstructionPlayback();
  }

  /// Stops playback and keeps the loop alive so [resume] can continue later.
  Future<void> pause() async {
    if (!_running || _paused) return;
    _paused = true;

    await _completeSub?.cancel();
    _completeSub = null;

    final player = _player;
    if (player != null) {
      try {
        await player.stop();
      } catch (_) {}
    }

    await AppAudio.instance.restoreBgmAfterInstructionPlayback();
  }

  /// Continues the loop after [pause].
  Future<void> resume() async {
    if (!_running || !_paused) return;
    _paused = false;
    _listenForComplete();
    await _playFromStart();
  }

  Future<void> stop() async {
    if (!_running && _player == null && _asset == null) return;
    await _haltCurrentPlayback(clearAsset: true);
  }

  /// Stops playback only; keeps cached players for the next salud session.
  Future<void> dispose() async {
    await stop();
  }
}
