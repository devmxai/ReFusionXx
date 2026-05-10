import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/refusion_scene_program_models.dart';
import 'package:refusion_app/features/editor/domain/services/scene_cta_button_component.dart';

void main() {
  const validator = SceneCtaButtonComponentValidator();

  ReFusionSceneProgram buildProgram({
    required String labelFitPolicy,
    required int iconLayerDurationMs,
    required double iconY,
  }) {
    return ReFusionSceneProgram(
      schemaVersion: 'refusion.scene-program/v1',
      name: 'CTA Button Contract',
      durationMs: 3000,
      frameRate: 30,
      layers: <ReFusionSceneProgramLayer>[
        ReFusionSceneProgramLayer(
          id: 'cta-shell-layer',
          kind: 'shape',
          startMs: 600,
          durationMs: 1800,
          elements: <ReFusionSceneProgramElement>[
            ReFusionSceneProgramElement(
              id: 'availableNowPill',
              kind: 'shape',
              properties: const <String, Object?>{
                'componentType': 'CTAButton',
                'layoutRole': 'container',
                'shapeKind': 'roundedRectangle',
                'position': <String, Object?>{'x': 0, 'y': 20},
                'width': 720,
                'height': 152,
                'cornerRadius': 76,
              },
            ),
          ],
        ),
        ReFusionSceneProgramLayer(
          id: 'cta-label-layer',
          kind: 'text',
          startMs: 760,
          durationMs: 1640,
          elements: <ReFusionSceneProgramElement>[
            ReFusionSceneProgramElement(
              id: 'availableNowText',
              kind: 'text',
              text: 'Available now',
              properties: <String, Object?>{
                'parentId': 'availableNowPill',
                'layoutRole': 'label',
                'position': const <String, Object?>{'x': -80, 'y': 20},
                'fontSize': 62,
                'fontWeight': 500,
                'lineHeight': 1,
                'letterSpacing': 0,
                'textFrame': <String, Object?>{
                  'width': 450,
                  'height': 62,
                  'maxLines': 1,
                  'fitPolicy': labelFitPolicy,
                },
              },
            ),
          ],
        ),
        ReFusionSceneProgramLayer(
          id: 'cta-arrow-layer',
          kind: 'shape',
          startMs: 820,
          durationMs: iconLayerDurationMs,
          elements: <ReFusionSceneProgramElement>[
            ReFusionSceneProgramElement(
              id: 'availableNowArrow',
              kind: 'icon',
              properties: <String, Object?>{
                'parentId': 'availableNowPill',
                'layoutRole': 'trailingAccessory',
                'icon': 'arrow-up',
                'position': <String, Object?>{'x': 230, 'y': iconY},
                'width': 58,
                'height': 58,
              },
            ),
          ],
        ),
      ],
    );
  }

  test('fails when label fit policy is not shrinkToFit', () {
    final result = validator.validate(
      buildProgram(
        labelFitPolicy: 'clip',
        iconLayerDurationMs: 1580,
        iconY: 20,
      ),
    );

    expect(result.isValid, isFalse);
    expect(
      result.issues.any(
        (issue) =>
            issue.severity == ReFusionSceneProgramIssueSeverity.error &&
            issue.message.contains('CTA_LABEL_OVERFLOW'),
      ),
      isTrue,
    );
  });

  test('fails when trailing icon outlives CTA shell', () {
    final result = validator.validate(
      buildProgram(
        labelFitPolicy: 'shrinkToFit',
        iconLayerDurationMs: 1900,
        iconY: 20,
      ),
    );

    expect(result.isValid, isFalse);
    expect(
      result.issues.any(
        (issue) =>
            issue.severity == ReFusionSceneProgramIssueSeverity.error &&
            issue.message.contains('CTA_CHILD_OUTLIVES_SHELL'),
      ),
      isTrue,
    );
  });

  test('fails when trailing icon baseline drifts from label', () {
    final result = validator.validate(
      buildProgram(
        labelFitPolicy: 'shrinkToFit',
        iconLayerDurationMs: 1580,
        iconY: 56,
      ),
    );

    expect(result.isValid, isFalse);
    expect(
      result.issues.any(
        (issue) =>
            issue.severity == ReFusionSceneProgramIssueSeverity.error &&
            issue.message.contains('CTA_ICON_BASELINE_DRIFT'),
      ),
      isTrue,
    );
  });

  test('passes typed CTAButton runtime proof', () {
    final result = validator.validate(
      buildProgram(
        labelFitPolicy: 'shrinkToFit',
        iconLayerDurationMs: 1580,
        iconY: 20,
      ),
    );
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
            issue.message.contains(SceneCtaButtonComponentValidator.proofTag),
      ),
      isTrue,
    );
  });
}
