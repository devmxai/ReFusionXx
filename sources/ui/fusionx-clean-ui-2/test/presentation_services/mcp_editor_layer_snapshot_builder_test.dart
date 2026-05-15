// ignore_for_file: prefer_const_literals_to_create_immutables

import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';
import 'package:refusion_app/features/editor/presentation/services/mcp_editor_layer_snapshot_builder.dart';

void main() {
  TimelineTime ms(int value) => TimelineTime.fromMilliseconds(value);

  MotionProjectModel buildProject() {
    final sceneRange = TimelineTimeRange(
      start: TimelineTime.zero,
      endExclusive: ms(4000),
    );
    final visualColor = MotionPropertyDefinition(
      id: 'visual.color',
      path: const MotionPropertyPath(
        group: MotionPropertyGroup.visual,
        name: 'color',
      ),
      valueKind: MotionPropertyValueKind.colorArgb,
      supportedTargets: const <MotionTargetKind>[MotionTargetKind.element],
      defaultValue: const MotionPropertyValue.colorArgb(0xFF111111),
    );
    final textElements = <MotionElementModel>[
      MotionElementModel(
        id: 'element-text',
        layerId: 'layer-text',
        kind: MotionElementKind.text,
        localRange: TimelineTimeRange(
          start: TimelineTime.zero,
          endExclusive: ms(3000),
        ),
        name: 'Title',
        sourceBinding: MotionElementSourceBinding(
          kind: MotionSourceKind.generatedText,
          sourceId: 'mcp.remote.text.1',
          label: 'Hello MCP',
          metadata: <String, String>{
            'text': 'Hello MCP',
            'mcp.remoteLayerId': 'remote-text-1',
            'mcp.remoteLayerName': 'Title',
          },
        ),
        properties: <MotionPropertyAssignment>[
          MotionPropertyAssignment(
            target: const MotionPropertyTarget(
              kind: MotionTargetKind.element,
              targetId: 'element-text',
            ),
            definition: MotionPropertyCatalog.positionX,
            value: const MotionPropertyValue.scalar(540),
          ),
          MotionPropertyAssignment(
            target: const MotionPropertyTarget(
              kind: MotionTargetKind.element,
              targetId: 'element-text',
            ),
            definition: MotionPropertyCatalog.positionY,
            value: const MotionPropertyValue.scalar(960),
          ),
          MotionPropertyAssignment(
            target: const MotionPropertyTarget(
              kind: MotionTargetKind.element,
              targetId: 'element-text',
            ),
            definition: MotionPropertyCatalog.fontSize,
            value: const MotionPropertyValue.scalar(28),
          ),
          MotionPropertyAssignment(
            target: const MotionPropertyTarget(
              kind: MotionTargetKind.element,
              targetId: 'element-text',
            ),
            definition: visualColor,
            value: const MotionPropertyValue.colorArgb(0xFF112233),
          ),
        ],
      ),
    ];

    final textLayer = MotionLayerModel(
      id: 'layer-text',
      sceneId: 'scene-1',
      kind: MotionLayerKind.text,
      visibleRange: sceneRange,
      zIndex: 10,
      elements: textElements,
    );

    final shapeElements = <MotionElementModel>[
      MotionElementModel(
        id: 'element-solid',
        layerId: 'layer-solid',
        kind: MotionElementKind.shape,
        shapeKind: MotionShapeKind.rectangle,
        localRange: TimelineTimeRange(
          start: TimelineTime.zero,
          endExclusive: ms(4000),
        ),
        name: 'Background',
        sourceBinding: MotionElementSourceBinding(
          kind: MotionSourceKind.generatedShape,
          sourceId: 'mcp.remote.shape.1',
          label: 'Background',
          metadata: <String, String>{
            'mcp.remoteLayerId': 'remote-solid-1',
            'mcp.remoteLayerName': 'Background',
            'mcp.backgroundRole': 'canvas',
          },
        ),
        properties: <MotionPropertyAssignment>[
          MotionPropertyAssignment(
            target: const MotionPropertyTarget(
              kind: MotionTargetKind.element,
              targetId: 'element-solid',
            ),
            definition: MotionPropertyCatalog.positionX,
            value: const MotionPropertyValue.scalar(540),
          ),
          MotionPropertyAssignment(
            target: const MotionPropertyTarget(
              kind: MotionTargetKind.element,
              targetId: 'element-solid',
            ),
            definition: MotionPropertyCatalog.positionY,
            value: const MotionPropertyValue.scalar(960),
          ),
          MotionPropertyAssignment(
            target: const MotionPropertyTarget(
              kind: MotionTargetKind.element,
              targetId: 'element-solid',
            ),
            definition: MotionPropertyCatalog.width,
            value: const MotionPropertyValue.scalar(1080),
          ),
          MotionPropertyAssignment(
            target: const MotionPropertyTarget(
              kind: MotionTargetKind.element,
              targetId: 'element-solid',
            ),
            definition: MotionPropertyCatalog.height,
            value: const MotionPropertyValue.scalar(1920),
          ),
          MotionPropertyAssignment(
            target: const MotionPropertyTarget(
              kind: MotionTargetKind.element,
              targetId: 'element-solid',
            ),
            definition: visualColor,
            value: const MotionPropertyValue.colorArgb(0xFFFFFFFF),
          ),
        ],
      ),
    ];

    final shapeLayer = MotionLayerModel(
      id: 'layer-solid',
      sceneId: 'scene-1',
      kind: MotionLayerKind.shape,
      visibleRange: sceneRange,
      zIndex: 0,
      elements: shapeElements,
    );

    return MotionProjectModel(
      id: 'project-1',
      format: const MotionProjectFormat(
        canvasSize: MotionSize2D(width: 1080, height: 1920),
      ),
      frameRate: const MotionFrameRate(numerator: 30, denominator: 1),
      scenes: <MotionSceneModel>[
        MotionSceneModel(
          id: 'scene-1',
          projectRange: sceneRange,
          layers: <MotionLayerModel>[shapeLayer, textLayer],
        ),
      ],
    );
  }

  test('exports text and solid snapshots for MCP visibility', () {
    const builder = McpEditorLayerSnapshotBuilder();
    final snapshots = builder.buildProjectLayerSnapshots(
      project: buildProject(),
      canvasSize: const MotionSize2D(width: 1080, height: 1920),
    );

    expect(snapshots, hasLength(2));

    final solidSnapshot = snapshots.firstWhere(
      (snapshot) => snapshot['layerKind'] == 'solid',
    );
    final solidPayload = solidSnapshot['payload'] as Map<String, Object?>;
    expect(solidPayload['localLayerId'], 'element-solid');
    expect(solidPayload['mcp.backgroundRole'], 'canvas');
    expect(solidPayload['width'], 1080);
    expect(solidPayload['height'], 1920);
    expect(solidPayload['label'], 'Background');
    expect(solidPayload['coordinateSpace'], 'centerOrigin');
    expect(solidPayload['absoluteCenterX'], 1080);
    expect(solidPayload['absoluteCenterY'], 1920);

    final textSnapshot = snapshots.firstWhere(
      (snapshot) => snapshot['layerKind'] == 'text',
    );
    final textPayload = textSnapshot['payload'] as Map<String, Object?>;
    expect(textPayload['localLayerId'], 'element-text');
    expect(textPayload['content'], 'Hello MCP');
    expect(textPayload['text'], 'Hello MCP');
    expect(textPayload['label'], 'Title');
    expect(textPayload['fontSize'], 28);
    expect(textPayload['coordinateSpace'], 'centerOrigin');
    expect(textPayload['centerX'], 1080);
    expect(textPayload['centerY'], 1920);
  });
}
