import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/refusion_motion_director_models.dart';
import 'package:refusion_app/features/editor/domain/services/scene_director_intelligence.dart';
import 'package:refusion_app/features/editor/domain/services/scene_director_blueprint_compiler.dart';
import 'package:refusion_app/features/editor/domain/services/scene_rhythm_density_validator.dart';

void main() {
  const intelligence = SceneDirectorIntelligence();

  test('compiles valid director brief into plan and semantic blueprint', () {
    final result = intelligence.compileFromRawBrief(
      <String, Object?>{
        'directorBrief': <String, Object?>{
          'intent': 'Showcase four product capabilities for creators',
          'audience': 'content creators',
          'mood': 'energetic professional',
          'primaryFocus': 'feature cards',
          'rhythm': 'intro -> cascade -> outro',
          'aspect': r'$canvas.vertical9x16',
          'durationIntent': r'$duration.deliberate',
          'elements': <Object?>[
            <String, Object?>{
              'kind': 'title',
              'importance': 'primary',
              'text': 'Everything your launch needs',
            },
            <String, Object?>{
              'kind': 'featureCardGroup',
              'importance': 'supporting',
              'cards': <Object?>[
                <String, Object?>{
                  'label': 'Fast',
                  'body': 'Edit polished videos quickly',
                },
                <String, Object?>{
                  'label': 'Voice',
                  'body': 'Clean voiceovers in one tap',
                },
                <String, Object?>{
                  'label': 'Smart',
                  'body': 'Readable kinetic typography',
                },
                <String, Object?>{
                  'label': 'Image+',
                  'body': 'Retouch, grade, and color',
                },
              ],
            },
          ],
        },
      },
    );

    expect(
      result.isValid,
      isTrue,
      reason: result.issues
          .where(
            (issue) =>
                issue.severity == ReFusionMotionDirectorIssueSeverity.error,
          )
          .map((issue) => '${issue.path}: ${issue.message}')
          .join(' | '),
    );
    expect(result.brief, isNotNull);
    expect(result.plan, isNotNull);
    expect(result.blueprint, isNotNull);
    expect(result.blueprint!.components, isNotEmpty);
    expect(result.blueprint!.beats, hasLength(3));
    expect(
      result.issues.any(
        (issue) => issue.message.contains(kSceneDirectorPlannerProofTag),
      ),
      isTrue,
    );
    expect(
      result.issues.any(
        (issue) => issue.message.contains(kSceneRhythmDensityProofTag),
      ),
      isTrue,
    );
  });

  test('rejects vague director brief before planning', () {
    final result = intelligence.compileFromRawBrief(
      <String, Object?>{
        'directorBrief': <String, Object?>{
          'intent': 'make something cool',
          'audience': 'everyone',
          'mood': 'energetic',
          'primaryFocus': 'headline',
          'rhythm': 'intro hold outro',
          'aspect': r'$canvas.vertical9x16',
          'durationIntent': r'$duration.medium',
          'elements': <Object?>[
            <String, Object?>{
              'kind': 'title',
              'importance': 'primary',
              'text': 'Hi',
            },
          ],
        },
      },
    );

    expect(result.isValid, isFalse);
    expect(result.plan, isNull);
    expect(result.blueprint, isNull);
    expect(
      result.issues.any((issue) => issue.path == 'directorBrief.intent'),
      isTrue,
    );
  });
}
