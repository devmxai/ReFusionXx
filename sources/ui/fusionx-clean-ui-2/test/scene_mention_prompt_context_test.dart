import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/domain/services/scene_mention_index.dart';
import 'package:refusion_app/features/editor/domain/services/scene_mention_prompt_context.dart';

void main() {
  const builder = SceneMentionPromptContextBuilder();

  SceneMentionEntity entity({
    required String id,
    required String label,
    List<MotionPropertyDefinition>? properties,
  }) {
    return SceneMentionEntity(
      mentionId: 'element:$id',
      entityKind: SceneMentionEntityKind.element,
      targetId: id,
      displayName: label,
      baseDisplayName: label,
      typeLabel: 'Text',
      sceneId: 'scene',
      layerId: 'layer-$id',
      elementId: id,
      supportedProperties: properties ??
          <MotionPropertyDefinition>[
            MotionPropertyCatalog.opacity,
            MotionPropertyCatalog.positionX,
          ],
    );
  }

  test('builds resolved mention payload from brace tokens', () {
    final logo = entity(id: 'logo', label: 'Logo Mark');
    final context = builder.build(
      prompt: 'Move @{Logo Mark} to the right and fade it in.',
      entities: <SceneMentionEntity>[logo],
    );

    expect(context.hasBrokenMentions, isFalse);
    expect(context.mentions.single.entity.targetId, 'logo');
    expect(context.toJson()['mentions'], isA<List<Object?>>());
    expect(
      context.mentions.single.toJson()['supportedProperties'],
      contains(MotionPropertyCatalog.opacity.id),
    );
  });

  test('selected chips are included even before prompt tokens are generated',
      () {
    final headline = entity(id: 'headline', label: 'Headline');
    final context = builder.build(
      prompt: 'Create a soft entrance.',
      entities: <SceneMentionEntity>[headline],
      selectedMentionIds: <String>[headline.mentionId],
    );

    expect(context.mentions.single.token, '@{Headline}');
    expect(context.mentions.single.entity.elementId, 'headline');
  });

  test('reports unresolved typed mentions', () {
    final context = builder.build(
      prompt: 'Animate @{Missing Shape} after @Logo.',
      entities: <SceneMentionEntity>[
        entity(id: 'headline', label: 'Headline'),
      ],
    );

    expect(context.mentions, isEmpty);
    expect(context.issues, hasLength(2));
    expect(
      context.issues.map((issue) => issue.code),
      everyElement(SceneMentionPromptIssueCode.unresolvedMention),
    );
  });
}
