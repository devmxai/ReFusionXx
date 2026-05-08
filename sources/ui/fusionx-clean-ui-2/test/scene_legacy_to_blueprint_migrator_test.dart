import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/refusion_scene_program_models.dart';
import 'package:refusion_app/features/editor/domain/services/scene_legacy_to_blueprint_migrator.dart';

void main() {
  const migrator = SceneLegacyToBlueprintMigrator();

  test('tier A migrates prompt-like legacy scene into semantic blueprint', () {
    final result = migrator.migrate(
      legacyPayload: <String, Object?>{
        'schemaVersion': 'refusion.scene-program/v1',
        'name': 'Legacy Prompt',
        'durationMs': 3200,
        'frameRate': 30,
        'layers': <Object?>[
          <String, Object?>{
            'id': 'prompt-layer',
            'elements': <Object?>[
              <String, Object?>{
                'id': 'prompt-shell',
                'kind': 'shape',
                'properties': <String, Object?>{
                  'position': <String, Object?>{'x': 0, 'y': -40},
                  'width': 860,
                  'height': 112,
                },
              },
              <String, Object?>{
                'id': 'prompt-text',
                'kind': 'text',
                'text': 'generate new offer for my business',
                'properties': <String, Object?>{
                  'textFrame': <String, Object?>{
                    'width': 680,
                    'height': 60,
                  },
                },
              },
            ],
          },
        ],
      },
    );

    expect(result.tier, SceneLegacyBlueprintMigrationTier.tierA);
    expect(result.isMigrated, isTrue);
    expect(result.blueprintPayload, isNotNull);
    final components = result.blueprintPayload!['components'] as List<Object?>;
    final first = components.first as Map<String, Object?>;
    expect(first['type'], 'PromptInputBar');
  });

  test('tier C keeps unknown legacy scene as raw payload', () {
    final result = migrator.migrate(
      legacyPayload: <String, Object?>{
        'schemaVersion': 'refusion.scene-program/v1',
        'layers': <Object?>[
          <String, Object?>{
            'id': 'unknown-layer',
            'elements': <Object?>[
              <String, Object?>{
                'id': 'ambient-orb',
                'kind': 'shape',
                'properties': <String, Object?>{'width': 420, 'height': 420},
              },
            ],
          },
        ],
      },
    );

    expect(result.tier, SceneLegacyBlueprintMigrationTier.tierC);
    expect(result.isMigrated, isFalse);
  });

  test('tier D rejects payload that is not a layer graph', () {
    final result = migrator.migrate(
      legacyPayload: <String, Object?>{
        'schemaVersion': 'refusion.scene-program/v1',
        'name': 'Broken payload',
      },
    );

    expect(result.tier, SceneLegacyBlueprintMigrationTier.tierD);
    expect(result.isMigrated, isFalse);
    expect(
      result.issues.any(
        (issue) => issue.severity == ReFusionSceneProgramIssueSeverity.error,
      ),
      isTrue,
    );
  });
}
