import 'package:flutter/foundation.dart';

import '../../presentation/models/timeline_time.dart';
import 'professional_motion_animation_models.dart';
import 'professional_motion_compilation_models.dart';
import 'professional_motion_models.dart';
import 'professional_motion_text_render_models.dart';
import 'professional_motion_text_models.dart';

String buildExportMotionTextNodeId(String elementId) =>
    'text-program:$elementId';

@immutable
class ExportMotionBezierControlPoints {
  const ExportMotionBezierControlPoints({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
  });

  final double x1;
  final double y1;
  final double x2;
  final double y2;

  Map<String, Object?> toBridgeMap() => <String, Object?>{
        'x1': x1,
        'y1': y1,
        'x2': x2,
        'y2': y2,
      };
}

@immutable
class ExportMotionSpringSpec {
  const ExportMotionSpringSpec({
    required this.stiffness,
    required this.damping,
    required this.mass,
    required this.initialVelocity,
  });

  final double stiffness;
  final double damping;
  final double mass;
  final double initialVelocity;

  Map<String, Object?> toBridgeMap() => <String, Object?>{
        'stiffness': stiffness,
        'damping': damping,
        'mass': mass,
        'initialVelocity': initialVelocity,
      };
}

@immutable
class ExportMotionInterpolationSpec {
  const ExportMotionInterpolationSpec({
    required this.kind,
    this.bezier,
    this.spring,
  });

  final String kind;
  final ExportMotionBezierControlPoints? bezier;
  final ExportMotionSpringSpec? spring;

  Map<String, Object?> toBridgeMap() => <String, Object?>{
        'kind': kind,
        'bezier': bezier?.toBridgeMap(),
        'spring': spring?.toBridgeMap(),
      };
}

@immutable
class ExportMotionScalarKeyframe {
  const ExportMotionScalarKeyframe({
    required this.time,
    required this.value,
    required this.interpolation,
  });

  final TimelineTime time;
  final double value;
  final ExportMotionInterpolationSpec interpolation;

  String get interpolationKind => interpolation.kind;

  Map<String, Object?> toBridgeMap() => <String, Object?>{
        'timeMs': time.inMilliseconds,
        'value': value,
        'interpolationKind': interpolationKind,
        'interpolation': interpolation.toBridgeMap(),
      };
}

@immutable
class ExportMotionScalarChannel {
  ExportMotionScalarChannel({
    required this.id,
    required this.propertyId,
    required this.projectRange,
    required this.activeRange,
    required this.beforeStart,
    required this.afterEnd,
    required List<ExportMotionScalarKeyframe> keyframes,
    this.baseValue,
    required this.fallbackValue,
  }) : keyframes = List.unmodifiable(keyframes);

  final String id;
  final String propertyId;
  final TimelineTimeRange projectRange;
  final TimelineTimeRange activeRange;
  final String beforeStart;
  final String afterEnd;
  final double? baseValue;
  final double fallbackValue;
  final List<ExportMotionScalarKeyframe> keyframes;

  Map<String, Object?> toBridgeMap() => <String, Object?>{
        'id': id,
        'propertyId': propertyId,
        'projectRange': _timelineTimeRangeBridgeMap(projectRange),
        'activeRange': _timelineTimeRangeBridgeMap(activeRange),
        'beforeStart': beforeStart,
        'afterEnd': afterEnd,
        'baseValue': baseValue,
        'fallbackValue': fallbackValue,
        'keyframes': keyframes
            .map((keyframe) => keyframe.toBridgeMap())
            .toList(growable: false),
      };
}

@immutable
class ExportMotionTextProgramAnimationBlock {
  ExportMotionTextProgramAnimationBlock({
    required this.id,
    required this.kind,
    required this.projectRange,
    required this.interpolation,
    required Map<String, MotionPropertyValue> parameters,
    this.revealUnit,
    this.revealStagger,
  }) : parameters = Map.unmodifiable(parameters);

  final String id;
  final String kind;
  final TimelineTimeRange projectRange;
  final ExportMotionInterpolationSpec interpolation;
  final Map<String, MotionPropertyValue> parameters;
  final String? revealUnit;
  final TimelineTime? revealStagger;

  String get interpolationKind => interpolation.kind;

  Map<String, Object?> toBridgeMap() => <String, Object?>{
        'id': id,
        'kind': kind,
        'projectRange': _timelineTimeRangeBridgeMap(projectRange),
        'interpolationKind': interpolationKind,
        'interpolation': interpolation.toBridgeMap(),
        'parameters': _motionPropertyValueMapBridgeValue(parameters),
        'revealUnit': revealUnit,
        'revealStaggerMs': revealStagger?.inMilliseconds,
      };
}

@immutable
class ExportMotionTextProgramNode {
  ExportMotionTextProgramNode({
    required this.id,
    required this.targetElementId,
    required this.sceneId,
    required this.layerId,
    required this.projectRange,
    required this.fullText,
    required this.revealUnit,
    required this.basePositionX,
    required this.basePositionY,
    required this.baseScaleX,
    required this.baseScaleY,
    required this.baseRotationDegrees,
    required this.baseOpacity,
    required this.baseBlurAmount,
    required this.baseFontSize,
    required this.baseLetterSpacing,
    required this.layerOpacity,
    required this.colorArgb,
    required this.fontFamily,
    required this.fontWeight,
    required this.fontStyle,
    required this.lineHeight,
    required this.textAlignment,
    required this.anchor,
    required this.blendMode,
    required this.zIndex,
    required List<String> animationKinds,
    required List<ExportMotionTextProgramAnimationBlock> animationBlocks,
    required List<ExportMotionScalarChannel> channels,
    required List<ExportMotionScalarChannel> layerChannels,
    this.name,
    this.presetId,
  })  : animationKinds = List.unmodifiable(animationKinds),
        animationBlocks = List.unmodifiable(animationBlocks),
        channels = List.unmodifiable(channels),
        layerChannels = List.unmodifiable(layerChannels);

  final String id;
  final String targetElementId;
  final String sceneId;
  final String layerId;
  final TimelineTimeRange projectRange;
  final String fullText;
  final String revealUnit;
  final double basePositionX;
  final double basePositionY;
  final double baseScaleX;
  final double baseScaleY;
  final double baseRotationDegrees;
  final double baseOpacity;
  final double baseBlurAmount;
  final double baseFontSize;
  final double baseLetterSpacing;
  final double layerOpacity;
  final int colorArgb;
  final String? fontFamily;
  final int fontWeight;
  final String fontStyle;
  final double lineHeight;
  final String textAlignment;
  final String anchor;
  final String blendMode;
  final int zIndex;
  final List<String> animationKinds;
  final List<ExportMotionTextProgramAnimationBlock> animationBlocks;
  final List<ExportMotionScalarChannel> channels;
  final List<ExportMotionScalarChannel> layerChannels;
  final String? name;
  final String? presetId;
}

@immutable
class ExportMotionTextProgram {
  ExportMotionTextProgram({
    required this.canvasSize,
    required List<ExportMotionTextProgramNode> nodes,
  }) : nodes = List.unmodifiable(nodes);

  final MotionSize2D canvasSize;
  final List<ExportMotionTextProgramNode> nodes;
}

ExportMotionTextProgram? buildExportMotionTextProgram(
  MotionNormalizedComposition? composition,
) {
  if (composition == null) {
    return null;
  }
  final presetCatalog = <String, MotionTextPresetDefinition>{
    for (final preset in MotionBuiltInTextPresets.all) preset.id: preset,
  };
  final textAnimationsByElementId = <String, MotionResolvedTextAnimationModel>{
    for (final animation in composition.textAnimations)
      animation.targetElementId: animation,
  };
  final nodes = <ExportMotionTextProgramNode>[];

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
        if (element.kind != MotionElementKind.text) {
          continue;
        }
        final textAnimation = textAnimationsByElementId[element.id];
        final fullText = _resolveProgramFullText(
          element: element,
          textAnimation: textAnimation,
          presetCatalog: presetCatalog,
        );
        final revealUnit = _resolveProgramRevealUnit(textAnimation);
        nodes.add(
          ExportMotionTextProgramNode(
            id: buildExportMotionTextNodeId(element.id),
            targetElementId: element.id,
            sceneId: scene.id,
            layerId: layer.id,
            projectRange: element.projectRange,
            fullText: fullText,
            revealUnit: revealUnit.name,
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
            baseFontSize: _staticScalarPropertyOrDefault(
              element.staticProperties,
              MotionPropertyCatalog.fontSize,
            ),
            baseLetterSpacing: _staticScalarPropertyOrDefault(
              element.staticProperties,
              MotionPropertyCatalog.letterSpacing,
            ),
            layerOpacity: layerOpacity,
            colorArgb: kMotionTextCanonicalColorArgb,
            fontFamily: kMotionTextCanonicalFontFamily,
            fontWeight: kMotionTextCanonicalFontWeight,
            fontStyle: kMotionTextCanonicalFontStyle,
            lineHeight: kMotionTextCanonicalLineHeight,
            textAlignment: kMotionTextCanonicalTextAlignment,
            anchor: kMotionTextCanonicalAnchor,
            blendMode: layer.blendMode.name,
            zIndex: layer.zIndex,
            animationKinds: (textAnimation?.animationKinds ??
                    const <MotionTextAnimationKind>[])
                .map((kind) => kind.name)
                .toList(growable: false),
            animationBlocks: (textAnimation?.animationBlocks ??
                    const <MotionResolvedTextAnimationBlockModel>[])
                .map(_buildProgramAnimationBlock)
                .toList(growable: false),
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
                'text.fontSize',
                'text.letterSpacing',
                'text.revealProgress',
              },
            ),
            layerChannels: layerChannels,
            name: element.name,
            presetId: textAnimation?.presetId,
          ),
        );
      }
    }
  }

  if (nodes.isEmpty) {
    return null;
  }

  return ExportMotionTextProgram(
    canvasSize: composition.format.canvasSize,
    nodes: nodes,
  );
}

Map<String, Object?> _timelineTimeRangeBridgeMap(TimelineTimeRange range) {
  return <String, Object?>{
    'startMs': range.start.inMilliseconds,
    'durationMs': range.duration.inMilliseconds,
    'endExclusiveMs': range.endExclusive.inMilliseconds,
  };
}

Map<String, Object?> _motionPropertyValueMapBridgeValue(
  Map<String, MotionPropertyValue> values,
) {
  return Map<String, Object?>.unmodifiable(
    values.map(
      (key, value) => MapEntry<String, Object?>(
        key,
        _motionPropertyValueBridgeMap(value),
      ),
    ),
  );
}

Map<String, Object?> _motionPropertyValueBridgeMap(MotionPropertyValue value) {
  return <String, Object?>{
    'kind': value.kind.name,
    'raw': _motionPropertyRawBridgeValue(value),
  };
}

Object? _motionPropertyRawBridgeValue(MotionPropertyValue value) {
  switch (value.kind) {
    case MotionPropertyValueKind.scalar:
    case MotionPropertyValueKind.integer:
    case MotionPropertyValueKind.boolean:
    case MotionPropertyValueKind.stringValue:
    case MotionPropertyValueKind.enumValue:
      return value.rawValue;
    case MotionPropertyValueKind.colorArgb:
      final argb = value.rawValue as int;
      return <String, Object?>{
        'argb': argb,
        'hex': '0x${argb.toRadixString(16).padLeft(8, '0').toUpperCase()}',
      };
    case MotionPropertyValueKind.point2D:
      final point = value.rawValue as MotionPoint2D;
      return <String, Object?>{
        'x': point.x,
        'y': point.y,
      };
    case MotionPropertyValueKind.size2D:
      final size = value.rawValue as MotionSize2D;
      return <String, Object?>{
        'width': size.width,
        'height': size.height,
      };
    case MotionPropertyValueKind.rect:
      final rect = value.rawValue as MotionRect;
      return <String, Object?>{
        'left': rect.left,
        'top': rect.top,
        'width': rect.width,
        'height': rect.height,
      };
  }
}

ExportMotionTextProgramAnimationBlock _buildProgramAnimationBlock(
  MotionResolvedTextAnimationBlockModel block,
) {
  return ExportMotionTextProgramAnimationBlock(
    id: block.id,
    kind: block.kind.name,
    projectRange: block.projectRange,
    interpolation: _exportInterpolationFromMotion(block.interpolation),
    parameters: block.parameters,
    revealUnit: block.revealSpec?.unit.name,
    revealStagger: block.revealSpec?.stagger,
  );
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
            interpolation: _exportInterpolationFromMotion(
              keyframe.interpolationToNext,
            ),
          ),
        )
        .toList(growable: false),
  );
}

ExportMotionInterpolationSpec _exportInterpolationFromMotion(
  MotionInterpolationSpec interpolation,
) {
  return ExportMotionInterpolationSpec(
    kind: interpolation.kind.name,
    bezier: interpolation.bezier == null
        ? null
        : ExportMotionBezierControlPoints(
            x1: interpolation.bezier!.x1,
            y1: interpolation.bezier!.y1,
            x2: interpolation.bezier!.x2,
            y2: interpolation.bezier!.y2,
          ),
    spring: interpolation.spring == null
        ? null
        : ExportMotionSpringSpec(
            stiffness: interpolation.spring!.stiffness,
            damping: interpolation.spring!.damping,
            mass: interpolation.spring!.mass,
            initialVelocity: interpolation.spring!.initialVelocity,
          ),
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

String _resolveProgramFullText({
  required MotionResolvedElementModel element,
  required MotionResolvedTextAnimationModel? textAnimation,
  required Map<String, MotionTextPresetDefinition> presetCatalog,
}) {
  final sourceBinding = element.sourceBinding;
  final metadata = sourceBinding?.metadata;
  final metadataText = metadata?['text'] ??
      metadata?['content'] ??
      metadata?['value'] ??
      metadata?['displayText'];
  if (metadataText != null && metadataText.isNotEmpty) {
    return metadataText;
  }
  if (sourceBinding?.label != null && sourceBinding!.label!.isNotEmpty) {
    return sourceBinding.label!;
  }
  final presetId = textAnimation?.presetId;
  final preset = presetId == null ? null : presetCatalog[presetId];
  if (preset != null && preset.defaultText.isNotEmpty) {
    return preset.defaultText;
  }
  if (element.name != null && element.name!.isNotEmpty) {
    return element.name!;
  }
  return '';
}

MotionTextRevealUnit _resolveProgramRevealUnit(
  MotionResolvedTextAnimationModel? textAnimation,
) {
  final kinds =
      textAnimation?.animationKinds ?? const <MotionTextAnimationKind>[];
  if (kinds.contains(MotionTextAnimationKind.wordReveal)) {
    return MotionTextRevealUnit.word;
  }
  if (kinds.contains(MotionTextAnimationKind.letterReveal) ||
      kinds.contains(MotionTextAnimationKind.typewriter)) {
    return MotionTextRevealUnit.letter;
  }
  return MotionTextRevealUnit.wholeText;
}
