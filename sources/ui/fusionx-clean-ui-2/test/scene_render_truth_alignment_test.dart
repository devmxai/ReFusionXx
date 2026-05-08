import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/refusion_scene_program_models.dart';
import 'package:refusion_app/features/editor/domain/services/kie_scene_program_agent_service.dart';
import 'package:refusion_app/features/editor/domain/services/refusion_scene_program_authoring_service.dart';
import 'package:refusion_app/features/editor/domain/services/scene_visual_frame_qa_validator.dart';

void main() {
  const visualQa = SceneVisualFrameQaValidator(
    enforceOverflowAsError: true,
  );

  _Bounds _parseWorldBoundsProof(String proof) {
    final match = RegExp(
      r'worldBounds=([-0-9.]+),([-0-9.]+),([-0-9.]+),([-0-9.]+)',
    ).firstMatch(proof);
    if (match == null) {
      fail('Missing worldBounds in proof: $proof');
    }
    return _Bounds(
      left: double.parse(match.group(1)!),
      top: double.parse(match.group(2)!),
      width: double.parse(match.group(3)!),
      height: double.parse(match.group(4)!),
    );
  }

  ReFusionSceneProgram _singleNodeCoordinateDriftProgram() {
    return ReFusionSceneProgram(
      schemaVersion: 'refusion.scene-program/v1',
      name: 'Coordinate Drift Probe',
      durationMs: 1200,
      frameRate: 30,
      layers: <ReFusionSceneProgramLayer>[
        ReFusionSceneProgramLayer(
          id: 'probe-layer',
          kind: 'shape',
          startMs: 0,
          durationMs: 1200,
          elements: <ReFusionSceneProgramElement>[
            ReFusionSceneProgramElement(
              id: 'probe-node',
              kind: 'shape',
              properties: const <String, Object?>{
                'shapeKind': 'roundedRectangle',
                'position': <String, Object?>{'x': 452, 'y': 640},
                'width': 176,
                'height': 176,
                'cornerRadius': 32,
                'color': '#111111',
                'opacity': 1,
              },
            ),
          ],
        ),
      ],
    );
  }

  test('aligns visual QA bounds with center-origin viewport mapping', () {
    final result = visualQa.validate(_singleNodeCoordinateDriftProgram());
    final proofIssue = result.issues.firstWhere(
      (issue) =>
          issue.message.contains('TF_SCENE_VISUAL_FRAME_QA_PROOF') &&
          issue.message.contains('componentId=probe-node'),
      orElse: () => fail(
        'Expected TF_SCENE_VISUAL_FRAME_QA_PROOF for probe-node',
      ),
    );
    final bounds = _parseWorldBoundsProof(proofIssue.message);

    const expectedViewportLeftFromCenterOrigin = 540 + 452 - (176 / 2);
    const expectedViewportTopFromCenterOrigin = 960 + 640 - (176 / 2);

    expect(bounds.left, closeTo(expectedViewportLeftFromCenterOrigin, 0.5));
    expect(bounds.top, closeTo(expectedViewportTopFromCenterOrigin, 0.5));
    expect(proofIssue.message.contains('qaUsedSharedPipeline=true'), isTrue);
  });

  test(
      'prompt-burst fixture passes shared visual truth after canonical rewrite',
      () {
    final source = File(
      'assets/scene_programs/revival_prompt_burst_feature_cards_scene.json',
    ).readAsStringSync();
    final extracted = KieSceneProgramAgentService()
        .extractSceneProgramPayloadFromContent(content: source);
    final authored =
        const ReFusionSceneProgramAuthoringService().importSceneProgram(
      ReFusionSceneProgramAuthoringRequest(
        source: extracted.sceneProgramJson,
        fileName: 'revival_prompt_burst_feature_cards_scene.json',
        projectId: 'prompt-burst-v4-regression',
        sceneId: 'prompt-burst-v4-regression',
      ),
    );

    expect(
      authored.isValid,
      isTrue,
      reason: authored.issues
          .map((issue) => '${issue.severity} ${issue.path}: ${issue.message}')
          .join('\n'),
    );
    expect(
      authored.issues.any(
        (issue) =>
            issue.message.contains('TF_SCENE_VISUAL_FRAME_QA_PROOF') &&
            issue.message.contains('passed=true'),
      ),
      isTrue,
    );
  });
}

class _Bounds {
  const _Bounds({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;
}
