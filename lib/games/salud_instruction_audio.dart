/// Salud cutscene instruction clips (`assets/audio/salud/…`).
///
/// When a clip ends and waits for input, start looping with
/// [CutsceneInstructionLoop] and pass the matching constant here.
/// Stop the loop when the player taps or the scene advances.
abstract final class SaludInstructionAudio {
  /// After [kSaludCowCatIntroAsset] — pick cow or cat.
  static const String cowCatIntro = 'audio/salud/vakyOgatyIniciar.mp3';

  /// After cow/cat enters bath — drag colgate onto cepillo.
  static const String cremaACepillo = 'audio/salud/cremaACepillo.mp3';

  /// Brushing teeth — drag cepillo con crema over teeth.
  static const String cepilloADientes = 'audio/salud/cepilloADientes.mp3';

  /// After brushing complete — tap to pour water into the cup.
  static const String aguaAvaso = 'audio/salud/aguaAvaso.mp3';

  /// After cup is filled — bring water to the mouth.
  static const String aguaABoca = 'audio/salud/aguaABoca.mp3';

  // Add one line per cutscene as clips are recorded, e.g.:
  // static const String cowPick = 'audio/salud/vakyCowPick.mp3';
}
