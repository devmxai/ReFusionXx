import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/composition_scene_clip_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_animation_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/domain/services/refusion_scene_program_authoring_service.dart';
import 'package:refusion_app/features/editor/domain/services/kie_scene_program_agent_service.dart';
import 'package:refusion_app/features/editor/domain/services/scene_pre_render_sanity_gate.dart';
import 'package:refusion_app/features/editor/domain/services/scene_program_apply_transaction.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';
import 'package:refusion_app/features/editor/domain/models/refusion_scene_program_models.dart';

void main() {
  const authoringService = ReFusionSceneProgramAuthoringService();
  const transaction = SceneProgramApplyTransaction();

  MotionProjectModel baseProject({
    List<MotionSceneModel> scenes = const <MotionSceneModel>[],
  }) {
    return MotionProjectModel(
      id: 'root-project',
      name: 'Root Project',
      format: const MotionProjectFormat(
        canvasSize: MotionSize2D(width: 1080, height: 1920),
      ),
      frameRate: const MotionFrameRate(numerator: 30, denominator: 1),
      scenes: scenes,
    );
  }

  MotionSceneModel rootScene({
    TimelineTime? end,
    List<MotionLayerModel> layers = const <MotionLayerModel>[],
  }) {
    return MotionSceneModel(
      id: 'root-scene',
      name: 'Root Scene',
      projectRange: TimelineTimeRange(
        start: TimelineTime.zero,
        endExclusive: end ?? TimelineTime.zero,
      ),
      layers: layers,
    );
  }

  ReFusionSceneProgramAuthoringResult authoringResult() {
    final source = File(
      'test/fixtures/refusion_scene_programs/first_generated_scene.json',
    ).readAsStringSync();
    final result = authoringService.importSceneProgram(
      ReFusionSceneProgramAuthoringRequest(
        source: source,
        fileName: 'first_generated_scene.json',
        projectId: 'agent-scene-project',
        sceneId: 'agent-scene',
      ),
    );
    expect(result.isValid, isTrue);
    return result;
  }

  ReFusionSceneProgramAuthoringResult typingAuthoringResult() {
    final result = authoringService.importSceneProgram(
      const ReFusionSceneProgramAuthoringRequest(
        source: '''
{
  "schemaVersion": "refusion.scene-program/v1",
  "name": "Typing Scene",
  "durationMs": 1800,
  "frameRate": 30,
  "layers": [
    {
      "id": "typing-layer",
      "kind": "text",
      "startMs": 0,
      "durationMs": 1800,
      "elements": [
        {
          "id": "typing-text",
          "kind": "text",
          "text": "hello world",
          "channels": [
            {
              "property": "typingProgress",
              "keyframes": [
                { "timeMs": 0, "value": 0.0 },
                { "timeMs": 1400, "value": 1.0 }
              ]
            }
          ]
        }
      ]
    }
  ]
}
''',
      ),
    );
    expect(result.isValid, isTrue);
    expect(result.textAnimationBindings, hasLength(1));
    return result;
  }

  ReFusionSceneProgramAuthoringResult promptBurstAuthoringResult() {
    final source = File(
      'assets/scene_programs/revival_prompt_burst_feature_cards_scene.json',
    ).readAsStringSync();
    String payloadSource;
    try {
      payloadSource = KieSceneProgramAgentService()
          .extractSceneProgramPayloadFromContent(content: source)
          .sceneProgramJson;
    } catch (error) {
      return ReFusionSceneProgramAuthoringResult(
        issues: <ReFusionSceneProgramIssue>[
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            message: '$error',
            path: 'source',
          ),
        ],
      );
    }
    final result = authoringService.importSceneProgram(
      ReFusionSceneProgramAuthoringRequest(
        source: payloadSource,
        fileName: 'revival_prompt_burst_feature_cards_scene.json',
        projectId: 'prompt-burst-project',
        sceneId: 'prompt-burst-scene',
      ),
    );
    return result;
  }

  ReFusionSceneProgramAuthoringResult professionalTestV2AuthoringResult() {
    final source = File(
      'assets/scene_programs/professional_test_version_2_scene.json',
    ).readAsStringSync();
    String payloadSource;
    try {
      payloadSource = KieSceneProgramAgentService()
          .extractSceneProgramPayloadFromContent(content: source)
          .sceneProgramJson;
    } catch (error) {
      return ReFusionSceneProgramAuthoringResult(
        issues: <ReFusionSceneProgramIssue>[
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            message: '$error',
            path: 'source',
          ),
        ],
      );
    }
    final result = authoringService.importSceneProgram(
      ReFusionSceneProgramAuthoringRequest(
        source: payloadSource,
        fileName: 'professional_test_version_2_scene.json',
        projectId: 'professional-test-v2-project',
        sceneId: 'professional-test-v2-scene',
      ),
    );
    return result;
  }

  ReFusionSceneProgramAuthoringResult smartTestPromptAuthoringResult() {
    final source = File(
      'assets/scene_programs/smart_test_app_prompt_scene.json',
    ).readAsStringSync();
    final payloadSource = KieSceneProgramAgentService()
        .extractSceneProgramPayloadFromContent(content: source)
        .sceneProgramJson;
    final result = authoringService.importSceneProgram(
      ReFusionSceneProgramAuthoringRequest(
        source: payloadSource,
        fileName: 'smart_test_app_prompt_scene.json',
        projectId: 'smart-test-app-prompt-project',
        sceneId: 'smart-test-app-prompt-scene',
      ),
    );
    expect(
      result.isValid,
      isTrue,
      reason: result.issues
          .map((issue) => '${issue.severity} ${issue.path}: ${issue.message}')
          .join('\n'),
    );
    return result;
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

  test('applies scene program as one root scene clip and one nested source',
      () {
    final result = transaction.apply(
      SceneProgramApplyTransactionRequest(
        baseProject: baseProject(scenes: <MotionSceneModel>[rootScene()]),
        authoringResult: authoringResult(),
        rootSceneId: 'root-scene',
        startTime: TimelineTime.fromMilliseconds(2000),
        clipId: 'intro-clip',
        sourceSceneId: 'intro-source',
        clipName: 'Intro Scene',
      ),
    );

    expect(result, isNotNull);
    expect(result!.sceneClip.id, 'intro-clip');
    expect(result.sceneClip.sourceSceneId, 'intro-source');
    expect(result.sceneClip.startTime.inMilliseconds, 2000);
    expect(result.sceneClip.durationTime.inMilliseconds, 3000);
    expect(result.sceneClips, hasLength(1));
    expect(result.rootScene.layers, isEmpty);
    expect(result.rootScene.projectRange.endExclusive.inMilliseconds, 5000);
    expect(result.sourceScene.id, 'intro-source');
    expect(result.sourceScene.layers, hasLength(3));
    expect(
      result.sourceScene.layers.map((layer) => layer.id),
      <String>[
        'intro-source__background-layer',
        'intro-source__accent-orb-layer',
        'intro-source__title-layer',
      ],
    );
    expect(result.project.scenes.map((scene) => scene.id), <String>[
      'root-scene',
      'intro-source',
    ]);
  });

  test('rejects legacy prompt burst preset at strict pre-render gate', () {
    final authoring = promptBurstAuthoringResult();
    expect(authoring.isValid, isFalse);
    final preRenderGate = const ScenePreRenderSanityGate().validate(
      authoringResult: authoring,
      sceneId: 'root-scene',
    );
    expect(preRenderGate.blocked, isTrue);
    final result = transaction.apply(
      SceneProgramApplyTransactionRequest(
        baseProject: baseProject(scenes: <MotionSceneModel>[rootScene()]),
        authoringResult: authoring,
        rootSceneId: 'root-scene',
        clipName: 'ReFusion Prompt Burst Feature Cards',
      ),
    );
    expect(result, isNull);
  });

  test('rejects raw-layer professional test version 2 preset in strict mode',
      () {
    final authoring = professionalTestV2AuthoringResult();
    expect(authoring.isValid, isFalse);
    final preRenderGate = const ScenePreRenderSanityGate().validate(
      authoringResult: authoring,
      sceneId: 'root-scene',
    );
    expect(preRenderGate.blocked, isTrue);
    final result = transaction.apply(
      SceneProgramApplyTransactionRequest(
        baseProject: baseProject(scenes: <MotionSceneModel>[rootScene()]),
        authoringResult: authoring,
        rootSceneId: 'root-scene',
        clipName: 'Professional Test Version 2',
      ),
    );
    expect(result, isNull);
  });

  test(
      'keeps imported channels and text bindings inside source scene namespace',
      () {
    final result = transaction.apply(
      SceneProgramApplyTransactionRequest(
        baseProject: baseProject(scenes: <MotionSceneModel>[rootScene()]),
        authoringResult: typingAuthoringResult(),
        rootSceneId: 'root-scene',
        sourceSceneId: 'agent-nested-scene',
      ),
    );

    expect(result, isNotNull);
    expect(result!.channels, hasLength(1));
    expect(
      result.channels.every(
        (channel) =>
            channel.id.startsWith('agent-nested-scene__') &&
            channel.target.sceneId == 'agent-nested-scene',
      ),
      isTrue,
    );
    expect(
      result.channels.expand((channel) => channel.keyframes).every(
            (keyframe) =>
                keyframe.id.startsWith('agent-nested-scene__') &&
                keyframe.channelId.startsWith('agent-nested-scene__'),
          ),
      isTrue,
    );
    expect(result.textAnimationBindings, hasLength(1));
    expect(
      result.textAnimationBindings.single.elementTarget.sceneId,
      'agent-nested-scene',
    );
    expect(
      result.textAnimationBindings.single.elementTarget.targetId,
      'agent-nested-scene__typing-text',
    );
  });

  test('applies smart test app prompt preset through pre-render gate', () {
    final authoring = smartTestPromptAuthoringResult();
    final preRenderGate = const ScenePreRenderSanityGate().validate(
      authoringResult: authoring,
      sceneId: 'root-scene',
    );
    expect(
      preRenderGate.blocked,
      isFalse,
      reason: preRenderGate.issues
          .map((issue) => '${issue.severity} ${issue.path}: ${issue.message}')
          .join('\n'),
    );
    final result = transaction.apply(
      SceneProgramApplyTransactionRequest(
        baseProject: baseProject(scenes: <MotionSceneModel>[rootScene()]),
        authoringResult: authoring,
        rootSceneId: 'root-scene',
        clipName: 'Smart Test App Prompt',
      ),
    );

    expect(result, isNotNull);
    expect(result!.sceneClips, hasLength(1));
  });

  test('preserves existing root content and chooses unique clip and scene ids',
      () {
    final existingLayer = MotionLayerModel(
      id: 'manual-layer',
      sceneId: 'root-scene',
      kind: MotionLayerKind.shape,
      visibleRange: TimelineTimeRange(
        start: TimelineTime.zero,
        endExclusive: TimelineTime.fromMilliseconds(1000),
      ),
      elements: const <MotionElementModel>[],
    );
    final existingChannel = MotionPropertyChannelModel(
      id: 'manual-opacity',
      target: const MotionPropertyTarget(
        kind: MotionTargetKind.layer,
        targetId: 'manual-layer',
        sceneId: 'root-scene',
        layerId: 'manual-layer',
      ),
      definition: MotionPropertyCatalog.opacity,
      keyframes: const <MotionKeyframeModel>[
        MotionKeyframeModel(
          id: 'manual-opacity-k0',
          channelId: 'manual-opacity',
          time: TimelineTime.zero,
          value: MotionPropertyValue.scalar(1),
          interpolationToNext: MotionInterpolationSpec.linear(),
        ),
      ],
    );
    final existingClip = CompositionSceneClipModel(
      id: 'agent-scene_source_clip',
      sourceSceneId: 'old-source',
      startTime: TimelineTime.zero,
      durationTime: TimelineTime.fromMilliseconds(1000),
    );

    final result = transaction.apply(
      SceneProgramApplyTransactionRequest(
        baseProject: baseProject(
          scenes: <MotionSceneModel>[
            rootScene(
              end: TimelineTime.fromMilliseconds(1000),
              layers: <MotionLayerModel>[existingLayer],
            ),
            MotionSceneModel(
              id: 'agent-scene_source',
              name: 'Existing Source',
              projectRange: TimelineTimeRange(
                start: TimelineTime.zero,
                endExclusive: TimelineTime.fromMilliseconds(1000),
              ),
              layers: const <MotionLayerModel>[],
            ),
          ],
        ),
        authoringResult: authoringResult(),
        rootSceneId: 'root-scene',
        existingSceneClips: <CompositionSceneClipModel>[existingClip],
        existingChannels: <MotionPropertyChannelModel>[existingChannel],
      ),
    );

    expect(result, isNotNull);
    expect(result!.rootScene.layers.single.id, 'manual-layer');
    expect(result.sceneClip.sourceSceneId, 'agent-scene_source_2');
    expect(result.sceneClip.id, 'agent-scene_source_2_clip');
    expect(result.sceneClips.map((clip) => clip.id), <String>[
      'agent-scene_source_clip',
      'agent-scene_source_2_clip',
    ]);
    expect(result.channels.first.id, 'manual-opacity');
    expect(
        result.project.scenes.map((scene) => scene.id),
        containsAll(<String>[
          'root-scene',
          'agent-scene_source',
          'agent-scene_source_2',
        ]));
  });

  test('returns null for invalid authoring results', () {
    final invalidAuthoring = authoringService.importSceneProgram(
      const ReFusionSceneProgramAuthoringRequest(source: '{ invalid json'),
    );

    final result = transaction.apply(
      SceneProgramApplyTransactionRequest(
        baseProject: baseProject(),
        authoringResult: invalidAuthoring,
        rootSceneId: 'root-scene',
      ),
    );

    expect(result, isNull);
  });

  test('blocks apply at pre-render sanity gate when visual defects slip in',
      () {
    final bypassedAuthoring = ReFusionSceneProgramAuthoringResult(
      issues: const <ReFusionSceneProgramIssue>[],
      program: _badSaasProgram(),
      project: MotionProjectModel(
        id: 'bypass-project',
        name: 'Bypass Project',
        format: const MotionProjectFormat(
          canvasSize: MotionSize2D(width: 1080, height: 1920),
        ),
        frameRate: const MotionFrameRate(numerator: 30, denominator: 1),
        scenes: <MotionSceneModel>[
          MotionSceneModel(
            id: 'bypass-scene',
            name: 'Bypass Scene',
            projectRange: TimelineTimeRange(
              start: TimelineTime.zero,
              endExclusive: TimelineTime.fromMilliseconds(1600),
            ),
            layers: const <MotionLayerModel>[],
          ),
        ],
      ),
    );

    final result = transaction.apply(
      SceneProgramApplyTransactionRequest(
        baseProject: baseProject(scenes: <MotionSceneModel>[rootScene()]),
        authoringResult: bypassedAuthoring,
        rootSceneId: 'root-scene',
      ),
    );

    expect(result, isNull);
  });

  test('keeps apply blocked when non-alignment pre-render errors exist', () {
    final mixedBlockedTransaction = SceneProgramApplyTransaction(
      preRenderSanityGate: _MixedBlockedGate(),
    );
    final result = mixedBlockedTransaction.apply(
      SceneProgramApplyTransactionRequest(
        baseProject: baseProject(scenes: <MotionSceneModel>[rootScene()]),
        authoringResult: authoringResult(),
        rootSceneId: 'root-scene',
      ),
    );
    expect(result, isNull);
  });
}

class _MixedBlockedGate extends ScenePreRenderSanityGate {
  @override
  ScenePreRenderSanityGateResult validate({
    required ReFusionSceneProgramAuthoringResult authoringResult,
    required String sceneId,
  }) {
    return ScenePreRenderSanityGateResult(
      sceneId: sceneId,
      hctValid: false,
      frameQaValid: false,
      blocked: true,
      fallbackReason: 'validation_failed',
      issues: <ReFusionSceneProgramIssue>[
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message:
              'TF_SCENE_RENDER_TRUTH_ALIGNMENT_PROOF sceneId=$sceneId matched=false',
          path: 'scene.renderTruthAlignment',
        ),
        const ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message: 'COMPONENT_QA::TEXT_EXCEEDS_TEXT_SLOT',
          path: 'scene.component',
        ),
      ],
    );
  }
}
