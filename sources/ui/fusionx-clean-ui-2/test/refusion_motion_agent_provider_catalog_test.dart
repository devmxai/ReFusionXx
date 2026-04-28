import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/domain/services/refusion_motion_agent_provider_catalog.dart';
import 'package:refusion_app/features/editor/domain/services/scene_mention_index.dart';
import 'package:refusion_app/features/editor/domain/services/scene_mention_prompt_context.dart';

void main() {
  const catalog = ReFusionMotionAgentProviderCatalog();
  const contextBuilder = SceneMentionPromptContextBuilder();

  SceneMentionEntity target() {
    return SceneMentionEntity(
      mentionId: 'element:headline',
      entityKind: SceneMentionEntityKind.element,
      targetId: 'headline',
      displayName: 'Headline',
      baseDisplayName: 'Headline',
      typeLabel: 'Text',
      sceneId: 'scene',
      layerId: 'layer-headline',
      elementId: 'headline',
      supportedProperties: <MotionPropertyDefinition>[
        MotionPropertyCatalog.opacity,
        MotionPropertyCatalog.positionX,
        MotionPropertyCatalog.scaleX,
      ],
    );
  }

  test('exposes KIE.ai motion authoring profiles', () {
    expect(
      ReFusionMotionAgentProviderCatalog.profiles.map((profile) => profile.id),
      containsAll(<String>[
        'kie-gpt55-motion-architect',
        'kie-codex53-motion-architect',
        'kie-gpt52-motion-designer',
      ]),
    );
    expect(
      ReFusionMotionAgentProviderCatalog.profiles.first.modelId,
      'gpt-5-5-openai-resp',
    );
  });

  test('builds a dry-run GPT 5.5 responses request without auth headers', () {
    final context = contextBuilder.build(
      prompt: 'Move @{Headline} in from the left.',
      entities: <SceneMentionEntity>[target()],
    );
    final preview = catalog.buildRequestPreview(
      profile: ReFusionMotionAgentProviderCatalog.profiles.first,
      context: context,
      scopeDurationMs: 2400,
    );

    expect(preview.isDryRun, isTrue);
    expect(preview.method, 'POST');
    expect(preview.endpointUrl, endsWith('/api/v1/responses'));
    expect(preview.body['model'], 'gpt-5-5-openai-resp');
    expect(preview.body.containsKey('Authorization'), isFalse);
    expect(preview.prettyBody, contains('refusion.motion-patch/v1'));
    expect(preview.prettyBody, contains('Move @{Headline} in from the left.'));
    expect(preview.prettyBody, contains('element:headline'));
    expect(preview.prettyBody, contains(r'\"target\"'));
    expect(preview.prettyBody, contains('Do not emit targetId'));
    expect(preview.prettyBody, contains('scope-local-ms'));
  });

  test('builds chat-completions dry-run request for GPT 5.2 profile', () {
    final profile = catalog.profileById('kie-gpt52-motion-designer');
    final context = contextBuilder.build(
      prompt: 'Fade @{Headline} up with a small scale overshoot.',
      entities: <SceneMentionEntity>[target()],
    );
    final preview = catalog.buildRequestPreview(
      profile: profile,
      context: context,
      scopeDurationMs: 1800,
    );

    expect(preview.endpointUrl, endsWith('/gpt-5-2/v1/chat/completions'));
    expect(preview.body['model'], 'gpt-5-2');
    expect(preview.body['messages'], isA<List<Object?>>());
    expect(preview.body['response_format'], isA<Map<String, Object?>>());
    expect(preview.prettyBody, contains('animateOnlyMentionedTargets'));
  });
}
