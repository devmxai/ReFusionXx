import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/refusion_scene_program_models.dart';
import 'package:refusion_app/features/editor/domain/services/scene_program_layout_contract.dart';

void main() {
  const validator = SceneProgramLayoutContractValidator();

  test('accepts an inspectable container and child relationship', () {
    final result = validator.validate(
      ReFusionSceneProgram(
        schemaVersion: 'refusion.scene-program/v1',
        name: 'Layout Contract',
        durationMs: 2400,
        frameRate: 30,
        layers: <ReFusionSceneProgramLayer>[
          ReFusionSceneProgramLayer(
            id: 'container-layer',
            kind: 'shape',
            startMs: 0,
            durationMs: 2400,
            elements: <ReFusionSceneProgramElement>[
              ReFusionSceneProgramElement(
                id: 'prompt-shell',
                kind: 'shape',
                properties: const <String, Object?>{
                  'layoutRole': 'container',
                },
              ),
              ReFusionSceneProgramElement(
                id: 'prompt-text',
                kind: 'text',
                text: 'Build an app',
                properties: const <String, Object?>{
                  'parentId': 'prompt-shell',
                  'layout': <String, Object?>{
                    'role': 'content',
                    'align': 'centerLeft',
                  },
                },
              ),
            ],
          ),
        ],
      ),
    );

    expect(result.isValid, isTrue);
    expect(result.issues, isEmpty);
  });

  test('rejects missing parent ids', () {
    final result = validator.validate(
      ReFusionSceneProgram(
        schemaVersion: 'refusion.scene-program/v1',
        name: 'Missing Parent',
        durationMs: 1000,
        frameRate: 30,
        layers: <ReFusionSceneProgramLayer>[
          ReFusionSceneProgramLayer(
            id: 'text-layer',
            kind: 'text',
            startMs: 0,
            durationMs: 1000,
            elements: <ReFusionSceneProgramElement>[
              ReFusionSceneProgramElement(
                id: 'prompt-text',
                kind: 'text',
                text: 'Hello',
                properties: const <String, Object?>{
                  'parentId': 'missing-container',
                },
              ),
            ],
          ),
        ],
      ),
    );

    expect(result.isValid, isFalse);
    expect(
      result.issues.where(
        (issue) =>
            issue.severity == ReFusionSceneProgramIssueSeverity.error &&
            issue.message.contains('does not exist'),
      ),
      isNotEmpty,
    );
  });

  test('rejects parent cycles', () {
    final result = validator.validate(
      ReFusionSceneProgram(
        schemaVersion: 'refusion.scene-program/v1',
        name: 'Cyclic Parents',
        durationMs: 1000,
        frameRate: 30,
        layers: <ReFusionSceneProgramLayer>[
          ReFusionSceneProgramLayer(
            id: 'shape-layer',
            kind: 'shape',
            startMs: 0,
            durationMs: 1000,
            elements: <ReFusionSceneProgramElement>[
              ReFusionSceneProgramElement(
                id: 'card-a',
                kind: 'shape',
                properties: const <String, Object?>{
                  'layoutRole': 'container',
                  'parentId': 'card-b',
                },
              ),
              ReFusionSceneProgramElement(
                id: 'card-b',
                kind: 'shape',
                properties: const <String, Object?>{
                  'layoutRole': 'container',
                  'parentId': 'card-a',
                },
              ),
            ],
          ),
        ],
      ),
    );

    expect(result.isValid, isFalse);
    expect(
      result.issues.where(
        (issue) =>
            issue.severity == ReFusionSceneProgramIssueSeverity.error &&
            issue.message.contains('contains a cycle'),
      ),
      isNotEmpty,
    );
  });

  test('rejects children that outlive their parent group', () {
    final result = validator.validate(
      ReFusionSceneProgram(
        schemaVersion: 'refusion.scene-program/v1',
        name: 'Lifetime Mismatch',
        durationMs: 2400,
        frameRate: 30,
        layers: <ReFusionSceneProgramLayer>[
          ReFusionSceneProgramLayer(
            id: 'container-layer',
            kind: 'shape',
            startMs: 500,
            durationMs: 900,
            elements: <ReFusionSceneProgramElement>[
              ReFusionSceneProgramElement(
                id: 'prompt-shell',
                kind: 'shape',
                properties: const <String, Object?>{
                  'layoutRole': 'container',
                },
              ),
            ],
          ),
          ReFusionSceneProgramLayer(
            id: 'text-layer',
            kind: 'text',
            startMs: 0,
            durationMs: 1800,
            elements: <ReFusionSceneProgramElement>[
              ReFusionSceneProgramElement(
                id: 'prompt-text',
                kind: 'text',
                text: 'Hello',
                properties: const <String, Object?>{
                  'parentId': 'prompt-shell',
                },
              ),
            ],
          ),
        ],
      ),
    );

    expect(result.isValid, isFalse);
    expect(
      result.issues.where(
        (issue) =>
            issue.severity == ReFusionSceneProgramIssueSeverity.error &&
            issue.message.contains('lifetime must stay inside parent'),
      ),
      isNotEmpty,
    );
  });
}
