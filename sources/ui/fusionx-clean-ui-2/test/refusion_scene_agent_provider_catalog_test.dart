import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/services/kie_scene_program_agent_service.dart';
import 'package:refusion_app/features/editor/domain/services/refusion_scene_agent_provider_catalog.dart';

void main() {
  const catalog = ReFusionSceneAgentProviderCatalog();
  final service = KieSceneProgramAgentService(catalog: catalog);

  test('exposes only Codex and Claude Opus scene generation profiles', () {
    expect(ReFusionSceneAgentProviderCatalog.profiles, hasLength(2));
    expect(
      ReFusionSceneAgentProviderCatalog.profiles.map((profile) => profile.id),
      <String>[
        'kie-codex-scene-director',
        'kie-claude-opus-scene-director',
      ],
    );
    expect(
      ReFusionSceneAgentProviderCatalog.profiles.first.modelId,
      'gpt-5.4-codex',
    );
    expect(
      ReFusionSceneAgentProviderCatalog.profiles.last.modelId,
      'claude-opus-4-6',
    );
  });

  test('builds Codex responses request with director and scene contracts', () {
    final preview = catalog.buildRequestPreview(
      profile: ReFusionSceneAgentProviderCatalog.profiles.first,
      prompt: 'Create a prompt bar that types hello world.',
      durationMs: 4200,
      canvasWidth: 1080,
      canvasHeight: 1920,
      frameRate: 30,
    );

    expect(preview.endpointUrl, endsWith('/api/v1/responses'));
    expect(preview.body['model'], 'gpt-5.4-codex');
    expect(preview.prettyBody, contains('refusion.motion-director/v1'));
    expect(preview.prettyBody, contains('refusion.scene-program/v1'));
    expect(preview.prettyBody, contains('typewriterProgress'));
    expect(preview.prettyBody, contains('Create a prompt bar'));
  });

  test('builds Claude Opus messages request with only JSON output contract',
      () {
    final profile = catalog.profileById('kie-claude-opus-scene-director');
    final preview = catalog.buildRequestPreview(
      profile: profile,
      prompt: 'Build an elegant line reveal.',
      durationMs: 3600,
      canvasWidth: 1080,
      canvasHeight: 1920,
      frameRate: 30,
    );

    expect(preview.endpointUrl, endsWith('/claude/v1/messages'));
    expect(preview.body['model'], 'claude-opus-4-6');
    expect(preview.body['messages'], isA<List<Object?>>());
    expect(preview.body['max_tokens'], 10000);
    expect(preview.prettyBody, contains('Build an elegant line reveal.'));
    expect(preview.prettyBody, contains('No markdown'));
  });

  test('extracts direct Scene Program JSON from Codex responses output', () {
    final rawResponse = jsonEncode(
      <String, Object?>{
        'output': <Object?>[
          <String, Object?>{
            'type': 'message',
            'content': <Object?>[
              <String, Object?>{
                'type': 'output_text',
                'text': _sceneProgramJson('Direct Codex Scene'),
              },
            ],
          },
        ],
      },
    );

    final extracted = service.extractSceneProgramJson(
      rawResponse: rawResponse,
      transport: ReFusionSceneAgentTransport.responses,
    );
    final decoded = jsonDecode(extracted) as Map<String, dynamic>;

    expect(decoded['schemaVersion'], 'refusion.scene-program/v1');
    expect(decoded['name'], 'Direct Codex Scene');
  });

  test('extracts wrapped Scene Program JSON from Claude messages output', () {
    final rawResponse = jsonEncode(
      <String, Object?>{
        'content': <Object?>[
          <String, Object?>{
            'type': 'text',
            'text': jsonEncode(
              <String, Object?>{
                'sceneProgram': jsonDecode(_sceneProgramJson('Claude Scene')),
              },
            ),
          },
        ],
      },
    );

    final extracted = service.extractSceneProgramJson(
      rawResponse: rawResponse,
      transport: ReFusionSceneAgentTransport.claudeMessages,
    );
    final decoded = jsonDecode(extracted) as Map<String, dynamic>;

    expect(decoded['schemaVersion'], 'refusion.scene-program/v1');
    expect(decoded['name'], 'Claude Scene');
  });
}

String _sceneProgramJson(String name) {
  return jsonEncode(
    <String, Object?>{
      'schemaVersion': 'refusion.scene-program/v1',
      'name': name,
      'durationMs': 1200,
      'frameRate': 30,
      'layers': <Object?>[
        <String, Object?>{
          'id': 'title-layer',
          'kind': 'text',
          'startMs': 0,
          'durationMs': 1200,
          'elements': <Object?>[
            <String, Object?>{
              'id': 'title',
              'kind': 'text',
              'text': 'ReFusion',
              'channels': <Object?>[
                <String, Object?>{
                  'property': 'opacity',
                  'keyframes': <Object?>[
                    <String, Object?>{'timeMs': 0, 'value': 0},
                    <String, Object?>{'timeMs': 1200, 'value': 1},
                  ],
                },
              ],
            },
          ],
        },
      ],
    },
  );
}
