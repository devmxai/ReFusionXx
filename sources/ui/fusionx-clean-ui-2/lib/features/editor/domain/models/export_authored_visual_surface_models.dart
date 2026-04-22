import 'package:flutter/foundation.dart';

import '../../presentation/models/timeline_time.dart';
import 'export_motion_text_program_models.dart';
import 'professional_motion_compilation_models.dart';
import 'professional_motion_models.dart';

String buildExportAuthoredVisualSurfaceNodeId(String elementId) =>
    'authored-surface:$elementId';

@immutable
class ExportAuthoredVisualSurfaceNode {
  ExportAuthoredVisualSurfaceNode({
    required this.id,
    required this.targetElementId,
    required this.sceneId,
    required this.layerId,
    required this.elementKind,
    required this.projectRange,
    required this.sourceKind,
    required this.sourceId,
    required this.basePositionX,
    required this.basePositionY,
    required this.baseScaleX,
    required this.baseScaleY,
    required this.baseRotationDegrees,
    required this.baseOpacity,
    required this.baseBlurAmount,
    required this.baseWidth,
    required this.baseHeight,
    required this.baseCornerRadius,
    required this.layerOpacity,
    required this.blendMode,
    required this.zIndex,
    required List<ExportMotionScalarChannel> channels,
    required List<ExportMotionScalarChannel> layerChannels,
    this.sourceAssetId,
    this.sourceLabel,
    this.shapeKind,
    Map<String, String> sourceMetadata = const <String, String>{},
    this.sourceRange,
    this.name,
  })  : channels = List.unmodifiable(channels),
        layerChannels = List.unmodifiable(layerChannels),
        sourceMetadata = Map.unmodifiable(sourceMetadata);

  final String id;
  final String targetElementId;
  final String sceneId;
  final String layerId;
  final String elementKind;
  final TimelineTimeRange projectRange;
  final String sourceKind;
  final String sourceId;
  final String? sourceAssetId;
  final String? sourceLabel;
  final String? shapeKind;
  final Map<String, String> sourceMetadata;
  final TimelineTimeRange? sourceRange;
  final double basePositionX;
  final double basePositionY;
  final double baseScaleX;
  final double baseScaleY;
  final double baseRotationDegrees;
  final double baseOpacity;
  final double baseBlurAmount;
  final double baseWidth;
  final double baseHeight;
  final double baseCornerRadius;
  final double layerOpacity;
  final String blendMode;
  final int zIndex;
  final List<ExportMotionScalarChannel> channels;
  final List<ExportMotionScalarChannel> layerChannels;
  final String? name;

  Map<String, Object?> toBridgeMap() => <String, Object?>{
        'id': id,
        'targetElementId': targetElementId,
        'sceneId': sceneId,
        'layerId': layerId,
        'elementKind': elementKind,
        'projectRange': _timelineTimeRangeBridgeMap(projectRange),
        'sourceKind': sourceKind,
        'sourceId': sourceId,
        'sourceAssetId': sourceAssetId,
        'sourceLabel': sourceLabel,
        'shapeKind': shapeKind,
        'sourceMetadata': sourceMetadata,
        'sourceRange': sourceRange == null
            ? null
            : _timelineTimeRangeBridgeMap(sourceRange!),
        'layout': <String, Object?>{
          'basePositionX': basePositionX,
          'basePositionY': basePositionY,
          'baseScaleX': baseScaleX,
          'baseScaleY': baseScaleY,
          'baseRotationDegrees': baseRotationDegrees,
          'baseWidth': baseWidth,
          'baseHeight': baseHeight,
          'baseCornerRadius': baseCornerRadius,
          'zIndex': zIndex,
        },
        'effects': <String, Object?>{
          'opacity': baseOpacity,
          'blurAmount': baseBlurAmount,
          'layerOpacity': layerOpacity,
          'blendMode': blendMode,
        },
        'channels': channels.map((channel) => channel.toBridgeMap()).toList(),
        'layerChannels':
            layerChannels.map((channel) => channel.toBridgeMap()).toList(),
        'channelPropertyIds':
            channels.map((channel) => channel.propertyId).toSet().toList(),
        'layerChannelPropertyIds':
            layerChannels.map((channel) => channel.propertyId).toSet().toList(),
        'name': name,
      };
}

@immutable
class ExportAuthoredVisualSurfaceProgram {
  ExportAuthoredVisualSurfaceProgram({
    required this.contractVersion,
    required this.canvasSize,
    required List<ExportAuthoredVisualSurfaceNode> nodes,
  }) : nodes = List.unmodifiable(nodes);

  final String contractVersion;
  final MotionSize2D canvasSize;
  final List<ExportAuthoredVisualSurfaceNode> nodes;

  Map<String, Object?> toBridgeMap() => <String, Object?>{
        'contractVersion': contractVersion,
        'canvasSize': <String, Object?>{
          'width': canvasSize.width,
          'height': canvasSize.height,
        },
        'nodes': nodes.map((node) => node.toBridgeMap()).toList(),
      };
}

ExportAuthoredVisualSurfaceProgram? buildExportAuthoredVisualSurfaceProgram(
  MotionNormalizedComposition? composition,
) {
  if (composition == null) {
    return null;
  }
  final nodes = <ExportAuthoredVisualSurfaceNode>[];

  for (final scene in composition.scenes) {
    for (final layer in scene.layers) {
      final layerOpacity = _staticScalarPropertyOrDefault(
        layer.staticProperties,
        MotionPropertyCatalog.opacity,
      );
      final layerChannels = _supportedScalarChannels(
        layer.propertyChannels,
        const <String>{'visual.opacity'},
      );

      for (final element in layer.elements) {
        if (!_isSupportedAuthoredVisualElement(element.kind)) {
          continue;
        }
        final sourceBinding = element.sourceBinding;
        nodes.add(
          ExportAuthoredVisualSurfaceNode(
            id: buildExportAuthoredVisualSurfaceNodeId(element.id),
            targetElementId: element.id,
            sceneId: scene.id,
            layerId: layer.id,
            elementKind: element.kind.name,
            projectRange: element.projectRange,
            sourceKind: sourceBinding?.kind.name ??
                MotionSourceKind.generatedShape.name,
            sourceId: sourceBinding?.sourceId ?? element.id,
            sourceAssetId: sourceBinding?.assetId,
            sourceLabel: sourceBinding?.label,
            shapeKind: element.shapeKind?.name,
            sourceMetadata: sourceBinding?.metadata ?? const <String, String>{},
            sourceRange: sourceBinding?.sourceRange,
            basePositionX: _staticScalarPropertyOrDefault(
              element.staticProperties,
              MotionPropertyCatalog.positionX,
            ),
            basePositionY: _staticScalarPropertyOrDefault(
              element.staticProperties,
              MotionPropertyCatalog.positionY,
            ),
            baseScaleX: _staticScalarPropertyOrDefault(
              element.staticProperties,
              MotionPropertyCatalog.scaleX,
            ),
            baseScaleY: _staticScalarPropertyOrDefault(
              element.staticProperties,
              MotionPropertyCatalog.scaleY,
            ),
            baseRotationDegrees: _staticScalarPropertyOrDefault(
              element.staticProperties,
              MotionPropertyCatalog.rotationDegrees,
            ),
            baseOpacity: _staticScalarPropertyOrDefault(
              element.staticProperties,
              MotionPropertyCatalog.opacity,
            ),
            baseBlurAmount: _staticScalarPropertyOrDefault(
              element.staticProperties,
              MotionPropertyCatalog.blurAmount,
            ),
            baseWidth: _staticScalarPropertyOrDefault(
              element.staticProperties,
              MotionPropertyCatalog.width,
            ),
            baseHeight: _staticScalarPropertyOrDefault(
              element.staticProperties,
              MotionPropertyCatalog.height,
            ),
            baseCornerRadius: _staticScalarPropertyOrDefault(
              element.staticProperties,
              MotionPropertyCatalog.cornerRadius,
            ),
            layerOpacity: layerOpacity,
            blendMode: layer.blendMode.name,
            zIndex: layer.zIndex,
            channels: _supportedScalarChannels(
              element.propertyChannels,
              const <String>{
                'transform.position.x',
                'transform.position.y',
                'transform.scale.x',
                'transform.scale.y',
                'transform.rotation.degrees',
                'visual.opacity',
                'visual.blur.amount',
                'visual.blur.mix',
                'visual.blur.edgeMode',
                'visual.blur.crop',
                'shape.width',
                'shape.height',
                'shape.cornerRadius',
              },
            ),
            layerChannels: layerChannels,
            name: element.name,
          ),
        );
      }
    }
  }

  if (nodes.isEmpty) {
    return null;
  }

  return ExportAuthoredVisualSurfaceProgram(
    contractVersion: 'authored-visual-surface.v1alpha1',
    canvasSize: composition.format.canvasSize,
    nodes: nodes,
  );
}

bool _isSupportedAuthoredVisualElement(MotionElementKind kind) {
  switch (kind) {
    case MotionElementKind.image:
    case MotionElementKind.shape:
    case MotionElementKind.mask:
    case MotionElementKind.videoClip:
      return true;
    case MotionElementKind.text:
    case MotionElementKind.audioClip:
    case MotionElementKind.camera:
    case MotionElementKind.effectControl:
      return false;
  }
}

Map<String, Object?> _timelineTimeRangeBridgeMap(TimelineTimeRange range) {
  return <String, Object?>{
    'startMs': range.start.inMilliseconds,
    'durationMs': range.duration.inMilliseconds,
    'endExclusiveMs': range.endExclusive.inMilliseconds,
  };
}

double _staticScalarPropertyOrDefault(
  List<MotionPropertyAssignment> assignments,
  MotionPropertyDefinition definition,
) {
  for (final assignment in assignments) {
    if (assignment.definition.id != definition.id) {
      continue;
    }
    final value = assignment.value;
    if (value.kind == MotionPropertyValueKind.scalar) {
      return value.rawValue as double;
    }
  }
  return definition.defaultValue.rawValue as double;
}

List<ExportMotionScalarChannel> _supportedScalarChannels(
  List<MotionResolvedPropertyChannel> channels,
  Set<String> supportedPropertyIds,
) {
  return channels
      .where((channel) =>
          supportedPropertyIds.contains(channel.channel.definition.id))
      .map(_scalarChannelFromResolved)
      .whereType<ExportMotionScalarChannel>()
      .toList(growable: false);
}

ExportMotionScalarChannel? _scalarChannelFromResolved(
  MotionResolvedPropertyChannel channel,
) {
  if (channel.channel.definition.valueKind != MotionPropertyValueKind.scalar) {
    return null;
  }
  final baseValue = _scalarValue(channel.channel.baseValue);
  final fallbackValue = _scalarValue(channel.channel.fallbackValue);
  if (fallbackValue == null) {
    return null;
  }
  return ExportMotionScalarChannel(
    id: channel.channel.id,
    propertyId: channel.channel.definition.id,
    projectRange: channel.projectRange,
    activeRange: channel.channel.activeRange ?? channel.projectRange,
    beforeStart: channel.channel.beforeStart.name,
    afterEnd: channel.channel.afterEnd.name,
    baseValue: baseValue,
    fallbackValue: fallbackValue,
    keyframes: channel.channel.keyframes
        .map(
          (keyframe) => ExportMotionScalarKeyframe(
            time: keyframe.time,
            value: _scalarValue(keyframe.value) ?? fallbackValue,
            interpolation: ExportMotionInterpolationSpec(
              kind: keyframe.interpolationToNext.kind.name,
              bezier: keyframe.interpolationToNext.bezier == null
                  ? null
                  : ExportMotionBezierControlPoints(
                      x1: keyframe.interpolationToNext.bezier!.x1,
                      y1: keyframe.interpolationToNext.bezier!.y1,
                      x2: keyframe.interpolationToNext.bezier!.x2,
                      y2: keyframe.interpolationToNext.bezier!.y2,
                    ),
              spring: keyframe.interpolationToNext.spring == null
                  ? null
                  : ExportMotionSpringSpec(
                      stiffness: keyframe.interpolationToNext.spring!.stiffness,
                      damping: keyframe.interpolationToNext.spring!.damping,
                      mass: keyframe.interpolationToNext.spring!.mass,
                      initialVelocity:
                          keyframe.interpolationToNext.spring!.initialVelocity,
                    ),
            ),
          ),
        )
        .toList(growable: false),
  );
}

double? _scalarValue(MotionPropertyValue? value) {
  if (value == null) {
    return null;
  }
  return switch (value.kind) {
    MotionPropertyValueKind.scalar => value.rawValue as double,
    MotionPropertyValueKind.integer => (value.rawValue as int).toDouble(),
    _ => null,
  };
}
