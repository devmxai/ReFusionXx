import 'dart:convert';

import 'package:flutter/foundation.dart';

enum ReFusionSceneAgentTransport {
  responses,
  claudeMessages,
}

@immutable
class ReFusionSceneAgentProfile {
  const ReFusionSceneAgentProfile({
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
    this.maxTokens = 8192,
  });

  final String id;
  final String providerId;
  final String label;
  final String shortLabel;
  final String description;
  final String endpointPath;
  final String modelId;
  final ReFusionSceneAgentTransport transport;
  final String recommendedUse;
  final String? reasoningEffort;
  final int maxTokens;
}

@immutable
class ReFusionSceneAgentRequestPreview {
  const ReFusionSceneAgentRequestPreview({
    required this.profile,
    required this.method,
    required this.endpointUrl,
    required this.body,
    required this.prettyBody,
    required this.isDryRun,
  });

  final ReFusionSceneAgentProfile profile;
  final String method;
  final String endpointUrl;
  final Map<String, Object?> body;
  final String prettyBody;
  final bool isDryRun;
}

class ReFusionSceneAgentProviderCatalog {
  const ReFusionSceneAgentProviderCatalog();

  static const String endpointBaseUrl = 'https://api.kie.ai';

  static const List<ReFusionSceneAgentProfile> profiles =
      <ReFusionSceneAgentProfile>[
    ReFusionSceneAgentProfile(
      id: 'kie-codex-scene-director',
      providerId: 'kie.ai',
      label: 'Codex Scene Director',
      shortLabel: 'Codex',
      description:
          'KIE.ai Codex profile for strict Director-first ReFusion Scene Program JSON.',
      endpointPath: '/api/v1/responses',
      modelId: 'gpt-5.4-codex',
      transport: ReFusionSceneAgentTransport.responses,
      recommendedUse:
          'Use for code-like JSON precision, schema repair, and exact keyframe timing.',
      reasoningEffort: 'high',
    ),
    ReFusionSceneAgentProfile(
      id: 'kie-claude-opus-scene-director',
      providerId: 'kie.ai',
      label: 'Claude Opus Scene Director',
      shortLabel: 'Claude Opus',
      description:
          'KIE.ai Claude Opus profile for visual choreography and structured Scene Program output.',
      endpointPath: '/claude/v1/messages',
      modelId: 'claude-opus-4-6',
      transport: ReFusionSceneAgentTransport.claudeMessages,
      recommendedUse:
          'Use for richer composition planning, scene sequencing, and motion language.',
      reasoningEffort: 'high',
      maxTokens: 10000,
    ),
  ];

  ReFusionSceneAgentProfile profileById(String id) {
    for (final profile in profiles) {
      if (profile.id == id) {
        return profile;
      }
    }
    return profiles.first;
  }

  ReFusionSceneAgentRequestPreview buildRequestPreview({
    required ReFusionSceneAgentProfile profile,
    required String prompt,
    required int durationMs,
    required int canvasWidth,
    required int canvasHeight,
    required double frameRate,
  }) {
    final safeDurationMs = durationMs <= 0 ? 3600 : durationMs;
    final task = <String, Object?>{
      'intent': 'generate-editable-refusion-scene-program',
      'outputSchema': 'refusion.scene-program/v1',
      'prompt': prompt.trim(),
      'composition': <String, Object?>{
        'width': canvasWidth <= 0 ? 1080 : canvasWidth,
        'height': canvasHeight <= 0 ? 1920 : canvasHeight,
        'durationMs': safeDurationMs,
        'frameRate': frameRate <= 0 ? 30 : frameRate,
        'coordinateSystem': 'center-origin',
      },
      'directorContract': _directorContract,
      'sceneProgramContract': _sceneProgramContract,
      'corePack': _corePack,
      'outputContract': const <String, Object?>{
        'returnJsonOnly': true,
        'preferredRoot': 'directorPlanAndSceneProgram',
        'acceptedRootForms': <String>[
          'Preferred: an object with directorPlan and sceneProgram fields',
          'Compatibility: a direct refusion.scene-program/v1 object',
        ],
        'requiredPreferredKeys': <String>['directorPlan', 'sceneProgram'],
        'noMarkdown': true,
        'noProse': true,
      },
    };
    final body = switch (profile.transport) {
      ReFusionSceneAgentTransport.responses => _responsesBody(
          profile: profile,
          task: task,
        ),
      ReFusionSceneAgentTransport.claudeMessages => _claudeMessagesBody(
          profile: profile,
          task: task,
        ),
    };
    const encoder = JsonEncoder.withIndent('  ');
    return ReFusionSceneAgentRequestPreview(
      profile: profile,
      method: 'POST',
      endpointUrl: '$endpointBaseUrl${profile.endpointPath}',
      body: body,
      prettyBody: encoder.convert(body),
      isDryRun: true,
    );
  }

  Map<String, Object?> _responsesBody({
    required ReFusionSceneAgentProfile profile,
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
      'max_output_tokens': profile.maxTokens,
      'text': const <String, Object?>{
        'format': <String, Object?>{
          'type': 'json_object',
        },
      },
    };
  }

  Map<String, Object?> _claudeMessagesBody({
    required ReFusionSceneAgentProfile profile,
    required Map<String, Object?> task,
  }) {
    return <String, Object?>{
      'model': profile.modelId,
      'system': _systemInstruction,
      'messages': <Map<String, Object?>>[
        <String, Object?>{
          'role': 'user',
          'content': jsonEncode(task),
        },
      ],
      'stream': false,
      'max_tokens': profile.maxTokens,
      'thinkingFlag': true,
    };
  }

  static const Map<String, Object?> _directorContract = <String, Object?>{
    'schemaVersion': 'refusion.motion-director/v1',
    'mustPlanBeforeSceneProgram': true,
    'rootRequiredKeys': <String>[
      'schemaVersion',
      'name',
      'durationMs',
      'frameRate',
      'canvasWidth',
      'canvasHeight',
      'beats',
      'components',
      'primitives',
    ],
    'beatRequiredKeys': <String>[
      'id',
      'label',
      'startMs',
      'endMs',
      'intent',
      'componentRefs',
    ],
    'componentRequiredKeys': <String>[
      'id',
      'role',
      'label',
    ],
    'componentRules': <String>[
      'Choose from known component roles and keep parent-child choreography coherent.',
      'Do not invent detached child timing where a component container exists.',
      'Do not guess loose child coordinates inside professional UI components.',
      'Prefer component-level motion recipes over isolated child fades.',
    ],
    'primitiveRequiredKeys': <String>[
      'id',
      'beatId',
      'targetComponentId',
      'kind',
      'startMs',
      'endMs',
    ],
    'beatRules': <String>[
      'Create ordered beats before writing layers or keyframes.',
      'Each beat must have a clear role: enter, reveal/type, hold, action, transform, exit.',
      'Avoid unrelated simultaneous motion. Parallel beats are allowed only when their componentRefs are explicit and disjoint.',
      'Same-component handoff overlap is allowed only when the overlapping primitives animate disjoint properties such as scale then width. If the same property overlaps, put it in one intentional beat.',
      'Use readable holds for text or UI states before the next action.',
    ],
    'primitiveRules': <String>[
      'One primitive should explain one motion intention.',
      'Every primitive must stay inside its owning beat.',
      'Typewriter/typing primitives must include property typewriterProgress, fromValue 0.0, and toValue 1.0 unless the prompt asks for deletion.',
      'Do not create one text element per character.',
    ],
  };

  static const Map<String, Object?> _sceneProgramContract = <String, Object?>{
    'schemaVersion': 'refusion.scene-program/v1',
    'rootRequiredKeys': <String>[
      'schemaVersion',
      'name',
      'durationMs',
      'frameRate',
      'layers',
    ],
    'supportedLayerKinds': <String>['shape', 'text', 'image'],
    'supportedElementKinds': <String>[
      'shape',
      'solid',
      'text',
      'image',
      'icon'
    ],
    'supportedShapeKinds': <String>[
      'rectangle',
      'roundedRectangle',
      'circle',
      'line',
    ],
    'supportedProperties': <String>[
      'position',
      'positionX',
      'positionY',
      'scale',
      'scaleX',
      'scaleY',
      'rotation',
      'opacity',
      'blur',
      'color',
      'width',
      'height',
      'cornerRadius',
      'fontSize',
      'letterSpacing',
      'typewriterProgress',
      'typingProgress',
      'reveal',
    ],
    'timeRules': <String>[
      'Layer timing fields must use canonical numeric startMs and durationMs, not strings.',
      'Default keyframe timeMs is local layer time from 0 to layer.durationMs.',
      'Use timeBasis: project only when all keyframes are absolute scene times.',
      'Layer durationMs must cover every local keyframe.',
      'All keyframes must stay inside scene durationMs.',
    ],
    'qualityRules': <String>[
      'Prefer 3-8 visible layers for a compact scene.',
      'Use stable human-readable ids.',
      'Keep text inside the canvas.',
      'Use high contrast and mobile-friendly sizing.',
      'Stagger actions by 80-300ms unless simultaneous motion is intentional.',
    ],
  };

  static const Map<String, Object?> _corePack = <String, Object?>{
    'icons': <String>[
      'arrow-down',
      'arrow-left',
      'arrow-right',
      'arrow-up',
      'bookmark',
      'camera',
      'check',
      'chevron-left',
      'chevron-right',
      'close',
      'comment',
      'crop',
      'heart',
      'image',
      'lock',
      'mic',
      'music',
      'paperclip',
      'pause',
      'play',
      'plus',
      'search',
      'send',
      'settings',
      'share',
      'sparkles',
      'text',
      'user',
      'verified',
      'video',
      'volume',
    ],
    'iconAliases': <String, String>{
      'attach': 'paperclip',
      'attachment': 'paperclip',
      'microphone': 'mic',
      'submit': 'send',
      'profile': 'user',
      'verification': 'verified',
      'favorite': 'heart',
      'chat': 'comment',
      'done': 'check',
      'add': 'plus',
    },
  };

  static const String _systemInstruction = '''
You are the ReFusion Scene Director.
Return only valid JSON. No markdown, no prose, no comments, no executable code.
Your final JSON must be {"directorPlan": {...}, "sceneProgram": {...}}.
directorPlan must use schemaVersion "refusion.motion-director/v1".
sceneProgram must use schemaVersion "refusion.scene-program/v1".

Before writing the Scene Program, internally plan a Motion Director structure:
ordered beats, semantic components, and animation primitives.
The final Scene Program must reflect that plan with real layers, elements, channels, keyframes, and easing.

Use ReFusion's center-origin canvas. Keep all keyframe timeMs values inside the owning timeline range.
Prefer component-aware authoring. Build coherent component groups instead of isolated loose children.
Do not place child icon/text layers with independent exits when they belong to one UI component shell.
Do not create one text element per character. Use a single text element with typewriterProgress or reveal from 0 to 1.
For every typewriter/typing primitive, include property "typewriterProgress", fromValue 0.0, and toValue 1.0.
Parallel beats are valid only when componentRefs are explicit and disjoint; same-component overlap must be one intentional beat.
Do not use JSX, JavaScript, CSS, imports, URLs, shader source, functions, eval, or runtime code.
Prefer professional choreography: enter, reveal/type, hold, action, transform/exit.
''';
}
