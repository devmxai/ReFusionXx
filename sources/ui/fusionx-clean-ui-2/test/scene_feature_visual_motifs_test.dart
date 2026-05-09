import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/services/scene_feature_visual_motifs.dart';

void main() {
  const motifs = SceneFeatureVisualMotifs();

  test('returns audio motif for voice card copy', () {
    final spec = motifs.resolve(
      label: 'Voice',
      body: 'Clean audio and dubbing in one tap',
    );
    expect(spec.id, 'motif.audio');
    expect(spec.iconToken, r'$icon.audioEngineering');
  });

  test('returns image motif for retouch card copy', () {
    final spec = motifs.resolve(
      label: 'Image+',
      body: 'Retouch and photo polish',
    );
    expect(spec.id, 'motif.image');
    expect(spec.iconToken, r'$icon.imageRetouch');
  });
}
