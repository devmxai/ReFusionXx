import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_animation_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/domain/models/refusion_scene_program_models.dart';
import 'package:refusion_app/features/editor/domain/services/refusion_scene_program_authoring_service.dart';
import 'package:refusion_app/features/editor/domain/services/refusion_scene_program_lowerer.dart';
import 'package:refusion_app/features/editor/domain/services/scene_pre_render_sanity_gate.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';

void main() {
  const gate = ScenePreRenderSanityGate();
  const authoringService = ReFusionSceneProgramAuthoringService();
  const lowerer = ReFusionSceneProgramLowerer();

  MotionProjectModel _dummyImportedProject() {
    return MotionProjectModel(
      id: 'dummy-import-project',
      name: 'Dummy Import Project',
      format: const MotionProjectFormat(
        canvasSize: MotionSize2D(width: 1080, height: 1920),
      ),
      frameRate: const MotionFrameRate(numerator: 30, denominator: 1),
      scenes: <MotionSceneModel>[
        MotionSceneModel(
          id: 'dummy-scene',
          name: 'Dummy Scene',
          projectRange: TimelineTimeRange(
            start: TimelineTime.zero,
            endExclusive: TimelineTime.fromMilliseconds(1600),
          ),
          layers: const <MotionLayerModel>[],
        ),
      ],
    );
  }

  ReFusionSceneProgram _badSaasProgram() {
    return ReFusionSceneProgram(
      schemaVersion: 'refusion.scene-program/v1',
      name: 'Bad SaaS',
      durationMs: 1600,
      frameRate: 30,
      layers: <ReFusionSceneProgramLayer>[
        ReFusionSceneProgramLayer(
          id: 'ui-layer',
          kind: 'text',
          startMs: 0,
          durationMs: 1600,
          elements: <ReFusionSceneProgramElement>[
            ReFusionSceneProgramElement(
              id: 'prompt-title',
              kind: 'text',
              text: 'Generate new offer for my business right now',
              properties: const <String, Object?>{
                'x': 120,
                'y': 360,
                'fontSize': 56,
                'textFrame': <String, Object?>{
                  'width': 360,
                  'height': 72,
                  'maxLines': 1,
                  'overflow': 'clip',
                  'fitPolicy': 'none',
                },
              },
            ),
          ],
        ),
      ],
    );
  }

  test('blocks pre-render apply for visual geometry violations', () {
    final authoringResult = ReFusionSceneProgramAuthoringResult(
      issues: const <ReFusionSceneProgramIssue>[],
      program: _badSaasProgram(),
      project: _dummyImportedProject(),
    );

    final result = gate.validate(
      authoringResult: authoringResult,
      sceneId: 'root-scene',
    );

    expect(result.blocked, isTrue);
    expect(result.frameQaValid, isFalse);
    expect(result.hctValid, isTrue);
    expect(
      result.issues.any(
        (issue) =>
            issue.severity == ReFusionSceneProgramIssueSeverity.info &&
            issue.message.contains('TF_SCENE_PRE_RENDER_GATE_PROOF') &&
            issue.message.contains('renderTruthAligned=') &&
            issue.message.contains('blocked=true'),
      ),
      isTrue,
    );
  });

  test('passes pre-render gate for valid authored scene', () {
    final source = File(
      'test/fixtures/refusion_scene_programs/first_generated_scene.json',
    ).readAsStringSync();
    final validResult = authoringService.importSceneProgram(
      ReFusionSceneProgramAuthoringRequest(
        source: source,
        fileName: 'first_generated_scene.json',
        projectId: 'agent-scene-project',
        sceneId: 'agent-scene',
      ),
    );

    expect(
      validResult.isValid,
      isTrue,
      reason: validResult.issues
          .map((issue) => '${issue.severity} ${issue.path}: ${issue.message}')
          .join('\n'),
    );

    final gateResult = gate.validate(
      authoringResult: validResult,
      sceneId: 'agent-scene',
    );

    expect(
      gateResult.blocked,
      isFalse,
      reason: gateResult.issues
          .map((issue) => '${issue.severity} ${issue.path}: ${issue.message}')
          .join('\n'),
    );
    expect(gateResult.frameQaValid, isTrue);
    expect(gateResult.hctValid, isTrue);
    expect(
      gateResult.issues.any(
        (issue) =>
            issue.message.contains('TF_SCENE_PRE_RENDER_GATE_PROOF') &&
            issue.message.contains('renderTruthAligned='),
      ),
      isTrue,
    );
  });

  test('blocks pre-render apply when QA and preview truth are misaligned', () {
    final hierarchyDriftProgram = ReFusionSceneProgram(
      schemaVersion: 'refusion.scene-program/v1',
      name: 'Hierarchy Drift Gate',
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
                  keyframes: const <ReFusionSceneProgramKeyframe>[
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
      ReFusionSceneProgramLoweringRequest(program: hierarchyDriftProgram),
    );
    final authoringResult = ReFusionSceneProgramAuthoringResult(
      issues: const <ReFusionSceneProgramIssue>[],
      program: hierarchyDriftProgram,
      project: lowered.project,
      channels: lowered.channels,
      textAnimationBindings: lowered.textAnimationBindings,
    );

    final gateResult = gate.validate(
      authoringResult: authoringResult,
      sceneId: 'hierarchy-drift-gate',
    );

    expect(
      gateResult.blocked,
      isTrue,
      reason: gateResult.issues
          .map((issue) => '${issue.severity} ${issue.path}: ${issue.message}')
          .join('\n'),
    );
    expect(
      gateResult.frameQaValid,
      isFalse,
      reason: gateResult.issues
          .map((issue) => '${issue.severity} ${issue.path}: ${issue.message}')
          .join('\n'),
    );
    expect(
      <String>{
        'render_truth_alignment_mismatch',
        'parent_child_desync',
        'safe_area_violation',
      }.contains(gateResult.fallbackReason),
      isTrue,
      reason: gateResult.issues
          .map((issue) => '${issue.severity} ${issue.path}: ${issue.message}')
          .join('\n'),
    );
    expect(
      gateResult.issues.any(
        (issue) =>
            issue.severity == ReFusionSceneProgramIssueSeverity.error &&
            issue.message.contains('TF_SCENE_RENDER_TRUTH_ALIGNMENT_PROOF') &&
            issue.message.contains('matched=false'),
      ),
      isTrue,
    );
  });
}
