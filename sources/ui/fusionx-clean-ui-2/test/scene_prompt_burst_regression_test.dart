import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/refusion_scene_program_models.dart';
import 'package:refusion_app/features/editor/domain/services/kie_scene_program_agent_service.dart';
import 'package:refusion_app/features/editor/domain/services/refusion_scene_program_authoring_service.dart';
import 'package:refusion_app/features/editor/domain/services/scene_coordinate_system.dart';
import 'package:refusion_app/features/editor/domain/services/scene_evaluation_pipeline.dart';

void main() {
  test('prompt burst preset passes strict authoring gate', () {
    final source = File(
      'assets/scene_programs/revival_prompt_burst_feature_cards_scene.json',
    ).readAsStringSync();
    final extracted = KieSceneProgramAgentService()
        .extractSceneProgramPayloadFromContent(content: source);
    final result =
        const ReFusionSceneProgramAuthoringService().importSceneProgram(
      ReFusionSceneProgramAuthoringRequest(
        source: extracted.sceneProgramJson,
        fileName: 'revival_prompt_burst_feature_cards_scene.json',
        projectId: 'prompt-burst-regression-test',
        sceneId: 'prompt-burst-scene',
      ),
    );

    expect(
      result.isValid,
      isTrue,
      reason: result.issues
          .map((issue) => '${issue.severity} ${issue.path}: ${issue.message}')
          .join('\n'),
    );
    expect(
      result.issues.any(
        (issue) =>
            issue.message.contains('TF_SCENE_VISUAL_FRAME_QA_PROOF') &&
            issue.severity == ReFusionSceneProgramIssueSeverity.info,
      ),
      isTrue,
    );
  });

  test('prompt burst keeps prompt text inside shell at hold frame', () {
    final source = File(
      'assets/scene_programs/revival_prompt_burst_feature_cards_scene.json',
    ).readAsStringSync();
    final extracted = KieSceneProgramAgentService()
        .extractSceneProgramPayloadFromContent(content: source);
    final result =
        const ReFusionSceneProgramAuthoringService().importSceneProgram(
      ReFusionSceneProgramAuthoringRequest(
        source: extracted.sceneProgramJson,
        fileName: 'revival_prompt_burst_feature_cards_scene.json',
        projectId: 'prompt-burst-regression-test',
        sceneId: 'prompt-burst-scene',
      ),
    );

    expect(result.program, isNotNull);
    final evaluation = const SceneEvaluationPipeline().evaluate(
      SceneEvaluationPipelineRequest(
        program: result.program!,
        globalTimeMs: 4600,
      ),
    );
    final shellNode = evaluation.truth.nodesById.values.singleWhere(
      (node) => node.sourceElementId == 'prompt-shell',
    );
    final textNode = evaluation.truth.nodesById.values.singleWhere(
      (node) => node.sourceElementId == 'prompt-text',
    );

    expect(
      _containsRect(shellNode.viewportBounds, textNode.viewportBounds),
      isTrue,
      reason:
          'prompt-text must stay inside prompt-shell at readable hold frame.',
    );
  });
}

bool _containsRect(
  SceneViewportRect parent,
  SceneViewportRect child, {
  double epsilon = 0.5,
}) {
  return child.left >= parent.left - epsilon &&
      child.top >= parent.top - epsilon &&
      child.right <= parent.right + epsilon &&
      child.bottom <= parent.bottom + epsilon;
}
