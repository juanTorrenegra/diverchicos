import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import '../app_audio.dart';

/// Repeating voice-over while a cutscene waits for input.
///
/// Call [start] when the clip finishes (e.g. intro video on last frame).
/// Call [stop] when the player acts or the scene tears down.
/// Use [pause] / [resume] to silence while dragging, then continue when idle.
class CutsceneInstructionLoop {
  CutsceneInstructionLoop({this.interval = const Duration(seconds: 3)});

  final Duration interval;

  static final Map<String, AudioPlayer> _assetPlayers = <String, AudioPlayer>{};
  static int _ownerSeed = 0;
  static int? _activeOwnerId;

  final int _ownerId = ++_ownerSeed;
  StreamSubscription<void>? _completeSub;
  AudioPlayer? _player;
  String? _asset;
  bool _running = false;
  bool _paused = false;

  bool get isRunning => _running;
  bool get isPaused => _paused;
  bool get _ownsSharedPlayer => _activeOwnerId == _ownerId;

  /// Plays [asset] to completion, waits [interval], then repeats until [stop].
  ///
  /// [asset] is relative to `assets/` (e.g. `audio/salud/foo.mp3`).
  Future<void> start(String asset) async {
    if (_running && !_paused && _asset == asset) return;
    await stop();

    _activeOwnerId = _ownerId;
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
    if (!_running || _paused || !_ownsSharedPlayer) return;
    final player = _player;
    final asset = _asset;
    if (player == null || asset == null) return;

    await AppAudio.instance.duckBgmForInstructionPlayback();

    try {
      await player.setReleaseMode(ReleaseMode.stop);
      await player.seek(Duration.zero);
      await player.resume();
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
    if (!_running || _paused || !_ownsSharedPlayer) return;
    await AppAudio.instance.restoreBgmAfterInstructionPlayback();
    await Future<void>.delayed(interval);
    if (!_running || _paused || !_ownsSharedPlayer) return;
    await _playFromStart();
  }

  /// Stops playback and keeps the loop alive so [resume] can continue later.
  Future<void> pause() async {
    if (!_running || _paused) return;
    _paused = true;

    await _completeSub?.cancel();
    _completeSub = null;

    final player = _player;
    if (_ownsSharedPlayer && player != null) {
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
    if (!_running && _player == null) return;

    _running = false;
    _paused = false;
    _asset = null;

    await _completeSub?.cancel();
    _completeSub = null;

    final player = _player;
    _player = null;
    if (_ownsSharedPlayer && player != null) {
      try {
        await player.stop();
      } catch (_) {}
    }

    if (_ownsSharedPlayer) {
      _activeOwnerId = null;
    }

    await AppAudio.instance.restoreBgmAfterInstructionPlayback();
  }

  /// Screen teardown should not dispose shared instruction audio.
  /// We only stop playback so instructions are immediately reusable.
  Future<void> dispose() async {
    await stop();
  }
}
