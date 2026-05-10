import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/composition_scene_clip_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/domain/models/refusion_motion_director_models.dart';
import 'package:refusion_app/features/editor/domain/models/refusion_scene_program_models.dart';
import 'package:refusion_app/features/editor/domain/services/refusion_motion_director_scene_program_compiler.dart';
import 'package:refusion_app/features/editor/domain/services/refusion_scene_program_authoring_service.dart';
import 'package:refusion_app/features/editor/domain/services/scene_design_scorecard.dart';
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
  final goodDir =
      Directory('$root/test/fixtures/director_briefs/v5/good');

  MotionProjectModel baseProject() {
    return MotionProjectModel(
      id: 'lovable-parity-project',
      name: 'Lovable Parity Project',
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

  test('PDS-22 lovable parity suite enforces professional acceptance', () {
    final fixtureFiles = goodDir
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.json'))
        .toList(growable: false)
      ..sort((left, right) => left.path.compareTo(right.path));
    expect(fixtureFiles.length, 20);

    var gatePassCount = 0;
    var gateBlockedCount = 0;

    for (var index = 0; index < fixtureFiles.length; index += 1) {
      final file = fixtureFiles[index];
      final payload = jsonDecode(file.readAsStringSync()) as Object?;

      final intelligence = directorIntelligence.compileFromRawBrief(payload);
      expect(
        intelligence.isValid,
        isTrue,
        reason:
            '${file.path} -> ${_directorErrors(intelligence.issues).join(' | ')}',
      );
      final plan = intelligence.plan!;

      // Determinism gate: two compiles from same plan must produce identical
      // scene-program JSON hash.
      final compileA = directorCompiler.compile(plan);
      final compileB = directorCompiler.compile(plan);
      expect(compileA.isValid, isTrue, reason: file.path);
      expect(compileB.isValid, isTrue, reason: file.path);
      final hashA = _stableHash(_encodeSceneProgram(compileA.program!));
      final hashB = _stableHash(_encodeSceneProgram(compileB.program!));
      expect(
        hashA,
        equals(hashB),
        reason: '${file.path} -> non-deterministic scene program compile',
      );

      final authoring = authoringService.importSceneProgram(
        ReFusionSceneProgramAuthoringRequest(
          source: _encodeSceneProgram(compileA.program!),
          fileName: file.uri.pathSegments.last,
          projectId: 'lovable-parity-project',
          sceneId: 'lovable-parity-scene',
        ),
      );

      final gate = preRenderGate.validate(
        authoringResult: authoring,
        sceneId: 'root-scene',
      );
      if (gate.blocked) {
        gateBlockedCount += 1;
        expect(
          gate.issues.any(
            (issue) => issue.severity == ReFusionSceneProgramIssueSeverity.error,
          ),
          isTrue,
          reason: '${file.path} -> blocked scene without error payload',
        );
        expect(
          gate.fallbackReason != 'none',
          isTrue,
          reason: '${file.path} -> blocked scene missing fallback reason',
        );
        continue;
      }

      gatePassCount += 1;
      expect(authoring.isValid, isTrue, reason: file.path);

      final scoreIssue = authoring.issues.firstWhere(
        (issue) => issue.message.contains(kSceneDesignScorecardProofTag),
        orElse: () => const ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message: '',
          path: 'scene.designScorecard',
        ),
      );
      expect(
        scoreIssue.message.contains(kSceneDesignScorecardProofTag),
        isTrue,
        reason: '${file.path} -> missing design scorecard proof',
      );
      final overall = _extractMetric(scoreIssue.message, 'overall');
      final typography = _extractMetric(scoreIssue.message, 'typography');
      final spacing = _extractMetric(scoreIssue.message, 'spacing');
      final iconText = _extractMetric(scoreIssue.message, 'iconText');
      final motion = _extractMetric(scoreIssue.message, 'motion');
      final density = _extractMetric(scoreIssue.message, 'density');
      expect(overall >= 74, isTrue, reason: '${file.path} -> overall=$overall');
      expect(
        typography >= 62,
        isTrue,
        reason: '${file.path} -> typography=$typography',
      );
      expect(spacing >= 62, isTrue, reason: '${file.path} -> spacing=$spacing');
      expect(iconText >= 62, isTrue, reason: '${file.path} -> iconText=$iconText');
      expect(motion >= 62, isTrue, reason: '${file.path} -> motion=$motion');
      expect(density >= 62, isTrue, reason: '${file.path} -> density=$density');

      final apply = applyTransaction.apply(
        SceneProgramApplyTransactionRequest(
          baseProject: baseProject(),
          authoringResult: authoring,
          rootSceneId: 'root-scene',
          clipId: 'lovable-parity-clip-$index',
          sourceSceneId: 'lovable-parity-source-$index',
          clipName: 'Lovable Parity Clip $index',
        ),
      );
      expect(apply, isNotNull, reason: '${file.path} -> apply failed');
    }

    expect(gatePassCount + gateBlockedCount, fixtureFiles.length);
    expect(
      gateBlockedCount,
      greaterThan(0),
      reason:
          'Suite must prove strict QA/apply gates are actively blocking fatal scenes.',
    );
  });
}

List<String> _directorErrors(List<ReFusionMotionDirectorIssue> issues) {
  return issues
      .where((issue) => issue.severity == ReFusionMotionDirectorIssueSeverity.error)
      .map((issue) => '${issue.path}: ${issue.message}')
      .toList(growable: false);
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

int _extractMetric(String message, String key) {
  final match = RegExp('$key=([0-9]+)').firstMatch(message);
  if (match == null) {
    return -1;
  }
  return int.tryParse(match.group(1) ?? '') ?? -1;
}

String _stableHash(String value) {
  var hash = 0xcbf29ce484222325;
  for (final unit in value.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
  }
  return hash.toRadixString(16).padLeft(16, '0');
}
