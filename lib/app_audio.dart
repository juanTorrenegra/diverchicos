import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'utils/instruction_audio_context.dart';

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
  static const String pairsLevelCompleteClip = 'audio/pairLevelCompleted.mp3';
  static const String pairsMatchClip = 'audio/pairMatch.mp3';
  static const String magiaClip = 'audio/magia.mp3';
  static const String grabClip = 'audio/grab.mp3';
  static const String releaseClip = 'audio/release.mp3';

  static const double instructionBgmVolume = 0.1;

  final double _baseBgmVolume = 0.5;
  bool _instructionDucked = false;
  String? _currentBgmAsset;

  bool _pausedForBackground = false;
  bool _bgmWasPlayingBeforeBackground = false;

  AudioPlayer? _levelFxPlayer;
  AudioPlayer? _matchFxPlayer;
  AudioPlayer? _magiaFxPlayer;
  AudioPlayer? _grabFxPlayer;
  AudioPlayer? _releaseFxPlayer;
  AudioPlayer? _pickFxPlayer;

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

  Future<void> _webPlayBgm(String asset, {bool force = false}) async {
    // Best-effort: if not warmed up, still try to play.
    final p = _webBgmPlayers.putIfAbsent(asset, () => AudioPlayer());
    await p.setReleaseMode(ReleaseMode.loop);
    if (p.source == null) {
      await p.setSource(AssetSource(asset));
    }
    await p.setVolume(_bgmVolume);

    if (!force &&
        _webCurrentBgm == asset &&
        p.state == PlayerState.playing) {
      return;
    }

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
      _currentBgmAsset = asset;
      return _webPlayBgm(asset, force: force);
    }
    return _enqueue(() async {
      if (!force && _currentBgmAsset == asset) {
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

  /// Starts menu BGM if it is not already playing (safe for menu tap handlers).
  Future<void> playMenuLoop() => _startBgmLoop(menuBgm);

  /// Stops any game BGM and always restarts main-menu music (used when leaving a mini-game).
  Future<void> returnToMenuMusic() => _startBgmLoop(menuBgm, force: true);

  Future<void> playAnimalsLoop() => _startBgmLoop(animalsBgm);

  Future<void> playPreschoolerLoop() => _startBgmLoop(preschoolerBgm);

  Future<void> playGridPuzzleLoop() => _startBgmLoop(gridPuzzleBgm);

  Future<void> playChickenPathLoop() => _startBgmLoop(chickenPathBgm);

  Future<void> playPairsLoop() => _startBgmLoop(pairsBgm);

  /// Pauses current BGM without clearing the track (level celebrations, etc.).
  Future<void> pauseBgm() {
    if (kIsWeb) {
      final current = _webCurrentBgm;
      if (current == null) return Future<void>.value();
      return _webBgmPlayers[current]?.pause() ?? Future<void>.value();
    }
    return _enqueue(() async {
      if (_bgmPlayer.state == PlayerState.playing) {
        await _bgmPlayer.pause();
      }
    });
  }

  /// Resumes the current BGM after [pauseBgm].
  Future<void> resumeBgm() {
    if (_currentBgmAsset == null) return Future<void>.value();

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

  Future<AudioPlayer> _ensureLevelFxPlayer() async {
    final existing = _levelFxPlayer;
    if (existing != null) return existing;
    final player = AudioPlayer();
    await InstructionAudioContext.applyTo(player);
    await player.setReleaseMode(ReleaseMode.stop);
    _levelFxPlayer = player;
    return player;
  }

  Future<AudioPlayer> _ensureMatchFxPlayer() async {
    final existing = _matchFxPlayer;
    if (existing != null) return existing;
    final player = AudioPlayer();
    await InstructionAudioContext.applyTo(player);
    await player.setReleaseMode(ReleaseMode.stop);
    _matchFxPlayer = player;
    return player;
  }

  /// Stops any in-progress playback, then plays the pairs level-complete sting.
  Future<void> playPairsLevelComplete() {
    return _enqueue(() async {
      final player = await _ensureLevelFxPlayer();
      await player.stop();
      await player.play(AssetSource(pairsLevelCompleteClip));
    });
  }

  Future<void> stopPairsLevelComplete() {
    return _enqueue(() async {
      final player = _levelFxPlayer;
      if (player != null) {
        await player.stop();
      }
    });
  }

  /// Short sting for each successful pair match.
  Future<void> playPairsMatch() {
    return _enqueue(() async {
      final player = await _ensureMatchFxPlayer();
      await player.stop();
      await player.play(AssetSource(pairsMatchClip));
    });
  }

  Future<void> stopPairsMatch() {
    return _enqueue(() async {
      final player = _matchFxPlayer;
      if (player != null) {
        await player.stop();
      }
    });
  }

  Future<AudioPlayer> _ensureOneShotFxPlayer({
    required AudioPlayer? existing,
    required void Function(AudioPlayer player) store,
  }) async {
    if (existing != null) return existing;
    final player = AudioPlayer();
    await InstructionAudioContext.applyTo(player);
    await player.setVolume(1);
    await player.setReleaseMode(ReleaseMode.stop);
    store(player);
    return player;
  }

  /// Path-connected play-button appear sting (chicken + grid puzzle).
  Future<void> playMagia() {
    return _enqueue(() async {
      final player = await _ensureOneShotFxPlayer(
        existing: _magiaFxPlayer,
        store: (p) => _magiaFxPlayer = p,
      );
      await player.stop();
      await player.play(AssetSource(magiaClip));
    });
  }

  /// Road-piece pick-up (chicken + grid puzzle).
  Future<void> playGrab() {
    return _enqueue(() async {
      final player = await _ensureOneShotFxPlayer(
        existing: _grabFxPlayer,
        store: (p) => _grabFxPlayer = p,
      );
      await player.stop();
      await player.play(AssetSource(grabClip));
    });
  }

  /// Road-piece successfully placed on a grid slot (chicken + grid puzzle).
  Future<void> playRelease() {
    return _enqueue(() async {
      final player = await _ensureOneShotFxPlayer(
        existing: _releaseFxPlayer,
        store: (p) => _releaseFxPlayer = p,
      );
      await player.stop();
      await player.play(AssetSource(releaseClip));
    });
  }

  /// Cat/cow pick sting on the salud character select screen.
  Future<void> playPick() {
    return _enqueue(() async {
      final player = await _ensureOneShotFxPlayer(
        existing: _pickFxPlayer,
        store: (p) => _pickFxPlayer = p,
      );
      await player.stop();
      await player.setVolume(0.5);
      await player.play(AssetSource(pairsMatchClip));
    });
  }

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
        await _levelFxPlayer?.stop();
        await _matchFxPlayer?.stop();
        await _magiaFxPlayer?.stop();
        await _grabFxPlayer?.stop();
        await _releaseFxPlayer?.stop();
        await _pickFxPlayer?.stop();
      });
    }
    return _enqueue(() async {
      _currentBgmAsset = null;
      await _fxPlayer.stop();
      await _levelFxPlayer?.stop();
      await _matchFxPlayer?.stop();
      await _magiaFxPlayer?.stop();
      await _grabFxPlayer?.stop();
      await _releaseFxPlayer?.stop();
      await _pickFxPlayer?.stop();
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
    await _levelFxPlayer?.dispose();
    _levelFxPlayer = null;
    await _matchFxPlayer?.dispose();
    _matchFxPlayer = null;
    await _magiaFxPlayer?.dispose();
    _magiaFxPlayer = null;
    await _grabFxPlayer?.dispose();
    _grabFxPlayer = null;
    await _releaseFxPlayer?.dispose();
    _releaseFxPlayer = null;
    await _pickFxPlayer?.dispose();
    _pickFxPlayer = null;
    await _fxPlayer.dispose();
    await _bgmPlayer.dispose();
  }
}
