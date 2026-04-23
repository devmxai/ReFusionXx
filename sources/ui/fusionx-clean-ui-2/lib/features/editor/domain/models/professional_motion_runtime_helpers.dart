import '../../presentation/models/timeline_time.dart';
import 'professional_motion_animation_models.dart';
import 'professional_motion_compilation_models.dart';
import 'professional_motion_evaluation_models.dart';
import 'professional_motion_models.dart';
import 'professional_motion_text_models.dart';
import 'professional_motion_text_runtime_helpers.dart';

class BasicMotionCompositionCompiler implements MotionCompositionCompiler {
  BasicMotionCompositionCompiler({
    BasicMotionTextPresetCompiler? textPresetCompiler,
  }) : textPresetCompiler =
            textPresetCompiler ?? BasicMotionTextPresetCompiler();

  final BasicMotionTextPresetCompiler textPresetCompiler;

  @override
  MotionCompileResult compile(MotionCompileRequest request) {
    final issues = <MotionCompileIssue>[];
    final project = request.project;
    final projectRange = request.projectRange ??
        TimelineTimeRange(
          start: TimelineTime.zero,
          endExclusive: project.durationTime,
        );

    final sceneIds = <String>{};
    final layerIds = <String>{};
    final elementIds = <String>{};
    final channelIds = <String>{};
    final elementsById = <String, MotionElementModel>{};

    for (final scene in project.scenes) {
      if (!sceneIds.add(scene.id)) {
        issues.add(
          MotionCompileIssue(
            code: MotionCompileIssueCode.duplicateId,
            severity: MotionCompileIssueSeverity.error,
            message: 'Duplicate scene id `${scene.id}`.',
            sceneId: scene.id,
          ),
        );
      }
      for (final layer in scene.layers) {
        if (!layerIds.add(layer.id)) {
          issues.add(
            MotionCompileIssue(
              code: MotionCompileIssueCode.duplicateId,
              severity: MotionCompileIssueSeverity.error,
              message: 'Duplicate layer id `${layer.id}`.',
              sceneId: scene.id,
              layerId: layer.id,
            ),
          );
        }
        for (final element in layer.elements) {
          elementsById[element.id] = element;
          if (!elementIds.add(element.id)) {
            issues.add(
              MotionCompileIssue(
                code: MotionCompileIssueCode.duplicateId,
                severity: MotionCompileIssueSeverity.error,
                message: 'Duplicate element id `${element.id}`.',
                sceneId: scene.id,
                layerId: layer.id,
                elementId: element.id,
              ),
            );
          }
        }
      }
    }

    for (final channel in request.propertyChannels) {
      if (!channelIds.add(channel.id)) {
        issues.add(
          MotionCompileIssue(
            code: MotionCompileIssueCode.duplicateId,
            severity: MotionCompileIssueSeverity.error,
            message: 'Duplicate channel id `${channel.id}`.',
            channelId: channel.id,
            propertyId: channel.definition.id,
          ),
        );
      }
    }

    if (project.scenes.isEmpty) {
      issues.add(
        const MotionCompileIssue(
          code: MotionCompileIssueCode.emptyComposition,
          severity: MotionCompileIssueSeverity.warning,
          message: 'Project contains no scenes.',
        ),
      );
    }

    final textPresetResult = textPresetCompiler.compileBindings(
      request: request,
      elementsById: elementsById,
    );
    issues.addAll(textPresetResult.issues);
    final textBindingRangeByElementId = <String, TimelineTimeRange>{
      for (final binding in request.textAnimationBindings)
        if (binding.activeRange.endExclusive > binding.activeRange.start)
          binding.elementTarget.targetId: binding.activeRange,
    };
    final allPropertyChannels = <MotionPropertyChannelModel>[
      ...textPresetResult.generatedChannels,
      ...request.propertyChannels,
    ];

    final projectTargetChannels = <MotionResolvedPropertyChannel>[];
    final resolvedEffects = <MotionResolvedEffectModel>[];
    final resolvedTransitions = <MotionResolvedTransitionModel>[];
    final resolvedCameras = <MotionResolvedCameraModel>[];
    final resolvedTextAnimations = List<MotionResolvedTextAnimationModel>.from(
      textPresetResult.resolvedTextAnimations,
    );
    final resolvedScenes = <MotionResolvedSceneModel>[];

    for (final channel in allPropertyChannels) {
      if (channel.target.kind == MotionTargetKind.project) {
        projectTargetChannels.add(
          MotionResolvedPropertyChannel(
            channel: channel,
            projectRange: channel.activeRange ?? projectRange,
            targetAddress: channel.target.canonicalAddress,
          ),
        );
      }
    }

    for (final effect in request.effectBindings) {
      resolvedEffects.add(
        MotionResolvedEffectModel(
          id: effect.id,
          kind: effect.kind,
          targetAddress: effect.target.canonicalAddress,
          projectRange: effect.activeRange,
          parameters: effect.parameters,
          name: effect.name,
          isEnabled: effect.isEnabled,
        ),
      );
    }

    for (final transition in request.transitionBindings) {
      resolvedTransitions.add(
        MotionResolvedTransitionModel(
          id: transition.id,
          kind: transition.kind,
          leftTargetId: transition.leftTargetId,
          rightTargetId: transition.rightTargetId,
          projectRange: transition.activeRange,
          parameters: transition.parameters,
          name: transition.name,
          isEnabled: transition.isEnabled,
        ),
      );
    }

    for (final camera in request.cameraBindings) {
      resolvedCameras.add(
        MotionResolvedCameraModel(
          id: camera.id,
          scope: camera.scope,
          targetAddress: camera.target.canonicalAddress,
          projectRange: camera.activeRange,
          staticProperties: camera.staticProperties,
          propertyChannels: camera.propertyChannels
              .map(
                (channel) => MotionResolvedPropertyChannel(
                  channel: channel,
                  projectRange: channel.activeRange ?? camera.activeRange,
                  targetAddress: channel.target.canonicalAddress,
                ),
              )
              .toList(growable: false),
          name: camera.name,
          isEnabled: camera.isEnabled,
        ),
      );
    }

    for (final scene in project.scenes) {
      if (!scene.isEnabled && !request.options.includeDisabledScenes) {
        continue;
      }
      final safeSceneRange = _intersectRanges(scene.projectRange, projectRange);
      if (safeSceneRange == null) {
        continue;
      }

      final sceneChannels = _resolveChannelsForTarget(
        projectDuration: request.project.durationTime,
        propertyChannels: allPropertyChannels,
        targetKind: MotionTargetKind.scene,
        targetId: scene.id,
      );

      final resolvedLayers = <MotionResolvedLayerModel>[];
      for (final layer in scene.layers) {
        if (!layer.isEnabled && !request.options.includeDisabledLayers) {
          continue;
        }

        final layerProjectRange = _intersectRanges(
          layer.visibleRange.shiftBy(scene.projectRange.start),
          safeSceneRange,
        );
        if (layerProjectRange == null) {
          continue;
        }

        final layerChannels = _resolveChannelsForTarget(
          projectDuration: request.project.durationTime,
          propertyChannels: allPropertyChannels,
          targetKind: MotionTargetKind.layer,
          targetId: layer.id,
        );

        final resolvedElements = <MotionResolvedElementModel>[];
        for (final element in layer.elements) {
          if (!element.isEnabled && !request.options.includeDisabledElements) {
            continue;
          }

          final preferredTextProjectRange =
              element.kind == MotionElementKind.text
                  ? textBindingRangeByElementId[element.id]
                  : null;
          final baseElementProjectRange = preferredTextProjectRange ??
              element.localRange.shiftBy(scene.projectRange.start);
          final elementProjectRange = _intersectRanges(
            baseElementProjectRange,
            layerProjectRange,
          );
          if (elementProjectRange == null) {
            continue;
          }
          final resolvedElementLocalRange = elementProjectRange.shiftBy(
            TimelineTime.zero - scene.projectRange.start,
          );

          final elementChannels = _resolveChannelsForTarget(
            projectDuration: request.project.durationTime,
            propertyChannels: allPropertyChannels,
            targetKind: MotionTargetKind.element,
            targetId: element.id,
          );
          final extraStaticProperties =
              textPresetResult.generatedStaticProperties[element.id] ??
                  const <MotionPropertyAssignment>[];

          resolvedElements.add(
            MotionResolvedElementModel(
              id: element.id,
              sourceElementId: element.id,
              sceneId: scene.id,
              layerId: layer.id,
              kind: element.kind,
              projectRange: elementProjectRange,
              localRange: resolvedElementLocalRange,
              staticProperties: <MotionPropertyAssignment>[
                ...element.properties,
                ...extraStaticProperties,
              ],
              propertyChannels: elementChannels,
              name: element.name,
              shapeKind: element.shapeKind,
              sourceBinding: element.sourceBinding,
              isEnabled: element.isEnabled,
            ),
          );
        }

        if (resolvedElements.isEmpty && !request.options.keepEmptyLayers) {
          continue;
        }

        resolvedLayers.add(
          MotionResolvedLayerModel(
            id: layer.id,
            sourceLayerId: layer.id,
            sceneId: scene.id,
            kind: layer.kind,
            projectRange: layerProjectRange,
            elements: resolvedElements,
            staticProperties: layer.properties,
            propertyChannels: layerChannels,
            name: layer.name,
            zIndex: layer.zIndex,
            isEnabled: layer.isEnabled,
            blendMode: layer.blendMode,
          ),
        );
      }

      if (resolvedLayers.isEmpty && !request.options.keepEmptyScenes) {
        continue;
      }

      resolvedScenes.add(
        MotionResolvedSceneModel(
          id: scene.id,
          sourceSceneId: scene.id,
          projectRange: safeSceneRange,
          layers: resolvedLayers,
          name: scene.name,
          cameraLayerId: scene.cameraLayerId,
          isEnabled: scene.isEnabled,
          staticProperties: scene.properties,
          propertyChannels: sceneChannels,
          metadata: scene.metadata,
        ),
      );
    }

    _appendMissingTargetIssues(
      propertyChannels: allPropertyChannels,
      resolvedScenes: resolvedScenes,
      issues: issues,
    );

    final composition = MotionNormalizedComposition(
      projectId: project.id,
      projectRange: projectRange,
      format: project.format,
      frameRate: project.frameRate,
      scenes: resolvedScenes,
      globalChannels: projectTargetChannels,
      effects: resolvedEffects,
      transitions: resolvedTransitions,
      cameras: resolvedCameras,
      textAnimations: resolvedTextAnimations,
      authoringOrigins: request.authoringOrigins,
      metadata: project.metadata,
    );

    return MotionCompileResult(
      request: request,
      composition: composition,
      issues: issues,
    );
  }

  List<MotionResolvedPropertyChannel> _resolveChannelsForTarget({
    required TimelineTime projectDuration,
    required List<MotionPropertyChannelModel> propertyChannels,
    required MotionTargetKind targetKind,
    required String targetId,
  }) {
    final resolved = <MotionResolvedPropertyChannel>[];
    for (final channel in propertyChannels) {
      if (channel.target.kind != targetKind) {
        continue;
      }
      if (channel.target.targetId != targetId) {
        continue;
      }
      resolved.add(
        MotionResolvedPropertyChannel(
          channel: channel,
          projectRange: channel.activeRange ??
              TimelineTimeRange(
                start: TimelineTime.zero,
                endExclusive: projectDuration,
              ),
          targetAddress: channel.target.canonicalAddress,
        ),
      );
    }
    return resolved;
  }

  void _appendMissingTargetIssues({
    required List<MotionPropertyChannelModel> propertyChannels,
    required List<MotionResolvedSceneModel> resolvedScenes,
    required List<MotionCompileIssue> issues,
  }) {
    final resolvedSceneIds = resolvedScenes.map((scene) => scene.id).toSet();
    final resolvedLayerIds = resolvedScenes
        .expand((scene) => scene.layers)
        .map((layer) => layer.id)
        .toSet();
    final resolvedElementIds = resolvedScenes
        .expand((scene) => scene.layers)
        .expand((layer) => layer.elements)
        .map((element) => element.id)
        .toSet();

    for (final channel in propertyChannels) {
      switch (channel.target.kind) {
        case MotionTargetKind.project:
          continue;
        case MotionTargetKind.scene:
          if (!resolvedSceneIds.contains(channel.target.targetId)) {
            issues.add(
              MotionCompileIssue(
                code: MotionCompileIssueCode.missingScene,
                severity: MotionCompileIssueSeverity.warning,
                message:
                    'Channel `${channel.id}` points to missing scene `${channel.target.targetId}`.',
                sceneId: channel.target.targetId,
                channelId: channel.id,
                propertyId: channel.definition.id,
              ),
            );
          }
          break;
        case MotionTargetKind.layer:
          if (!resolvedLayerIds.contains(channel.target.targetId)) {
            issues.add(
              MotionCompileIssue(
                code: MotionCompileIssueCode.missingLayer,
                severity: MotionCompileIssueSeverity.warning,
                message:
                    'Channel `${channel.id}` points to missing layer `${channel.target.targetId}`.',
                layerId: channel.target.targetId,
                channelId: channel.id,
                propertyId: channel.definition.id,
              ),
            );
          }
          break;
        case MotionTargetKind.element:
          if (!resolvedElementIds.contains(channel.target.targetId)) {
            issues.add(
              MotionCompileIssue(
                code: MotionCompileIssueCode.missingElement,
                severity: MotionCompileIssueSeverity.warning,
                message:
                    'Channel `${channel.id}` points to missing element `${channel.target.targetId}`.',
                elementId: channel.target.targetId,
                channelId: channel.id,
                propertyId: channel.definition.id,
              ),
            );
          }
          break;
      }
    }
  }

  TimelineTimeRange? _intersectRanges(
    TimelineTimeRange left,
    TimelineTimeRange right,
  ) {
    final start = left.start > right.start ? left.start : right.start;
    final end = left.endExclusive < right.endExclusive
        ? left.endExclusive
        : right.endExclusive;
    if (start >= end) {
      return null;
    }
    return TimelineTimeRange(start: start, endExclusive: end);
  }
}

class BasicMotionPropertyChannelSampler
    implements MotionPropertyChannelSampler {
  const BasicMotionPropertyChannelSampler();

  @override
  MotionEvaluatedPropertyValue sample({
    required MotionResolvedPropertyChannel channel,
    required TimelineTime time,
  }) {
    final definition = channel.channel.definition;
    final target = channel.channel.target;
    final activeRange = channel.channel.activeRange ?? channel.projectRange;
    if (!activeRange.contains(time)) {
      return MotionEvaluatedPropertyValue(
        target: target,
        definition: definition,
        value: channel.channel.fallbackValue,
        status: MotionEvaluationStatus.outOfRange,
        channelId: channel.channel.id,
      );
    }

    final keyframes = channel.channel.keyframes;
    if (keyframes.isEmpty) {
      return MotionEvaluatedPropertyValue(
        target: target,
        definition: definition,
        value: channel.channel.fallbackValue,
        status: channel.channel.baseValue == null
            ? MotionEvaluationStatus.defaulted
            : MotionEvaluationStatus.resolved,
        channelId: channel.channel.id,
      );
    }

    final first = keyframes.first;
    final last = keyframes.last;
    if (time <= first.time) {
      return MotionEvaluatedPropertyValue(
        target: target,
        definition: definition,
        value: first.value,
        status: MotionEvaluationStatus.resolved,
        channelId: channel.channel.id,
      );
    }
    if (time >= last.time) {
      return MotionEvaluatedPropertyValue(
        target: target,
        definition: definition,
        value: last.value,
        status: MotionEvaluationStatus.resolved,
        channelId: channel.channel.id,
      );
    }

    for (var index = 0; index < keyframes.length - 1; index += 1) {
      final current = keyframes[index];
      final next = keyframes[index + 1];
      if (time < current.time || time > next.time) {
        continue;
      }
      if (time == current.time) {
        return MotionEvaluatedPropertyValue(
          target: target,
          definition: definition,
          value: current.value,
          status: MotionEvaluationStatus.resolved,
          channelId: channel.channel.id,
        );
      }
      if (time == next.time) {
        return MotionEvaluatedPropertyValue(
          target: target,
          definition: definition,
          value: next.value,
          status: MotionEvaluationStatus.resolved,
          channelId: channel.channel.id,
        );
      }
      if (current.interpolationToNext.kind == MotionInterpolationKind.hold) {
        return MotionEvaluatedPropertyValue(
          target: target,
          definition: definition,
          value: current.value,
          status: MotionEvaluationStatus.resolved,
          channelId: channel.channel.id,
        );
      }
      final progress = _normalizedProgress(
        current.time,
        next.time,
        time,
      );
      return MotionEvaluatedPropertyValue(
        target: target,
        definition: definition,
        value: _interpolateValue(
          from: current.value,
          to: next.value,
          progress: _curveProgress(current.interpolationToNext, progress),
        ),
        status: MotionEvaluationStatus.resolved,
        channelId: channel.channel.id,
      );
    }

    return MotionEvaluatedPropertyValue(
      target: target,
      definition: definition,
      value: channel.channel.fallbackValue,
      status: MotionEvaluationStatus.missingData,
      channelId: channel.channel.id,
    );
  }

  double _normalizedProgress(
    TimelineTime start,
    TimelineTime end,
    TimelineTime current,
  ) {
    final durationTicks = (end - start).inProjectTicks;
    if (durationTicks <= 0) {
      return 0;
    }
    final elapsedTicks = (current - start).inProjectTicks;
    return elapsedTicks / durationTicks;
  }

  double _curveProgress(
    MotionInterpolationSpec interpolation,
    double progress,
  ) {
    final clampedProgress = progress.clamp(0.0, 1.0).toDouble();
    switch (interpolation.kind) {
      case MotionInterpolationKind.hold:
        return 0;
      case MotionInterpolationKind.linear:
      case MotionInterpolationKind.spring:
      case MotionInterpolationKind.bounce:
      case MotionInterpolationKind.elastic:
        return clampedProgress;
      case MotionInterpolationKind.cubicBezier:
        final bezier = interpolation.bezier;
        if (bezier == null) {
          return clampedProgress;
        }
        return _solveCubicBezierProgress(bezier, clampedProgress);
      case MotionInterpolationKind.easeIn:
        return clampedProgress * clampedProgress;
      case MotionInterpolationKind.easeOut:
        final inverse = 1 - clampedProgress;
        return 1 - (inverse * inverse);
      case MotionInterpolationKind.easeInOut:
        if (clampedProgress < 0.5) {
          return 2 * clampedProgress * clampedProgress;
        }
        final inverse = -2 * clampedProgress + 2;
        return 1 - ((inverse * inverse) / 2);
    }
  }

  double _solveCubicBezierProgress(
    MotionBezierControlPoints bezier,
    double x,
  ) {
    final clampedX = x.clamp(0.0, 1.0).toDouble();
    if (clampedX <= 0.0 || clampedX >= 1.0) {
      return clampedX;
    }
    var t = clampedX;
    for (var iteration = 0; iteration < 8; iteration += 1) {
      final estimate = _cubicCoordinate(t, 0.0, bezier.x1, bezier.x2, 1.0);
      final derivative = _cubicDerivative(t, 0.0, bezier.x1, bezier.x2, 1.0);
      final delta = estimate - clampedX;
      if (delta.abs() <= 0.000001 || derivative.abs() <= 0.000001) {
        break;
      }
      t = (t - (delta / derivative)).clamp(0.0, 1.0).toDouble();
    }
    var lower = 0.0;
    var upper = 1.0;
    for (var iteration = 0; iteration < 12; iteration += 1) {
      final estimate = _cubicCoordinate(t, 0.0, bezier.x1, bezier.x2, 1.0);
      if ((estimate - clampedX).abs() <= 0.000001) {
        break;
      }
      if (estimate < clampedX) {
        lower = t;
      } else {
        upper = t;
      }
      t = ((lower + upper) * 0.5).clamp(0.0, 1.0).toDouble();
    }
    return _cubicCoordinate(t, 0.0, bezier.y1, bezier.y2, 1.0)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  double _cubicCoordinate(
    double t,
    double p0,
    double p1,
    double p2,
    double p3,
  ) {
    final inverse = 1.0 - t;
    return (inverse * inverse * inverse * p0) +
        (3.0 * inverse * inverse * t * p1) +
        (3.0 * inverse * t * t * p2) +
        (t * t * t * p3);
  }

  double _cubicDerivative(
    double t,
    double p0,
    double p1,
    double p2,
    double p3,
  ) {
    final inverse = 1.0 - t;
    return (3.0 * inverse * inverse * (p1 - p0)) +
        (6.0 * inverse * t * (p2 - p1)) +
        (3.0 * t * t * (p3 - p2));
  }

  MotionPropertyValue _interpolateValue({
    required MotionPropertyValue from,
    required MotionPropertyValue to,
    required double progress,
  }) {
    if (from.kind != to.kind) {
      return from;
    }
    switch (from.kind) {
      case MotionPropertyValueKind.scalar:
        final start = from.rawValue as double;
        final end = to.rawValue as double;
        return MotionPropertyValue.scalar(start + ((end - start) * progress));
      case MotionPropertyValueKind.integer:
        final start = from.rawValue as int;
        final end = to.rawValue as int;
        return MotionPropertyValue.integer(
          (start + ((end - start) * progress)).round(),
        );
      case MotionPropertyValueKind.point2D:
        final start = from.rawValue as MotionPoint2D;
        final end = to.rawValue as MotionPoint2D;
        return MotionPropertyValue.point2D(
          MotionPoint2D(
            x: start.x + ((end.x - start.x) * progress),
            y: start.y + ((end.y - start.y) * progress),
          ),
        );
      case MotionPropertyValueKind.size2D:
        final start = from.rawValue as MotionSize2D;
        final end = to.rawValue as MotionSize2D;
        return MotionPropertyValue.size2D(
          MotionSize2D(
            width: start.width + ((end.width - start.width) * progress),
            height: start.height + ((end.height - start.height) * progress),
          ),
        );
      case MotionPropertyValueKind.rect:
        final start = from.rawValue as MotionRect;
        final end = to.rawValue as MotionRect;
        return MotionPropertyValue.rect(
          MotionRect(
            left: start.left + ((end.left - start.left) * progress),
            top: start.top + ((end.top - start.top) * progress),
            width: start.width + ((end.width - start.width) * progress),
            height: start.height + ((end.height - start.height) * progress),
          ),
        );
      case MotionPropertyValueKind.boolean:
      case MotionPropertyValueKind.stringValue:
      case MotionPropertyValueKind.colorArgb:
      case MotionPropertyValueKind.enumValue:
        return progress < 0.5 ? from : to;
    }
  }
}

class BasicMotionRuntimeEvaluator implements MotionRuntimeEvaluator {
  const BasicMotionRuntimeEvaluator({
    this.channelSampler = const BasicMotionPropertyChannelSampler(),
  });

  final MotionPropertyChannelSampler channelSampler;

  @override
  MotionEvaluationSnapshot evaluate(MotionEvaluationRequest request) {
    final scenes = <MotionEvaluatedSceneState>[];
    final transitions = <MotionTransitionEvaluationState>[];
    final effects = <MotionEffectEvaluationState>[];
    final cameras = <MotionEvaluatedCameraState>[];
    final textAnimations = <MotionEvaluatedTextAnimationState>[];

    for (final scene in request.composition.scenes) {
      final sceneActive = scene.projectRange.contains(request.time);
      if (!sceneActive && !request.includeInactiveScenes) {
        continue;
      }

      final evaluatedSceneProperties = _resolveProperties(
        staticAssignments: scene.staticProperties,
        channels: scene.propertyChannels,
        time: request.time,
      );

      final evaluatedLayers = <MotionEvaluatedLayerState>[];
      for (final layer in scene.layers) {
        final layerActive =
            sceneActive && layer.projectRange.contains(request.time);
        if (!layerActive && !request.includeInactiveLayers) {
          continue;
        }

        final evaluatedLayerProperties = _resolveProperties(
          staticAssignments: layer.staticProperties,
          channels: layer.propertyChannels,
          time: request.time,
        );

        final evaluatedElements = <MotionEvaluatedElementState>[];
        for (final element in layer.elements) {
          final elementActive =
              layerActive && element.projectRange.contains(request.time);
          if (!elementActive && !request.includeInactiveElements) {
            continue;
          }

          evaluatedElements.add(
            MotionEvaluatedElementState(
              id: element.id,
              sourceElementId: element.sourceElementId,
              sceneId: element.sceneId,
              layerId: element.layerId,
              kind: element.kind,
              projectRange: element.projectRange,
              activationState: elementActive
                  ? MotionActivationState.active
                  : MotionActivationState.inactive,
              properties: _resolveProperties(
                staticAssignments: element.staticProperties,
                channels: element.propertyChannels,
                time: request.time,
              ),
              name: element.name,
              shapeKind: element.shapeKind,
            ),
          );
        }

        evaluatedLayers.add(
          MotionEvaluatedLayerState(
            id: layer.id,
            sourceLayerId: layer.sourceLayerId,
            sceneId: layer.sceneId,
            kind: layer.kind,
            projectRange: layer.projectRange,
            activationState: layerActive
                ? MotionActivationState.active
                : MotionActivationState.inactive,
            properties: evaluatedLayerProperties,
            elements: evaluatedElements,
            name: layer.name,
            zIndex: layer.zIndex,
            blendMode: layer.blendMode,
          ),
        );
      }

      scenes.add(
        MotionEvaluatedSceneState(
          id: scene.id,
          sourceSceneId: scene.sourceSceneId,
          projectRange: scene.projectRange,
          activationState: sceneActive
              ? MotionActivationState.active
              : MotionActivationState.inactive,
          layers: evaluatedLayers,
          name: scene.name,
          cameraLayerId: scene.cameraLayerId,
          properties: evaluatedSceneProperties,
        ),
      );
    }

    for (final transition in request.composition.transitions) {
      final active = transition.projectRange.contains(request.time);
      transitions.add(
        MotionTransitionEvaluationState(
          id: transition.id,
          targetRange: transition.projectRange,
          progress: active
              ? _normalizedProgress(
                  transition.projectRange.start,
                  transition.projectRange.endExclusive,
                  request.time,
                )
              : 0,
          activationState: active
              ? MotionActivationState.active
              : MotionActivationState.inactive,
          parameters: transition.parameters,
        ),
      );
    }

    for (final effect in request.composition.effects) {
      final active = effect.projectRange.contains(request.time);
      effects.add(
        MotionEffectEvaluationState(
          id: effect.id,
          targetAddress: effect.targetAddress,
          activationState: active
              ? MotionActivationState.active
              : MotionActivationState.inactive,
          parameters: effect.parameters,
        ),
      );
    }

    for (final camera in request.composition.cameras) {
      final active = camera.projectRange.contains(request.time);
      cameras.add(
        MotionEvaluatedCameraState(
          id: camera.id,
          scope: camera.scope,
          targetAddress: camera.targetAddress,
          activationState: active
              ? MotionActivationState.active
              : MotionActivationState.inactive,
          properties: _resolveProperties(
            staticAssignments: camera.staticProperties,
            channels: camera.propertyChannels,
            time: request.time,
          ),
          name: camera.name,
        ),
      );
    }

    final evaluatedElementMap = <String, MotionEvaluatedElementState>{
      for (final scene in scenes)
        for (final layer in scene.layers)
          for (final element in layer.elements) element.id: element,
    };

    for (final textAnimation in request.composition.textAnimations) {
      final active = textAnimation.projectRange.contains(request.time);
      final elementState = evaluatedElementMap[textAnimation.targetElementId];
      final revealProgress = elementState == null
          ? null
          : _extractScalarProperty(
              elementState.properties,
              MotionPropertyCatalog.revealProgress.id,
            );
      textAnimations.add(
        MotionEvaluatedTextAnimationState(
          id: textAnimation.id,
          targetElementId: textAnimation.targetElementId,
          targetAddress: textAnimation.targetAddress,
          activationState: active
              ? MotionActivationState.active
              : MotionActivationState.inactive,
          presetId: textAnimation.presetId,
          revealProgress: revealProgress,
          revealUnit: _resolveTextAnimationRevealUnit(textAnimation),
          revealDirection: _resolveTextAnimationRevealDirection(textAnimation),
          animationKinds: textAnimation.animationKinds,
        ),
      );
    }

    return MotionEvaluationSnapshot(
      projectId: request.composition.projectId,
      time: request.time,
      scenes: scenes,
      transitions: transitions,
      effects: effects,
      cameras: cameras,
      textAnimations: textAnimations,
    );
  }

  double _normalizedProgress(
    TimelineTime start,
    TimelineTime end,
    TimelineTime current,
  ) {
    final durationTicks = (end - start).inProjectTicks;
    if (durationTicks <= 0) {
      return 0;
    }
    final elapsedTicks = (current - start).inProjectTicks;
    return elapsedTicks / durationTicks;
  }

  List<MotionEvaluatedPropertyValue> _resolveProperties({
    required List<MotionPropertyAssignment> staticAssignments,
    required List<MotionResolvedPropertyChannel> channels,
    required TimelineTime time,
  }) {
    final resolved = <String, MotionEvaluatedPropertyValue>{};
    for (final assignment in staticAssignments) {
      resolved[assignment.definition.id] = MotionEvaluatedPropertyValue(
        target: assignment.target,
        definition: assignment.definition,
        value: assignment.value,
        status: MotionEvaluationStatus.resolved,
      );
    }
    for (final channel in channels) {
      final sampled = channelSampler.sample(channel: channel, time: time);
      resolved[channel.channel.definition.id] = sampled;
    }
    return resolved.values.toList(growable: false);
  }

  double? _extractScalarProperty(
    List<MotionEvaluatedPropertyValue> properties,
    String propertyId,
  ) {
    for (final property in properties) {
      if (property.definition.id != propertyId) {
        continue;
      }
      if (property.value.kind != MotionPropertyValueKind.scalar) {
        return null;
      }
      return property.value.rawValue as double;
    }
    return null;
  }

  MotionTextRevealUnit _resolveTextAnimationRevealUnit(
    MotionResolvedTextAnimationModel textAnimation,
  ) {
    final parameterValue = textAnimation.parameterValues['revealBy'];
    if (parameterValue != null) {
      final normalized = switch (parameterValue.kind) {
        MotionPropertyValueKind.enumValue ||
        MotionPropertyValueKind.stringValue =>
          (parameterValue.rawValue as String).trim().toLowerCase(),
        _ => null,
      };
      switch (normalized) {
        case 'word':
          return MotionTextRevealUnit.word;
        case 'letter':
        case 'type':
        case 'typewriter':
          return MotionTextRevealUnit.letter;
      }
    }
    for (final block in textAnimation.animationBlocks) {
      final revealSpec = block.revealSpec;
      if (revealSpec != null) {
        return revealSpec.unit;
      }
    }
    final kinds = textAnimation.animationKinds;
    if (kinds.contains(MotionTextAnimationKind.wordReveal)) {
      return MotionTextRevealUnit.word;
    }
    if (kinds.contains(MotionTextAnimationKind.letterReveal) ||
        kinds.contains(MotionTextAnimationKind.typewriter)) {
      return MotionTextRevealUnit.letter;
    }
    return MotionTextRevealUnit.wholeText;
  }

  MotionTextRevealDirection _resolveTextAnimationRevealDirection(
    MotionResolvedTextAnimationModel textAnimation,
  ) {
    final parameterValue = textAnimation.parameterValues['revealDirection'];
    if (parameterValue != null) {
      final normalized = switch (parameterValue.kind) {
        MotionPropertyValueKind.enumValue ||
        MotionPropertyValueKind.stringValue =>
          (parameterValue.rawValue as String).trim().toLowerCase(),
        _ => null,
      };
      if (normalized == 'reverse' || normalized == 'backward') {
        return MotionTextRevealDirection.reverse;
      }
    }
    return MotionTextRevealDirection.forward;
  }
}
