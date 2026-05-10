import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/refusion_scene_program_models.dart';
import 'package:refusion_app/features/editor/domain/services/kie_scene_program_agent_service.dart';
import 'package:refusion_app/features/editor/domain/services/refusion_scene_program_import_service.dart';
import 'package:refusion_app/features/editor/domain/services/scene_feature_card_component.dart';

void main() {
  const validator = SceneFeatureCardComponentValidator();

  ReFusionSceneProgram buildSingleCardProgram({
    required String bodyText,
    required String bodyFitPolicy,
    required int bodyLayerDurationMs,
  }) {
    return ReFusionSceneProgram(
      schemaVersion: 'refusion.scene-program/v1',
      name: 'Feature Card Contract',
      durationMs: 4000,
      frameRate: 30,
      layers: <ReFusionSceneProgramLayer>[
        ReFusionSceneProgramLayer(
          id: 'file-card-shell-layer',
          kind: 'shape',
          startMs: 400,
          durationMs: 2000,
          elements: <ReFusionSceneProgramElement>[
            ReFusionSceneProgramElement(
              id: 'fileCardOneShell',
              kind: 'shape',
              properties: const <String, Object?>{
                'layoutRole': 'container',
                'componentType': 'FeatureCard',
                'shapeKind': 'roundedRectangle',
                'position': <String, Object?>{'x': 0, 'y': -80},
                'width': 720,
                'height': 190,
                'cornerRadius': 42,
              },
            ),
          ],
        ),
        ReFusionSceneProgramLayer(
          id: 'file-card-icon-box-layer',
          kind: 'shape',
          startMs: 470,
          durationMs: 1930,
          elements: <ReFusionSceneProgramElement>[
            ReFusionSceneProgramElement(
              id: 'fileCardOneIconBox',
              kind: 'shape',
              properties: const <String, Object?>{
                'parentId': 'fileCardOneShell',
                'layoutRole': 'container',
                'position': <String, Object?>{'x': -235, 'y': -80},
                'width': 94,
                'height': 94,
                'cornerRadius': 18,
              },
            ),
          ],
        ),
        ReFusionSceneProgramLayer(
          id: 'file-card-icon-layer',
          kind: 'shape',
          startMs: 520,
          durationMs: 1880,
          elements: <ReFusionSceneProgramElement>[
            ReFusionSceneProgramElement(
              id: 'fileCardOneIcon',
              kind: 'icon',
              properties: const <String, Object?>{
                'parentId': 'fileCardOneIconBox',
                'icon': 'file',
                'position': <String, Object?>{'x': -235, 'y': -80},
                'width': 40,
                'height': 40,
              },
            ),
          ],
        ),
        ReFusionSceneProgramLayer(
          id: 'file-card-title-layer',
          kind: 'text',
          startMs: 560,
          durationMs: 1840,
          elements: <ReFusionSceneProgramElement>[
            ReFusionSceneProgramElement(
              id: 'fileCardOneTitle',
              kind: 'text',
              text: 'sales_deck.pdf',
              properties: const <String, Object?>{
                'parentId': 'fileCardOneShell',
                'position': <String, Object?>{'x': 90, 'y': -106},
                'fontSize': 40,
                'fontWeight': 560,
                'lineHeight': 1,
                'textFrame': <String, Object?>{
                  'width': 420,
                  'height': 50,
                  'maxLines': 1,
                  'fitPolicy': 'shrinkToFit',
                },
              },
            ),
          ],
        ),
        ReFusionSceneProgramLayer(
          id: 'file-card-body-layer',
          kind: 'text',
          startMs: 620,
          durationMs: bodyLayerDurationMs,
          elements: <ReFusionSceneProgramElement>[
            ReFusionSceneProgramElement(
              id: 'fileCardOneStatus',
              kind: 'text',
              text: bodyText,
              properties: <String, Object?>{
                'parentId': 'fileCardOneShell',
                'position': const <String, Object?>{'x': 80, 'y': -42},
                'fontSize': 32,
                'fontWeight': 430,
                'lineHeight': 1,
                'textFrame': <String, Object?>{
                  'width': 390,
                  'height': 40,
                  'maxLines': 1,
                  'fitPolicy': bodyFitPolicy,
                  'minFontSize': 22,
                },
              },
            ),
          ],
        ),
      ],
    );
  }

  test('fails when body text is clipped without fit policy', () {
    final result = validator.validate(
      buildSingleCardProgram(
        bodyText: 'Extremely long sentence that will not fit one line cleanly',
        bodyFitPolicy: 'clip',
        bodyLayerDurationMs: 1780,
      ),
    );

    expect(result.isValid, isFalse);
    expect(
      result.issues.any(
        (issue) =>
            issue.severity == ReFusionSceneProgramIssueSeverity.error &&
            issue.message.contains('FEATURE_TEXT_CLIPPED'),
      ),
      isTrue,
    );
  });

  test('fails when body text ends with dangling phrase fragment', () {
    final result = validator.validate(
      buildSingleCardProgram(
        bodyText: 'Retouch, grade, and',
        bodyFitPolicy: 'shrinkToFit',
        bodyLayerDurationMs: 1780,
      ),
    );

    expect(result.isValid, isFalse);
    expect(
      result.issues.any(
        (issue) =>
            issue.severity == ReFusionSceneProgramIssueSeverity.error &&
            issue.message.contains('FEATURE_SENTENCE_CUT_MID_PHRASE'),
      ),
      isTrue,
    );
  });

  test('fails when card child outlives shell lifecycle', () {
    final result = validator.validate(
      buildSingleCardProgram(
        bodyText: 'Analyzing...',
        bodyFitPolicy: 'shrinkToFit',
        bodyLayerDurationMs: 2200,
      ),
    );

    expect(result.isValid, isFalse);
    expect(
      result.issues.any(
        (issue) =>
            issue.severity == ReFusionSceneProgramIssueSeverity.error &&
            issue.message.contains('FEATURE_CHILD_VISIBLE_AFTER_CARD_EXIT'),
      ),
      isTrue,
    );
  });

  test('passes Professional Test Version 2 feature card hierarchy proof', () {
    final source = File(
      'assets/scene_programs/professional_test_version_2_scene.json',
    ).readAsStringSync();
    final payload = KieSceneProgramAgentService()
        .extractSceneProgramPayloadFromContent(content: source);
    final program = ReFusionSceneProgramImportService()
        .validate(source: payload.sceneProgramJson)
        .program;
    expect(program, isNotNull);

    final result = validator.validate(program!);
    final errors = result.issues.where(
      (issue) => issue.severity == ReFusionSceneProgramIssueSeverity.error,
    );
    expect(
      errors,
      isEmpty,
      reason: result.issues
          .map((issue) => '${issue.severity} ${issue.path}: ${issue.message}')
          .join('\n'),
    );
    expect(
      result.issues.any(
        (issue) =>
            issue.message.contains(SceneFeatureCardComponentValidator.proofTag),
      ),
      isTrue,
    );
  });
}
