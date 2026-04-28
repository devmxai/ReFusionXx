import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/services/kie_motion_agent_service.dart';
import 'package:refusion_app/features/editor/domain/services/refusion_motion_agent_provider_catalog.dart';

void main() {
  final service = KieMotionAgentService();

  const patch = <String, Object?>{
    'schemaVersion': 'refusion.motion-patch/v1',
    'name': 'Generated Text Move',
    'scopeDurationMs': 1200,
    'operations': <Map<String, Object?>>[
      <String, Object?>{
        'action': 'animate',
        'target': 'element:headline',
        'property': 'opacity',
        'keyframes': <Map<String, Object?>>[
          <String, Object?>{'timeMs': 0, 'value': 0},
          <String, Object?>{'timeMs': 1200, 'value': 1},
        ],
      },
    ],
  };

  test('extracts Motion Patch JSON from KIE Responses output', () {
    final raw = jsonEncode(<String, Object?>{
      'output': <Map<String, Object?>>[
        <String, Object?>{
          'type': 'message',
          'content': <Map<String, Object?>>[
            <String, Object?>{
              'type': 'output_text',
              'text': jsonEncode(patch),
            },
          ],
        },
      ],
    });

    final source = service.extractMotionPatchJson(
      rawResponse: raw,
      transport: ReFusionMotionAgentTransport.responses,
    );

    expect(jsonDecode(source), patch);
  });

  test('extracts fenced Motion Patch JSON from chat completion content', () {
    final raw = jsonEncode(<String, Object?>{
      'choices': <Map<String, Object?>>[
        <String, Object?>{
          'message': <String, Object?>{
            'role': 'assistant',
            'content': '```json\n${jsonEncode(patch)}\n```',
          },
        },
      ],
    });

    final source = service.extractMotionPatchJson(
      rawResponse: raw,
      transport: ReFusionMotionAgentTransport.chatCompletions,
    );

    expect(jsonDecode(source), patch);
  });

  test('extracts Motion Patch JSON from SSE data event', () {
    final raw = 'event: response.completed\n'
        'data: ${jsonEncode(<String, Object?>{
          'output': <Map<String, Object?>>[
            <String, Object?>{
              'content': <Map<String, Object?>>[
                <String, Object?>{'text': jsonEncode(patch)},
              ],
            },
          ],
        })}\n\n'
        'data: [DONE]\n';

    final source = service.extractMotionPatchJson(
      rawResponse: raw,
      transport: ReFusionMotionAgentTransport.responses,
    );

    expect(jsonDecode(source), patch);
  });
}
