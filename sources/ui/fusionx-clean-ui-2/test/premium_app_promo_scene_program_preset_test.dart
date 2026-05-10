import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/domain/models/refusion_scene_program_models.dart';
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
  });

  test('premium app promo keeps prompt text inside fixed input frame at hold',
      () {
    final source = File(
      'assets/scene_programs/premium_app_promo_prompt_bar_scene.json',
    ).readAsStringSync();
    final payload = jsonDecode(source) as Map<String, Object?>;
    final directorPlan = payload['directorPlan'] as Map<String, Object?>;
    final sceneProgram = payload['sceneProgram'] as Map<String, Object?>;
    final layers = sceneProgram['layers'] as List<Object?>;
    final promptLayer = layers.cast<Map<String, Object?>>().singleWhere(
          (layer) => layer['id'] == 'prompt-layer',
        );
    final elements = promptLayer['elements'] as List<Object?>;
    final promptShell = elements.cast<Map<String, Object?>>().singleWhere(
          (element) => element['id'] == 'prompt-shell',
        );
    final promptText = elements.cast<Map<String, Object?>>().singleWhere(
          (element) => element['id'] == 'prompt-text',
        );

    final shellProperties = promptShell['properties'] as Map<String, Object?>;
    final textProperties = promptText['properties'] as Map<String, Object?>;
    final contentInsets =
        shellProperties['contentInsets'] as Map<String, Object?>;
    final textFrame = textProperties['textFrame'] as Map<String, Object?>;
    final textChannels = promptText['channels'] as List<Object?>;
    final typewriterChannel =
        textChannels.cast<Map<String, Object?>>().singleWhere(
              (channel) => channel['property'] == 'typewriterProgress',
            );
    final keyframes = typewriterChannel['keyframes'] as List<Object?>;
    final typewriterEnd =
        keyframes.cast<Map<String, Object?>>().last['timeMs'] as int;
    final layerStartMs = promptLayer['startMs'] as int;
    final beats = directorPlan['beats'] as List<Object?>;
    final promptHoldBeat = beats.cast<Map<String, Object?>>().singleWhere(
          (beat) => beat['id'] == 'prompt-readable-hold',
        );

    expect(shellProperties['layoutRole'], 'container');
    expect(textProperties['parentId'], 'prompt-shell');
    expect((textProperties['layout'] as Map<String, Object?>)['slot'],
        'primaryText');
    expect(textFrame['maxLines'], 1);
    expect(textFrame['fitPolicy'], 'shrinkToFit');
    expect(textFrame['measure'], 'fullText');

    final shellWidth = shellProperties['width'] as num;
    final reservedInsets =
        (contentInsets['left'] as num) + (contentInsets['right'] as num);
    expect(textFrame['width'] as num,
        lessThanOrEqualTo(shellWidth - reservedInsets));

    expect(layerStartMs + typewriterEnd,
        lessThanOrEqualTo(promptHoldBeat['startMs'] as int));

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
    expect(
      result.issues.any(
        (issue) =>
            issue.message.contains('TF_SCENE_LAYOUT_GEOMETRY_PROOF') &&
            issue.message.contains('insideContent=true'),
      ),
      isTrue,
    );
    expect(
      result.issues.any(
        (issue) =>
            issue.message.contains('TF_SCENE_TEXT_FIT_PROOF') &&
            issue.message.contains('accepted=true'),
      ),
      isTrue,
    );
  });

  test(
      'revival native intelligence preset imports through scene authoring pipeline',
      () {
    final source = File(
      'assets/scene_programs/saas_launch_match_cut_scene.json',
    ).readAsStringSync();

    final extracted = KieSceneProgramAgentService()
        .extractSceneProgramPayloadFromContent(content: source);
    final result =
        const ReFusionSceneProgramAuthoringService().importSceneProgram(
      ReFusionSceneProgramAuthoringRequest(
        source: extracted.sceneProgramJson,
        fileName: 'saas_launch_match_cut_scene.json',
        projectId: 'revival-native-intelligence-test',
        sceneId: 'revival-native-intelligence-scene',
      ),
    );

    expect(
      result.isValid,
      isTrue,
      reason: result.issues
          .map((issue) => '${issue.severity} ${issue.path}: ${issue.message}')
          .join('\n'),
    );
    expect(result.program?.name, 'Revival Native Intelligence Showcase');
    expect(result.program?.durationMs, 14000);
    expect(
      result.issues.any(
        (issue) => issue.message.contains('TF_SCENE_VISUAL_FRAME_QA_PROOF'),
      ),
      isTrue,
    );
  });

  test(
      'refusion prompt burst legacy preset is rejected by strict component gate',
      () {
    final source = File(
      'assets/scene_programs/revival_prompt_burst_feature_cards_scene.json',
    ).readAsStringSync();

    expect(
      () => KieSceneProgramAgentService()
          .extractSceneProgramPayloadFromContent(content: source),
      throwsA(
        isA<KieSceneProgramAgentException>().having(
          (exception) => exception.message,
          'message',
          contains('COMPONENT_QA::'),
        ),
      ),
    );
  });

  test(
      'revival native intelligence result card text follows card timing tracks',
      () {
    final source = File(
      'assets/scene_programs/saas_launch_match_cut_scene.json',
    ).readAsStringSync();
    final payload = jsonDecode(source) as Map<String, Object?>;
    final sceneProgram = payload['sceneProgram'] as Map<String, Object?>;
    final layers =
        (sceneProgram['layers'] as List<Object?>).cast<Map<String, Object?>>();

    void expectPositionTrackStart({
      required String layerId,
      required String elementId,
      required int firstKeyframeTimeMs,
    }) {
      final layer = layers.singleWhere((layer) => layer['id'] == layerId);
      final elements =
          (layer['elements'] as List<Object?>).cast<Map<String, Object?>>();
      final element =
          elements.singleWhere((element) => element['id'] == elementId);
      final channels =
          (element['channels'] as List<Object?>).cast<Map<String, Object?>>();
      final position = channels.singleWhere(
        (channel) => channel['property'] == 'position',
      );
      final keyframes =
          (position['keyframes'] as List<Object?>).cast<Map<String, Object?>>();
      expect(
        keyframes.first['timeMs'],
        firstKeyframeTimeMs,
        reason: '$elementId must begin from its canonical card timing.',
      );
      expect(
        keyframes.length,
        greaterThanOrEqualTo(2),
        reason: '$elementId should include at least entry and settle motion.',
      );
    }

    expectPositionTrackStart(
      layerId: 'result-copy-layer',
      elementId: 'story-title',
      firstKeyframeTimeMs: 6100,
    );
    expectPositionTrackStart(
      layerId: 'result-copy-layer',
      elementId: 'story-copy',
      firstKeyframeTimeMs: 6100,
    );
    expectPositionTrackStart(
      layerId: 'result-copy-layer',
      elementId: 'motion-title',
      firstKeyframeTimeMs: 6350,
    );
    expectPositionTrackStart(
      layerId: 'result-copy-layer',
      elementId: 'motion-copy',
      firstKeyframeTimeMs: 6350,
    );
    expectPositionTrackStart(
      layerId: 'result-copy-layer',
      elementId: 'export-title',
      firstKeyframeTimeMs: 6600,
    );
    expectPositionTrackStart(
      layerId: 'result-copy-layer',
      elementId: 'export-copy',
      firstKeyframeTimeMs: 6600,
    );
  });

  testWidgets('present sheet is empty until the next clean scene is authored',
      (tester) async {
    SceneProgramImportSheetResult? appliedResult;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () async {
                  appliedResult =
                      await showModalBottomSheet<SceneProgramImportSheetResult>(
                    context: context,
                    builder: (_) => const SceneProgramPresentBottomSheet(
                      projectId: 'revival-native-intelligence-test',
                      sceneId: 'revival-native-intelligence-scene',
                      canvasSize: MotionSize2D(width: 1080, height: 1920),
                    ),
                  );
                },
                child: const Text('Open Present'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Present'));
    await tester.pumpAndSettle();

    expect(find.text('Professional Test Version 3'), findsNothing);
    expect(find.text('Premium App Promo'), findsNothing);
    expect(find.text('ReFusion Prompt Burst'), findsNothing);
    expect(find.text('No clean present scene yet'), findsOneWidget);
    expect(appliedResult, isNull);
  });
}
