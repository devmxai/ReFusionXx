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
    expect(preview.body['max_output_tokens'], 8192);
    expect(preview.prettyBody, contains('refusion.motion-director/v1'));
    expect(preview.prettyBody, contains('refusion.scene-program/v1'));
    expect(preview.prettyBody, contains('directorPlan'));
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

  test(
      'extracts direct Scene Program JSON from Codex responses output with warning',
      () {
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

    final extracted = service.extractSceneProgramPayload(
      rawResponse: rawResponse,
      transport: ReFusionSceneAgentTransport.responses,
    );
    final decoded =
        jsonDecode(extracted.sceneProgramJson) as Map<String, dynamic>;

    expect(decoded['schemaVersion'], 'refusion.scene-program/v1');
    expect(decoded['name'], 'Direct Codex Scene');
    expect(extracted.directorPlan, isNull);
    expect(
      extracted.directorIssues.where(
        (issue) => issue.message.contains('did not include `directorPlan`'),
      ),
      isNotEmpty,
    );
  });

  test('rejects direct Scene Program JSON with duplicate timing channels', () {
    final rawResponse = jsonEncode(
      <String, Object?>{
        'output_text': _sceneProgramJson(
          'Duplicate Timing Scene',
          duplicateChannel: true,
        ),
      },
    );

    expect(
      () => service.extractSceneProgramPayload(
        rawResponse: rawResponse,
        transport: ReFusionSceneAgentTransport.responses,
      ),
      throwsA(
        isA<KieSceneProgramAgentException>().having(
          (error) => error.message,
          'message',
          allOf(
            contains('professional timing contract'),
            contains('Fix: merge all keyframes'),
          ),
        ),
      ),
    );
  });

  test(
      'extracts wrapped directorPlan and Scene Program JSON from Claude output',
      () {
    final rawResponse = jsonEncode(
      <String, Object?>{
        'content': <Object?>[
          <String, Object?>{
            'type': 'text',
            'text': jsonEncode(
              <String, Object?>{
                'directorPlan': _directorPlanJson(),
                'sceneProgram': jsonDecode(_sceneProgramJson('Claude Scene')),
              },
            ),
          },
        ],
      },
    );

    final extracted = service.extractSceneProgramPayload(
      rawResponse: rawResponse,
      transport: ReFusionSceneAgentTransport.claudeMessages,
    );
    final decoded =
        jsonDecode(extracted.sceneProgramJson) as Map<String, dynamic>;

    expect(decoded['schemaVersion'], 'refusion.scene-program/v1');
    expect(decoded['name'], 'Claude Scene');
    expect(extracted.directorPlan, isNotNull);
    expect(extracted.directorPlan!.beats, hasLength(3));
    expect(
      extracted.directorIssues.where(
        (issue) => issue.severity.name == 'error',
      ),
      isEmpty,
    );
  });

  test('extracts pasted directorPlan and Scene Program wrapper content', () {
    final extracted = service.extractSceneProgramPayloadFromContent(
      content: jsonEncode(
        <String, Object?>{
          'directorPlan': _directorPlanJson(),
          'sceneProgram': jsonDecode(_sceneProgramJson('Manual KIE Scene')),
        },
      ),
    );
    final decoded =
        jsonDecode(extracted.sceneProgramJson) as Map<String, dynamic>;

    expect(decoded['schemaVersion'], 'refusion.scene-program/v1');
    expect(decoded['name'], 'Manual KIE Scene');
    expect(extracted.directorPlan, isNotNull);
  });

  test('extracts director wrapper with shared-component handoff beats', () {
    final extracted = service.extractSceneProgramPayloadFromContent(
      content: jsonEncode(
        <String, Object?>{
          'directorPlan': _handoffDirectorPlanJson(),
          'sceneProgram': jsonDecode(_handoffSceneProgramJson()),
        },
      ),
    );
    final decoded =
        jsonDecode(extracted.sceneProgramJson) as Map<String, dynamic>;

    expect(decoded['schemaVersion'], 'refusion.scene-program/v1');
    expect(decoded['name'], 'Prompt Handoff Scene');
    expect(
      extracted.directorIssues.where(
        (issue) => issue.message.contains('Accepted as intentional handoff'),
      ),
      isNotEmpty,
    );
    expect(
      extracted.directorIssues.where(
        (issue) => issue.severity.name == 'error',
      ),
      isEmpty,
    );
  });

  test('rejects wrapped Scene Program when directorPlan fails lint', () {
    final rawResponse = jsonEncode(
      <String, Object?>{
        'output': <Object?>[
          <String, Object?>{
            'type': 'message',
            'content': <Object?>[
              <String, Object?>{
                'type': 'output_text',
                'text': jsonEncode(
                  <String, Object?>{
                    'directorPlan': _directorPlanJson(reverseTyping: true),
                    'sceneProgram':
                        jsonDecode(_sceneProgramJson('Bad Director Scene')),
                  },
                ),
              },
            ],
          },
        ],
      },
    );

    expect(
      () => service.extractSceneProgramPayload(
        rawResponse: rawResponse,
        transport: ReFusionSceneAgentTransport.responses,
      ),
      throwsA(
        isA<KieSceneProgramAgentException>().having(
          (error) => error.message,
          'message',
          contains('directorPlan failed validation'),
        ),
      ),
    );
  });

  test('rejects wrapped Scene Program when directorPlan is malformed', () {
    final rawResponse = jsonEncode(
      <String, Object?>{
        'output_text': jsonEncode(
          <String, Object?>{
            'directorPlan': <Object?>['not', 'a', 'plan'],
            'sceneProgram': jsonDecode(_sceneProgramJson('Malformed Director')),
          },
        ),
      },
    );

    expect(
      () => service.extractSceneProgramPayload(
        rawResponse: rawResponse,
        transport: ReFusionSceneAgentTransport.responses,
      ),
      throwsA(
        isA<KieSceneProgramAgentException>().having(
          (error) => error.message,
          'message',
          contains('Director plan must be a JSON object'),
        ),
      ),
    );
  });

  test('falls back to compiled directorPlan when Scene Program mismatches', () {
    final rawResponse = jsonEncode(
      <String, Object?>{
        'output_text': jsonEncode(
          <String, Object?>{
            'directorPlan': _directorPlanJson(),
            'sceneProgram': jsonDecode(
              _sceneProgramJson('Mismatched Director Scene',
                  property: 'opacity'),
            ),
          },
        ),
      },
    );

    final extracted = service.extractSceneProgramPayload(
      rawResponse: rawResponse,
      transport: ReFusionSceneAgentTransport.responses,
    );
    final decoded =
        jsonDecode(extracted.sceneProgramJson) as Map<String, dynamic>;

    expect(decoded['schemaVersion'], 'refusion.scene-program/v1');
    expect(decoded['name'], 'Prompt Director');
    expect(
      extracted.directorIssues.where(
        (issue) => issue.message.contains('compiled the directorPlan locally'),
      ),
      isNotEmpty,
    );
    expect(
      extracted.directorIssues.where(
        (issue) => issue.severity.name == 'error',
      ),
      isEmpty,
    );
  });

  test('falls back to compiled directorPlan when Scene Program timing fails',
      () {
    final rawResponse = jsonEncode(
      <String, Object?>{
        'output_text': jsonEncode(
          <String, Object?>{
            'directorPlan': _directorPlanJson(),
            'sceneProgram': jsonDecode(
              _sceneProgramJson(
                'Duplicate Timed Director Scene',
                duplicateChannel: true,
              ),
            ),
          },
        ),
      },
    );

    final extracted = service.extractSceneProgramPayload(
      rawResponse: rawResponse,
      transport: ReFusionSceneAgentTransport.responses,
    );
    final decoded =
        jsonDecode(extracted.sceneProgramJson) as Map<String, dynamic>;

    expect(decoded['schemaVersion'], 'refusion.scene-program/v1');
    expect(decoded['name'], 'Prompt Director');
    expect(
      extracted.directorIssues.where(
        (issue) => issue.message.contains('timing contract'),
      ),
      isNotEmpty,
    );
    expect(
      extracted.directorIssues.where(
        (issue) => issue.severity.name == 'error',
      ),
      isEmpty,
    );
  });

  test('compiles directorPlan-only response into Scene Program JSON', () {
    final rawResponse = jsonEncode(
      <String, Object?>{
        'output_text': jsonEncode(
          <String, Object?>{
            'directorPlan': _directorPlanJson(),
          },
        ),
      },
    );

    final extracted = service.extractSceneProgramPayload(
      rawResponse: rawResponse,
      transport: ReFusionSceneAgentTransport.responses,
    );
    final decoded =
        jsonDecode(extracted.sceneProgramJson) as Map<String, dynamic>;

    expect(decoded['schemaVersion'], 'refusion.scene-program/v1');
    expect(decoded['name'], 'Prompt Director');
    expect(decoded['layers'], isA<List<Object?>>());
    expect(decoded['layers'], isNotEmpty);
    expect(extracted.directorPlan, isNotNull);
  });
}

Map<String, Object?> _directorPlanJson({bool reverseTyping = false}) {
  return <String, Object?>{
    'schemaVersion': 'refusion.motion-director/v1',
    'name': 'Prompt Director',
    'durationMs': 1600,
    'frameRate': 30,
    'canvasWidth': 1080,
    'canvasHeight': 1920,
    'components': <Object?>[
      <String, Object?>{
        'id': 'title',
        'role': 'text.typewriter',
        'label': 'Title',
      },
    ],
    'beats': <Object?>[
      <String, Object?>{
        'id': 'enter',
        'label': 'Enter',
        'startMs': 0,
        'endMs': 300,
        'intent': 'Text prepares.',
        'componentRefs': <String>['title'],
      },
      <String, Object?>{
        'id': 'typing',
        'label': 'Typing',
        'startMs': 300,
        'endMs': 1200,
        'intent': 'Text types.',
        'componentRefs': <String>['title'],
      },
      <String, Object?>{
        'id': 'readable-hold',
        'label': 'Readable hold',
        'startMs': 1200,
        'endMs': 1600,
        'intent': 'Hold the typed text so it can be read.',
        'componentRefs': <String>['title'],
      },
    ],
    'primitives': <Object?>[
      <String, Object?>{
        'id': 'type-on',
        'beatId': 'typing',
        'targetComponentId': 'title',
        'kind': 'typewriter',
        'property': 'typewriterProgress',
        'startMs': 300,
        'endMs': 1200,
        'fromValue': reverseTyping ? 1.0 : 0.0,
        'toValue': reverseTyping ? 0.0 : 1.0,
        'easing': 'linear',
      },
    ],
  };
}

String _sceneProgramJson(
  String name, {
  String property = 'typewriterProgress',
  bool duplicateChannel = false,
}) {
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
                  'property': property,
                  'keyframes': <Object?>[
                    <String, Object?>{'timeMs': 0, 'value': 0},
                    <String, Object?>{'timeMs': 1200, 'value': 1},
                  ],
                },
                if (duplicateChannel)
                  <String, Object?>{
                    'property': property,
                    'keyframes': <Object?>[
                      <String, Object?>{'timeMs': 0, 'value': 1},
                      <String, Object?>{'timeMs': 1200, 'value': 0},
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

Map<String, Object?> _handoffDirectorPlanJson() {
  return <String, Object?>{
    'schemaVersion': 'refusion.motion-director/v1',
    'name': 'Prompt Handoff',
    'durationMs': 3600,
    'frameRate': 30,
    'canvasWidth': 1080,
    'canvasHeight': 1920,
    'components': <Object?>[
      <String, Object?>{
        'id': 'promptShell',
        'role': 'promptInputBar.shell',
        'label': 'Prompt Shell',
      },
    ],
    'beats': <Object?>[
      <String, Object?>{
        'id': 'input-circle',
        'label': 'Input Circle',
        'startMs': 300,
        'endMs': 1500,
        'intent': 'The prompt shell scales into view.',
        'componentRefs': <String>['promptShell'],
      },
      <String, Object?>{
        'id': 'input-expand',
        'label': 'Input Expand',
        'startMs': 1400,
        'endMs': 3100,
        'intent': 'The same shell expands into an input field.',
        'componentRefs': <String>['promptShell'],
      },
    ],
    'primitives': <Object?>[
      <String, Object?>{
        'id': 'shell-pop',
        'beatId': 'input-circle',
        'targetComponentId': 'promptShell',
        'kind': 'scale',
        'property': 'scale',
        'startMs': 300,
        'endMs': 1500,
        'fromValue': 0.2,
        'toValue': 1.0,
      },
      <String, Object?>{
        'id': 'shell-expand-width',
        'beatId': 'input-expand',
        'targetComponentId': 'promptShell',
        'kind': 'widthGrow',
        'property': 'width',
        'startMs': 1400,
        'endMs': 3100,
        'fromValue': 112,
        'toValue': 780,
      },
    ],
  };
}

String _handoffSceneProgramJson() {
  return jsonEncode(
    <String, Object?>{
      'schemaVersion': 'refusion.scene-program/v1',
      'name': 'Prompt Handoff Scene',
      'durationMs': 3600,
      'frameRate': 30,
      'layers': <Object?>[
        <String, Object?>{
          'id': 'promptShell-layer',
          'kind': 'shape',
          'startMs': 0,
          'durationMs': 3600,
          'elements': <Object?>[
            <String, Object?>{
              'id': 'promptShell',
              'kind': 'shape',
              'properties': <String, Object?>{
                'shapeKind': 'roundedRectangle',
                'width': 112,
                'height': 112,
                'cornerRadius': 56,
              },
              'channels': <Object?>[
                <String, Object?>{
                  'property': 'scale',
                  'keyframes': <Object?>[
                    <String, Object?>{'timeMs': 300, 'value': 0.2},
                    <String, Object?>{'timeMs': 1500, 'value': 1.0},
                  ],
                },
                <String, Object?>{
                  'property': 'width',
                  'keyframes': <Object?>[
                    <String, Object?>{'timeMs': 1400, 'value': 112},
                    <String, Object?>{'timeMs': 3100, 'value': 780},
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
