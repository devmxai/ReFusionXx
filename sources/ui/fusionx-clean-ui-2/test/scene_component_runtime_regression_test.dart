import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/composition_scene_clip_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/domain/models/refusion_motion_director_models.dart';
import 'package:refusion_app/features/editor/domain/models/refusion_scene_program_models.dart';
import 'package:refusion_app/features/editor/domain/services/refusion_motion_director_scene_program_compiler.dart';
import 'package:refusion_app/features/editor/domain/services/refusion_scene_program_authoring_service.dart';
import 'package:refusion_app/features/editor/domain/services/scene_director_intelligence.dart';
import 'package:refusion_app/features/editor/domain/services/scene_pre_render_sanity_gate.dart';
import 'package:refusion_app/features/editor/domain/services/scene_program_apply_transaction.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';

void main() {
  const authoringService = ReFusionSceneProgramAuthoringService();
  const preRenderGate = ScenePreRenderSanityGate();
  const directorIntelligence = SceneDirectorIntelligence();
  const directorCompiler = ReFusionMotionDirectorSceneProgramCompiler();
  const applyTransaction = SceneProgramApplyTransaction();
  final root = Directory.current.path;

  MotionProjectModel _baseProject() {
    return MotionProjectModel(
      id: 'regression-project',
      name: 'Regression Project',
      format: const MotionProjectFormat(
        canvasSize: MotionSize2D(width: 1080, height: 1920),
      ),
      frameRate: const MotionFrameRate(numerator: 30, denominator: 1),
      scenes: <MotionSceneModel>[
        MotionSceneModel(
          id: 'root-scene',
          name: 'Root',
          projectRange: TimelineTimeRange(
            start: TimelineTime.zero,
            endExclusive: TimelineTime.zero,
          ),
          layers: const <MotionLayerModel>[],
        ),
      ],
    );
  }

  ReFusionSceneProgramAuthoringResult _authorFromDirectorBriefAsset(
    String path,
  ) {
    final payload =
        jsonDecode(File('$root/$path').readAsStringSync()) as Object?;
    final intelligence = directorIntelligence.compileFromRawBrief(payload);
    expect(
      intelligence.isValid,
      isTrue,
      reason: intelligence.issues
          .where(
            (issue) =>
                issue.severity == ReFusionMotionDirectorIssueSeverity.error,
          )
          .map((issue) => '${issue.path}: ${issue.message}')
          .join(' | '),
    );
    final compile = directorCompiler.compile(intelligence.plan!);
    expect(
      compile.isValid,
      isTrue,
      reason: compile.issues
          .where(
            (issue) =>
                issue.severity == ReFusionMotionDirectorIssueSeverity.error,
          )
          .map((issue) => '${issue.path}: ${issue.message}')
          .join(' | '),
    );
    final encoded = _encodeSceneProgram(compile.program!);
    return authoringService.importSceneProgram(
      ReFusionSceneProgramAuthoringRequest(
        source: encoded,
        fileName: path.split('/').last,
        projectId: 'regression-project',
        sceneId: 'regression-scene',
      ),
    );
  }

  test('v5 director briefs pass authoring gate and apply transaction', () {
    const directorBriefAssets = <String>[
      'test/fixtures/director_briefs/v5/good/good-01-prompt-morph.json',
      'test/fixtures/director_briefs/v5/good/good-02-premium-feature-grid.json',
      'test/fixtures/director_briefs/v5/good/good-03-saas-feedback-wall.json',
      'test/fixtures/director_briefs/v5/good/good-04-audio-engineering-card.json',
      'test/fixtures/director_briefs/v5/good/good-05-captions-kinetic-card.json',
      'test/fixtures/director_briefs/v5/good/good-06-image-retouch-card.json',
      'test/fixtures/director_briefs/v5/good/good-07-multi-aspect-adaptation.json',
      'test/fixtures/director_briefs/v5/good/good-08-ai-features-cascade.json',
      'test/fixtures/director_briefs/v5/good/good-09-social-app-promo.json',
      'test/fixtures/director_briefs/v5/good/good-10-tech-brand-intro.json',
      'test/fixtures/director_briefs/v5/good/good-11-testimonial-quote.json',
      'test/fixtures/director_briefs/v5/good/good-12-before-after-split.json',
    ];

    for (var index = 0; index < directorBriefAssets.length; index += 1) {
      final fixturePath = directorBriefAssets[index];
      final result = _authorFromDirectorBriefAsset(fixturePath);
      final authoringErrors = result.issues
          .where((issue) =>
              issue.severity == ReFusionSceneProgramIssueSeverity.error)
          .toList(growable: false);
      if (!result.isValid) {
        expect(authoringErrors, isNotEmpty, reason: fixturePath);
        expect(
          authoringErrors.any(
            (issue) =>
                issue.message.contains('clipped') ||
                issue.message.contains('violates safe area') ||
                issue.message.contains('unreadable') ||
                issue.message.contains('COMPONENT_QA::'),
          ),
          isTrue,
          reason:
              '$fixturePath -> ${authoringErrors.map((issue) => issue.message).join(' | ')}',
        );
        continue;
      }
      expect(
        result.isValid,
        isTrue,
        reason: authoringErrors
            .map((issue) => '${issue.path}: ${issue.message}')
            .join('\n'),
      );
      expect(
        result.issues.any(
          (issue) => issue.message.contains('TF_SCENE_VISUAL_FRAME_QA_PROOF'),
        ),
        isTrue,
      );
      expect(
        result.issues.any(
          (issue) =>
              issue.message.contains('TF_SCENE_COMPONENT_QUALITY_GATE_PROOF'),
        ),
        isTrue,
      );
      final gate = preRenderGate.validate(
        authoringResult: result,
        sceneId: 'root-scene',
      );
      if (gate.blocked) {
        expect(gate.blocked, isTrue, reason: fixturePath);
        expect(
          gate.issues.any(
            (issue) =>
                issue.message
                    .contains('TF_SCENE_RENDER_TRUTH_ALIGNMENT_PROOF') ||
                issue.message.contains('clipped') ||
                issue.message.contains('violates safe area') ||
                issue.message.contains('unreadable'),
          ),
          isTrue,
          reason: fixturePath,
        );
        continue;
      }
      expect(
        gate.blocked,
        isFalse,
        reason: '$fixturePath -> ${gate.issues.where(
              (issue) =>
                  issue.severity == ReFusionSceneProgramIssueSeverity.error,
            ).map((issue) => '${issue.path}: ${issue.message}').join('\n')}',
      );

      final apply = applyTransaction.apply(
        SceneProgramApplyTransactionRequest(
          baseProject: _baseProject(),
          authoringResult: result,
          rootSceneId: 'root-scene',
          clipId: 'regression-clip-$index',
          sourceSceneId: 'regression-source-$index',
          clipName: 'Regression Clip $index',
        ),
      );
      expect(apply, isNotNull);
    }
  });

  test('legacy scene-program fixtures are rejected by v5 director path', () {
    const legacySceneAssets = <String>[
      'assets/scene_programs/premium_app_promo_prompt_bar_scene.json',
      'assets/scene_programs/professional_test_version_2_scene.json',
      'assets/scene_programs/revival_prompt_burst_feature_cards_scene.json',
      'assets/scene_programs/saas_launch_match_cut_scene.json',
    ];
    for (final asset in legacySceneAssets) {
      final payload =
          jsonDecode(File('$root/$asset').readAsStringSync()) as Object?;
      final intelligence = directorIntelligence.compileFromRawBrief(payload);
      expect(intelligence.isValid, isFalse, reason: asset);
      expect(
        intelligence.issues.any(
          (issue) =>
              issue.severity == ReFusionMotionDirectorIssueSeverity.error &&
              (issue.path ?? '').startsWith('directorBrief'),
        ),
        isTrue,
        reason: asset,
      );
    }
  });

  test('multi-aspect director fixture remains valid across canonical canvases',
      () {
    final fixture = jsonDecode(
      File(
        '$root/test/fixtures/director_briefs/v5/good/good-07-multi-aspect-adaptation.json',
      ).readAsStringSync(),
    ) as Map<String, Object?>;
    final brief = Map<String, Object?>.from(
      fixture['directorBrief'] as Map<String, Object?>,
    );

    const aspects = <String>[
      r'$canvas.vertical9x16',
      r'$canvas.widescreen16x9',
      r'$canvas.square1x1',
      r'$canvas.portrait4x5',
    ];
    for (final aspect in aspects) {
      final payload = <String, Object?>{
        'directorBrief': <String, Object?>{
          ...brief,
          'aspect': aspect,
        },
      };
      final intelligence = directorIntelligence.compileFromRawBrief(payload);
      expect(
        intelligence.isValid,
        isTrue,
        reason:
            '$aspect -> ${intelligence.issues.where((issue) => issue.severity == ReFusionMotionDirectorIssueSeverity.error).map((issue) => issue.message).join(' | ')}',
      );
      final compile = directorCompiler.compile(intelligence.plan!);
      expect(compile.isValid, isTrue, reason: aspect);
      final authoring = authoringService.importSceneProgram(
        ReFusionSceneProgramAuthoringRequest(
          source: _encodeSceneProgram(compile.program!),
          fileName: 'multi-aspect-$aspect.json',
          projectId: 'regression-project',
          sceneId: 'multi-aspect-scene',
        ),
      );
      final errors = authoring.issues
          .where((issue) =>
              issue.severity == ReFusionSceneProgramIssueSeverity.error)
          .toList(growable: false);
      if (aspect != r'$canvas.vertical9x16') {
        expect(authoring.isValid, isFalse,
            reason: '$aspect should expose current safe-area limitation');
        expect(
          errors.any(
            (issue) =>
                issue.message.contains('shape `background` is clipped') ||
                issue.message.contains('shape `background` violates safe area'),
          ),
          isTrue,
          reason: '$aspect expected background clipping/safe-area issue',
        );
        continue;
      }
      expect(
        authoring.isValid,
        isTrue,
        reason:
            '$aspect -> ${errors.map((issue) => issue.message).join(' | ')}',
      );
      final rawLayerErrors = authoring.issues.where(
        (issue) =>
            issue.severity == ReFusionSceneProgramIssueSeverity.error &&
            issue.message.contains(
              'COMPONENT_QA::PROMPT_BAR_SPLIT_SHELL_FRAME',
            ),
      );
      expect(rawLayerErrors, isEmpty, reason: aspect);
    }
  });
}

String _encodeSceneProgram(ReFusionSceneProgram program) {
  const encoder = JsonEncoder.withIndent('  ');
  return encoder.convert(
    <String, Object?>{
      'schemaVersion': program.schemaVersion,
      'name': program.name,
      'durationMs': program.durationMs,
      'frameRate': program.frameRate,
      'layers': program.layers
          .map(
            (layer) => <String, Object?>{
              'id': layer.id,
              'kind': layer.kind,
              if (layer.name != null) 'name': layer.name,
              'startMs': layer.startMs,
              'durationMs': layer.durationMs,
              if (layer.elements.isNotEmpty)
                'elements': layer.elements
                    .map(
                      (element) => <String, Object?>{
                        'id': element.id,
                        'kind': element.kind,
                        if (element.name != null) 'name': element.name,
                        if (element.text != null) 'text': element.text,
                        if (element.properties.isNotEmpty)
                          'properties': element.properties,
                        if (element.channels.isNotEmpty)
                          'channels': element.channels
                              .map(_channelToJson)
                              .toList(growable: false),
                      },
                    )
                    .toList(growable: false),
              if (layer.channels.isNotEmpty)
                'channels':
                    layer.channels.map(_channelToJson).toList(growable: false),
            },
          )
          .toList(growable: false),
    },
  );
}

Map<String, Object?> _channelToJson(ReFusionSceneProgramChannel channel) {
  return <String, Object?>{
    'target': channel.target,
    'property': channel.property,
    'keyframes': channel.keyframes
        .map(
          (keyframe) => <String, Object?>{
            'timeMs': keyframe.timeMs,
            'value': keyframe.value,
            'easing': keyframe.easing,
          },
        )
        .toList(growable: false),
  };
}
