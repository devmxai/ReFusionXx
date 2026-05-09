import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/services/scene_director_plan_validator.dart';

void main() {
  const validator = SceneDirectorPlanValidator();

  test('accepts valid director brief and emits proof', () {
    final result = validator.validate(
      <String, Object?>{
        'directorBrief': <String, Object?>{
          'intent': 'Showcase editor features for creators',
          'audience': 'content creators',
          'mood': 'energetic professional',
          'primaryFocus': 'feature cards',
          'rhythm': 'intro hold outro',
          'aspect': r'$canvas.vertical9x16',
          'durationIntent': r'$duration.deliberate',
          'elements': <Object?>[
            <String, Object?>{
              'id': 'title',
              'kind': 'title',
              'importance': 'primary',
              'text': 'Everything your launch needs',
            },
            <String, Object?>{
              'id': 'cards',
              'kind': 'featureCardGroup',
              'importance': 'supporting',
              'cards': <Object?>[
                <String, Object?>{
                  'label': 'Fast',
                  'body': 'Polish edits in minutes',
                  'icon': r'$icon.montage',
                },
                <String, Object?>{
                  'label': 'Voice',
                  'body': 'Clean voiceovers in one tap',
                  'icon': r'$icon.audioEngineering',
                },
              ],
            },
          ],
        },
      },
    );

    expect(result.isValid, isTrue);
    expect(result.brief, isNotNull);
    expect(
      result.issues.any(
        (issue) => issue.message.contains(kSceneDirectorBriefProofTag),
      ),
      isTrue,
    );
  });

  test('rejects missing intent and missing primary hierarchy', () {
    final result = validator.validate(
      <String, Object?>{
        'directorBrief': <String, Object?>{
          'mood': 'professional',
          'rhythm': 'intro outro',
          'elements': <Object?>[
            <String, Object?>{
              'kind': 'subtitle',
              'importance': 'supporting',
              'text': 'Secondary text only',
            },
          ],
        },
      },
    );

    expect(result.isValid, isFalse);
    expect(
      result.issues.any(
        (issue) => issue.path == 'directorBrief.intent',
      ),
      isTrue,
    );
    expect(
      result.issues.any(
        (issue) => issue.message.contains('at least one `primary`'),
      ),
      isTrue,
    );
  });

  test('rejects contradictory luxury mood with bouncy motion hint', () {
    final result = validator.validate(
      <String, Object?>{
        'directorBrief': <String, Object?>{
          'intent': 'Premium luxury product reveal',
          'mood': 'luxury minimal',
          'primaryFocus': 'logo',
          'rhythm': 'slow intro hold',
          'elements': <Object?>[
            <String, Object?>{
              'kind': 'title',
              'importance': 'primary',
              'text': 'Premium',
              'motionHint': 'scaleInBounce',
            },
          ],
        },
      },
    );

    expect(result.isValid, isFalse);
    expect(
      result.issues.any(
        (issue) => issue.message.contains('luxury/minimal'),
      ),
      isTrue,
    );
  });
}
