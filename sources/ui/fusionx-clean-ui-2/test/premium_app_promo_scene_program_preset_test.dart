import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/domain/services/kie_scene_program_agent_service.dart';
import 'package:refusion_app/features/editor/domain/services/refusion_scene_program_authoring_service.dart';
import 'package:refusion_app/features/editor/presentation/widgets/scene_program_import_bottom_sheet.dart';

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

  testWidgets('present sheet applies premium app promo wrapper asset',
      (tester) async {
    SceneProgramImportSheetResult? appliedResult;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () async {
                appliedResult =
                    await showModalBottomSheet<SceneProgramImportSheetResult>(
                  context: context,
                  builder: (_) => const SceneProgramPresentBottomSheet(
                    projectId: 'premium-app-promo-test',
                    sceneId: 'premium-app-promo-scene',
                    canvasSize: MotionSize2D(width: 1080, height: 1920),
                  ),
                );
              },
              child: const Text('Open Present'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open Present'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Premium App Promo'),
      180,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Premium App Promo'), findsOneWidget);

    await tester.tap(find.text('Premium App Promo'));
    await tester.pumpAndSettle();

    expect(appliedResult, isNotNull);
    expect(appliedResult!.name, 'Premium App Promo Prompt Bar');
    expect(appliedResult!.authoringResult.program?.durationMs, 9200);
  });
}
