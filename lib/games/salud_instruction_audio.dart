/// Salud cutscene instruction clips (`assets/audio/salud/…`).
///
/// When a clip ends and waits for input, start looping with
/// [CutsceneInstructionLoop] and pass the matching constant here.
/// Stop the loop when the player taps or the scene advances.
abstract final class SaludInstructionAudio {
  /// After [kSaludCowCatIntroAsset] — pick cow or cat.
  static const String cowCatIntro = 'audio/salud/vakyOgatyIniciar.mp3';

  // Add one line per cutscene as clips are recorded, e.g.:
  // static const String cowPick = 'audio/salud/vakyCowPick.mp3';
}
