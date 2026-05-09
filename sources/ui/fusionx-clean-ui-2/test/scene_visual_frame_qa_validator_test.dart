import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/refusion_scene_program_models.dart';
import 'package:refusion_app/features/editor/domain/services/evaluated_frame_truth.dart';
import 'package:refusion_app/features/editor/domain/services/scene_coordinate_system.dart';
import 'package:refusion_app/features/editor/domain/services/scene_evaluation_diagnostics.dart';
import 'package:refusion_app/features/editor/domain/services/scene_evaluation_pipeline.dart';
import 'package:refusion_app/features/editor/domain/services/scene_visual_frame_qa_validator.dart';

void main() {
  const validator = SceneVisualFrameQaValidator(
    enforceOverflowAsError: true,
  );

  test('emits frame probe proof for reveal channels', () {
    final result = validator.validate(
      ReFusionSceneProgram(
        schemaVersion: 'refusion.scene-program/v1',
        name: 'QA probes',
        durationMs: 2400,
        frameRate: 30,
        layers: <ReFusionSceneProgramLayer>[
          ReFusionSceneProgramLayer(
            id: 'prompt-layer',
            kind: 'text',
            startMs: 0,
            durationMs: 2400,
            elements: <ReFusionSceneProgramElement>[
              ReFusionSceneProgramElement(
                id: 'prompt-text',
                kind: 'text',
                text: 'generate new offer for my business',
                properties: const <String, Object?>{
                  'fontSize': 32,
                  'textFrame': <String, Object?>{
                    'width': 520,
                    'height': 56,
                    'maxLines': 1,
                    'overflow': 'clip',
                    'fitPolicy': 'shrinkToFit',
                  },
                },
              ),
            ],
            channels: <ReFusionSceneProgramChannel>[
              ReFusionSceneProgramChannel(
                target: 'prompt-text',
                property: 'typewriterProgress',
                keyframes: const <ReFusionSceneProgramKeyframe>[
                  ReFusionSceneProgramKeyframe(timeMs: 200, value: 0.0),
                  ReFusionSceneProgramKeyframe(timeMs: 1300, value: 1.0),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    expect(
      result.isValid,
      isTrue,
      reason: result.issues.map((issue) => issue.message).join('\n'),
    );
    expect(
      result.issues.any(
        (issue) =>
            issue.message.contains('TF_SCENE_VISUAL_FRAME_QA_PROOF') &&
            issue.message.contains('qaUsedSharedPipeline=true') &&
            issue.message.contains('geometryHash=') &&
            issue.message.contains('evaluatedFrameTruthHash='),
      ),
      isTrue,
    );
  });

  test('errors when reveal text overflows with no supported fit policy', () {
    final result = validator.validate(
      ReFusionSceneProgram(
        schemaVersion: 'refusion.scene-program/v1',
        name: 'QA overflow',
        durationMs: 2400,
        frameRate: 30,
        layers: <ReFusionSceneProgramLayer>[
          ReFusionSceneProgramLayer(
            id: 'prompt-layer',
            kind: 'text',
            startMs: 0,
            durationMs: 2400,
            elements: <ReFusionSceneProgramElement>[
              ReFusionSceneProgramElement(
                id: 'prompt-text',
                kind: 'text',
                text: 'generate new offer for my business with weekly promos',
                properties: const <String, Object?>{
                  'fontSize': 40,
                  'textFrame': <String, Object?>{
                    'width': 300,
                    'maxLines': 1,
                    'overflow': 'clip',
                    'fitPolicy': 'none',
                  },
                },
              ),
            ],
            channels: <ReFusionSceneProgramChannel>[
              ReFusionSceneProgramChannel(
                target: 'prompt-text',
                property: 'typewriterProgress',
                keyframes: const <ReFusionSceneProgramKeyframe>[
                  ReFusionSceneProgramKeyframe(timeMs: 200, value: 0.0),
                  ReFusionSceneProgramKeyframe(timeMs: 1300, value: 1.0),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    expect(
      result.issues.any(
        (issue) =>
            issue.severity == ReFusionSceneProgramIssueSeverity.error &&
            issue.message.contains('bounded frame overflow detected'),
      ),
      isTrue,
    );
  });

  test('checks static bounded text overflow without reveal channel', () {
    final result = validator.validate(
      ReFusionSceneProgram(
        schemaVersion: 'refusion.scene-program/v1',
        name: 'QA static overflow',
        durationMs: 2400,
        frameRate: 30,
        layers: <ReFusionSceneProgramLayer>[
          ReFusionSceneProgramLayer(
            id: 'card-layer',
            kind: 'shape',
            startMs: 0,
            durationMs: 2400,
            elements: <ReFusionSceneProgramElement>[
              ReFusionSceneProgramElement(
                id: 'feedback-body',
                kind: 'text',
                text:
                    'Very long static text body that should trigger bounded overflow checks in visual QA.',
                properties: const <String, Object?>{
                  'fontSize': 32,
                  'lineHeight': 1.2,
                  'textFrame': <String, Object?>{
                    'width': 260,
                    'height': 64,
                    'maxLines': 1,
                    'overflow': 'ellipsis',
                    'fitPolicy': 'none',
                  },
                },
              ),
            ],
          ),
        ],
      ),
    );

    expect(
      result.issues.any(
        (issue) =>
            issue.severity == ReFusionSceneProgramIssueSeverity.error &&
            issue.message.contains('static bounded frame overflow detected'),
      ),
      isTrue,
    );
  });

  test('bad SaaS style card text is detected by visual QA probes', () {
    final result = validator.validate(
      ReFusionSceneProgram(
        schemaVersion: 'refusion.scene-program/v1',
        name: 'Bad SaaS Cards',
        durationMs: 3000,
        frameRate: 30,
        layers: <ReFusionSceneProgramLayer>[
          ReFusionSceneProgramLayer(
            id: 'feedback-card-1',
            kind: 'shape',
            startMs: 0,
            durationMs: 3000,
            elements: <ReFusionSceneProgramElement>[
              ReFusionSceneProgramElement(
                id: 'feedback-text-1',
                kind: 'text',
                text:
                    'Really strong pacing overall, this body intentionally exceeds the card text frame.',
                properties: const <String, Object?>{
                  'x': 120,
                  'y': 220,
                  'fontSize': 44,
                  'lineHeight': 1.2,
                  'textFrame': <String, Object?>{
                    'width': 340,
                    'height': 72,
                    'maxLines': 1,
                    'overflow': 'clip',
                    'fitPolicy': 'none',
                  },
                },
              ),
            ],
            channels: <ReFusionSceneProgramChannel>[
              ReFusionSceneProgramChannel(
                target: 'feedback-text-1',
                property: 'opacity',
                keyframes: const <ReFusionSceneProgramKeyframe>[
                  ReFusionSceneProgramKeyframe(timeMs: 0, value: 0.0),
                  ReFusionSceneProgramKeyframe(timeMs: 300, value: 1.0),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    expect(result.isValid, isFalse);
    expect(
      result.issues.any(
        (issue) =>
            issue.message.contains('TF_SCENE_VISUAL_FRAME_QA_PROOF') &&
            issue.message.contains('textOverflow=true'),
      ),
      isTrue,
    );
  });

  test('repaired SaaS style card text passes visual QA probes', () {
    final result = validator.validate(
      ReFusionSceneProgram(
        schemaVersion: 'refusion.scene-program/v1',
        name: 'Repaired SaaS Cards',
        durationMs: 3000,
        frameRate: 30,
        layers: <ReFusionSceneProgramLayer>[
          ReFusionSceneProgramLayer(
            id: 'feedback-card-1',
            kind: 'shape',
            startMs: 0,
            durationMs: 3000,
            elements: <ReFusionSceneProgramElement>[
              ReFusionSceneProgramElement(
                id: 'feedback-text-1',
                kind: 'text',
                text: 'Strong pacing and clean feedback summary.',
                properties: const <String, Object?>{
                  'x': 120,
                  'y': 220,
                  'fontSize': 20,
                  'lineHeight': 1.2,
                  'textFrame': <String, Object?>{
                    'width': 620,
                    'height': 110,
                    'maxLines': 2,
                    'overflow': 'ellipsis',
                    'fitPolicy': 'shrinkToFit',
                  },
                },
              ),
            ],
            channels: <ReFusionSceneProgramChannel>[
              ReFusionSceneProgramChannel(
                target: 'feedback-text-1',
                property: 'opacity',
                keyframes: const <ReFusionSceneProgramKeyframe>[
                  ReFusionSceneProgramKeyframe(timeMs: 0, value: 0.0),
                  ReFusionSceneProgramKeyframe(timeMs: 300, value: 1.0),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    expect(result.isValid, isTrue);
    expect(
      result.issues.any(
        (issue) =>
            issue.message.contains('TF_SCENE_VISUAL_FRAME_QA_PROOF') &&
            issue.message.contains('passed=true') &&
            issue.message.contains('probeCount='),
      ),
      isTrue,
    );
  });

  test('detects midpoint-only text overflow from animated font sizing', () {
    final result = validator.validate(
      ReFusionSceneProgram(
        schemaVersion: 'refusion.scene-program/v1',
        name: 'Midpoint Overflow',
        durationMs: 2400,
        frameRate: 30,
        layers: <ReFusionSceneProgramLayer>[
          ReFusionSceneProgramLayer(
            id: 'title-layer',
            kind: 'text',
            startMs: 0,
            durationMs: 2400,
            elements: <ReFusionSceneProgramElement>[
              ReFusionSceneProgramElement(
                id: 'headline',
                kind: 'text',
                text: 'Professional launch sequence',
                properties: const <String, Object?>{
                  'x': 120,
                  'y': 320,
                  'fontSize': 20,
                  'textFrame': <String, Object?>{
                    'width': 360,
                    'height': 80,
                    'maxLines': 1,
                    'overflow': 'clip',
                    'fitPolicy': 'none',
                  },
                },
              ),
            ],
            channels: <ReFusionSceneProgramChannel>[
              ReFusionSceneProgramChannel(
                target: 'headline',
                property: 'fontSize',
                keyframes: const <ReFusionSceneProgramKeyframe>[
                  ReFusionSceneProgramKeyframe(timeMs: 0, value: 20),
                  ReFusionSceneProgramKeyframe(timeMs: 1200, value: 62),
                  ReFusionSceneProgramKeyframe(timeMs: 2400, value: 20),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    expect(result.isValid, isFalse);
    expect(
      result.issues.any(
        (issue) =>
            issue.severity == ReFusionSceneProgramIssueSeverity.error &&
            issue.message.contains('bounded frame overflow detected'),
      ),
      isTrue,
    );
    expect(
      result.issues.any(
        (issue) =>
            issue.message.contains('TF_SCENE_VISUAL_FRAME_QA_PROOF') &&
            issue.message.contains('timelineTimeMs=1200') &&
            issue.message.contains('textOverflow=true'),
      ),
      isTrue,
    );
  });

  test('detects parent-child desync when child drifts away from card shell',
      () {
    final result = validator.validate(
      ReFusionSceneProgram(
        schemaVersion: 'refusion.scene-program/v1',
        name: 'Parent Child Desync',
        durationMs: 2200,
        frameRate: 30,
        layers: <ReFusionSceneProgramLayer>[
          ReFusionSceneProgramLayer(
            id: 'card-layer',
            kind: 'shape',
            startMs: 0,
            durationMs: 2200,
            elements: <ReFusionSceneProgramElement>[
              ReFusionSceneProgramElement(
                id: 'card-shell',
                kind: 'shape',
                properties: const <String, Object?>{
                  'x': 120,
                  'y': 300,
                  'width': 640,
                  'height': 220,
                },
                channels: <ReFusionSceneProgramChannel>[
                  ReFusionSceneProgramChannel(
                    target: 'card-shell',
                    property: 'x',
                    keyframes: <ReFusionSceneProgramKeyframe>[
                      ReFusionSceneProgramKeyframe(timeMs: 0, value: 120),
                      ReFusionSceneProgramKeyframe(timeMs: 1800, value: 420),
                    ],
                  ),
                ],
              ),
              ReFusionSceneProgramElement(
                id: 'card-text',
                kind: 'text',
                text: 'Refusion premium analysis',
                properties: const <String, Object?>{
                  'parentId': 'card-shell',
                  'x': 44,
                  'y': 64,
                  'fontSize': 24,
                  'textFrame': <String, Object?>{
                    'width': 420,
                    'height': 52,
                    'maxLines': 1,
                    'overflow': 'ellipsis',
                    'fitPolicy': 'shrinkToFit',
                  },
                },
                channels: <ReFusionSceneProgramChannel>[
                  ReFusionSceneProgramChannel(
                    target: 'card-text',
                    property: 'x',
                    keyframes: const <ReFusionSceneProgramKeyframe>[
                      ReFusionSceneProgramKeyframe(timeMs: 0, value: 44),
                      ReFusionSceneProgramKeyframe(timeMs: 1800, value: 260),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    expect(result.isValid, isFalse);
    expect(
      result.issues.any(
        (issue) =>
            issue.severity == ReFusionSceneProgramIssueSeverity.error &&
            issue.message.contains('desynced from parent'),
      ),
      isTrue,
    );
    expect(
      result.issues.any(
        (issue) =>
            issue.message.contains('TF_SCENE_VISUAL_FRAME_QA_PROOF') &&
            issue.message.contains('parentChildDesync=true'),
      ),
      isTrue,
    );
  });

  test('rejects child that outlives hidden parent lifecycle', () {
    final program = ReFusionSceneProgram(
      schemaVersion: 'refusion.scene-program/v1',
      name: 'Parent Cascade Guard',
      durationMs: 1200,
      frameRate: 30,
      layers: <ReFusionSceneProgramLayer>[
        ReFusionSceneProgramLayer(
          id: 'layer-a',
          kind: 'shape',
          startMs: 0,
          durationMs: 1200,
          elements: <ReFusionSceneProgramElement>[
            ReFusionSceneProgramElement(
              id: 'parent-shell',
              kind: 'shape',
              properties: const <String, Object?>{
                'width': 400,
                'height': 120,
              },
            ),
            ReFusionSceneProgramElement(
              id: 'child-text',
              kind: 'text',
              text: 'still visible',
              properties: const <String, Object?>{
                'parentId': 'parent-shell',
                'width': 200,
                'height': 40,
                'fontSize': 20,
                'textFrame': <String, Object?>{
                  'width': 200,
                  'height': 40,
                  'maxLines': 1,
                  'overflow': 'ellipsis',
                  'fitPolicy': 'shrinkToFit',
                },
              },
            ),
          ],
        ),
      ],
    );

    const validatorWithFakePipeline = SceneVisualFrameQaValidator(
      enforceOverflowAsError: true,
      evaluationPipeline: _OutlivesParentFakePipeline(),
    );
    final result = validatorWithFakePipeline.validate(program);

    expect(result.isValid, isFalse);
    expect(
      result.issues.any(
        (issue) =>
            issue.severity == ReFusionSceneProgramIssueSeverity.error &&
            issue.message.contains('TF_SCENE_PARENT_EXIT_CASCADE_PROOF'),
      ),
      isTrue,
    );
  });
}

class _OutlivesParentFakePipeline extends SceneEvaluationPipeline {
  const _OutlivesParentFakePipeline();

  @override
  SceneEvaluationPipelineResult evaluate(
    SceneEvaluationPipelineRequest request,
  ) {
    const parentId = '__layer__layer-a__element__parent-shell';
    const childId = '__layer__layer-a__element__child-text';
    final truth = EvaluatedFrameTruth(
      coordinateSystem: SceneCoordinateSystem.canonical,
      canvas: const SceneCanvasMetrics(width: 1080, height: 1920),
      globalTimeMs: request.globalTimeMs,
      sceneId: request.program.name,
      nodesById: <String, EvaluatedSceneNode>{
        parentId: const EvaluatedSceneNode(
          nodeId: parentId,
          sourceLayerId: 'layer-a',
          sourceElementId: 'parent-shell',
          parentNodeId: '__scene__root',
          nodeType: 'shape',
          localTransform: EvaluatedTransform2D.identity,
          worldTransform: EvaluatedTransform2D.identity,
          localBoundsCenter: SceneRectCenter(
            centerX: 0,
            centerY: 0,
            width: 400,
            height: 120,
          ),
          worldBoundsCenter: SceneRectCenter(
            centerX: 0,
            centerY: 0,
            width: 400,
            height: 120,
          ),
          viewportBounds: SceneViewportRect(
            left: 340,
            top: 900,
            width: 400,
            height: 120,
          ),
          effectiveOpacity: 0.0,
          active: false,
          visible: false,
          zOrder: 1,
        ),
        childId: const EvaluatedSceneNode(
          nodeId: childId,
          sourceLayerId: 'layer-a',
          sourceElementId: 'child-text',
          parentNodeId: parentId,
          nodeType: 'text',
          localTransform: EvaluatedTransform2D.identity,
          worldTransform: EvaluatedTransform2D.identity,
          localBoundsCenter: SceneRectCenter(
            centerX: 0,
            centerY: 0,
            width: 200,
            height: 40,
          ),
          worldBoundsCenter: SceneRectCenter(
            centerX: 0,
            centerY: 0,
            width: 200,
            height: 40,
          ),
          viewportBounds: SceneViewportRect(
            left: 440,
            top: 940,
            width: 200,
            height: 40,
          ),
          effectiveOpacity: 1.0,
          active: true,
          visible: true,
          textMetrics: EvaluatedTextMetrics(
            fontSize: 20,
            lineHeight: 1.1,
            letterSpacing: 0,
            maxLines: 1,
            typewriterProgress: 1.0,
          ),
          zOrder: 2,
        ),
      },
    );
    return SceneEvaluationPipelineResult(
      truth: truth,
      issues: const <ReFusionSceneProgramIssue>[],
      diagnostics: SceneEvaluationDiagnostics(
        events: const <SceneEvaluationDiagnosticEvent>[],
      ),
    );
  }
}
