import 'package:audioplayers/audioplayers.dart';

class AppAudio {
  AppAudio._();
  static final AppAudio instance = AppAudio._();

  final AudioPlayer _bgmPlayer = AudioPlayer();
  final AudioPlayer _fxPlayer = AudioPlayer();

  static const String introClip = 'audio/intro3seconds.mp3';
  static const String menuBgm = 'audio/butterlfy33seconds.mp3';
  static const String animalsBgm = 'audio/round122seconds.mp3';

  final double _baseBgmVolume = 1.0;
  double _instructionDuckFactor = 1.0;
  String? _currentBgmAsset;

  bool get isInstructionDucked => _instructionDuckFactor < 1.0;
  String? get currentBgmAsset => _currentBgmAsset;

  Future<void> _applyBgmVolume() async {
    final v = (_baseBgmVolume * _instructionDuckFactor).clamp(0.0, 1.0);
    await _bgmPlayer.setVolume(v);
  }

  Future<void> playIntroOnce() async {
    await _fxPlayer.stop();
    await _fxPlayer.setReleaseMode(ReleaseMode.stop);
    await _fxPlayer.play(AssetSource(introClip));
  }

  Future<void> playMenuLoop() async {
    if (_currentBgmAsset == menuBgm) {
      await _applyBgmVolume();
      return;
    }
    _currentBgmAsset = menuBgm;
    await _bgmPlayer.stop();
    await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
    await _bgmPlayer.play(AssetSource(menuBgm));
    await _applyBgmVolume();
  }

  Future<void> playAnimalsLoop() async {
    if (_currentBgmAsset == animalsBgm) {
      await _applyBgmVolume();
      return;
    }
    _currentBgmAsset = animalsBgm;
    await _bgmPlayer.stop();
    await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
    await _bgmPlayer.play(AssetSource(animalsBgm));
    await _applyBgmVolume();
  }

  Future<void> stopBgm() async {
    _currentBgmAsset = null;
    await _bgmPlayer.stop();
  }

  Future<void> duckBackgroundForInstructions() async {
    _instructionDuckFactor = 0.5;
    await _applyBgmVolume();
  }

  Future<void> restoreBackgroundVolume() async {
    _instructionDuckFactor = 1.0;
    await _applyBgmVolume();
  }

  Future<void> stopAll() async {
    _currentBgmAsset = null;
    await _fxPlayer.stop();
    await _bgmPlayer.stop();
  }

  Future<void> dispose() async {
    await _fxPlayer.dispose();
    await _bgmPlayer.dispose();
  }
}
