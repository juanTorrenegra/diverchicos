import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../app_audio.dart';
import '../utils/cutscene_instruction_loop.dart';
import '../widgets/diverchicos_loading_screen.dart';
import '../widgets/menu_back_pill.dart';
import 'salud_cat_game.dart';
import 'salud_cow_game.dart';
import 'salud_instruction_audio.dart';

/// Bundled cow/cat intro clip for the SALUD entry point.
const String kSaludCowCatIntroAsset = 'assets/video/salud/cowCatIntro.mp4';

const String kSaludCowPickAsset = 'assets/video/salud/cowPick.mp4';
const String kSaludCatPickAsset = 'assets/video/salud/catPick.mp4';
const String kSaludCowCatBlinkAsset = 'assets/video/salud/cowCatBlink.mp4';

/// Fullscreen intro: fixed logical **1980×1080**, stretched to device; pauses on last frame; [onClose] from back pill
class SaludCowCatIntroLayer extends StatefulWidget {
  const SaludCowCatIntroLayer({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  State<SaludCowCatIntroLayer> createState() => _SaludCowCatIntroLayerState();
}

class _SaludCowCatIntroLayerState extends State<SaludCowCatIntroLayer> {
  static const double _kLogicalW = 1980;
  static const double _kLogicalH = 1080;

  /// Cow = larger tap target.
  static const Size _kRectCowSize = Size(300, 700);
  static const Offset _kRectCowPos = Offset(373.4, 185.7);

  /// Cat = smaller tap target.
  static const Size _kRectCatSize = Size(300, 300);
  static const Offset _kRectCatPos = Offset(720.8, 586.2);

  VideoPlayerController? _introController;
  bool _introReady = false;
  bool _showTapTargets = false;

  VideoPlayerController? _pickController;
  bool _pickReady = false;
  bool _pickBusy = false;
  bool _lastPickWasCow = false;

  VideoPlayerController? _blinkController;
  bool _blinkReady = false;

  Timer? _idleBlinkTimer;

  final CutsceneInstructionLoop _instructions = CutsceneInstructionLoop();

  /// Non-null while [SaludCowGameLayer] owns the cow pick → bath flow.
  VideoPlayerController? _cowGamePick;

  /// Non-null while [SaludCatGameLayer] owns the cat pick → bath flow.
  VideoPlayerController? _catGamePick;

  void _exitToMenu() {
    _cancelIdleBlinkTimer();
    unawaited(_instructions.stop());
    widget.onClose();
  }

  Future<void> _bootstrapIntro(LoadProgressCallback reportProgress) async {
    reportProgress(0.1);
    final c = VideoPlayerController.asset(
      kSaludCowCatIntroAsset,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    reportProgress(0.25);
    try {
      await c.initialize().timeout(const Duration(seconds: 20));
      reportProgress(0.85);
      if (!mounted) {
        await c.dispose();
        return;
      }
      await c.setLooping(false);
      c.addListener(_onIntroTick);
      setState(() {
        _introController = c;
        _introReady = true;
      });
      reportProgress(1);
    } catch (_) {
      await c.dispose();
      if (mounted) _exitToMenu();
    }
  }

  void _startIntroPlayback() {
    final c = _introController;
    if (c == null) return;
    unawaited(c.play());
  }

  void _onIntroTick() {
    final v = _introController;
    if (v == null || !mounted) return;
    final value = v.value;
    if (!value.isInitialized || value.hasError) return;
    if (value.isCompleted) {
      unawaited(v.pause());
      if (!_showTapTargets) {
        setState(() => _showTapTargets = true);
        unawaited(
          _instructions.start(SaludInstructionAudio.cowCatIntro),
        );
        _scheduleIdleBlink();
      }
    }
  }

  void _scheduleIdleBlink() {
    _idleBlinkTimer?.cancel();
    if (!_showTapTargets || !_introReady) return;
    if (_pickReady && _pickController != null) return;
    if (_blinkReady && _blinkController != null) return;
    if (_cowGamePick != null) return;
    if (_catGamePick != null) return;

    _idleBlinkTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      unawaited(_playBlink());
    });
  }

  void _cancelIdleBlinkTimer() {
    _idleBlinkTimer?.cancel();
    _idleBlinkTimer = null;
  }

  void _onBlinkTick() {
    final c = _blinkController;
    if (c == null || !mounted) return;
    final value = c.value;
    if (!value.isInitialized || value.hasError) return;
    if (value.isCompleted) {
      c.removeListener(_onBlinkTick);
      unawaited(c.dispose());
      if (!mounted) return;
      setState(() {
        _blinkController = null;
        _blinkReady = false;
      });
      _scheduleIdleBlink();
    }
  }

  Future<void> _disposeBlink() async {
    final c = _blinkController;
    _blinkController = null;
    _blinkReady = false;
    if (c != null) {
      c.removeListener(_onBlinkTick);
      await c.dispose();
    }
    if (mounted) setState(() {});
  }

  Future<void> _playBlink() async {
    if (!_showTapTargets || !_introReady) return;
    if (_pickReady && _pickController != null) return;
    if (_blinkController != null) return;
    if (_cowGamePick != null) return;
    if (_catGamePick != null) return;

    _cancelIdleBlinkTimer();

    final c = VideoPlayerController.asset(
      kSaludCowCatBlinkAsset,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    try {
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        _scheduleIdleBlink();
        return;
      }
      await c.setLooping(false);
      c.addListener(_onBlinkTick);
      await c.play();
      setState(() {
        _blinkController = c;
        _blinkReady = true;
      });
    } catch (_) {
      await c.dispose();
      if (mounted) _scheduleIdleBlink();
    }
  }

  void _onPickTick() {
    final c = _pickController;
    if (c == null || !mounted) return;
    final value = c.value;
    if (!value.isInitialized || value.hasError) return;
    if (value.isCompleted) {
      c.removeListener(_onPickTick);
      if (_lastPickWasCow) {
        setState(() {
          _cowGamePick = c;
          _pickController = null;
          _pickReady = false;
          _pickBusy = false;
        });
      } else {
        setState(() {
          _catGamePick = c;
          _pickController = null;
          _pickReady = false;
          _pickBusy = false;
        });
      }
    }
  }

  Future<void> _disposePickOnly() async {
    final c = _pickController;
    _pickController = null;
    _pickReady = false;
    if (c != null) {
      c.removeListener(_onPickTick);
      await c.dispose();
    }
  }

  Future<void> _disposeIntro() async {
    final c = _introController;
    _introController = null;
    _introReady = false;
    _showTapTargets = false;
    if (c != null) {
      c.removeListener(_onIntroTick);
      await c.dispose();
    }
  }

  Future<void> _teardownIntroForCowGame() async {
    _cancelIdleBlinkTimer();
    await _instructions.stop();
    await _disposeBlink();
    await _disposeIntro();
  }

  Future<void> _teardownIntroForCatGame() async {
    _cancelIdleBlinkTimer();
    await _instructions.stop();
    await _disposeBlink();
    await _disposeIntro();
  }

  Future<void> _disposePick() async {
    await _disposePickOnly();
  }

  Future<void> _playPick(String assetPath) async {
    if (_pickBusy) return;
    _pickBusy = true;
    _lastPickWasCow = assetPath == kSaludCowPickAsset;
    unawaited(AppAudio.instance.playPick());
    _cancelIdleBlinkTimer();
    await _instructions.stop();
    await _disposeBlink();
    await _disposePick();
    if (!mounted) return;

    final c = VideoPlayerController.asset(
      assetPath,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    try {
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        _pickBusy = false;
        _scheduleIdleBlink();
        return;
      }
      await c.setLooping(false);
      c.addListener(_onPickTick);
      await c.play();
      setState(() {
        _pickController = c;
        _pickReady = true;
        _pickBusy = false;
      });
    } catch (_) {
      await c.dispose();
      if (mounted) {
        setState(() => _pickBusy = false);
        _scheduleIdleBlink();
      }
    }
  }

  Widget _tapTarget({
    required Offset position,
    required Size size,
    required VoidCallback onTap,
  }) {
    return Positioned(
      left: position.dx,
      top: position.dy,
      width: size.width,
      height: size.height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(width: size.width, height: size.height),
      ),
    );
  }

  bool get _hideIntroStack =>
      (_pickReady && _pickController != null) ||
      _cowGamePick != null ||
      _catGamePick != null;

  @override
  void dispose() {
    _cancelIdleBlinkTimer();
    unawaited(_instructions.dispose());
    _introController?.removeListener(_onIntroTick);
    _introController?.dispose();
    final pick = _pickController;
    if (pick != null) {
      pick.removeListener(_onPickTick);
      pick.dispose();
    }
    final blink = _blinkController;
    if (blink != null) {
      blink.removeListener(_onBlinkTick);
      blink.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DiverchicosLoadingScreen(
      load: _bootstrapIntro,
      useFrogVideo: false,
      showLogo: false,
      onRevealed: _startIntroPlayback,
      child: _buildViewport(),
    );
  }

  Widget _buildViewport() {
    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_cowGamePick != null)
              Positioned.fill(
                child: SaludCowGameLayer(
                  pickController: _cowGamePick!,
                  onTeardownIntro: _teardownIntroForCowGame,
                  onClose: _exitToMenu,
                ),
              )
            else if (_catGamePick != null)
              Positioned.fill(
                child: SaludCatGameLayer(
                  pickController: _catGamePick!,
                  onTeardownIntro: _teardownIntroForCatGame,
                  onClose: _exitToMenu,
                ),
              )
            else ...[
              if (!_hideIntroStack)
                Center(
                  child: FittedBox(
                    fit: BoxFit.fill,
                    child: SizedBox(
                      width: _kLogicalW,
                      height: _kLogicalH,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          if (_introReady && _introController != null)
                            Positioned.fill(
                              child: VideoPlayer(_introController!),
                            )
                          else
                            const ColoredBox(color: Colors.black),
                          if (_blinkReady && _blinkController != null)
                            Positioned.fill(
                              child: VideoPlayer(_blinkController!),
                            ),
                          if (_showTapTargets &&
                              !(_pickReady && _pickController != null)) ...[
                            _tapTarget(
                              position: _kRectCowPos,
                              size: _kRectCowSize,
                              onTap: () {
                                _cancelIdleBlinkTimer();
                                unawaited(_disposeBlink());
                                unawaited(_playPick(kSaludCowPickAsset));
                              },
                            ),
                            _tapTarget(
                              position: _kRectCatPos,
                              size: _kRectCatSize,
                              onTap: () {
                                _cancelIdleBlinkTimer();
                                unawaited(_disposeBlink());
                                unawaited(_playPick(kSaludCatPickAsset));
                              },
                            ),
                          ],
                          GameLogicalBackPill(onPressed: _exitToMenu),
                        ],
                      ),
                    ),
                  ),
                ),
              if (_pickReady && _pickController != null)
                Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black,
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.fill,
                        child: SizedBox(
                          width: _kLogicalW,
                          height: _kLogicalH,
                          child: Stack(
                            children: [
                              VideoPlayer(_pickController!),
                              GameLogicalBackPill(onPressed: _exitToMenu),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
