import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/services/scene_micro_scene_registry.dart';

void main() {
  const registry = SceneMicroSceneRegistry();

  test('exposes professional semantic micro-scene coverage', () {
    final ids = registry.ids;
    expect(ids.toSet().length, ids.length);
    expect(
      ids,
      containsAll(<String>[
        'audio.waveform',
        'ai.nodes',
        'montage.timeline',
        'speed.lines',
        'cloud.paths',
        'code.grid',
        'social.links',
        'privacy.shields',
      ]),
    );
  });
}
