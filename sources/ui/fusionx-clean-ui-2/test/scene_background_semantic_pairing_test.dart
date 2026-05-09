import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/scene_director_brief_models.dart';
import 'package:refusion_app/features/editor/domain/services/scene_background_semantic_pairing.dart';

void main() {
  const pairing = SceneBackgroundSemanticPairing();

  test('maps audio-focused brief to waveform micro-scene', () {
    final brief = SceneDirectorBrief(
      intent: 'Clean voice and dubbing workflow',
      audience: 'creators',
      mood: 'professional',
      primaryFocus: 'audio features',
      rhythm: 'intro -> features -> outro',
      aspect: r'$canvas.vertical9x16',
      durationIntent: r'$duration.medium',
      elements: <SceneDirectorBriefElement>[
        SceneDirectorBriefElement(
          kind: 'featureCardGroup',
          importance: 'primary',
          cards: const <SceneDirectorBriefCard>[
            SceneDirectorBriefCard(
              label: 'Voice',
              body: 'Studio-like dubbing',
            ),
          ],
        ),
      ],
    );

    final result = pairing.resolve(brief);
    expect(result.spec.topic, 'audio');
    expect(result.spec.microSceneId, 'audio.waveform');
    expect(result.microScene, isNotNull);
    expect(
      result.issues.any(
        (issue) => issue.message.contains(kSceneBackgroundPairingProofTag),
      ),
      isTrue,
    );
  });
}
