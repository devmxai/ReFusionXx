import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_animation_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/domain/models/refusion_motion_patch_models.dart';
import 'package:refusion_app/features/editor/domain/services/refusion_motion_patch_applicator.dart';
import 'package:refusion_app/features/editor/domain/services/refusion_motion_patch_import_service.dart';
import 'package:refusion_app/features/editor/domain/services/scene_mention_index.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';

void main() {
  const importer = ReFusionMotionPatchImportService();
  const applicator = ReFusionMotionPatchApplicator();

  const target = MotionPropertyTarget(
    kind: MotionTargetKind.element,
    targetId: 'headline',
    sceneId: 'scene',
    layerId: 'layer-headline',
    elementId: 'headline',
  );

  SceneMentionEntity entity({
    required String id,
    required String label,
    required String type,
    required List<MotionPropertyDefinition> properties,
  }) {
    return SceneMentionEntity(
      mentionId: 'element:$id',
      entityKind: SceneMentionEntityKind.element,
      targetId: id,
      displayName: label,
      baseDisplayName: label,
      typeLabel: type,
      sceneId: 'scene',
      layerId: 'layer-$id',
      elementId: id,
      supportedProperties: properties,
    );
  }

  final textEntity = entity(
    id: 'headline',
    label: 'Headline',
    type: 'Text',
    properties: <MotionPropertyDefinition>[
      MotionPropertyCatalog.opacity,
      MotionPropertyCatalog.positionX,
      MotionPropertyCatalog.positionY,
      MotionPropertyCatalog.revealProgress,
    ],
  );

  final shapeEntity = entity(
    id: 'dot',
    label: 'Dot',
    type: 'Shape',
    properties: <MotionPropertyDefinition>[
      MotionPropertyCatalog.opacity,
      MotionPropertyCatalog.positionX,
      MotionPropertyCatalog.positionY,
      MotionPropertyCatalog.width,
    ],
  );

  test('applies validated patch into editable motion channels', () {
    final importResult = importer.validate(
      scopeDurationMs: 3000,
      mentionEntities: <SceneMentionEntity>[textEntity, shapeEntity],
      source: '''
{
  "schemaVersion": "refusion.motion-patch/v1",
  "name": "Headline and dot motion",
  "durationMs": 3000,
  "operations": [
    {
      "id": "headline-type",
      "target": "element:headline",
      "property": "typewriterProgress",
      "keyframes": [
        { "timeMs": 0, "value": 0.0 },
        { "timeMs": 3000, "value": 1.0, "easing": "easeOut" }
      ]
    },
    {
      "id": "dot-slide",
      "target": "Dot",
      "property": "position",
      "keyframes": [
        { "timeMs": 0, "value": { "x": -220, "y": 0 } },
        { "timeMs": 1200, "value": { "x": 240, "y": 80 }, "easing": "spring" }
      ]
    }
  ]
}
''',
    );

    final applied = applicator.apply(
      ReFusionMotionPatchApplyRequest(
        channels: const <MotionPropertyChannelModel>[],
        importResult: importResult,
      ),
    );

    expect(applied.hasErrors, isFalse);
    expect(applied.channels.map((channel) => channel.definition.id), <String>[
      MotionPropertyCatalog.revealProgress.id,
      MotionPropertyCatalog.positionX.id,
      MotionPropertyCatalog.positionY.id,
    ]);
    final reveal = applied.channels.singleWhere(
      (channel) =>
          channel.definition.id == MotionPropertyCatalog.revealProgress.id,
    );
    expect(reveal.keyframes.last.time, TimelineTime.fromMilliseconds(3000));
    expect(reveal.keyframes.last.value.rawValue, 1.0);

    final positionX = applied.channels.singleWhere(
      (channel) => channel.definition.id == MotionPropertyCatalog.positionX.id,
    );
    final positionY = applied.channels.singleWhere(
      (channel) => channel.definition.id == MotionPropertyCatalog.positionY.id,
    );
    expect(positionX.keyframes.last.value.rawValue, 240.0);
    expect(positionY.keyframes.last.value.rawValue, 80.0);
    expect(applied.changedKeyframeIds, hasLength(6));
  });

  test('updates an existing keyframe without changing its identity', () {
    final existing = MotionPropertyChannelModel(
      id: 'existing.opacity',
      target: target,
      definition: MotionPropertyCatalog.opacity,
      activeRange: TimelineTimeRange(
        start: TimelineTime.zero,
        endExclusive: TimelineTime.fromMilliseconds(2000),
      ),
      keyframes: <MotionKeyframeModel>[
        MotionKeyframeModel(
          id: 'existing-key',
          channelId: 'existing.opacity',
          time: TimelineTime.fromMilliseconds(1000),
          value: const MotionPropertyValue.scalar(0.2),
          interpolationToNext: const MotionInterpolationSpec.linear(),
        ),
      ],
    );
    final importResult = importer.validate(
      scopeDurationMs: 2000,
      mentionEntities: <SceneMentionEntity>[textEntity],
      source: '''
{
  "schemaVersion": "refusion.motion-patch/v1",
  "operations": [
    {
      "target": "element:headline",
      "property": "opacity",
      "keyframes": [
        { "timeMs": 1000, "value": 0.85, "easing": "easeInOut" }
      ]
    }
  ]
}
''',
    );

    final applied = applicator.apply(
      ReFusionMotionPatchApplyRequest(
        channels: <MotionPropertyChannelModel>[existing],
        importResult: importResult,
      ),
    );

    expect(applied.hasErrors, isFalse);
    expect(applied.channels, hasLength(1));
    final keyframe = applied.channels.single.keyframes.single;
    expect(keyframe.id, 'existing-key');
    expect(keyframe.value.rawValue, 0.85);
    expect(
        keyframe.interpolationToNext.kind, MotionInterpolationKind.easeInOut);
  });

  test('refuses to apply invalid import result and preserves channels', () {
    final importResult = importer.validate(
      scopeDurationMs: 1000,
      mentionEntities: <SceneMentionEntity>[textEntity],
      source: '''
{
  "schemaVersion": "refusion.motion-patch/v1",
  "operations": [
    {
      "target": "@{Missing}",
      "property": "opacity",
      "keyframes": [
        { "timeMs": 0, "value": 1.0 }
      ]
    }
  ]
}
''',
    );

    final applied = applicator.apply(
      ReFusionMotionPatchApplyRequest(
        channels: const <MotionPropertyChannelModel>[],
        importResult: importResult,
      ),
    );

    expect(applied.hasErrors, isTrue);
    expect(applied.channels, isEmpty);
    expect(
      applied.issues.map((issue) => issue.message),
      contains('Cannot apply an invalid motion patch.'),
    );
  });

  test('warns and falls back when an easing token is unknown', () {
    final importResult = importer.validate(
      scopeDurationMs: 1000,
      mentionEntities: <SceneMentionEntity>[textEntity],
      source: '''
{
  "schemaVersion": "refusion.motion-patch/v1",
  "operations": [
    {
      "target": "element:headline",
      "property": "opacity",
      "keyframes": [
        { "timeMs": 0, "value": 0.0, "easing": "agentMagic" },
        { "timeMs": 1000, "value": 1.0 }
      ]
    }
  ]
}
''',
    );

    final applied = applicator.apply(
      ReFusionMotionPatchApplyRequest(
        channels: const <MotionPropertyChannelModel>[],
        importResult: importResult,
      ),
    );

    expect(applied.hasErrors, isFalse);
    expect(
      applied.issues.single.severity,
      ReFusionMotionPatchIssueSeverity.warning,
    );
    expect(
      applied.channels.single.keyframes.first.interpolationToNext.kind,
      MotionInterpolationKind.linear,
    );
  });
}
