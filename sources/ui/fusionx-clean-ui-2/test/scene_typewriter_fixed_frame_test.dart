import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_compilation_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_evaluation_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_text_preview_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_runtime_helpers.dart';
import 'package:refusion_app/features/editor/domain/services/kie_scene_program_agent_service.dart';
import 'package:refusion_app/features/editor/domain/services/refusion_scene_program_authoring_service.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';

void main() {
  test('typewriter preview emits fixed-frame reveal proof diagnostics', () {
    final source = File(
      'assets/scene_programs/premium_app_promo_prompt_bar_scene.json',
    ).readAsStringSync();
    final extracted = KieSceneProgramAgentService()
        .extractSceneProgramPayloadFromContent(content: source);
    final authoring =
        const ReFusionSceneProgramAuthoringService().importSceneProgram(
      ReFusionSceneProgramAuthoringRequest(
        source: extracted.sceneProgramJson,
        fileName: 'premium_app_promo_prompt_bar_scene.json',
        projectId: 'typewriter-proof-project',
        sceneId: 'typewriter-proof-scene',
        canvasSize: const MotionSize2D(width: 1080, height: 1920),
      ),
    );
    expect(authoring.isValid, isTrue, reason: _issues(authoring));

    final compilation = BasicMotionCompositionCompiler().compile(
      MotionCompileRequest(
        project: authoring.project!,
        propertyChannels: authoring.channels,
        textAnimationBindings: authoring.textAnimationBindings,
      ),
    );
    expect(compilation.hasErrors, isFalse);

    final composition = compilation.composition!;
    const evaluator = BasicMotionRuntimeEvaluator();
    final evaluation = evaluator.evaluate(
      MotionEvaluationRequest(
        composition: composition,
        time: TimelineTime.fromMilliseconds(3500),
      ),
    );
    final preview = BasicMotionTextPreviewBinder().bind(
      composition: composition,
      evaluation: evaluation,
    );

    expect(
      preview.diagnostics.any(
        (diagnostic) =>
            diagnostic.code == 'TF_SCENE_TEXT_REVEAL_FRAME_PROOF' &&
            diagnostic.message.contains('fixedFrame=true'),
      ),
      isTrue,
    );
  });
}

String _issues(ReFusionSceneProgramAuthoringResult result) {
  return result.issues
      .map((issue) => '${issue.severity} ${issue.path}: ${issue.message}')
      .join('\n');
}
