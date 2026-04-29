import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_animation_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/domain/services/layer_scope_composition_adapter.dart';
import 'package:refusion_app/features/editor/domain/services/scope_motion_property_catalog.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';

void main() {
  const catalog = ScopeMotionPropertyCatalog();
  const adapter = LayerScopeCompositionAdapter();

  TimelineTime at(double seconds) => TimelineTime.fromSecondsDouble(seconds);

  TimelineTimeRange range(double start, double end) {
    return TimelineTimeRange(
      start: at(start),
      endExclusive: at(end),
    );
  }

  String propertyIds(Iterable<MotionPropertyDefinition> definitions) {
    return definitions.map((definition) => definition.id).join('|');
  }

  MotionElementModel element({
    required String layerId,
    required String elementId,
    required MotionElementKind kind,
  }) {
    return MotionElementModel(
      id: elementId,
      layerId: layerId,
      kind: kind,
      localRange: range(0, 6),
    );
  }

  MotionLayerModel layer({
    required String layerId,
    required MotionLayerKind layerKind,
    required MotionElementModel element,
  }) {
    return MotionLayerModel(
      id: layerId,
      sceneId: 'scene',
      kind: layerKind,
      visibleRange: range(0, 6),
      elements: <MotionElementModel>[element],
    );
  }

  MotionProjectModel project() {
    final textElement = element(
      layerId: 'text-layer',
      elementId: 'text-element',
      kind: MotionElementKind.text,
    );
    final imageElement = element(
      layerId: 'image-layer',
      elementId: 'image-element',
      kind: MotionElementKind.image,
    );
    final shapeElement = element(
      layerId: 'shape-layer',
      elementId: 'shape-element',
      kind: MotionElementKind.shape,
    );

    return MotionProjectModel(
      id: 'project',
      format: const MotionProjectFormat(
        canvasSize: MotionSize2D(width: 1080, height: 1920),
      ),
      frameRate: const MotionFrameRate(numerator: 60, denominator: 1),
      scenes: <MotionSceneModel>[
        MotionSceneModel(
          id: 'scene',
          projectRange: range(0, 12),
          layers: <MotionLayerModel>[
            layer(
              layerId: 'text-layer',
              layerKind: MotionLayerKind.text,
              element: textElement,
            ),
            layer(
              layerId: 'image-layer',
              layerKind: MotionLayerKind.image,
              element: imageElement,
            ),
            layer(
              layerId: 'shape-layer',
              layerKind: MotionLayerKind.shape,
              element: shapeElement,
            ),
          ],
        ),
      ],
    );
  }

  test('shares transform and visual properties across editable visual scopes',
      () {
    final expectedSharedIds = propertyIds(
      ScopeMotionPropertyCatalog.sharedVisualElementProperties,
    );

    for (final kind in <MotionElementKind>[
      MotionElementKind.text,
      MotionElementKind.image,
      MotionElementKind.shape,
    ]) {
      final properties = catalog.propertiesForElementKind(kind);
      expect(
        propertyIds(
          properties.take(
            ScopeMotionPropertyCatalog.sharedVisualElementProperties.length,
          ),
        ),
        expectedSharedIds,
      );
      expect(
        properties.map((definition) => definition.id),
        containsAll(<String>[
          MotionPropertyCatalog.positionX.id,
          MotionPropertyCatalog.positionY.id,
          MotionPropertyCatalog.scaleX.id,
          MotionPropertyCatalog.scaleY.id,
          MotionPropertyCatalog.rotationDegrees.id,
          MotionPropertyCatalog.opacity.id,
          MotionPropertyCatalog.blurAmount.id,
        ]),
      );
    }
  });

  test('keeps kind-specific property support explicit', () {
    expect(
      catalog.propertiesForElementKind(MotionElementKind.text).map(
            (definition) => definition.id,
          ),
      containsAll(<String>[
        MotionPropertyCatalog.fontSize.id,
        MotionPropertyCatalog.fontWeight.id,
        MotionPropertyCatalog.letterSpacing.id,
        MotionPropertyCatalog.revealProgress.id,
      ]),
    );
    expect(
      catalog.propertiesForElementKind(MotionElementKind.image).map(
            (definition) => definition.id,
          ),
      contains(MotionPropertyCatalog.cropRect.id),
    );
    expect(
      catalog.propertiesForElementKind(MotionElementKind.shape).map(
            (definition) => definition.id,
          ),
      containsAll(<String>[
        MotionPropertyCatalog.width.id,
        MotionPropertyCatalog.height.id,
        MotionPropertyCatalog.cornerRadius.id,
      ]),
    );

    expect(
      catalog.supportsPropertyForElementKind(
        elementKind: MotionElementKind.text,
        definition: MotionPropertyCatalog.width,
      ),
      isFalse,
    );
    expect(
      catalog.supportsPropertyForElementKind(
        elementKind: MotionElementKind.shape,
        definition: MotionPropertyCatalog.revealProgress,
      ),
      isFalse,
    );
    expect(catalog.supportsElementKind(MotionElementKind.videoClip), isFalse);
  });

  test('builds canonical element targets for scope authoring', () {
    final target = catalog.elementTarget(
      projectId: 'project',
      sceneId: 'scene',
      layerId: 'shape-layer',
      elementId: 'shape-element',
    );

    expect(target.kind, MotionTargetKind.element);
    expect(target.targetId, 'shape-element');
    expect(target.layerId, 'shape-layer');
    expect(target.elementId, 'shape-element');
    expect(target.canonicalAddress, 'element:shape-element');
  });

  test('uses the same layer scope adapter for text image and shape keyframes',
      () {
    final motionProject = project();
    var channels = const <MotionPropertyChannelModel>[];

    for (final spec in <({String layerId, String elementId})>[
      (layerId: 'text-layer', elementId: 'text-element'),
      (layerId: 'image-layer', elementId: 'image-element'),
      (layerId: 'shape-layer', elementId: 'shape-element'),
    ]) {
      final scope = adapter
          .resolveScope(
            project: motionProject,
            sceneId: 'scene',
            layerId: spec.layerId,
            globalTime: at(2),
            channels: channels,
          )
          .projection!;
      final target = catalog.elementTarget(
        projectId: 'project',
        sceneId: 'scene',
        layerId: spec.layerId,
        elementId: spec.elementId,
      );
      final result = adapter.addKeyframe(
        LayerScopeCompositionKeyframeRequest(
          projection: scope,
          channels: channels,
          target: target,
          definition: MotionPropertyCatalog.opacity,
          localTime: at(1),
          value: const MotionPropertyValue.scalar(0.5),
        ),
      );

      expect(result.hasIssues, isFalse);
      channels = result.channels;
    }

    expect(channels, hasLength(3));
    expect(
      channels.map((channel) => channel.target.targetId),
      <String>['text-element', 'image-element', 'shape-element'],
    );
    expect(
      channels.map((channel) => channel.definition.id).toSet(),
      <String>{MotionPropertyCatalog.opacity.id},
    );
    expect(
      channels.every((channel) => channel.keyframes.single.time == at(1)),
      isTrue,
    );
  });
}
