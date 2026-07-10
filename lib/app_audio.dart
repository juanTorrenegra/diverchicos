import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AppAudio {
  AppAudio._();
  static final AppAudio instance = AppAudio._();

  AudioPlayer _bgmPlayer = AudioPlayer();
  AudioPlayer _fxPlayer = AudioPlayer();
  Future<void> _audioChain = Future<void>.value();

  // Web-only: keep prepared players per-track and switch via pause/resume.
  // This avoids browsers blocking play() that happens after async preparation.
  final Map<String, AudioPlayer> _webBgmPlayers = <String, AudioPlayer>{};
  AudioPlayer? _webIntroFx;
  String? _webCurrentBgm;
  bool _webWarmedUp = false;

  static const String introClip = 'audio/intro3seconds.mp3';
  static const String menuBgm = 'audio/butterlfy33seconds.mp3';
  static const String animalsBgm = 'audio/round122seconds.mp3';
  static const String preschoolerBgm = 'audio/preschooler.mp3';
  static const String gridPuzzleBgm = 'audio/mrJelly.mp3';
  static const String chickenPathBgm = 'audio/daft_cat.mp3';
  static const String pairsBgm = 'audio/forestBirds.mp3';

  static const double instructionBgmVolume = 0.1;

  final double _baseBgmVolume = 0.5;
  bool _instructionDucked = false;
  String? _currentBgmAsset;

  bool _pausedForBackground = false;
  bool _bgmWasPlayingBeforeBackground = false;

  String? get currentBgmAsset => _currentBgmAsset;

  double get _bgmVolume =>
      (_instructionDucked ? instructionBgmVolume : _baseBgmVolume)
          .clamp(0.0, 1.0);

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final next = _audioChain.then((_) => action());
    _audioChain = next.then((_) {}, onError: (_) {});
    return next;
  }

  Future<void> _applyBgmVolume() async {
    if (kIsWeb) {
      final current = _webCurrentBgm;
      if (current != null) {
        final p = _webBgmPlayers[current];
        if (p != null) {
          await p.setVolume(_bgmVolume);
        }
      }
      return;
    }
    await _bgmPlayer.setVolume(_bgmVolume);
  }

  /// Call this ONCE from the first web user tap (the "TOCA PARA EMPEZAR" gate).
  /// It prepares each asset source so later transitions can use pause/resume
  /// without needing async preparation inside a gesture.
  Future<void> webWarmUpOnFirstTap() async {
    if (!kIsWeb || _webWarmedUp) return;

    Future<AudioPlayer> ensureLoopingBgm(String asset) async {
      return _webBgmPlayers.putIfAbsent(asset, () => AudioPlayer());
    }

    // Prepare BGM players.
    for (final asset in <String>[
      menuBgm,
      animalsBgm,
      preschoolerBgm,
      gridPuzzleBgm,
      chickenPathBgm,
      pairsBgm,
    ]) {
      final p = await ensureLoopingBgm(asset);
      await p.setReleaseMode(ReleaseMode.loop);
      // Reduce latency: set source now, later just resume().
      await p.setSource(AssetSource(asset));
      await p.setVolume(_bgmVolume);
      await p.pause();
    }

    // Prepare intro FX.
    _webIntroFx ??= AudioPlayer();
    await _webIntroFx!.setReleaseMode(ReleaseMode.stop);
    await _webIntroFx!.setSource(AssetSource(introClip));

    // Web unlock: do a very short resume/pause on menu BGM so the browser
    // considers audio "user initiated" for this session.
    final menu = _webBgmPlayers[menuBgm]!;
    await menu.resume();
    await menu.pause();

    _webWarmedUp = true;
  }

  Future<void> _webPlayBgm(String asset) async {
    // Best-effort: if not warmed up, still try to play.
    final p = _webBgmPlayers.putIfAbsent(asset, () => AudioPlayer());
    await p.setReleaseMode(ReleaseMode.loop);
    if (p.source == null) {
      await p.setSource(AssetSource(asset));
    }
    await p.setVolume(_bgmVolume);

    final current = _webCurrentBgm;
    if (current != null && current != asset) {
      final curPlayer = _webBgmPlayers[current];
      if (curPlayer != null) {
        await curPlayer.pause();
      }
    }

    _webCurrentBgm = asset;
    await p.resume();
  }

  Future<void> _webStopBgm() async {
    final current = _webCurrentBgm;
    if (current == null) return;
    final p = _webBgmPlayers[current];
    _webCurrentBgm = null;
    if (p != null) {
      await p.pause();
    }
  }

  Future<void> _webPlayIntroOnce() async {
    final p = _webIntroFx ??= AudioPlayer();
    if (p.source == null) {
      await p.setReleaseMode(ReleaseMode.stop);
      await p.setSource(AssetSource(introClip));
    }
    await p.seek(Duration.zero);
    await p.resume();
  }

  Future<void> playIntroOnce() {
    if (kIsWeb) {
      return _webPlayIntroOnce();
    }
    return _enqueue(() async {
      await _fxPlayer.stop();
      await _fxPlayer.setReleaseMode(ReleaseMode.stop);
      await _fxPlayer.play(AssetSource(introClip));
    });
  }

  Future<void> _startBgmLoop(String asset, {bool force = false}) {
    if (kIsWeb) {
      // Web: switch via preloaded players (pause/resume).
      _currentBgmAsset = asset;
      return _webPlayBgm(asset);
    }
    return _enqueue(() async {
      if (!kIsWeb && !force && _currentBgmAsset == asset) {
        await _applyBgmVolume();
        return;
      }

      _currentBgmAsset = asset;

      await _bgmPlayer.stop();

      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer.play(AssetSource(asset));
      await _applyBgmVolume();
    });
  }

  Future<void> playMenuLoop() => _startBgmLoop(menuBgm, force: kIsWeb);

  /// Stops any game BGM and always restarts main-menu music (used when leaving a mini-game).
  Future<void> returnToMenuMusic() => _startBgmLoop(menuBgm, force: true);

  Future<void> playAnimalsLoop() => _startBgmLoop(animalsBgm);

  Future<void> playPreschoolerLoop() => _startBgmLoop(preschoolerBgm);

  Future<void> playGridPuzzleLoop() => _startBgmLoop(gridPuzzleBgm);

  Future<void> playChickenPathLoop() => _startBgmLoop(chickenPathBgm);

  Future<void> playPairsLoop() => _startBgmLoop(pairsBgm);

  Future<void> stopBgm() {
    if (kIsWeb) {
      _currentBgmAsset = null;
      return _webStopBgm();
    }
    return _enqueue(() async {
      _currentBgmAsset = null;
      await _bgmPlayer.stop();
    });
  }

  /// Lowers BGM while a cutscene instruction clip is playing.
  Future<void> duckBgmForInstructionPlayback() {
    _instructionDucked = true;
    if (kIsWeb) return _applyBgmVolume();
    return _enqueue(_applyBgmVolume);
  }

  /// Restores BGM to normal after an instruction clip finishes or [stop] is called.
  Future<void> restoreBgmAfterInstructionPlayback() {
    _instructionDucked = false;
    if (kIsWeb) return _applyBgmVolume();
    return _enqueue(() async {
      await _applyBgmVolume();
      if (_currentBgmAsset != null &&
          _bgmPlayer.state != PlayerState.playing) {
        await _bgmPlayer.resume();
      }
    });
  }

  Future<void> stopAll() {
    if (kIsWeb) {
      _currentBgmAsset = null;
      return Future<void>(() async {
        await _webStopBgm();
        final fx = _webIntroFx;
        if (fx != null) {
          await fx.pause();
        }
      });
    }
    return _enqueue(() async {
      _currentBgmAsset = null;
      await _fxPlayer.stop();
      await _bgmPlayer.stop();
    });
  }

  /// Pauses BGM when the app leaves the foreground (home button, app switcher).
  Future<void> pauseForBackground() {
    if (_pausedForBackground) return Future<void>.value();
    _pausedForBackground = true;

    if (kIsWeb) {
      final current = _webCurrentBgm;
      if (current == null) return Future<void>.value();
      final player = _webBgmPlayers[current];
      _bgmWasPlayingBeforeBackground =
          player?.state == PlayerState.playing;
      return player?.pause() ?? Future<void>.value();
    }

    return _enqueue(() async {
      _bgmWasPlayingBeforeBackground =
          _bgmPlayer.state == PlayerState.playing;
      await _bgmPlayer.pause();
    });
  }

  /// Resumes BGM after returning to the foreground if it was playing before.
  Future<void> resumeFromBackground() {
    if (!_pausedForBackground) return Future<void>.value();
    _pausedForBackground = false;

    if (!_bgmWasPlayingBeforeBackground || _currentBgmAsset == null) {
      return Future<void>.value();
    }

    if (kIsWeb) {
      final current = _webCurrentBgm ?? _currentBgmAsset;
      if (current == null) return Future<void>.value();
      final player = _webBgmPlayers[current];
      return player?.resume() ?? Future<void>.value();
    }

    return _enqueue(() async {
      if (_bgmPlayer.state != PlayerState.playing) {
        await _bgmPlayer.resume();
      }
    });
  }

  Future<void> dispose() async {
    await _audioChain;
    for (final p in _webBgmPlayers.values) {
      await p.dispose();
    }
    _webBgmPlayers.clear();
    await _webIntroFx?.dispose();
    await _fxPlayer.dispose();
    await _bgmPlayer.dispose();
  }
}
