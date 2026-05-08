import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/refusion_scene_program_models.dart';
import 'package:refusion_app/features/editor/domain/services/refusion_scene_program_lowerer.dart';
import 'package:refusion_app/features/editor/domain/services/scene_render_truth_alignment_validator.dart';

void main() {
  final validator = SceneRenderTruthAlignmentValidator();
  const lowerer = ReFusionSceneProgramLowerer();

  test('matches QA and preview bounds for non-hierarchical scene geometry', () {
    final program = ReFusionSceneProgram(
      schemaVersion: 'refusion.scene-program/v1',
      name: 'Aligned Scene',
      durationMs: 1200,
      frameRate: 30,
      layers: <ReFusionSceneProgramLayer>[
        ReFusionSceneProgramLayer(
          id: 'card-layer',
          kind: 'shape',
          startMs: 0,
          durationMs: 1200,
          elements: <ReFusionSceneProgramElement>[
            ReFusionSceneProgramElement(
              id: 'card',
              kind: 'shape',
              properties: const <String, Object?>{
                'position': <String, Object?>{'x': 0, 'y': 120},
                'width': 480,
                'height': 240,
              },
            ),
          ],
        ),
      ],
    );
    final lowered = lowerer.lower(
      ReFusionSceneProgramLoweringRequest(program: program),
    );
    final result = validator.validate(
      program: program,
      project: lowered.project,
      channels: lowered.channels,
      textAnimationBindings: lowered.textAnimationBindings,
    );

    expect(
      result.aligned,
      isTrue,
      reason: result.issues.map((issue) => issue.message).join('\n'),
    );
    expect(
      result.mismatchCount,
      0,
      reason: result.issues.map((issue) => issue.message).join('\n'),
    );
    expect(
      result.issues.any(
        (issue) =>
            issue.message
                .contains(SceneRenderTruthAlignmentValidator.proofTag) &&
            issue.message.contains('matched=true'),
      ),
      isTrue,
    );
  });

  test(
      'detects parent-child render drift when lowerer lacks executable hierarchy',
      () {
    final program = ReFusionSceneProgram(
      schemaVersion: 'refusion.scene-program/v1',
      name: 'Hierarchy Drift',
      durationMs: 1400,
      frameRate: 30,
      layers: <ReFusionSceneProgramLayer>[
        ReFusionSceneProgramLayer(
          id: 'ui-layer',
          kind: 'shape',
          startMs: 0,
          durationMs: 1400,
          elements: <ReFusionSceneProgramElement>[
            ReFusionSceneProgramElement(
              id: 'card-shell',
              kind: 'shape',
              properties: const <String, Object?>{
                'position': <String, Object?>{'x': 0, 'y': 200},
                'width': 520,
                'height': 200,
              },
              channels: <ReFusionSceneProgramChannel>[
                ReFusionSceneProgramChannel(
                  target: 'card-shell',
                  property: 'x',
                  keyframes: <ReFusionSceneProgramKeyframe>[
                    ReFusionSceneProgramKeyframe(timeMs: 0, value: 0),
                    ReFusionSceneProgramKeyframe(timeMs: 1200, value: 280),
                  ],
                ),
              ],
            ),
            ReFusionSceneProgramElement(
              id: 'card-title',
              kind: 'text',
              text: 'Professional Scene',
              properties: const <String, Object?>{
                'parentId': 'card-shell',
                'position': <String, Object?>{'x': 40, 'y': -20},
                'width': 260,
                'height': 56,
                'fontSize': 28,
              },
            ),
          ],
        ),
      ],
    );

    final lowered = lowerer.lower(
      ReFusionSceneProgramLoweringRequest(program: program),
    );
    final result = validator.validate(
      program: program,
      project: lowered.project,
      channels: lowered.channels,
      textAnimationBindings: lowered.textAnimationBindings,
    );

    expect(result.aligned, isFalse);
    expect(result.mismatchCount, greaterThan(0));
    expect(
      result.issues.any(
        (issue) =>
            issue.message
                .contains(SceneRenderTruthAlignmentValidator.proofTag) &&
            issue.message.contains('targetId=card-title') &&
            issue.message.contains('matched=false'),
      ),
      isTrue,
    );
  });
}
