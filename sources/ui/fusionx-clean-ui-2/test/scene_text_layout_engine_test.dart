import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/refusion_motion_director_models.dart';
import 'package:refusion_app/features/editor/domain/services/scene_director_blueprint_compiler.dart';
import 'package:refusion_app/features/editor/domain/services/scene_semantic_blueprint_service.dart';

void main() {
  test('director blueprint compiler defaults text fit policy to wrapToLines', () {
    const compiler = SceneDirectorBlueprintCompiler();
    final plan = ReFusionMotionDirectorPlan(
      schemaVersion: ReFusionMotionDirectorPlan.currentSchemaVersion,
      name: 'Text layout baseline',
      durationMs: 2400,
      frameRate: 30,
      canvasWidth: 1080,
      canvasHeight: 1920,
      beats: <ReFusionMotionDirectorBeat>[
        ReFusionMotionDirectorBeat(
          id: 'intro',
          label: 'Intro',
          startMs: 0,
          endMs: 1200,
          intent: 'Reveal text',
          componentRefs: <String>['body-a'],
        ),
      ],
      components: <ReFusionMotionDirectorComponent>[
        ReFusionMotionDirectorComponent(
          id: 'body-a',
          role: 'text.copy',
          label: 'Body A',
          properties: <String, Object?>{
            'text': 'Readable bounded copy',
          },
        ),
      ],
      primitives: const <ReFusionMotionDirectorPrimitive>[],
    );

    final result = compiler.compile(plan: plan);
    expect(result.blueprint.components, hasLength(1));
    expect(result.blueprint.components.first.fitPolicy, r'$textFit.wrapToLines');
  });

  test('fails closed when bounded text uses fitPolicy none under overflow risk',
      () {
    final service = SceneSemanticBlueprintService();
    final validation = service.validate(<String, Object?>{
      'schemaVersion': 'refusion.semantic-blueprint/v1',
      'name': 'Text fit fail closed',
      'durationMs': 2200,
      'frameRate': 30,
      'components': <Object?>[
        <String, Object?>{
          'id': 'card-a',
          'type': 'FeatureCard',
          'properties': <String, Object?>{
            'width': 360,
            'height': 180,
            'anchor': <String, Object?>{'x': 0, 'y': 0},
          },
          'slots': <String, Object?>{
            'title': <String, Object?>{
              'text': 'Fast',
              'textFrame': <String, Object?>{
                'width': 240,
                'height': 40,
                'maxLines': 1,
                'overflow': 'ellipsis',
                'fitPolicy': 'none',
              },
            },
            'body': <String, Object?>{
              'text': 'This body line is intentionally long and should not '
                  'be accepted with fitPolicy none inside a bounded frame.',
              'textFrame': <String, Object?>{
                'width': 220,
                'height': 48,
                'maxLines': 1,
                'overflow': 'clip',
                'fitPolicy': 'none',
              },
            },
          },
        },
      ],
    });

    expect(validation.isValid, isFalse);
    expect(
      validation.issues.any(
        (issue) =>
            (issue.path?.contains('fitPolicy') ?? false) &&
            issue.message.contains('fitPolicy') &&
            issue.message.contains('none'),
      ),
      isTrue,
    );
  });
}
