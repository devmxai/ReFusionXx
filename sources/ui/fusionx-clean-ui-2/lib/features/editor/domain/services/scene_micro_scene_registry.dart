class SceneMicroSceneSpec {
  const SceneMicroSceneSpec({
    required this.id,
    required this.kind,
    required this.width,
    required this.height,
    required this.opacity,
    required this.motionRecipe,
    required this.aspectBias,
  });

  final String id;
  final String kind;
  final double width;
  final double height;
  final double opacity;
  final String motionRecipe;
  final String aspectBias;
}

class SceneMicroSceneRegistry {
  const SceneMicroSceneRegistry();

  static const Map<String, SceneMicroSceneSpec> _specs =
      <String, SceneMicroSceneSpec>{
    'audio.waveform': SceneMicroSceneSpec(
      id: 'audio.waveform',
      kind: 'waveform',
      width: 920,
      height: 120,
      opacity: 0.09,
      motionRecipe: r'$motion.softFadeUp',
      aspectBias: 'horizontal',
    ),
    'captions.lines': SceneMicroSceneSpec(
      id: 'captions.lines',
      kind: 'captionLines',
      width: 860,
      height: 180,
      opacity: 0.07,
      motionRecipe: r'$motion.softFadeUp',
      aspectBias: 'horizontal',
    ),
    'montage.timeline': SceneMicroSceneSpec(
      id: 'montage.timeline',
      kind: 'timelineStrips',
      width: 940,
      height: 140,
      opacity: 0.08,
      motionRecipe: r'$motion.softFadeUp',
      aspectBias: 'horizontal',
    ),
    'image.sparkles': SceneMicroSceneSpec(
      id: 'image.sparkles',
      kind: 'sparkles',
      width: 700,
      height: 220,
      opacity: 0.06,
      motionRecipe: r'$motion.softFadeUp',
      aspectBias: 'free',
    ),
    'color.wheels': SceneMicroSceneSpec(
      id: 'color.wheels',
      kind: 'colorWheels',
      width: 760,
      height: 220,
      opacity: 0.07,
      motionRecipe: r'$motion.softFadeUp',
      aspectBias: 'free',
    ),
    'app.modules': SceneMicroSceneSpec(
      id: 'app.modules',
      kind: 'moduleGrid',
      width: 880,
      height: 220,
      opacity: 0.06,
      motionRecipe: r'$motion.softFadeUp',
      aspectBias: 'free',
    ),
    'ai.nodes': SceneMicroSceneSpec(
      id: 'ai.nodes',
      kind: 'particleNodes',
      width: 900,
      height: 240,
      opacity: 0.07,
      motionRecipe: r'$motion.softFadeUp',
      aspectBias: 'free',
    ),
    'speed.lines': SceneMicroSceneSpec(
      id: 'speed.lines',
      kind: 'motionLines',
      width: 980,
      height: 160,
      opacity: 0.07,
      motionRecipe: r'$motion.softFadeUp',
      aspectBias: 'horizontal',
    ),
    'cloud.paths': SceneMicroSceneSpec(
      id: 'cloud.paths',
      kind: 'cloudDots',
      width: 920,
      height: 200,
      opacity: 0.06,
      motionRecipe: r'$motion.softFadeUp',
      aspectBias: 'free',
    ),
    'code.grid': SceneMicroSceneSpec(
      id: 'code.grid',
      kind: 'codeGrid',
      width: 900,
      height: 220,
      opacity: 0.06,
      motionRecipe: r'$motion.softFadeUp',
      aspectBias: 'horizontal',
    ),
    'social.links': SceneMicroSceneSpec(
      id: 'social.links',
      kind: 'socialLinks',
      width: 920,
      height: 220,
      opacity: 0.06,
      motionRecipe: r'$motion.softFadeUp',
      aspectBias: 'free',
    ),
    'privacy.shields': SceneMicroSceneSpec(
      id: 'privacy.shields',
      kind: 'shieldPattern',
      width: 860,
      height: 220,
      opacity: 0.06,
      motionRecipe: r'$motion.softFadeUp',
      aspectBias: 'free',
    ),
  };

  SceneMicroSceneSpec? find(String id) => _specs[id];

  List<String> get ids => _specs.keys.toList(growable: false)..sort();
}
