import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/services/kie_scene_program_agent_service.dart';
import 'package:refusion_app/features/editor/domain/services/refusion_scene_program_authoring_service.dart';
import 'package:refusion_app/features/editor/domain/services/evaluated_frame_truth.dart';
import 'package:refusion_app/features/editor/domain/services/scene_coordinate_system.dart';
import 'package:refusion_app/features/editor/domain/services/scene_evaluation_pipeline.dart';

void main() {
  const sourcePath = 'assets/scene_programs/prompt_bar_spring_morph_scene.json';
  const authoringService = ReFusionSceneProgramAuthoringService();
  const pipeline = SceneEvaluationPipeline();
  const canvas = SceneCanvasMetrics(width: 1080, height: 1920);

  test('prompt bar spring morph preserves hold-frame render truth contracts',
      () {
    final source = File(sourcePath).readAsStringSync();
    final decoded = jsonDecode(source) as Map<String, Object?>;
    final extracted = KieSceneProgramAgentService()
        .extractSceneProgramPayloadFromContent(content: source);
    final authoring = authoringService.importSceneProgram(
      ReFusionSceneProgramAuthoringRequest(
        source: extracted.sceneProgramJson,
        fileName: 'prompt_bar_spring_morph_scene.json',
        projectId: 'prompt-bar-hold-proof',
        sceneId: 'prompt-bar-scene',
      ),
    );

    expect(
      authoring.isValid,
      isTrue,
      reason: authoring.issues
          .map((issue) => '${issue.severity} ${issue.path}: ${issue.message}')
          .join('\n'),
    );
    final program = authoring.program!;

    final holdTimeMs = _holdFrameTimeMs(decoded);
    final evaluation = pipeline.evaluate(
      SceneEvaluationPipelineRequest(
        program: program,
        globalTimeMs: holdTimeMs,
        canvas: canvas,
      ),
    );
    expect(
      evaluation.isValid,
      isTrue,
      reason: evaluation.issues
          .map((issue) => '${issue.severity} ${issue.path}: ${issue.message}')
          .join('\n'),
    );

    final shell = _nodeBySourceElementId(evaluation, 'promptFrame');
    final plus = _nodeBySourceElementId(evaluation, 'promptPlusIcon');
    final mic = _nodeBySourceElementId(evaluation, 'promptMicIcon');
    final sendButton = _nodeBySourceElementId(evaluation, 'sendButton');
    final voice = _nodeBySourceElementId(evaluation, 'voiceIcon');
    final text = _nodeBySourceElementId(evaluation, 'promptText');

    expect(shell.visible, isTrue);
    expect(shell.viewportBounds.width, greaterThan(640));
    expect(shell.viewportBounds.width, lessThan(1030));
    expect(shell.viewportBounds.height, greaterThanOrEqualTo(84));
    expect(shell.viewportBounds.height, lessThanOrEqualTo(120));

    final frameContract = _promptFrameContract(decoded);
    final borderWidth = (frameContract['borderWidth'] as num?)?.toDouble() ?? 0;
    final borderColor =
        ((frameContract['borderColor'] as String?) ?? '').toUpperCase();
    expect(borderWidth, greaterThanOrEqualTo(1));
    expect(
      borderColor != '#FFFFFF' && borderColor != '#FFFFFFFF',
      isTrue,
      reason: 'Prompt shell border must not be white on white background.',
    );

    expect(shell.viewportBounds.contains(plus.viewportBounds), isTrue);
    expect(shell.viewportBounds.contains(mic.viewportBounds), isTrue);
    expect(shell.viewportBounds.contains(sendButton.viewportBounds), isTrue);
    expect(shell.viewportBounds.contains(voice.viewportBounds), isTrue);
    expect(shell.viewportBounds.contains(text.viewportBounds), isTrue);

    expect(plus.viewportBounds.left, lessThan(text.viewportBounds.left));
    expect(mic.viewportBounds.left, greaterThan(text.viewportBounds.right));
    expect(sendButton.viewportBounds.left, greaterThan(mic.viewportBounds.left));
    expect(voice.viewportBounds.left, greaterThan(sendButton.viewportBounds.left));

    final textMetrics = text.textMetrics;
    expect(textMetrics, isNotNull);
    expect(textMetrics!.fontSize, greaterThanOrEqualTo(22));
    expect(textMetrics.fontSize, lessThanOrEqualTo(34));
    expect(
      text.slotBoundsCenter != null &&
          SceneCoordinateSystem.containsRectCenter(
            parent: text.slotBoundsCenter!,
            child: text.worldBoundsCenter,
          ),
      isTrue,
      reason: 'Prompt text must remain inside the primary text slot.',
    );
  });
}

int _holdFrameTimeMs(Map<String, Object?> decoded) {
  final directorPlan = decoded['directorPlan'];
  if (directorPlan is Map<String, Object?>) {
    final beats = directorPlan['beats'];
    if (beats is List<Object?>) {
      for (final rawBeat in beats) {
        if (rawBeat is! Map<String, Object?>) {
          continue;
        }
        final id = (rawBeat['id'] as String?)?.trim().toLowerCase() ?? '';
        if (id == 'readable-hold' || id == 'prompt-readable-hold') {
          final start = (rawBeat['startMs'] as num?)?.toInt();
          final end = (rawBeat['endMs'] as num?)?.toInt();
          if (start != null && end != null && end > start) {
            return start + ((end - start) ~/ 2);
          }
        }
      }
    }
  }
  return 3600;
}

Map<String, Object?> _promptFrameContract(Map<String, Object?> decoded) {
  final sceneProgram = decoded['sceneProgram'];
  if (sceneProgram is! Map<String, Object?>) {
    return const <String, Object?>{};
  }
  final layersRaw = sceneProgram['layers'];
  if (layersRaw is! List<Object?>) {
    return const <String, Object?>{};
  }
  for (final rawLayer in layersRaw) {
    if (rawLayer is! Map<String, Object?>) {
      continue;
    }
    final elementsRaw = rawLayer['elements'];
    if (elementsRaw is! List<Object?>) {
      continue;
    }
    for (final rawElement in elementsRaw) {
      if (rawElement is! Map<String, Object?>) {
        continue;
      }
      if ((rawElement['id'] as String?) == 'promptFrame') {
        final properties = rawElement['properties'];
        if (properties is Map<String, Object?>) {
          return properties;
        }
      }
    }
  }
  return const <String, Object?>{};
}

EvaluatedSceneNode _nodeBySourceElementId(
  SceneEvaluationPipelineResult evaluation,
  String sourceElementId,
) {
  final match = evaluation.truth.nodesById.values.where(
    (node) => node.sourceElementId == sourceElementId,
  );
  expect(
    match.length,
    1,
    reason:
        'Expected one evaluated node for `$sourceElementId`, found ${match.length}.',
  );
  return match.first;
}
