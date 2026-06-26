import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import '../app_audio.dart';

/// Alternates between instruction clips on a fixed timer (shared singleton).
///
/// Ducks BGM while a clip plays; restores BGM between clips and when idle.
class AlternatingInstructionLoop {
  factory AlternatingInstructionLoop() => shared;

  AlternatingInstructionLoop._();

  static final AlternatingInstructionLoop shared = AlternatingInstructionLoop._();

  static final Map<String, AudioPlayer> _assetPlayers =
      <String, AudioPlayer>{};

  Timer? _timer;
  StreamSubscription<void>? _completeSub;
  List<String> _assets = const [];
  int _index = 0;
  Duration _interval = const Duration(seconds: 8);
  AudioPlayer? _player;
  String? _asset;
  bool _running = false;
  bool _paused = false;

  bool get isRunning => _running;
  bool get isPaused => _paused;

  /// Plays [assets[0]], then switches every [interval] until [stop].
  Future<void> start(
    List<String> assets, {
    Duration interval = const Duration(seconds: 8),
  }) async {
    if (assets.isEmpty) return;
    if (_running &&
        !_paused &&
        _assets.length == assets.length &&
        _listEquals(_assets, assets)) {
      return;
    }

    await stop();

    _assets = List<String>.from(assets);
    _index = 0;
    _interval = interval;
    _running = true;
    _paused = false;

    await _playCurrent();

    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) {
      if (!_running || _paused) return;
      _index = (_index + 1) % _assets.length;
      unawaited(_playCurrent());
    });
  }

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
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
      if (!_running || _paused) return;
      unawaited(AppAudio.instance.restoreBgmAfterInstructionPlayback());
    });
  }

  Future<void> _playCurrent() async {
    if (!_running || _paused || _assets.isEmpty) return;

    final asset = _assets[_index];
    if (_asset != null && _asset != asset) {
      final previous = _assetPlayers[_asset!];
      if (previous != null) {
        try {
          await previous.stop();
        } catch (_) {}
      }
    }

    _asset = asset;
    _player = await _ensurePlayerForAsset(asset);
    _listenForComplete();

    await AppAudio.instance.duckBgmForInstructionPlayback();

    try {
      await _player!.stop();
      await _player!.setReleaseMode(ReleaseMode.stop);
      await _player!.play(AssetSource(asset));
    } catch (_) {
      try {
        await _player!.seek(Duration.zero);
        await _player!.resume();
      } catch (_) {
        await AppAudio.instance.restoreBgmAfterInstructionPlayback();
      }
    }
  }

  Future<void> pause() async {
    if (!_running || _paused) return;
    _paused = true;

    _timer?.cancel();
    _timer = null;

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

  Future<void> resume() async {
    if (!_running || !_paused || _assets.isEmpty) return;
    _paused = false;

    await _playCurrent();

    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) {
      if (!_running || _paused) return;
      _index = (_index + 1) % _assets.length;
      unawaited(_playCurrent());
    });
  }

  Future<void> stop() async {
    _running = false;
    _paused = false;
    _assets = const [];
    _index = 0;
    _asset = null;

    _timer?.cancel();
    _timer = null;

    await _completeSub?.cancel();
    _completeSub = null;

    final player = _player;
    _player = null;
    if (player != null) {
      try {
        await player.stop();
      } catch (_) {}
    }

    await AppAudio.instance.restoreBgmAfterInstructionPlayback();
  }

  Future<void> dispose() async {
    await stop();
  }
}
