import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/professional_normal_transition_models.dart';
import 'package:refusion_app/features/editor/domain/services/normal_transition_script_import_service.dart';
import 'package:refusion_app/features/editor/presentation/services/normal_transition_script_timeline_mapper.dart';

void main() {
  const importService = NormalTransitionScriptImportService();
  const mapper = NormalTransitionScriptTimelineMapper();

  test('maps declarative transition script channels into editable lanes', () {
    final importResult = importService.validate(
      source: '''
{
  "kind": "refusion.transition",
  "schemaVersion": "1.0.0",
  "id": "script_zoom_flash",
  "name": "Script Zoom Flash",
  "rendererType": "primitive",
  "defaultDurationMs": 900,
  "channels": [
    {
      "target": "from",
      "property": "scale",
      "keyframes": [
        { "t": 0, "value": 1 },
        { "t": 1, "value": 1.12 }
      ]
    },
    {
      "target": "to",
      "property": "positionX",
      "keyframes": [
        { "t": 0, "value": 1 },
        { "t": 1, "value": 0 }
      ]
    },
    {
      "target": "transition",
      "property": "whiteFlash",
      "keyframes": [
        { "t": 0, "value": 0 },
        { "t": 0.5, "value": 0.75 },
        { "t": 1, "value": 0 }
      ]
    },
    {
      "target": "from",
      "property": "opacity",
      "keyframes": [
        { "t": 0, "value": 1 },
        { "t": 1, "value": 0 }
      ]
    },
    {
      "target": "to",
      "property": "positionY",
      "keyframes": [
        { "t": 0, "value": 0.25 },
        { "t": 1, "value": 0 }
      ]
    },
    {
      "target": "to",
      "property": "rotation",
      "keyframes": [
        { "t": 0, "value": 8 },
        { "t": 1, "value": 0 }
      ]
    }
  ]
}
''',
    );

    expect(importResult.canImport, isTrue);
    final mapping = mapper.mapDefinition(
      definition: importResult.definition!,
      targetClipId: 'clip-a',
    );

    expect(mapping.hasSupportedLanes, isTrue);
    expect(
      mapping.effectIds,
      <String>[
        'outgoingBoostScale',
        'incomingOffsetX',
        'whiteFlash',
        'outgoingOpacity',
        'incomingOffsetY',
        'incomingRotation',
      ],
    );
    expect(mapping.lanes[0].keyframeValues[0], 100);
    expect(mapping.lanes[0].keyframeValues[1], closeTo(112, 0.0001));
    expect(mapping.lanes[1].keyframeValues, <double>[100, 0]);
    expect(mapping.lanes[2].keyframeValues, <double>[0, 75, 0]);
    expect(mapping.lanes[2].normalizedKeyframeStops, <double>[0, 0.5, 1]);
    expect(mapping.lanes[3].keyframeValues, <double>[100, 0]);
    expect(mapping.lanes[4].keyframeValues, <double>[25, 0]);
    expect(mapping.lanes[5].keyframeValues, <double>[8, 0]);
  });

  test('rejects scripts with no currently editable transition lanes', () {
    final definition = NormalTransitionDefinition(
      definitionId: 'unsupported',
      schemaVersion: kNormalTransitionSchemaVersion,
      label: 'Unsupported',
      category: NormalTransitionCategory.custom,
      rendererTier: NormalTransitionRendererTier.primitive,
      defaultDuration: kNormalTransitionMinimumDuration,
      channels: <NormalTransitionChannelSpec>[
        NormalTransitionChannelSpec(
          target: 'from',
          property: 'skew',
          keyframes: const <NormalTransitionKeyframeSpec>[
            NormalTransitionKeyframeSpec(normalizedTime: 0, value: 0),
            NormalTransitionKeyframeSpec(normalizedTime: 1, value: 90),
          ],
        ),
      ],
    );

    final mapping = mapper.mapDefinition(
      definition: definition,
      targetClipId: 'clip-a',
    );

    expect(mapping.hasSupportedLanes, isFalse);
    expect(
      mapping.issues.any(
        (issue) => issue.severity == NormalTransitionIssueSeverity.error,
      ),
      isTrue,
    );
  });
}
