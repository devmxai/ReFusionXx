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

  test('maps AI-focused brief to node-link micro-scene', () {
    final brief = SceneDirectorBrief(
      intent: 'AI assistant launch',
      audience: 'founders',
      mood: 'modern',
      primaryFocus: 'chatgpt automation',
      rhythm: 'intro -> demo -> outro',
      aspect: r'$canvas.vertical9x16',
      durationIntent: r'$duration.medium',
      elements: <SceneDirectorBriefElement>[
        SceneDirectorBriefElement(
          kind: 'title',
          importance: 'primary',
          text: 'Think deeper',
        ),
      ],
    );

    final result = pairing.resolve(brief);
    expect(result.spec.topic, 'ai');
    expect(result.spec.microSceneId, 'ai.nodes');
    expect(result.microScene, isNotNull);
  });

  test('maps social-focused brief to connection micro-scene', () {
    final brief = SceneDirectorBrief(
      intent: 'Social creator toolkit',
      audience: 'creators',
      mood: 'energetic',
      primaryFocus: 'community growth',
      rhythm: 'intro -> cards -> outro',
      aspect: r'$canvas.vertical9x16',
      durationIntent: r'$duration.medium',
      elements: <SceneDirectorBriefElement>[
        SceneDirectorBriefElement(
          kind: 'featureCardGroup',
          importance: 'primary',
          cards: <SceneDirectorBriefCard>[
            SceneDirectorBriefCard(
              label: 'Feed',
              body: 'Plan posts and social campaigns',
            ),
          ],
        ),
      ],
    );

    final result = pairing.resolve(brief);
    expect(result.spec.topic, 'social');
    expect(result.spec.microSceneId, 'social.links');
    expect(result.microScene, isNotNull);
  });

  test('supports explicit no-background override in brief metadata', () {
    final brief = SceneDirectorBrief(
      intent: 'Minimal clean prompt animation',
      audience: 'marketers',
      mood: 'calm',
      primaryFocus: 'prompt bar',
      rhythm: 'intro -> text -> outro',
      aspect: r'$canvas.vertical9x16',
      durationIntent: r'$duration.medium',
      metadata: const <String, Object?>{
        'noBackground': true,
      },
      elements: <SceneDirectorBriefElement>[
        SceneDirectorBriefElement(
          kind: 'typingPrompt',
          importance: 'primary',
        ),
      ],
    );

    final result = pairing.resolve(brief);
    expect(result.spec.backgroundEnabled, isFalse);
    expect(result.microScene, isNull);
    expect(result.spec.topic, 'disabled');
  });
}
