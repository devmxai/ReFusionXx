import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/services/kie_scene_program_agent_service.dart';
import 'package:refusion_app/features/editor/domain/services/refusion_scene_program_authoring_service.dart';

void main() {
  test('premium app promo preset imports through scene authoring pipeline', () {
    final source = File(
      'assets/scene_programs/premium_app_promo_prompt_bar_scene.json',
    ).readAsStringSync();

    final extracted = KieSceneProgramAgentService()
        .extractSceneProgramPayloadFromContent(content: source);
    final result =
        const ReFusionSceneProgramAuthoringService().importSceneProgram(
      ReFusionSceneProgramAuthoringRequest(
        source: extracted.sceneProgramJson,
        fileName: 'premium_app_promo_prompt_bar_scene.json',
        projectId: 'premium-app-promo-test',
        sceneId: 'premium-app-promo-scene',
      ),
    );

    expect(
      result.isValid,
      isTrue,
      reason: result.issues
          .map((issue) => '${issue.severity} ${issue.path}: ${issue.message}')
          .join('\n'),
    );
    expect(result.program?.name, 'Premium App Promo Prompt Bar');
    expect(result.program?.durationMs, 9200);
    expect(result.channels.length, greaterThan(8));
  });
}
