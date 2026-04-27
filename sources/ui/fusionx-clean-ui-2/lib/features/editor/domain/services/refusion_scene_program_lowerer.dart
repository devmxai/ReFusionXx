import 'package:flutter/foundation.dart';

import '../../presentation/models/timeline_time.dart';
import '../models/professional_motion_animation_models.dart';
import '../models/professional_motion_interpolation_parsing.dart';
import '../models/professional_motion_models.dart';
import '../models/professional_motion_text_models.dart';
import '../models/refusion_scene_program_models.dart';
import 'refusion_core_design_pack.dart';

@immutable
class ReFusionSceneProgramLoweringRequest {
  const ReFusionSceneProgramLoweringRequest({
    required this.program,
    this.projectId,
    this.sceneId,
    this.canvasSize = const MotionSize2D(width: 1080, height: 1920),
  });

  final ReFusionSceneProgram program;
  final String? projectId;
  final String? sceneId;
  final MotionSize2D canvasSize;
}

@immutable
class ReFusionSceneProgramLoweringResult {
  ReFusionSceneProgramLoweringResult({
    required this.project,
    required List<MotionPropertyChannelModel> channels,
    List<MotionTextAnimationBindingModel> textAnimationBindings =
        const <MotionTextAnimationBindingModel>[],
    List<ReFusionSceneProgramIssue> issues =
        const <ReFusionSceneProgramIssue>[],
  })  : channels = List.unmodifiable(channels),
        textAnimationBindings = List.unmodifiable(textAnimationBindings),
        issues = List.unmodifiable(issues);

  final MotionProjectModel project;
  final List<MotionPropertyChannelModel> channels;
  final List<MotionTextAnimationBindingModel> textAnimationBindings;
  final List<ReFusionSceneProgramIssue> issues;

  bool get hasErrors => issues.any(
        (issue) => issue.severity == ReFusionSceneProgramIssueSeverity.error,
      );
}

class ReFusionSceneProgramLowerer {
  const ReFusionSceneProgramLowerer();

  ReFusionSceneProgramLoweringResult lower(
    ReFusionSceneProgramLoweringRequest request,
  ) {
    final issues = <ReFusionSceneProgramIssue>[];
    final channels = <MotionPropertyChannelModel>[];
    final textAnimationBindings = <MotionTextAnimationBindingModel>[];
    final projectId = _sanitizeId(request.projectId ?? request.program.name);
    final sceneId = _sanitizeId(request.sceneId ?? '${projectId}_scene');
    final projectDuration = TimelineTime.fromMilliseconds(
      request.program.durationMs,
    );
    final sceneRange = TimelineTimeRange(
      start: TimelineTime.zero,
      endExclusive: projectDuration,
    );
    final layers = <MotionLayerModel>[];
    final channelIds = <String>{};

    for (var index = 0; index < request.program.layers.length; index += 1) {
      final layer = request.program.layers[index];
      final layerPath = 'layers[$index]';
      final layerModel = _lowerLayer(
        layer: layer,
        layerPath: layerPath,
        projectId: projectId,
        sceneId: sceneId,
        zIndex: index,
        sceneDuration: projectDuration,
        channels: channels,
        channelIds: channelIds,
        textAnimationBindings: textAnimationBindings,
        issues: issues,
      );
      if (layerModel != null) {
        layers.add(layerModel);
      }
    }

    final project = MotionProjectModel(
      id: projectId,
      name: request.program.name,
      format: MotionProjectFormat(canvasSize: request.canvasSize),
      frameRate: _frameRateFor(request.program.frameRate),
      scenes: <MotionSceneModel>[
        MotionSceneModel(
          id: sceneId,
          name: request.program.name,
          projectRange: sceneRange,
          layers: layers,
          metadata: <String, String>{
            'source': 'refusion.scene-program',
            'schemaVersion': request.program.schemaVersion,
          },
        ),
      ],
      metadata: <String, String>{
        'source': 'refusion.scene-program',
        'schemaVersion': request.program.schemaVersion,
      },
    );

    return ReFusionSceneProgramLoweringResult(
      project: project,
      channels: channels,
      textAnimationBindings: textAnimationBindings,
      issues: issues,
    );
  }

  MotionLayerModel? _lowerLayer({
    required ReFusionSceneProgramLayer layer,
    required String layerPath,
    required String projectId,
    required String sceneId,
    required int zIndex,
    required TimelineTime sceneDuration,
    required List<MotionPropertyChannelModel> channels,
    required Set<String> channelIds,
    required List<MotionTextAnimationBindingModel> textAnimationBindings,
    required List<ReFusionSceneProgramIssue> issues,
  }) {
    final layerKind = _layerKindFor(layer.kind);
    if (layerKind == null) {
      _addIssue(
        issues,
        severity: ReFusionSceneProgramIssueSeverity.warning,
        message: 'Layer kind `${layer.kind}` is not supported by lowering v1.',
        path: '$layerPath.kind',
      );
      return null;
    }

    final visibleRange = _rangeFor(
      startMs: layer.startMs,
      durationMs: layer.durationMs,
      maxEnd: sceneDuration,
    );
    final elements = <MotionElementModel>[];
    for (var index = 0; index < layer.elements.length; index += 1) {
      final element = layer.elements[index];
      final elementPath = '$layerPath.elements[$index]';
      final elementModel = _lowerElement(
        element: element,
        elementPath: elementPath,
        layer: layer,
        projectId: projectId,
        sceneId: sceneId,
        layerRange: visibleRange,
        issues: issues,
      );
      if (elementModel == null) {
        continue;
      }
      elements.add(elementModel);
      _lowerChannels(
        ownerChannels: element.channels,
        ownerPath: '$elementPath.channels',
        ownerId: element.id,
        ownerTarget: _elementTarget(
          projectId: projectId,
          sceneId: sceneId,
          layerId: layer.id,
          elementId: element.id,
        ),
        elementKind: elementModel.kind,
        activeRange: visibleRange,
        timeOffset: visibleRange.start,
        channelPrefix: <String>[layer.id, element.id],
        channels: channels,
        channelIds: channelIds,
        issues: issues,
      );
      final textBinding = _textRevealBindingForElement(
        element: element,
        elementKind: elementModel.kind,
        layer: layer,
        projectId: projectId,
        sceneId: sceneId,
        activeRange: visibleRange,
      );
      if (textBinding != null) {
        textAnimationBindings.add(textBinding);
      }
    }

    if (elements.isEmpty) {
      _addIssue(
        issues,
        severity: ReFusionSceneProgramIssueSeverity.warning,
        message: 'Layer `${layer.id}` produced no supported elements.',
        path: '$layerPath.elements',
      );
      return null;
    }

    final layerTarget = MotionPropertyTarget(
      kind: MotionTargetKind.layer,
      targetId: layer.id,
      projectId: projectId,
      sceneId: sceneId,
      layerId: layer.id,
    );
    _lowerChannels(
      ownerChannels: layer.channels,
      ownerPath: '$layerPath.channels',
      ownerId: layer.id,
      ownerTarget: layerTarget,
      fallbackElementTarget: _elementTarget(
        projectId: projectId,
        sceneId: sceneId,
        layerId: layer.id,
        elementId: elements.first.id,
      ),
      fallbackElementKind: elements.first.kind,
      activeRange: visibleRange,
      timeOffset: visibleRange.start,
      channelPrefix: <String>[layer.id],
      channels: channels,
      channelIds: channelIds,
      issues: issues,
    );

    return MotionLayerModel(
      id: layer.id,
      sceneId: sceneId,
      kind: layerKind,
      visibleRange: visibleRange,
      name: layer.name,
      zIndex: zIndex,
      elements: elements,
    );
  }

  MotionElementModel? _lowerElement({
    required ReFusionSceneProgramElement element,
    required String elementPath,
    required ReFusionSceneProgramLayer layer,
    required String projectId,
    required String sceneId,
    required TimelineTimeRange layerRange,
    required List<ReFusionSceneProgramIssue> issues,
  }) {
    final elementKind = _elementKindFor(element.kind);
    if (elementKind == null) {
      _addIssue(
        issues,
        severity: ReFusionSceneProgramIssueSeverity.warning,
        message:
            'Element kind `${element.kind}` is not supported by lowering v1.',
        path: '$elementPath.kind',
      );
      return null;
    }
    final target = _elementTarget(
      projectId: projectId,
      sceneId: sceneId,
      layerId: layer.id,
      elementId: element.id,
    );
    final assignments = _lowerStaticProperties(
      properties: element.properties,
      path: '$elementPath.properties',
      target: target,
      elementKind: elementKind,
      issues: issues,
    );

    return MotionElementModel(
      id: element.id,
      layerId: layer.id,
      kind: elementKind,
      localRange: TimelineTimeRange(
        start: TimelineTime.zero,
        endExclusive: layerRange.duration,
      ),
      name: element.name,
      shapeKind: _shapeKindFor(element),
      sourceBinding: _sourceBindingFor(element),
      properties: assignments,
    );
  }

  void _lowerChannels({
    required List<ReFusionSceneProgramChannel> ownerChannels,
    required String ownerPath,
    required String ownerId,
    required MotionPropertyTarget ownerTarget,
    required TimelineTimeRange activeRange,
    required TimelineTime timeOffset,
    required List<String> channelPrefix,
    required List<MotionPropertyChannelModel> channels,
    required Set<String> channelIds,
    required List<ReFusionSceneProgramIssue> issues,
    MotionElementKind? elementKind,
    MotionPropertyTarget? fallbackElementTarget,
    MotionElementKind? fallbackElementKind,
  }) {
    for (var index = 0; index < ownerChannels.length; index += 1) {
      final channel = ownerChannels[index];
      final path = '$ownerPath[$index]';
      final loweredProperties = _definitionsForProperty(
        channel.property,
        path: '$path.property',
        issues: issues,
      );
      if (loweredProperties.isEmpty) {
        continue;
      }
      for (final loweredProperty in loweredProperties) {
        final target = _targetForChannel(
          channel: channel,
          ownerTarget: ownerTarget,
          ownerId: ownerId,
          definition: loweredProperty.definition,
          elementKind: elementKind,
          fallbackElementTarget: fallbackElementTarget,
          fallbackElementKind: fallbackElementKind,
          path: '$path.target',
          issues: issues,
        );
        if (target == null) {
          continue;
        }
        final keyframes = _lowerKeyframes(
          keyframes: channel.keyframes,
          channelProperty: channel.property,
          loweredProperty: loweredProperty,
          path: '$path.keyframes',
          timeOffset: timeOffset,
          issues: issues,
        );
        if (keyframes.isEmpty) {
          _addIssue(
            issues,
            severity: ReFusionSceneProgramIssueSeverity.warning,
            message:
                'Channel `${channel.property}` produced no valid keyframes.',
            path: '$path.keyframes',
          );
          continue;
        }
        final channelId = _channelIdFor(
          channelPrefix: channelPrefix,
          target: target,
          definition: loweredProperty.definition,
        );
        if (!channelIds.add(channelId)) {
          _addIssue(
            issues,
            severity: ReFusionSceneProgramIssueSeverity.warning,
            message: 'Duplicate lowered channel `$channelId` was skipped.',
            path: path,
          );
          continue;
        }
        channels.add(
          MotionPropertyChannelModel(
            id: channelId,
            target: target,
            definition: loweredProperty.definition,
            activeRange: activeRange,
            baseValue: loweredProperty.definition.defaultValue,
            beforeStart: MotionChannelExtrapolationMode.clamp,
            afterEnd: MotionChannelExtrapolationMode.clamp,
            keyframes: keyframes
                .map(
                  (keyframe) => keyframe.copyWith(
                    id: '$channelId.${keyframe.time.inProjectTicks}',
                    channelId: channelId,
                  ),
                )
                .toList(growable: false),
          ),
        );
      }
    }
  }

  List<MotionPropertyAssignment> _lowerStaticProperties({
    required Map<String, Object?> properties,
    required String path,
    required MotionPropertyTarget target,
    required MotionElementKind elementKind,
    required List<ReFusionSceneProgramIssue> issues,
  }) {
    final assignments = <MotionPropertyAssignment>[];
    for (final entry in properties.entries) {
      final loweredProperties = _definitionsForProperty(
        entry.key,
        path: '$path.${entry.key}',
        issues: issues,
      );
      for (final loweredProperty in loweredProperties) {
        if (!_supportsDefinitionForElement(
          definition: loweredProperty.definition,
          target: target,
          elementKind: elementKind,
        )) {
          continue;
        }
        final value = _valueForDefinition(
          raw: entry.value,
          channelProperty: entry.key,
          loweredProperty: loweredProperty,
          path: '$path.${entry.key}',
          issues: issues,
        );
        if (value == null) {
          continue;
        }
        assignments.add(
          MotionPropertyAssignment(
            target: target,
            definition: loweredProperty.definition,
            value: value,
          ),
        );
      }
    }
    return assignments;
  }

  List<MotionKeyframeModel> _lowerKeyframes({
    required List<ReFusionSceneProgramKeyframe> keyframes,
    required String channelProperty,
    required _LoweredProperty loweredProperty,
    required String path,
    required TimelineTime timeOffset,
    required List<ReFusionSceneProgramIssue> issues,
  }) {
    final lowered = <MotionKeyframeModel>[];
    final usedTimes = <int>{};
    for (var index = 0; index < keyframes.length; index += 1) {
      final keyframe = keyframes[index];
      final keyframePath = '$path[$index]';
      final localTime = TimelineTime.fromMilliseconds(keyframe.timeMs);
      final time = timeOffset + localTime;
      if (!usedTimes.add(time.inProjectTicks)) {
        _addIssue(
          issues,
          severity: ReFusionSceneProgramIssueSeverity.warning,
          message: 'Duplicate keyframe time `${keyframe.timeMs}` was skipped.',
          path: keyframePath,
        );
        continue;
      }
      final value = _valueForDefinition(
        raw: keyframe.value,
        channelProperty: channelProperty,
        loweredProperty: loweredProperty,
        path: '$keyframePath.value',
        issues: issues,
      );
      if (value == null) {
        continue;
      }
      lowered.add(
        MotionKeyframeModel(
          id: 'pending.${time.inProjectTicks}',
          channelId: 'pending',
          time: time,
          value: value,
          interpolationToNext: _interpolationFor(
            keyframe.easing,
            path: '$keyframePath.easing',
            issues: issues,
          ),
        ),
      );
    }
    lowered.sort((left, right) => left.time.compareTo(right.time));
    return lowered;
  }

  MotionPropertyTarget? _targetForChannel({
    required ReFusionSceneProgramChannel channel,
    required MotionPropertyTarget ownerTarget,
    required String ownerId,
    required MotionPropertyDefinition definition,
    required MotionElementKind? elementKind,
    required MotionPropertyTarget? fallbackElementTarget,
    required MotionElementKind? fallbackElementKind,
    required String path,
    required List<ReFusionSceneProgramIssue> issues,
  }) {
    final normalizedTarget = _normalizeToken(channel.target);
    if (normalizedTarget != 'self' &&
        normalizedTarget != _normalizeToken(ownerId)) {
      _addIssue(
        issues,
        severity: ReFusionSceneProgramIssueSeverity.warning,
        message:
            'Scene program channel target `${channel.target}` is not supported by lowering v1.',
        path: path,
      );
      return null;
    }
    if (_supportsDefinitionForElement(
      definition: definition,
      target: ownerTarget,
      elementKind: elementKind,
    )) {
      return ownerTarget;
    }
    if (fallbackElementTarget != null &&
        _supportsDefinitionForElement(
          definition: definition,
          target: fallbackElementTarget,
          elementKind: fallbackElementKind,
        )) {
      return fallbackElementTarget;
    }
    _addIssue(
      issues,
      severity: ReFusionSceneProgramIssueSeverity.warning,
      message:
          'Property `${definition.id}` cannot be applied to target `${ownerTarget.canonicalAddress}`.',
      path: path,
    );
    return null;
  }

  bool _supportsDefinitionForElement({
    required MotionPropertyDefinition definition,
    required MotionPropertyTarget target,
    MotionElementKind? elementKind,
  }) {
    if (!definition.supportedTargets.contains(target.kind)) {
      return false;
    }
    if (target.kind != MotionTargetKind.element || elementKind == null) {
      return true;
    }
    final supported = switch (elementKind) {
      MotionElementKind.text => <String>{
          MotionPropertyCatalog.positionX.id,
          MotionPropertyCatalog.positionY.id,
          MotionPropertyCatalog.scaleX.id,
          MotionPropertyCatalog.scaleY.id,
          MotionPropertyCatalog.rotationDegrees.id,
          MotionPropertyCatalog.opacity.id,
          MotionPropertyCatalog.blurAmount.id,
          _SceneProgramPropertyDefinitions.color.id,
          MotionPropertyCatalog.fontSize.id,
          MotionPropertyCatalog.letterSpacing.id,
          MotionPropertyCatalog.revealProgress.id,
        },
      MotionElementKind.shape => <String>{
          MotionPropertyCatalog.positionX.id,
          MotionPropertyCatalog.positionY.id,
          MotionPropertyCatalog.scaleX.id,
          MotionPropertyCatalog.scaleY.id,
          MotionPropertyCatalog.rotationDegrees.id,
          MotionPropertyCatalog.opacity.id,
          MotionPropertyCatalog.blurAmount.id,
          _SceneProgramPropertyDefinitions.color.id,
          MotionPropertyCatalog.width.id,
          MotionPropertyCatalog.height.id,
          MotionPropertyCatalog.cornerRadius.id,
          _SceneProgramPropertyDefinitions.icon.id,
        },
      MotionElementKind.image => <String>{
          MotionPropertyCatalog.positionX.id,
          MotionPropertyCatalog.positionY.id,
          MotionPropertyCatalog.scaleX.id,
          MotionPropertyCatalog.scaleY.id,
          MotionPropertyCatalog.rotationDegrees.id,
          MotionPropertyCatalog.opacity.id,
          MotionPropertyCatalog.blurAmount.id,
          _SceneProgramPropertyDefinitions.color.id,
          MotionPropertyCatalog.cropRect.id,
        },
      _ => const <String>{},
    };
    return supported.contains(definition.id);
  }

  List<_LoweredProperty> _definitionsForProperty(
    String property, {
    required String path,
    required List<ReFusionSceneProgramIssue> issues,
  }) {
    final normalized = _normalizeToken(property);
    final definitions = switch (normalized) {
      'position' || 'transformposition' => <_LoweredProperty>[
          _LoweredProperty(
            definition: MotionPropertyCatalog.positionX,
            component: _VectorComponent.x,
          ),
          _LoweredProperty(
            definition: MotionPropertyCatalog.positionY,
            component: _VectorComponent.y,
          ),
        ],
      'positionx' || 'x' || 'transformpositionx' => <_LoweredProperty>[
          _LoweredProperty(
            definition: MotionPropertyCatalog.positionX,
            component: _VectorComponent.x,
          ),
        ],
      'positiony' || 'y' || 'transformpositiony' => <_LoweredProperty>[
          _LoweredProperty(
            definition: MotionPropertyCatalog.positionY,
            component: _VectorComponent.y,
          ),
        ],
      'scale' || 'transformscale' => <_LoweredProperty>[
          _LoweredProperty(
            definition: MotionPropertyCatalog.scaleX,
            component: _VectorComponent.x,
          ),
          _LoweredProperty(
            definition: MotionPropertyCatalog.scaleY,
            component: _VectorComponent.y,
          ),
        ],
      'scalex' || 'transformscalex' => <_LoweredProperty>[
          _LoweredProperty(
            definition: MotionPropertyCatalog.scaleX,
            component: _VectorComponent.x,
          ),
        ],
      'scaley' || 'transformscaley' => <_LoweredProperty>[
          _LoweredProperty(
            definition: MotionPropertyCatalog.scaleY,
            component: _VectorComponent.y,
          ),
        ],
      'rotation' ||
      'rotationdegrees' ||
      'transformrotation' ||
      'transformrotationdegrees' =>
        <_LoweredProperty>[
          _LoweredProperty(definition: MotionPropertyCatalog.rotationDegrees),
        ],
      'opacity' || 'alpha' || 'visualopacity' => <_LoweredProperty>[
          _LoweredProperty(definition: MotionPropertyCatalog.opacity),
        ],
      'blur' ||
      'bluramount' ||
      'visualblur' ||
      'visualbluramount' =>
        <_LoweredProperty>[
          _LoweredProperty(definition: MotionPropertyCatalog.blurAmount),
        ],
      'color' ||
      'fill' ||
      'fillcolor' ||
      'background' ||
      'backgroundcolor' ||
      'bg' ||
      'bgcolor' ||
      'textcolor' ||
      'shapefillcolor' =>
        <_LoweredProperty>[
          _LoweredProperty(definition: _SceneProgramPropertyDefinitions.color),
        ],
      'fontsize' || 'textfontsize' => <_LoweredProperty>[
          _LoweredProperty(definition: MotionPropertyCatalog.fontSize),
        ],
      'letterspacing' || 'textletterspacing' => <_LoweredProperty>[
          _LoweredProperty(definition: MotionPropertyCatalog.letterSpacing),
        ],
      'reveal' ||
      'revealprogress' ||
      'textreveal' ||
      'textrevealprogress' ||
      'wordreveal' ||
      'wordrevealprogress' ||
      'letterreveal' ||
      'letterrevealprogress' ||
      'typing' ||
      'typingprogress' ||
      'typewriter' ||
      'typewriterprogress' ||
      'texttypingprogress' =>
        <_LoweredProperty>[
          _LoweredProperty(definition: MotionPropertyCatalog.revealProgress),
        ],
      'width' || 'shapewidth' => <_LoweredProperty>[
          _LoweredProperty(definition: MotionPropertyCatalog.width),
        ],
      'height' || 'shapeheight' => <_LoweredProperty>[
          _LoweredProperty(definition: MotionPropertyCatalog.height),
        ],
      'cornerradius' || 'shapecornerradius' => <_LoweredProperty>[
          _LoweredProperty(definition: MotionPropertyCatalog.cornerRadius),
        ],
      'radius' || 'borderradius' => <_LoweredProperty>[
          _LoweredProperty(definition: MotionPropertyCatalog.cornerRadius),
        ],
      'size' || 'iconsize' || 'shapesize' => <_LoweredProperty>[
          _LoweredProperty(
            definition: MotionPropertyCatalog.width,
            component: _VectorComponent.x,
          ),
          _LoweredProperty(
            definition: MotionPropertyCatalog.height,
            component: _VectorComponent.y,
          ),
        ],
      'icon' || 'iconname' || 'symbol' || 'coreicon' => <_LoweredProperty>[
          _LoweredProperty(definition: _SceneProgramPropertyDefinitions.icon),
        ],
      'shapekind' || 'shape' || 'type' => const <_LoweredProperty>[],
      _ => const <_LoweredProperty>[],
    };
    if (definitions.isEmpty && !_isMetadataOnlyProperty(normalized)) {
      _addIssue(
        issues,
        severity: ReFusionSceneProgramIssueSeverity.warning,
        message: 'Unsupported scene-program property `$property`.',
        path: path,
      );
    }
    return definitions;
  }

  bool _isMetadataOnlyProperty(String normalizedProperty) {
    return const <String>{
      'shapekind',
      'shape',
      'type',
      'source',
      'uri',
      'assetid',
      'layout',
      'padding',
      'gap',
      'align',
      'alignment',
      'anchor',
      'zindex',
      'role',
      'description',
      'notes',
    }.contains(normalizedProperty);
  }

  MotionPropertyValue? _valueForDefinition({
    required Object? raw,
    required String channelProperty,
    required _LoweredProperty loweredProperty,
    required String path,
    required List<ReFusionSceneProgramIssue> issues,
  }) {
    final rawComponent = _componentValue(
      raw,
      component: loweredProperty.component,
      property: channelProperty,
    );
    if (loweredProperty.definition.id ==
        _SceneProgramPropertyDefinitions.icon.id) {
      if (rawComponent is String) {
        final normalizedIcon =
            ReFusionCoreDesignPack.normalizeIconId(rawComponent);
        if (normalizedIcon != null) {
          return MotionPropertyValue.stringValue(normalizedIcon);
        }
      }
      _addIssue(
        issues,
        severity: ReFusionSceneProgramIssueSeverity.warning,
        message:
            'Icon `$raw` is not in the ReFusion Core Pack and was replaced with `sparkles`.',
        path: path,
      );
      return const MotionPropertyValue.stringValue('sparkles');
    }
    final value = switch (loweredProperty.definition.valueKind) {
      MotionPropertyValueKind.scalar => _scalarValue(rawComponent),
      MotionPropertyValueKind.integer when rawComponent is int =>
        MotionPropertyValue.integer(rawComponent),
      MotionPropertyValueKind.boolean when rawComponent is bool =>
        MotionPropertyValue.boolean(rawComponent),
      MotionPropertyValueKind.stringValue when rawComponent is String =>
        MotionPropertyValue.stringValue(rawComponent),
      MotionPropertyValueKind.enumValue when rawComponent is String =>
        MotionPropertyValue.enumValue(rawComponent),
      MotionPropertyValueKind.colorArgb => _colorValue(rawComponent),
      MotionPropertyValueKind.point2D => _pointValue(rawComponent),
      MotionPropertyValueKind.size2D => _sizeValue(rawComponent),
      MotionPropertyValueKind.rect => _rectValue(rawComponent),
      _ => null,
    };
    if (value == null) {
      _addIssue(
        issues,
        severity: ReFusionSceneProgramIssueSeverity.warning,
        message:
            'Value `$raw` cannot be lowered to `${loweredProperty.definition.valueKind.name}`.',
        path: path,
      );
    }
    return value;
  }

  Object? _componentValue(
    Object? raw, {
    required _VectorComponent? component,
    required String property,
  }) {
    if (component == null) {
      return raw;
    }
    if (raw is num && _normalizeToken(property).contains('scale')) {
      return raw;
    }
    if (raw is num &&
        const <String>{'size', 'iconsize', 'shapesize'}
            .contains(_normalizeToken(property))) {
      return raw;
    }
    if (raw is List && raw.isNotEmpty) {
      final index = component == _VectorComponent.x ? 0 : 1;
      if (raw.length > index) {
        return raw[index];
      }
    }
    if (raw is Map) {
      final keys = component == _VectorComponent.x
          ? const <String>['x', 'left', 'width']
          : const <String>['y', 'top', 'height'];
      for (final key in keys) {
        final value = raw[key];
        if (value != null) {
          return value;
        }
      }
    }
    return raw;
  }

  MotionPropertyValue? _scalarValue(Object? raw) {
    if (raw is num) {
      return MotionPropertyValue.scalar(raw.toDouble());
    }
    if (raw is String) {
      final parsed = double.tryParse(raw.trim());
      if (parsed != null) {
        return MotionPropertyValue.scalar(parsed);
      }
    }
    return null;
  }

  MotionPropertyValue? _colorValue(Object? raw) {
    if (raw is int) {
      return MotionPropertyValue.colorArgb(raw);
    }
    if (raw is String) {
      final normalized = raw.trim().replaceFirst('#', '');
      final parsed = int.tryParse(normalized, radix: 16);
      if (parsed != null) {
        final value = normalized.length <= 6 ? 0xFF000000 | parsed : parsed;
        return MotionPropertyValue.colorArgb(value);
      }
    }
    return null;
  }

  MotionPropertyValue? _pointValue(Object? raw) {
    if (raw is List && raw.length >= 2 && raw[0] is num && raw[1] is num) {
      return MotionPropertyValue.point2D(
        MotionPoint2D(
          x: (raw[0] as num).toDouble(),
          y: (raw[1] as num).toDouble(),
        ),
      );
    }
    if (raw is Map && raw['x'] is num && raw['y'] is num) {
      return MotionPropertyValue.point2D(
        MotionPoint2D(
          x: (raw['x'] as num).toDouble(),
          y: (raw['y'] as num).toDouble(),
        ),
      );
    }
    return null;
  }

  MotionPropertyValue? _sizeValue(Object? raw) {
    if (raw is List && raw.length >= 2 && raw[0] is num && raw[1] is num) {
      return MotionPropertyValue.size2D(
        MotionSize2D(
          width: (raw[0] as num).toDouble(),
          height: (raw[1] as num).toDouble(),
        ),
      );
    }
    if (raw is Map && raw['width'] is num && raw['height'] is num) {
      return MotionPropertyValue.size2D(
        MotionSize2D(
          width: (raw['width'] as num).toDouble(),
          height: (raw['height'] as num).toDouble(),
        ),
      );
    }
    return null;
  }

  MotionPropertyValue? _rectValue(Object? raw) {
    if (raw is Map &&
        raw['left'] is num &&
        raw['top'] is num &&
        raw['width'] is num &&
        raw['height'] is num) {
      return MotionPropertyValue.rect(
        MotionRect(
          left: (raw['left'] as num).toDouble(),
          top: (raw['top'] as num).toDouble(),
          width: (raw['width'] as num).toDouble(),
          height: (raw['height'] as num).toDouble(),
        ),
      );
    }
    return null;
  }

  MotionInterpolationSpec _interpolationFor(
    String easing, {
    required String path,
    required List<ReFusionSceneProgramIssue> issues,
  }) {
    final parsed = tryParseNamedMotionInterpolationSpec(easing);
    if (parsed != null) {
      return parsed;
    }
    _addIssue(
      issues,
      severity: ReFusionSceneProgramIssueSeverity.warning,
      message: 'Unsupported easing `$easing` was replaced with linear.',
      path: path,
    );
    return const MotionInterpolationSpec.linear();
  }

  MotionLayerKind? _layerKindFor(String kind) {
    switch (_normalizeToken(kind)) {
      case 'text':
        return MotionLayerKind.text;
      case 'shape':
        return MotionLayerKind.shape;
      case 'image':
        return MotionLayerKind.image;
      case 'video':
        return MotionLayerKind.video;
    }
    return null;
  }

  MotionElementKind? _elementKindFor(String kind) {
    switch (_normalizeToken(kind)) {
      case 'text':
        return MotionElementKind.text;
      case 'shape':
      case 'solid':
      case 'icon':
        return MotionElementKind.shape;
      case 'image':
        return MotionElementKind.image;
    }
    return null;
  }

  MotionTextAnimationBindingModel? _textRevealBindingForElement({
    required ReFusionSceneProgramElement element,
    required MotionElementKind elementKind,
    required ReFusionSceneProgramLayer layer,
    required String projectId,
    required String sceneId,
    required TimelineTimeRange activeRange,
  }) {
    if (elementKind != MotionElementKind.text) {
      return null;
    }
    final revealUnit = _textRevealIntentForElement(element);
    if (revealUnit == null) {
      return null;
    }
    final animationKind = revealUnit == MotionTextRevealUnit.word
        ? MotionTextAnimationKind.wordReveal
        : MotionTextAnimationKind.typewriter;
    return MotionTextAnimationBindingModel(
      id: _sanitizeId('${layer.id}_${element.id}_scene_text_reveal'),
      elementTarget: _elementTarget(
        projectId: projectId,
        sceneId: sceneId,
        layerId: layer.id,
        elementId: element.id,
      ),
      activeRange: activeRange,
      animationBlocks: <MotionTextAnimationBlock>[
        MotionTextAnimationBlock(
          id: _sanitizeId('${layer.id}_${element.id}_scene_reveal_block'),
          kind: animationKind,
          relativeRange: TimelineTimeRange(
            start: TimelineTime.zero,
            endExclusive: activeRange.duration,
          ),
          interpolation: const MotionInterpolationSpec.linear(),
          revealSpec: MotionTextRevealSpec(
            unit: revealUnit,
            stagger: TimelineTime.zero,
          ),
          parameters: const <String, MotionPropertyValue>{
            'manualRevealProgress': MotionPropertyValue.boolean(true),
            'revealDirection': MotionPropertyValue.enumValue('forward'),
          },
        ),
      ],
    );
  }

  MotionTextRevealUnit? _textRevealIntentForElement(
    ReFusionSceneProgramElement element,
  ) {
    for (final channel in element.channels) {
      final intent = _textRevealIntentForProperty(channel.property);
      if (intent != null) {
        return intent;
      }
    }
    for (final property in element.properties.keys) {
      final intent = _textRevealIntentForProperty(property);
      if (intent != null) {
        return intent;
      }
    }
    return null;
  }

  MotionTextRevealUnit? _textRevealIntentForProperty(String property) {
    switch (_normalizeToken(property)) {
      case 'wordreveal':
      case 'wordrevealprogress':
        return MotionTextRevealUnit.word;
      case 'reveal':
      case 'revealprogress':
      case 'textreveal':
      case 'textrevealprogress':
      case 'letterreveal':
      case 'letterrevealprogress':
      case 'typing':
      case 'typingprogress':
      case 'typewriter':
      case 'typewriterprogress':
      case 'texttypingprogress':
        return MotionTextRevealUnit.letter;
    }
    return null;
  }

  MotionShapeKind? _shapeKindFor(ReFusionSceneProgramElement element) {
    final normalizedKind = _normalizeToken(element.kind);
    if (normalizedKind == 'text' || normalizedKind == 'image') {
      return null;
    }
    if (normalizedKind == 'icon') {
      return MotionShapeKind.customPath;
    }
    final rawShape = element.properties['shapeKind'] ??
        element.properties['shape'] ??
        element.properties['type'] ??
        element.kind;
    final normalizedShape = _normalizeToken('$rawShape');
    return switch (normalizedShape) {
      'circle' || 'ellipse' => MotionShapeKind.circle,
      'line' => MotionShapeKind.line,
      'roundedrectangle' || 'roundedrect' => MotionShapeKind.roundedRectangle,
      _ => MotionShapeKind.rectangle,
    };
  }

  MotionElementSourceBinding _sourceBindingFor(
    ReFusionSceneProgramElement element,
  ) {
    final elementKind = _elementKindFor(element.kind);
    final sourceKind = switch (elementKind) {
      MotionElementKind.text => MotionSourceKind.generatedText,
      MotionElementKind.image => MotionSourceKind.image,
      _ => MotionSourceKind.generatedShape,
    };
    return MotionElementSourceBinding(
      kind: sourceKind,
      sourceId: _sourceIdFor(element),
      assetId: _assetIdFor(element),
      label: element.text ?? element.name ?? element.id,
      metadata: <String, String>{
        'sceneProgramElementKind': element.kind,
        if (element.text != null) 'text': element.text!,
        if (element.properties['color'] != null)
          'color': '${element.properties['color']}',
        if (element.properties['icon'] != null)
          'icon': '${element.properties['icon']}',
        if (element.properties['uri'] != null)
          'uri': '${element.properties['uri']}',
      },
    );
  }

  String _sourceIdFor(ReFusionSceneProgramElement element) {
    final source = element.properties['source'] ?? element.properties['uri'];
    if (source is String && source.trim().isNotEmpty) {
      return source.trim();
    }
    return element.id;
  }

  String? _assetIdFor(ReFusionSceneProgramElement element) {
    final assetId = element.properties['assetId'];
    if (assetId is String && assetId.trim().isNotEmpty) {
      return assetId.trim();
    }
    return null;
  }

  MotionPropertyTarget _elementTarget({
    required String projectId,
    required String sceneId,
    required String layerId,
    required String elementId,
  }) {
    return MotionPropertyTarget(
      kind: MotionTargetKind.element,
      targetId: elementId,
      projectId: projectId,
      sceneId: sceneId,
      layerId: layerId,
      elementId: elementId,
    );
  }

  TimelineTimeRange _rangeFor({
    required int startMs,
    required int durationMs,
    required TimelineTime maxEnd,
  }) {
    final start = TimelineTime.fromMilliseconds(startMs);
    final requestedEnd = TimelineTime.fromMilliseconds(startMs + durationMs);
    final end = requestedEnd > maxEnd ? maxEnd : requestedEnd;
    return TimelineTimeRange(start: start, endExclusive: end);
  }

  MotionFrameRate _frameRateFor(double frameRate) {
    if (frameRate == frameRate.roundToDouble()) {
      return MotionFrameRate(numerator: frameRate.round(), denominator: 1);
    }
    return MotionFrameRate(
      numerator: (frameRate * 1000).round(),
      denominator: 1000,
    );
  }

  String _channelIdFor({
    required List<String> channelPrefix,
    required MotionPropertyTarget target,
    required MotionPropertyDefinition definition,
  }) {
    return <String>[
      'sceneProgram',
      ...channelPrefix,
      target.canonicalAddress,
      definition.id,
    ].map(_sanitizeId).join('.');
  }

  String _sanitizeId(String value) {
    final sanitized = value.replaceAll(RegExp(r'[^a-zA-Z0-9_\\-]+'), '_');
    return sanitized.isEmpty ? 'item' : sanitized;
  }

  String _normalizeToken(String value) =>
      value.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '').toLowerCase();

  void _addIssue(
    List<ReFusionSceneProgramIssue> issues, {
    required ReFusionSceneProgramIssueSeverity severity,
    required String message,
    String? path,
  }) {
    issues.add(
      ReFusionSceneProgramIssue(
        severity: severity,
        message: message,
        path: path,
      ),
    );
  }
}

enum _VectorComponent {
  x,
  y,
}

@immutable
class _LoweredProperty {
  const _LoweredProperty({
    required this.definition,
    this.component,
  });

  final MotionPropertyDefinition definition;
  final _VectorComponent? component;
}

class _SceneProgramPropertyDefinitions {
  _SceneProgramPropertyDefinitions._();

  static final MotionPropertyDefinition color = MotionPropertyDefinition(
    id: 'visual.color',
    path: const MotionPropertyPath(
      group: MotionPropertyGroup.visual,
      name: 'color',
    ),
    valueKind: MotionPropertyValueKind.colorArgb,
    supportedTargets: const <MotionTargetKind>[MotionTargetKind.element],
    defaultValue: const MotionPropertyValue.colorArgb(0xFFFFFFFF),
  );

  static final MotionPropertyDefinition icon = MotionPropertyDefinition(
    id: 'asset.icon',
    path: const MotionPropertyPath(
      group: MotionPropertyGroup.visual,
      name: 'icon',
    ),
    valueKind: MotionPropertyValueKind.stringValue,
    supportedTargets: const <MotionTargetKind>[MotionTargetKind.element],
    defaultValue: const MotionPropertyValue.stringValue('sparkles'),
  );
}
