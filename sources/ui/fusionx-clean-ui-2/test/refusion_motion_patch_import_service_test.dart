import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/domain/models/refusion_motion_patch_models.dart';
import 'package:refusion_app/features/editor/domain/services/refusion_motion_patch_import_service.dart';
import 'package:refusion_app/features/editor/domain/services/scene_mention_index.dart';

void main() {
  const service = ReFusionMotionPatchImportService();

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
      MotionPropertyCatalog.scaleX,
      MotionPropertyCatalog.letterSpacing,
      MotionPropertyCatalog.revealProgress,
    ],
  );
  final shapeEntity = entity(
    id: 'dot',
    label: 'Reveal Dot',
    type: 'Circle',
    properties: <MotionPropertyDefinition>[
      MotionPropertyCatalog.opacity,
      MotionPropertyCatalog.positionX,
      MotionPropertyCatalog.positionY,
      MotionPropertyCatalog.width,
      MotionPropertyCatalog.height,
    ],
  );

  test('validates an agent patch against real mention targets', () {
    final result = service.validate(
      scopeDurationMs: 3000,
      mentionEntities: <SceneMentionEntity>[textEntity, shapeEntity],
      source: '''
{
  "schemaVersion": "refusion.motion-patch/v1",
  "name": "Move headline and dot",
  "durationMs": 3000,
  "operations": [
    {
      "id": "headline-type",
      "target": "@{Headline}",
      "property": "typewriterProgress",
      "keyframes": [
        { "timeMs": 0, "value": 0.0 },
        { "timeMs": 1200, "value": 1.0, "easing": "easeOut" }
      ]
    },
    {
      "id": "dot-move",
      "target": "element:dot",
      "property": "position",
      "keyframes": [
        { "timeMs": 0, "value": { "x": -320, "y": 0 } },
        { "timeMs": 900, "value": { "x": 240, "y": 0 } }
      ]
    }
  ]
}
''',
    );

    expect(result.isValid, isTrue);
    expect(result.patch!.operations, hasLength(2));
    expect(
      result.resolvedChannels.map((channel) => channel.definition.id),
      containsAll(<String>[
        MotionPropertyCatalog.revealProgress.id,
        MotionPropertyCatalog.positionX.id,
        MotionPropertyCatalog.positionY.id,
      ]),
    );
  });

  test('accepts text range selector and tracking aliases in motion patches',
      () {
    final result = service.validate(
      scopeDurationMs: 1600,
      mentionEntities: <SceneMentionEntity>[textEntity],
      source: '''
{
  "schemaVersion": "refusion.motion-patch/v1",
  "name": "Range selector edit",
  "durationMs": 1600,
  "operations": [
    {
      "target": "@{Headline}",
      "property": "wordRangeSelectorProgress",
      "keyframes": [
        { "timeMs": 0, "value": 0.0 },
        { "timeMs": 800, "value": 1.0 }
      ]
    },
    {
      "target": "@{Headline}",
      "property": "trackingAmount",
      "keyframes": [
        { "timeMs": 0, "value": -120 },
        { "timeMs": 800, "value": 0 }
      ]
    }
  ]
}
''',
    );

    expect(result.isValid, isTrue);
    expect(
      result.resolvedChannels.map((channel) => channel.definition.id),
      containsAll(<String>[
        MotionPropertyCatalog.revealProgress.id,
        MotionPropertyCatalog.letterSpacing.id,
      ]),
    );
  });

  test('accepts targetId as a defensive alias for agent output', () {
    final result = service.validate(
      scopeDurationMs: 13000,
      mentionEntities: <SceneMentionEntity>[textEntity],
      source: '''
{
  "schemaVersion": "refusion.motion-patch/v1",
  "operations": [
    {
      "op": "animate",
      "targetId": "headline",
      "property": "visual.opacity",
      "keyframes": [
        { "timeMs": 0, "value": 0.0 },
        { "timeMs": 320, "value": 1.0 },
        { "timeMs": 12200, "value": 1.0 },
        { "timeMs": 12900, "value": 0.0 }
      ]
    },
    {
      "op": "animate",
      "targetId": "headline",
      "property": "transform.scale.x",
      "keyframes": [
        { "timeMs": 0, "value": 0.82 },
        { "timeMs": 220, "value": 1.04 },
        { "timeMs": 420, "value": 1.0 }
      ]
    }
  ]
}
''',
    );

    expect(result.isValid, isTrue);
    expect(result.patch!.operations.first.action, 'animate');
    expect(result.patch!.operations.map((operation) => operation.target), [
      'headline',
      'headline',
    ]);
    expect(
      result.resolvedChannels.map((channel) => channel.definition.id),
      containsAll(<String>[
        MotionPropertyCatalog.opacity.id,
        MotionPropertyCatalog.scaleX.id,
      ]),
    );
  });

  test('rejects unknown targets and unsupported properties', () {
    final result = service.validate(
      scopeDurationMs: 2000,
      mentionEntities: <SceneMentionEntity>[shapeEntity],
      source: '''
{
  "schemaVersion": "refusion.motion-patch/v1",
  "operations": [
    {
      "target": "@{Missing}",
      "property": "opacity",
      "keyframes": [
        { "timeMs": 0, "value": 0.0 },
        { "timeMs": 1000, "value": 1.0 }
      ]
    },
    {
      "target": "element:dot",
      "property": "typewriterProgress",
      "keyframes": [
        { "timeMs": 0, "value": 0.0 },
        { "timeMs": 1000, "value": 1.0 }
      ]
    }
  ]
}
''',
    );

    expect(result.isValid, isFalse);
    expect(
      result.issues.map((issue) => issue.path),
      containsAll(<String>['operations[0].target', 'operations[1].property']),
    );
  });

  test('rejects time outside the active scope and incompatible values', () {
    final result = service.validate(
      scopeDurationMs: 1000,
      mentionEntities: <SceneMentionEntity>[shapeEntity],
      source: '''
{
  "schemaVersion": "refusion.motion-patch/v1",
  "operations": [
    {
      "target": "Reveal Dot",
      "property": "position",
      "keyframes": [
        { "timeMs": 0, "value": { "x": 0, "y": 0 } },
        { "timeMs": 1600, "value": { "x": "bad", "y": 20 } }
      ]
    }
  ]
}
''',
    );

    expect(result.isValid, isFalse);
    expect(
      result.issues.map((issue) => issue.path),
      containsAll(<String>[
        'operations[0].keyframes[1].timeMs',
        'operations[0].keyframes[1].value',
      ]),
    );
  });

  test('rejects executable keys and hidden runtime operations', () {
    final result = service.validate(
      scopeDurationMs: 1000,
      mentionEntities: <SceneMentionEntity>[textEntity],
      source: '''
{
  "schemaVersion": "refusion.motion-patch/v1",
  "operations": [
    {
      "action": "run",
      "target": "element:headline",
      "property": "opacity",
      "script": "fetch('https://example.com')",
      "keyframes": [
        { "timeMs": 0, "value": 1.0 }
      ]
    }
  ]
}
''',
    );

    expect(result.isValid, isFalse);
    expect(
      result.issues.map((issue) => issue.path),
      containsAll(<String>['operations[0].action', 'operations[0].script']),
    );
  });

  test('normalizes unsorted keyframes with a warning', () {
    final result = service.validate(
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
        { "timeMs": 800, "value": 1.0 },
        { "timeMs": 0, "value": 0.0 }
      ]
    }
  ]
}
''',
    );

    expect(result.isValid, isTrue);
    expect(
      result.issues.single.severity,
      ReFusionMotionPatchIssueSeverity.warning,
    );
    expect(
      result.patch!.operations.single.keyframes
          .map((keyframe) => keyframe.timeMs),
      <int>[0, 800],
    );
  });
}
