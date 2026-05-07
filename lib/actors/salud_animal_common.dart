import 'package:flame/components.dart';
import 'package:flame_texturepacker/flame_texturepacker.dart';

import '../games/salud_constants.dart';

/// Shared TexturePacker ordering for `cow` / blank / indexed regions.
List<Sprite> saludIndexedFramesFromAtlas(
  TexturePackerAtlas atlas, {
  required String preferredName,
  required String atlasLabelForAssert,
}) {
  List<TexturePackerSprite> pick(String n) =>
      atlas.findSpritesByName(n).toList(growable: false);

  var frames = pick(preferredName);
  if (frames.isEmpty) {
    frames = pick('');
  }
  if (frames.isEmpty) {
    frames = List<TexturePackerSprite>.from(atlas.sprites);
  }
  frames.sort((a, b) {
    final ia = a.region.index == -1 ? 0x7FFFFFFF : a.region.index;
    final ib = b.region.index == -1 ? 0x7FFFFFFF : b.region.index;
    return ia.compareTo(ib);
  });
  assert(
    frames.isNotEmpty,
    'No frames in $atlasLabelForAssert ($preferredName / blank / atlas.sprites)',
  );
  return List<Sprite>.from(frames);
}

SpriteAnimation saludSpriteAnim(
  List<Sprite> frames, {
  required bool loop,
  required double stepTime,
}) {
  return SpriteAnimation.spriteList(frames, stepTime: stepTime, loop: loop);
}

SpriteAnimation saludComposeEnterWalk({
  required List<Sprite> jumpFrames,
  required List<Sprite> jumpToIdleFrames,
  required int jumpLoops,
  required double stepTime,
}) {
  final sprites = <Sprite>[];
  for (var i = 0; i < jumpLoops; i++) {
    sprites.addAll(jumpFrames);
  }
  sprites.addAll(jumpToIdleFrames);
  return saludSpriteAnim(sprites, loop: false, stepTime: stepTime);
}

double saludDefaultAnimalDrawPx() =>
    kSaludAnimalDrawSizePx.clamp(1, kSaludCowLogicalHeight);
