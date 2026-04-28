import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'scene_mention_prompt_context.dart';

enum ReFusionMotionAgentTransport {
  responses,
  chatCompletions,
}

@immutable
class ReFusionMotionAgentProfile {
  const ReFusionMotionAgentProfile({
    required this.id,
    required this.providerId,
    required this.label,
    required this.shortLabel,
    required this.description,
    required this.endpointPath,
    required this.modelId,
    required this.transport,
    required this.recommendedUse,
    this.reasoningEffort,
  });

  final String id;
  final String providerId;
  final String label;
  final String shortLabel;
  final String description;
  final String endpointPath;
  final String modelId;
  final ReFusionMotionAgentTransport transport;
  final String recommendedUse;
  final String? reasoningEffort;
}

@immutable
class ReFusionMotionAgentRequestPreview {
  const ReFusionMotionAgentRequestPreview({
    required this.profile,
    required this.method,
    required this.endpointUrl,
    required this.body,
    required this.prettyBody,
    required this.isDryRun,
  });

  final ReFusionMotionAgentProfile profile;
  final String method;
  final String endpointUrl;
  final Map<String, Object?> body;
  final String prettyBody;
  final bool isDryRun;
}

class ReFusionMotionAgentProviderCatalog {
  const ReFusionMotionAgentProviderCatalog();

  static const String endpointBaseUrl = 'https://api.kie.ai';

  static const List<ReFusionMotionAgentProfile> profiles =
      <ReFusionMotionAgentProfile>[
    ReFusionMotionAgentProfile(
      id: 'kie-gpt55-motion-architect',
      providerId: 'kie.ai',
      label: 'GPT 5.5 Motion Architect',
      shortLabel: 'GPT 5.5',
      description:
          'Best available KIE.ai GPT-5.5 reasoning profile for strict Motion Patch JSON.',
      endpointPath: '/api/v1/responses',
      modelId: 'gpt-5-5-openai-resp',
      transport: ReFusionMotionAgentTransport.responses,
      recommendedUse:
          'Use first for professional prompt-to-keyframe motion when your KIE account supports GPT-5.5.',
      reasoningEffort: 'high',
    ),
    ReFusionMotionAgentProfile(
      id: 'kie-codex53-motion-architect',
      providerId: 'kie.ai',
      label: 'Codex 5.3 Motion Architect',
      shortLabel: 'Codex 5.3',
      description:
          'Documented Codex fallback for strict Motion Patch JSON, schema repair, and code-like timing logic.',
      endpointPath: '/api/v1/responses',
      modelId: 'gpt-5.3-codex',
      transport: ReFusionMotionAgentTransport.responses,
      recommendedUse:
          'Use if GPT-5.5 is not enabled for the current KIE API key.',
      reasoningEffort: 'high',
    ),
    ReFusionMotionAgentProfile(
      id: 'kie-gpt52-motion-designer',
      providerId: 'kie.ai',
      label: 'GPT 5.2 Motion Designer',
      shortLabel: 'GPT 5.2',
      description:
          'Best for creative motion direction that still returns a validated patch.',
      endpointPath: '/gpt-5-2/v1/chat/completions',
      modelId: 'gpt-5-2',
      transport: ReFusionMotionAgentTransport.chatCompletions,
      recommendedUse:
          'Use for expressive prompt-to-motion design over existing mentions.',
      reasoningEffort: 'high',
    ),
    ReFusionMotionAgentProfile(
      id: 'kie-gemini31-visual-planner',
      providerId: 'kie.ai',
      label: 'Gemini 3.1 Visual Planner',
      shortLabel: 'Gemini',
      description:
          'Best for visual layout planning before the final Motion Patch is validated.',
      endpointPath: '/gemini-3.1-pro/v1/chat/completions',
      modelId: 'gemini-3.1-pro',
      transport: ReFusionMotionAgentTransport.chatCompletions,
      recommendedUse:
          'Use for visual choreography ideas and multi-object sequencing.',
      reasoningEffort: 'high',
    ),
  ];

  ReFusionMotionAgentProfile profileById(String id) {
    for (final profile in profiles) {
      if (profile.id == id) {
        return profile;
      }
    }
    return profiles.first;
  }

  ReFusionMotionAgentRequestPreview buildRequestPreview({
    required ReFusionMotionAgentProfile profile,
    required SceneMentionPromptContext context,
    required int scopeDurationMs,
  }) {
    final safeDurationMs = scopeDurationMs <= 0 ? 1 : scopeDurationMs;
    final task = <String, Object?>{
      'intent': 'generate-refusion-motion-patch',
      'outputSchema': 'refusion.motion-patch/v1',
      'prompt': context.prompt.trim(),
      'timeline': <String, Object?>{
        'timeBasis': 'scope-local-ms',
        'scopeDurationMs': safeDurationMs,
        'allowedRangeMs': <int>[0, safeDurationMs],
      },
      'targets': context.mentions
          .map((mention) => mention.toJson())
          .toList(growable: false),
      'allowedOperations': const <String>['animate'],
      'outputContract': const <String, Object?>{
        'rootRequiredKeys': <String>[
          'schemaVersion',
          'scopeDurationMs',
          'operations',
        ],
        'schemaVersion': 'refusion.motion-patch/v1',
        'operationRequiredKeys': <String>[
          'action',
          'target',
          'property',
          'keyframes',
        ],
        'targetRule':
            'Set operation.target to an exact target.mentionId such as "element:headline" or exact target.targetId such as "headline". Do not emit targetId as the operation key.',
        'canonicalExample': <String, Object?>{
          'schemaVersion': 'refusion.motion-patch/v1',
          'scopeDurationMs': 1200,
          'operations': <Map<String, Object?>>[
            <String, Object?>{
              'action': 'animate',
              'target': 'element:example',
              'property': 'opacity',
              'keyframes': <Map<String, Object?>>[
                <String, Object?>{'timeMs': 0, 'value': 0},
                <String, Object?>{'timeMs': 1200, 'value': 1},
              ],
            },
          ],
        },
      },
      'constraints': const <String, Object?>{
        'returnJsonOnly': true,
        'doNotCreateNewElements': true,
        'animateOnlyMentionedTargets': true,
        'noExecutableCode': true,
        'noMarkdown': true,
        'noComments': true,
        'noImports': true,
        'noUrls': true,
        'mustValidateBeforeApply': true,
      },
    };
    final body = switch (profile.transport) {
      ReFusionMotionAgentTransport.responses => _responsesBody(
          profile: profile,
          task: task,
        ),
      ReFusionMotionAgentTransport.chatCompletions => _chatCompletionsBody(
          profile: profile,
          task: task,
        ),
    };
    const encoder = JsonEncoder.withIndent('  ');
    return ReFusionMotionAgentRequestPreview(
      profile: profile,
      method: 'POST',
      endpointUrl: '$endpointBaseUrl${profile.endpointPath}',
      body: body,
      prettyBody: encoder.convert(body),
      isDryRun: true,
    );
  }

  Map<String, Object?> _responsesBody({
    required ReFusionMotionAgentProfile profile,
    required Map<String, Object?> task,
  }) {
    return <String, Object?>{
      'model': profile.modelId,
      'stream': false,
      'input': <Map<String, Object?>>[
        <String, Object?>{
          'role': 'system',
          'content': <Map<String, Object?>>[
            <String, Object?>{
              'type': 'input_text',
              'text': _systemInstruction,
            },
          ],
        },
        <String, Object?>{
          'role': 'user',
          'content': <Map<String, Object?>>[
            <String, Object?>{
              'type': 'input_text',
              'text': jsonEncode(task),
            },
          ],
        },
      ],
      if (profile.reasoningEffort != null)
        'reasoning': <String, Object?>{
          'effort': profile.reasoningEffort,
        },
      'text': const <String, Object?>{
        'format': <String, Object?>{
          'type': 'json_object',
        },
      },
    };
  }

  Map<String, Object?> _chatCompletionsBody({
    required ReFusionMotionAgentProfile profile,
    required Map<String, Object?> task,
  }) {
    return <String, Object?>{
      'model': profile.modelId,
      'messages': <Map<String, Object?>>[
        <String, Object?>{
          'role': 'system',
          'content': _systemInstruction,
        },
        <String, Object?>{
          'role': 'user',
          'content': jsonEncode(task),
        },
      ],
      if (profile.reasoningEffort != null)
        'reasoning_effort': profile.reasoningEffort,
      'response_format': const <String, Object?>{
        'type': 'json_object',
      },
    };
  }

  static const String _systemInstruction = '''
You are a ReFusion motion agent. Return only valid JSON for schemaVersion "refusion.motion-patch/v1".
Animate only the mentioned targets from the supplied target list.
Do not create new layers, new elements, executable code, imports, URLs, markdown, or prose.
All keyframe timeMs values must be inside the supplied scope-local allowedRangeMs.
Prefer professional timing: short ease-in/ease-out, clean overshoot only when requested, and editable keyframes.
Use only properties listed under each target.supportedProperties.
Each operation must use "target" as the target key. The value must be an exact target.mentionId or target.targetId from the supplied target list. Do not use "targetId" as an operation key.
Each operation must use "action": "animate"; do not use "op".
''';
}
