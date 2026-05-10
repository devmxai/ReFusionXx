import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/refusion_scene_program_models.dart';
import 'package:refusion_app/features/editor/domain/services/scene_icon_alignment_validator.dart';

void main() {
  const validator = SceneIconAlignmentValidator();

  ReFusionSceneProgram buildProgram({
    required List<ReFusionSceneProgramElement> elements,
  }) {
    return ReFusionSceneProgram(
      schemaVersion: 'refusion.scene-program/v1',
      name: 'Optical Alignment Test',
      durationMs: 2200,
      frameRate: 30,
      layers: <ReFusionSceneProgramLayer>[
        ReFusionSceneProgramLayer(
          id: 'scene',
          kind: 'shape',
          startMs: 0,
          durationMs: 2200,
          elements: elements,
        ),
      ],
    );
  }

  test('accepts optically-centered app icon R glyph', () {
    final result = validator.validate(
      buildProgram(
        elements: <ReFusionSceneProgramElement>[
          ReFusionSceneProgramElement(
            id: 'app-shell',
            kind: 'shape',
            properties: const <String, Object?>{
              'position': <String, Object?>{'x': 0, 'y': 0},
              'width': 140,
              'height': 140,
            },
          ),
          ReFusionSceneProgramElement(
            id: 'app-glyph',
            kind: 'text',
            text: 'R',
            properties: const <String, Object?>{
              'parentId': 'app-shell',
              'position': <String, Object?>{'x': 4.2, 'y': 0},
              'width': 54,
              'height': 54,
            },
          ),
        ],
      ),
    );

    expect(result.isValid, isTrue);
    expect(
      result.issues.any(
        (issue) => issue.message.contains(kSceneIconAlignmentProofTag),
      ),
      isTrue,
    );
    expect(
      result.issues.where(
        (issue) => issue.severity == ReFusionSceneProgramIssueSeverity.error,
      ),
      isEmpty,
    );
  });

  test('rejects R glyph when optical center delta is violated', () {
    final result = validator.validate(
      buildProgram(
        elements: <ReFusionSceneProgramElement>[
          ReFusionSceneProgramElement(
            id: 'app-shell',
            kind: 'shape',
            properties: const <String, Object?>{
              'position': <String, Object?>{'x': 0, 'y': 0},
              'width': 140,
              'height': 140,
            },
          ),
          ReFusionSceneProgramElement(
            id: 'app-glyph',
            kind: 'text',
            text: 'R',
            properties: const <String, Object?>{
              'parentId': 'app-shell',
              'position': <String, Object?>{'x': -18, 'y': 0},
              'width': 54,
              'height': 54,
            },
          ),
        ],
      ),
    );

    expect(result.isValid, isFalse);
    expect(
      result.issues.any(
        (issue) =>
            issue.severity == ReFusionSceneProgramIssueSeverity.error &&
            issue.message.contains('fallbackReason=center_delta'),
      ),
      isTrue,
    );
  });

  test('rejects R glyph when delta exceeds strict 1.5px app threshold', () {
    final result = validator.validate(
      buildProgram(
        elements: <ReFusionSceneProgramElement>[
          ReFusionSceneProgramElement(
            id: 'app-shell',
            kind: 'shape',
            properties: const <String, Object?>{
              'position': <String, Object?>{'x': 0, 'y': 0},
              'width': 140,
              'height': 140,
            },
          ),
          ReFusionSceneProgramElement(
            id: 'app-glyph',
            kind: 'text',
            text: 'R',
            properties: const <String, Object?>{
              'parentId': 'app-shell',
              'position': <String, Object?>{'x': 6.0, 'y': 0},
              'width': 54,
              'height': 54,
            },
          ),
        ],
      ),
    );

    expect(result.isValid, isFalse);
    expect(
      result.issues.any(
        (issue) =>
            issue.severity == ReFusionSceneProgramIssueSeverity.error &&
            issue.message.contains('allowedDeltaPx=1.50'),
      ),
      isTrue,
    );
  });

  test('accepts centered plus and send icons in prompt slots', () {
    final result = validator.validate(
      buildProgram(
        elements: <ReFusionSceneProgramElement>[
          ReFusionSceneProgramElement(
            id: 'plus-slot',
            kind: 'shape',
            properties: const <String, Object?>{
              'position': <String, Object?>{'x': -300, 'y': 40},
              'width': 64,
              'height': 64,
            },
          ),
          ReFusionSceneProgramElement(
            id: 'plus-icon',
            kind: 'icon',
            properties: const <String, Object?>{
              'parentId': 'plus-slot',
              'icon': 'plus',
              'position': <String, Object?>{'x': -300, 'y': 40},
              'width': 24,
              'height': 24,
            },
          ),
          ReFusionSceneProgramElement(
            id: 'send-slot',
            kind: 'shape',
            properties: const <String, Object?>{
              'position': <String, Object?>{'x': 300, 'y': 40},
              'width': 72,
              'height': 72,
            },
          ),
          ReFusionSceneProgramElement(
            id: 'send-icon',
            kind: 'icon',
            properties: const <String, Object?>{
              'parentId': 'send-slot',
              'icon': 'send',
              'position': <String, Object?>{'x': 299.2, 'y': 39.4},
              'width': 26,
              'height': 26,
            },
          ),
        ],
      ),
    );

    expect(result.isValid, isTrue);
    expect(
      result.issues.where(
        (issue) => issue.severity == ReFusionSceneProgramIssueSeverity.error,
      ),
      isEmpty,
    );
  });

  test('rejects brand icon that violates safe-zone margins', () {
    final result = validator.validate(
      buildProgram(
        elements: <ReFusionSceneProgramElement>[
          ReFusionSceneProgramElement(
            id: 'brand-slot',
            kind: 'shape',
            properties: const <String, Object?>{
              'position': <String, Object?>{'x': 0, 'y': 0},
              'width': 80,
              'height': 80,
            },
          ),
          ReFusionSceneProgramElement(
            id: 'brand-icon',
            kind: 'icon',
            properties: const <String, Object?>{
              'parentId': 'brand-slot',
              'brandToken': r'$brand.chatgpt',
              'position': <String, Object?>{'x': 0, 'y': 0},
              'width': 70,
              'height': 70,
            },
          ),
        ],
      ),
    );

    expect(result.isValid, isFalse);
    expect(
      result.issues.any(
        (issue) =>
            issue.severity == ReFusionSceneProgramIssueSeverity.error &&
            issue.message.contains('fallbackReason=safe_zone'),
      ),
      isTrue,
    );
  });

  test('accepts up-triangle icon after optical downward correction', () {
    final result = validator.validate(
      buildProgram(
        elements: <ReFusionSceneProgramElement>[
          ReFusionSceneProgramElement(
            id: 'triangle-slot',
            kind: 'shape',
            properties: const <String, Object?>{
              'position': <String, Object?>{'x': 0, 'y': 0},
              'width': 100,
              'height': 100,
            },
          ),
          ReFusionSceneProgramElement(
            id: 'triangle-up',
            kind: 'icon',
            properties: const <String, Object?>{
              'parentId': 'triangle-slot',
              'icon': 'triangle-up',
              'position': <String, Object?>{'x': 0, 'y': 3},
              'width': 52,
              'height': 52,
            },
          ),
        ],
      ),
    );

    expect(result.isValid, isTrue);
    expect(
      result.issues.any(
        (issue) =>
            issue.message.contains('profileId=icon.triangle.up') &&
            issue.severity == ReFusionSceneProgramIssueSeverity.info,
      ),
      isTrue,
    );
  });
}
