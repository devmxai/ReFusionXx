import '../../domain/models/professional_motion_animation_models.dart';
import '../../domain/models/professional_motion_models.dart';
import '../models/timeline_mock_models.dart';
import '../models/timeline_time.dart';
import 'transition_focus_value_write_adapter.dart';

enum ManualTransitionLaneChannelIssueCode {
  unsupportedLane,
  invalidTransitionWindow,
}

class ManualTransitionLaneChannelIssue {
  const ManualTransitionLaneChannelIssue({
    required this.code,
    required this.message,
    this.laneId,
  });

  final ManualTransitionLaneChannelIssueCode code;
  final String message;
  final String? laneId;
}

class ManualTransitionLaneChannelProjection {
  ManualTransitionLaneChannelProjection({
    required List<MotionPropertyChannelModel> channels,
    List<ManualTransitionLaneChannelIssue> issues =
        const <ManualTransitionLaneChannelIssue>[],
  })  : channels = List.unmodifiable(channels),
        issues = List.unmodifiable(issues);

  final List<MotionPropertyChannelModel> channels;
  final List<ManualTransitionLaneChannelIssue> issues;

  bool get hasIssues => issues.isNotEmpty;
}

class ManualTransitionLaneChannelProjectionRequest {
  const ManualTransitionLaneChannelProjectionRequest({
    required this.transition,
    required this.seamTime,
    required this.projectId,
    this.transitionTargetId,
    this.windowStartTime,
    this.windowEndTime,
  });

  final TimelineTrackTransitionData transition;
  final TimelineTime seamTime;
  final String projectId;
  final String? transitionTargetId;
  final TimelineTime? windowStartTime;
  final TimelineTime? windowEndTime;
}

class ManualTransitionLaneToMotionChannelAdapter {
  const ManualTransitionLaneToMotionChannelAdapter();

  ManualTransitionLaneChannelProjection projectChannels({
    required ManualTransitionLaneChannelProjectionRequest request,
  }) {
    final transition = request.transition;
    final targetId = (request.transitionTargetId == null ||
            request.transitionTargetId!.trim().isEmpty)
        ? transition.leftClipId
        : request.transitionTargetId!.trim();
    final windowStart = request.windowStartTime ??
        (request.seamTime - transition.resolvedLeadingDurationTime);
    final windowEnd = request.windowEndTime ??
        (request.seamTime + transition.resolvedTrailingDurationTime);
    if (windowEnd <= windowStart) {
      return ManualTransitionLaneChannelProjection(
        channels: const <MotionPropertyChannelModel>[],
        issues: const <ManualTransitionLaneChannelIssue>[
          ManualTransitionLaneChannelIssue(
            code: ManualTransitionLaneChannelIssueCode.invalidTransitionWindow,
            message: 'Manual transition window is invalid.',
          ),
        ],
      );
    }

    final lanesById = <String, TimelineAnimationLaneData>{
      for (final lane in transition.manualAnimationLanes) lane.id: lane,
    };
    final orderedLaneIds = <String>[
      ...transition.manualEffectIds,
      ...transition.manualAnimationLanes
          .map((lane) => lane.id)
          .where((laneId) => !transition.manualEffectIds.contains(laneId)),
    ];
    final channels = <MotionPropertyChannelModel>[];
    final issues = <ManualTransitionLaneChannelIssue>[];
    for (final laneId in orderedLaneIds) {
      final lane = lanesById[laneId] ??
          TimelineAnimationLaneData(
            id: laneId,
            label: laneId,
            targetClipId: targetId,
            normalizedKeyframeStops: const <double>[],
            keyframeIds: const <String>[],
            keyframeValues: const <double>[],
          );
      final mappedChannels = _channelsForLane(
        transition: transition,
        lane: lane,
        projectId: request.projectId,
        targetId: targetId,
        windowStart: windowStart,
        windowEnd: windowEnd,
      );
      if (mappedChannels == null) {
        issues.add(
          ManualTransitionLaneChannelIssue(
            code: ManualTransitionLaneChannelIssueCode.unsupportedLane,
            laneId: laneId,
            message:
                'Manual transition lane `$laneId` is not mapped to motion channels yet.',
          ),
        );
        continue;
      }
      channels.addAll(mappedChannels);
    }
    return ManualTransitionLaneChannelProjection(
      channels: channels,
      issues: issues,
    );
  }

  List<MotionPropertyChannelModel>? _channelsForLane({
    required TimelineTrackTransitionData transition,
    required TimelineAnimationLaneData lane,
    required String projectId,
    required String targetId,
    required TimelineTime windowStart,
    required TimelineTime windowEnd,
  }) {
    final activeRange =
        TimelineTimeRange(start: windowStart, endExclusive: windowEnd);
    final keyframes = _scalarKeyframesForLane(
      transition: transition,
      lane: lane,
      windowStart: windowStart,
      windowEnd: windowEnd,
    );
    final laneTargetIds = _resolvedLaneTargetIds(
      transition: transition,
      lane: lane,
      fallbackTargetId: targetId,
    );
    switch (lane.id) {
      case 'scale':
        return <MotionPropertyChannelModel>[
          for (final laneTargetId in laneTargetIds) ...[
            MotionPropertyChannelModel(
              id: 'manual-transition-${transition.id}-${lane.id}-$laneTargetId-scale-x',
              target: _elementTargetFor(
                projectId: projectId,
                targetId: laneTargetId,
              ),
              definition: MotionPropertyCatalog.scaleX,
              activeRange: activeRange,
              baseValue: MotionPropertyValue.scalar(
                _scaleValueFromPercent(_defaultFallbackValueForLane(lane.id)),
              ),
              keyframes: _mapKeyframes(
                keyframes,
                valueResolver: _scaleValueFromPercent,
                channelId:
                    'manual-transition-${transition.id}-${lane.id}-$laneTargetId-scale-x',
              ),
            ),
            MotionPropertyChannelModel(
              id: 'manual-transition-${transition.id}-${lane.id}-$laneTargetId-scale-y',
              target: _elementTargetFor(
                projectId: projectId,
                targetId: laneTargetId,
              ),
              definition: MotionPropertyCatalog.scaleY,
              activeRange: activeRange,
              baseValue: MotionPropertyValue.scalar(
                _scaleValueFromPercent(_defaultFallbackValueForLane(lane.id)),
              ),
              keyframes: _mapKeyframes(
                keyframes,
                valueResolver: _scaleValueFromPercent,
                channelId:
                    'manual-transition-${transition.id}-${lane.id}-$laneTargetId-scale-y',
              ),
            ),
          ],
        ];
      case 'opacity':
        return <MotionPropertyChannelModel>[
          for (final laneTargetId in laneTargetIds)
            MotionPropertyChannelModel(
              id: 'manual-transition-${transition.id}-${lane.id}-$laneTargetId-opacity',
              target: _elementTargetFor(
                projectId: projectId,
                targetId: laneTargetId,
              ).copyWith(kind: MotionTargetKind.layer),
              definition: MotionPropertyCatalog.opacity,
              activeRange: activeRange,
              baseValue: MotionPropertyValue.scalar(
                _opacityValueFromPercent(_defaultFallbackValueForLane(lane.id)),
              ),
              keyframes: _mapKeyframes(
                keyframes,
                valueResolver: _opacityValueFromPercent,
                channelId:
                    'manual-transition-${transition.id}-${lane.id}-$laneTargetId-opacity',
              ),
            ),
        ];
      case 'position':
        return <MotionPropertyChannelModel>[
          for (final laneTargetId in laneTargetIds)
            MotionPropertyChannelModel(
              id: 'manual-transition-${transition.id}-${lane.id}-$laneTargetId-position-x',
              target: _elementTargetFor(
                projectId: projectId,
                targetId: laneTargetId,
              ),
              definition: MotionPropertyCatalog.positionX,
              activeRange: activeRange,
              baseValue: MotionPropertyValue.scalar(
                _defaultFallbackValueForLane(lane.id),
              ),
              keyframes: _mapKeyframes(
                keyframes,
                valueResolver: (value) => value,
                channelId:
                    'manual-transition-${transition.id}-${lane.id}-$laneTargetId-position-x',
              ),
            ),
        ];
      case 'rotation':
        return <MotionPropertyChannelModel>[
          for (final laneTargetId in laneTargetIds)
            MotionPropertyChannelModel(
              id: 'manual-transition-${transition.id}-${lane.id}-$laneTargetId-rotation-deg',
              target: _elementTargetFor(
                projectId: projectId,
                targetId: laneTargetId,
              ),
              definition: MotionPropertyCatalog.rotationDegrees,
              activeRange: activeRange,
              baseValue: MotionPropertyValue.scalar(
                _defaultFallbackValueForLane(lane.id),
              ),
              keyframes: _mapKeyframes(
                keyframes,
                valueResolver: (value) => value,
                channelId:
                    'manual-transition-${transition.id}-${lane.id}-$laneTargetId-rotation-deg',
              ),
            ),
        ];
      case 'gaussian_blur':
        return <MotionPropertyChannelModel>[
          for (final laneTargetId in laneTargetIds)
            MotionPropertyChannelModel(
              id: 'manual-transition-${transition.id}-${lane.id}-$laneTargetId-blur-amount',
              target: _elementTargetFor(
                projectId: projectId,
                targetId: laneTargetId,
              ),
              definition: MotionPropertyCatalog.blurAmount,
              activeRange: activeRange,
              baseValue: MotionPropertyValue.scalar(
                _defaultFallbackValueForLane(lane.id).clamp(0.0, 400.0),
              ),
              keyframes: _mapKeyframes(
                keyframes,
                valueResolver: (value) => value.clamp(0.0, 400.0).toDouble(),
                channelId:
                    'manual-transition-${transition.id}-${lane.id}-$laneTargetId-blur-amount',
              ),
            ),
        ];
      case 'edge_fill':
        return <MotionPropertyChannelModel>[
          for (final laneTargetId in laneTargetIds)
            MotionPropertyChannelModel(
              id: 'manual-transition-${transition.id}-${lane.id}-$laneTargetId-edge-fill-amount',
              target: _elementTargetFor(
                projectId: projectId,
                targetId: laneTargetId,
              ),
              definition: MotionPropertyCatalog.edgeFillAmount,
              activeRange: activeRange,
              baseValue: MotionPropertyValue.scalar(
                (transition
                            .parameterValue(
                              lane.id,
                              fallback: _defaultFallbackValueForLane(lane.id),
                            )
                            .clamp(0.0, 100.0) /
                        100.0)
                    .toDouble(),
              ),
              keyframes: _mapKeyframes(
                keyframes,
                valueResolver: (value) =>
                    (value.clamp(0.0, 100.0) / 100.0).toDouble(),
                channelId:
                    'manual-transition-${transition.id}-${lane.id}-$laneTargetId-edge-fill-amount',
              ),
            ),
          ..._constantEdgeFillChannels(
            transition: transition,
            laneId: lane.id,
            laneTargetIds: laneTargetIds,
            projectId: projectId,
            activeRange: activeRange,
          ),
        ];
      case 'motion_blur':
      case 'transform.motion_blur':
      case 'position.motion_blur':
      case 'scale.motion_blur':
      case 'rotation.motion_blur':
        return <MotionPropertyChannelModel>[
          for (final laneTargetId in laneTargetIds)
            MotionPropertyChannelModel(
              id: 'manual-transition-${transition.id}-${lane.id}-$laneTargetId-motion-blur-amount',
              target: _elementTargetFor(
                projectId: projectId,
                targetId: laneTargetId,
              ),
              definition: MotionPropertyCatalog.motionBlurAmount,
              activeRange: activeRange,
              baseValue: MotionPropertyValue.scalar(
                transition
                    .parameterValue(
                      lane.id,
                      fallback: _defaultFallbackValueForLane(lane.id),
                    )
                    .clamp(0.0, 100.0)
                    .toDouble(),
              ),
              keyframes: _mapKeyframes(
                keyframes,
                valueResolver: (value) => value.clamp(0.0, 100.0).toDouble(),
                channelId:
                    'manual-transition-${transition.id}-${lane.id}-$laneTargetId-motion-blur-amount',
              ),
            ),
          ..._constantMotionBlurChannels(
            transition: transition,
            laneId: lane.id,
            laneTargetIds: laneTargetIds,
            projectId: projectId,
            activeRange: activeRange,
          ),
        ];
      default:
        return null;
    }
  }

  List<MotionPropertyChannelModel> _constantEdgeFillChannels({
    required TimelineTrackTransitionData transition,
    required String laneId,
    required List<String> laneTargetIds,
    required String projectId,
    required TimelineTimeRange activeRange,
  }) {
    final specs = <({
      String key,
      MotionPropertyDefinition definition,
      String suffix,
      double fallback,
      double min,
      double max,
      bool integerValue,
    })>[
      (
        key: 'edge_fill_mode',
        definition: MotionPropertyCatalog.edgeFillMode,
        suffix: 'edge-fill-mode',
        fallback: 1.0,
        min: 0.0,
        max: 7.0,
        integerValue: true,
      ),
      (
        key: 'edge_fill_overscan_scale',
        definition: MotionPropertyCatalog.edgeFillOverscanScale,
        suffix: 'edge-fill-overscan-scale',
        fallback: 1.2,
        min: 1.0,
        max: 10.0,
        integerValue: false,
      ),
      (
        key: 'edge_fill_softness_px',
        definition: MotionPropertyCatalog.edgeFillSoftnessPx,
        suffix: 'edge-fill-softness-px',
        fallback: 0.0,
        min: 0.0,
        max: 512.0,
        integerValue: false,
      ),
      (
        key: 'edge_fill_blur_sigma_px',
        definition: MotionPropertyCatalog.edgeFillBlurSigmaPx,
        suffix: 'edge-fill-blur-sigma-px',
        fallback: 0.0,
        min: 0.0,
        max: 512.0,
        integerValue: false,
      ),
      (
        key: 'edge_fill_max_expansion_px',
        definition: MotionPropertyCatalog.edgeFillMaxExpansionPx,
        suffix: 'edge-fill-max-expansion-px',
        fallback: 320.0,
        min: 0.0,
        max: 8192.0,
        integerValue: false,
      ),
    ];
    final boolSpecs = <({
      String key,
      MotionPropertyDefinition definition,
      String suffix,
      bool fallback,
    })>[
      (
        key: 'edge_fill_affect_rotation',
        definition: MotionPropertyCatalog.edgeFillAffectRotation,
        suffix: 'edge-fill-affect-rotation',
        fallback: true,
      ),
      (
        key: 'edge_fill_affect_scale',
        definition: MotionPropertyCatalog.edgeFillAffectScale,
        suffix: 'edge-fill-affect-scale',
        fallback: true,
      ),
      (
        key: 'edge_fill_affect_position',
        definition: MotionPropertyCatalog.edgeFillAffectPosition,
        suffix: 'edge-fill-affect-position',
        fallback: true,
      ),
      (
        key: 'edge_fill_affect_motion_blur',
        definition: MotionPropertyCatalog.edgeFillAffectMotionBlur,
        suffix: 'edge-fill-affect-motion-blur',
        fallback: true,
      ),
    ];
    return <MotionPropertyChannelModel>[
      for (final laneTargetId in laneTargetIds)
        for (final spec in specs)
          MotionPropertyChannelModel(
            id: 'manual-transition-${transition.id}-$laneId-$laneTargetId-${spec.suffix}',
            target: _elementTargetFor(
              projectId: projectId,
              targetId: laneTargetId,
            ),
            definition: spec.definition,
            activeRange: activeRange,
            baseValue: spec.integerValue
                ? MotionPropertyValue.integer(
                    transition
                        .parameterValue(
                          _edgeFillSettingKeyForLane(laneId, spec.key),
                          fallback: spec.fallback,
                        )
                        .clamp(spec.min, spec.max)
                        .round(),
                  )
                : MotionPropertyValue.scalar(
                    transition
                        .parameterValue(
                          _edgeFillSettingKeyForLane(laneId, spec.key),
                          fallback: spec.fallback,
                        )
                        .clamp(spec.min, spec.max)
                        .toDouble(),
                  ),
          ),
      for (final laneTargetId in laneTargetIds)
        for (final spec in boolSpecs)
          MotionPropertyChannelModel(
            id: 'manual-transition-${transition.id}-$laneId-$laneTargetId-${spec.suffix}',
            target: _elementTargetFor(
              projectId: projectId,
              targetId: laneTargetId,
            ),
            definition: spec.definition,
            activeRange: activeRange,
            baseValue: MotionPropertyValue.boolean(
              transition
                      .parameterValue(
                        _edgeFillSettingKeyForLane(laneId, spec.key),
                        fallback: spec.fallback ? 1.0 : 0.0,
                      )
                      .round() >
                  0,
            ),
          ),
    ];
  }

  List<MotionPropertyChannelModel> _constantMotionBlurChannels({
    required TimelineTrackTransitionData transition,
    required String laneId,
    required List<String> laneTargetIds,
    required String projectId,
    required TimelineTimeRange activeRange,
  }) {
    final affectFlags = _motionBlurAffectFlagsForLane(laneId);
    final specs = <({
      String key,
      MotionPropertyDefinition definition,
      String suffix,
      double fallback,
      double min,
      double max,
      bool integerValue,
    })>[
      (
        key: 'motion_blur_shutter_angle',
        definition: MotionPropertyCatalog.motionBlurShutterAngle,
        suffix: 'motion-blur-shutter-angle',
        fallback: 180.0,
        min: 0.0,
        max: 720.0,
        integerValue: false,
      ),
      (
        key: 'motion_blur_shutter_phase',
        definition: MotionPropertyCatalog.motionBlurShutterPhase,
        suffix: 'motion-blur-shutter-phase',
        fallback: -90.0,
        min: -360.0,
        max: 360.0,
        integerValue: false,
      ),
      (
        key: 'motion_blur_samples',
        definition: MotionPropertyCatalog.motionBlurSamples,
        suffix: 'motion-blur-samples',
        fallback: 12.0,
        min: 1.0,
        max: 32.0,
        integerValue: true,
      ),
      (
        key: 'motion_blur_adaptive_samples',
        definition: MotionPropertyCatalog.motionBlurAdaptiveSampleLimit,
        suffix: 'motion-blur-adaptive-samples',
        fallback: 24.0,
        min: 1.0,
        max: 64.0,
        integerValue: true,
      ),
      (
        key: 'motion_blur_max_trail',
        definition: MotionPropertyCatalog.motionBlurMaxTrailPx,
        suffix: 'motion-blur-max-trail',
        fallback: 240.0,
        min: 0.0,
        max: 600.0,
        integerValue: false,
      ),
    ];
    return <MotionPropertyChannelModel>[
      for (final laneTargetId in laneTargetIds)
        for (final spec in specs)
          MotionPropertyChannelModel(
            id: 'manual-transition-${transition.id}-$laneId-$laneTargetId-${spec.suffix}',
            target: _elementTargetFor(
              projectId: projectId,
              targetId: laneTargetId,
            ),
            definition: spec.definition,
            activeRange: activeRange,
            baseValue: spec.integerValue
                ? MotionPropertyValue.integer(
                    transition
                        .parameterValue(
                          _motionBlurSettingKeyForLane(laneId, spec.key),
                          fallback: spec.fallback,
                        )
                        .clamp(spec.min, spec.max)
                        .round(),
                  )
                : MotionPropertyValue.scalar(
                    transition
                        .parameterValue(
                          _motionBlurSettingKeyForLane(laneId, spec.key),
                          fallback: spec.fallback,
                        )
                        .clamp(spec.min, spec.max)
                        .toDouble(),
                  ),
          ),
      for (final laneTargetId in laneTargetIds) ...[
        _constantMotionBlurBooleanChannel(
          transition: transition,
          laneId: laneId,
          laneTargetId: laneTargetId,
          projectId: projectId,
          activeRange: activeRange,
          definition: MotionPropertyCatalog.motionBlurAffectPosition,
          suffix: 'motion-blur-affect-position',
          value: affectFlags.affectPosition,
        ),
        _constantMotionBlurBooleanChannel(
          transition: transition,
          laneId: laneId,
          laneTargetId: laneTargetId,
          projectId: projectId,
          activeRange: activeRange,
          definition: MotionPropertyCatalog.motionBlurAffectScale,
          suffix: 'motion-blur-affect-scale',
          value: affectFlags.affectScale,
        ),
        _constantMotionBlurBooleanChannel(
          transition: transition,
          laneId: laneId,
          laneTargetId: laneTargetId,
          projectId: projectId,
          activeRange: activeRange,
          definition: MotionPropertyCatalog.motionBlurAffectRotation,
          suffix: 'motion-blur-affect-rotation',
          value: affectFlags.affectRotation,
        ),
      ],
    ];
  }

  String _motionBlurSettingKeyForLane(String laneId, String legacySettingKey) {
    if (laneId == 'motion_blur') {
      return legacySettingKey;
    }
    final suffix = legacySettingKey.replaceFirst('motion_blur_', '');
    return '$laneId.$suffix';
  }

  String _edgeFillSettingKeyForLane(String laneId, String settingKey) {
    if (laneId == 'edge_fill') {
      return settingKey;
    }
    return '$laneId.$settingKey';
  }

  MotionPropertyChannelModel _constantMotionBlurBooleanChannel({
    required TimelineTrackTransitionData transition,
    required String laneId,
    required String laneTargetId,
    required String projectId,
    required TimelineTimeRange activeRange,
    required MotionPropertyDefinition definition,
    required String suffix,
    required bool value,
  }) {
    return MotionPropertyChannelModel(
      id: 'manual-transition-${transition.id}-$laneId-$laneTargetId-$suffix',
      target: _elementTargetFor(
        projectId: projectId,
        targetId: laneTargetId,
      ),
      definition: definition,
      activeRange: activeRange,
      baseValue: MotionPropertyValue.boolean(value),
      keyframes: const <MotionKeyframeModel>[],
    );
  }

  ({bool affectPosition, bool affectScale, bool affectRotation})
      _motionBlurAffectFlagsForLane(String laneId) {
    return switch (laneId) {
      'position.motion_blur' => (
          affectPosition: true,
          affectScale: false,
          affectRotation: false,
        ),
      'scale.motion_blur' => (
          affectPosition: false,
          affectScale: true,
          affectRotation: false,
        ),
      'rotation.motion_blur' => (
          affectPosition: false,
          affectScale: false,
          affectRotation: true,
        ),
      _ => (
          affectPosition: true,
          affectScale: true,
          affectRotation: true,
        ),
    };
  }

  MotionPropertyTarget _elementTargetFor({
    required String projectId,
    required String targetId,
  }) {
    return MotionPropertyTarget(
      kind: MotionTargetKind.element,
      targetId: targetId,
      projectId: projectId,
      elementId: targetId,
    );
  }

  List<String> _resolvedLaneTargetIds({
    required TimelineTrackTransitionData transition,
    required TimelineAnimationLaneData lane,
    required String fallbackTargetId,
  }) {
    final rawLaneTargetId = lane.targetClipId.trim().isEmpty
        ? fallbackTargetId
        : lane.targetClipId.trim();
    final laneTargetId = _canonicalManualLaneTargetId(
      transition: transition,
      laneTargetId: rawLaneTargetId,
      fallbackTargetId: fallbackTargetId,
    );
    if (_isExplicitManualTransitionSideTarget(
      transition: transition,
      rawLaneTargetId: rawLaneTargetId,
    )) {
      return <String>[laneTargetId];
    }
    if (_isActiveSourceManualTransitionLane(lane.id)) {
      final rightClipId = transition.rightClipId.trim();
      return <String>{
        laneTargetId,
        if (rightClipId.isNotEmpty) rightClipId,
      }.toList(growable: false);
    }
    final rightClipId = transition.rightClipId.trim();
    if (rightClipId.isEmpty || rightClipId == laneTargetId) {
      return <String>[laneTargetId];
    }
    return <String>[laneTargetId];
  }

  bool _isActiveSourceManualTransitionLane(String laneId) {
    return switch (laneId) {
      'scale' ||
      'opacity' ||
      'position' ||
      'rotation' ||
      'gaussian_blur' ||
      'motion_blur' ||
      'transform.motion_blur' ||
      'position.motion_blur' ||
      'scale.motion_blur' ||
      'rotation.motion_blur' =>
        true,
      'edge_fill' => true,
      _ => false,
    };
  }

  bool _isExplicitManualTransitionSideTarget({
    required TimelineTrackTransitionData transition,
    required String rawLaneTargetId,
  }) {
    final trimmed = rawLaneTargetId.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    if (trimmed == transition.rightClipId.trim()) {
      return true;
    }
    final transitionPrefix = '${transition.id}::focus-';
    return trimmed.startsWith(transitionPrefix) ||
        trimmed.endsWith('::focus-left') ||
        trimmed.endsWith('::focus-right');
  }

  String _canonicalManualLaneTargetId({
    required TimelineTrackTransitionData transition,
    required String laneTargetId,
    required String fallbackTargetId,
  }) {
    final trimmed = laneTargetId.trim();
    if (trimmed.isEmpty) {
      return fallbackTargetId;
    }
    if (trimmed == transition.leftClipId || trimmed == transition.rightClipId) {
      return trimmed;
    }
    final transitionPrefix = '${transition.id}::focus-';
    if (trimmed.startsWith(transitionPrefix)) {
      final side = trimmed.substring(transitionPrefix.length);
      if (side == 'left') {
        return transition.leftClipId;
      }
      if (side == 'right') {
        return transition.rightClipId;
      }
    }
    if (trimmed.endsWith('::focus-left')) {
      return transition.leftClipId;
    }
    if (trimmed.endsWith('::focus-right')) {
      return transition.rightClipId;
    }
    return trimmed;
  }

  List<MotionKeyframeModel> _mapKeyframes(
    List<_LaneKeyframe> keyframes, {
    required double Function(double value) valueResolver,
    required String channelId,
    MotionPropertyValue Function(double value)? valueBuilder,
  }) {
    return <MotionKeyframeModel>[
      for (final keyframe in keyframes)
        MotionKeyframeModel(
          id: keyframe.id,
          channelId: channelId,
          time: keyframe.time,
          value: (valueBuilder ?? MotionPropertyValue.scalar)(
            valueResolver(keyframe.value),
          ),
          interpolationToNext: keyframe.interpolationToNext,
        ),
    ];
  }

  List<_LaneKeyframe> _scalarKeyframesForLane({
    required TimelineTrackTransitionData transition,
    required TimelineAnimationLaneData lane,
    required TimelineTime windowStart,
    required TimelineTime windowEnd,
  }) {
    final stops = lane.normalizedKeyframeStops;
    final values = lane.alignedKeyframeValues(
      fallbackValue: _defaultFallbackValueForLane(lane.id),
      clampToPercent: false,
    );
    final keyframeIds = List<String>.from(lane.keyframeIds);
    while (keyframeIds.length < stops.length) {
      keyframeIds.add(
        '${transition.id}:${lane.id}:${keyframeIds.length}',
      );
    }
    final spanMs = (windowEnd - windowStart).inMilliseconds;
    final paired = <_LaneKeyframe>[
      for (var index = 0; index < stops.length; index++)
        _LaneKeyframe(
          id: keyframeIds[index],
          time: spanMs <= 0
              ? windowStart
              : windowStart +
                  TimelineTime.fromMilliseconds(
                    (spanMs * stops[index].clamp(0.0, 1.0)).round(),
                  ),
          value: values[index],
          interpolationToNext: _interpolationForLaneKeyframe(
            transition: transition,
            lane: lane,
            keyframeId: keyframeIds[index],
          ),
        ),
    ]..sort((left, right) => left.time.compareTo(right.time));
    return List<_LaneKeyframe>.unmodifiable(paired);
  }

  MotionInterpolationSpec _interpolationForLaneKeyframe({
    required TimelineTrackTransitionData transition,
    required TimelineAnimationLaneData lane,
    required String keyframeId,
  }) {
    final parameterKey = transitionFocusGraphPresetParameterKey(
      laneId: lane.id,
      keyframeId: keyframeId,
    );
    final presetIndex =
        transitionFocusGraphPresetIndex(transition.parameterValues[parameterKey]);
    final presetInterpolation = _interpolationForGraphPresetIndex(presetIndex);
    final velocity = transitionFocusGraphVelocityFromParameters(
      transition: transition,
      laneId: lane.id,
      keyframeId: keyframeId,
      fallback: presetInterpolation.velocity,
    );
    return presetInterpolation.copyWith(velocity: velocity);
  }

  MotionInterpolationSpec _interpolationForGraphPresetIndex(int presetIndex) {
    switch (presetIndex.clamp(0, 8)) {
      case 0:
        return const MotionInterpolationSpec.linear();
      case 1:
        return const MotionInterpolationSpec.cubicBezier(
          bezier: MotionBezierControlPoints(
            x1: 0.3333,
            y1: 0.0,
            x2: 0.6667,
            y2: 1.0,
          ),
        ).copyWith(
          velocity: const MotionKeyframeVelocity(
            incomingSpeed: 0.0,
            outgoingSpeed: 0.0,
            incomingInfluence: 33.333,
            outgoingInfluence: 33.333,
            continuous: true,
            presetId: 'easyEase',
          ),
        );
      case 2:
        return const MotionInterpolationSpec.easeIn().copyWith(
          velocity: const MotionKeyframeVelocity(
            incomingSpeed: 0.0,
            incomingInfluence: 33.333,
            continuous: true,
            presetId: 'easyEaseIn',
          ),
        );
      case 3:
        return const MotionInterpolationSpec.easeOut().copyWith(
          velocity: const MotionKeyframeVelocity(
            outgoingSpeed: 0.0,
            outgoingInfluence: 33.333,
            continuous: true,
            presetId: 'easyEaseOut',
          ),
        );
      case 4:
        return const MotionInterpolationSpec.cubicBezier(
          bezier: MotionBezierControlPoints(
            x1: 0.2,
            y1: 0.0,
            x2: 0.8,
            y2: 1.0,
          ),
        ).copyWith(
          velocity: const MotionKeyframeVelocity(
            incomingInfluence: 85.0,
            outgoingInfluence: 85.0,
            continuous: true,
            presetId: 'slowFastSlow',
          ),
        );
      case 5:
        return const MotionInterpolationSpec.cubicBezier(
          bezier: MotionBezierControlPoints(
            x1: 0.05,
            y1: 0.9,
            x2: 0.35,
            y2: 1.0,
          ),
        ).copyWith(
          velocity: const MotionKeyframeVelocity(
            incomingInfluence: 15.0,
            outgoingInfluence: 75.0,
            continuous: true,
            presetId: 'fastSlow',
          ),
        );
      case 6:
        return const MotionInterpolationSpec.cubicBezier(
          bezier: MotionBezierControlPoints(
            x1: 0.65,
            y1: 0.0,
            x2: 0.95,
            y2: 0.1,
          ),
        ).copyWith(
          velocity: const MotionKeyframeVelocity(
            incomingInfluence: 75.0,
            outgoingInfluence: 15.0,
            continuous: true,
            presetId: 'slowFast',
          ),
        );
      case 7:
        return const MotionInterpolationSpec.cubicBezier(
          bezier: MotionBezierControlPoints(
            x1: 0.05,
            y1: 0.0,
            x2: 0.25,
            y2: 1.0,
          ),
        ).copyWith(
          velocity: const MotionKeyframeVelocity(
            incomingInfluence: 10.0,
            outgoingInfluence: 95.0,
            continuous: false,
            presetId: 'whipSnap',
          ),
        );
      case 8:
        return const MotionInterpolationSpec.cubicBezier(
          bezier: MotionBezierControlPoints(
            x1: 0.3333,
            y1: 0.0,
            x2: 0.6667,
            y2: 1.0,
          ),
        ).copyWith(
          velocity: const MotionKeyframeVelocity(
            continuous: false,
            presetId: 'customSpeedGraph',
          ),
        );
      default:
        return const MotionInterpolationSpec.linear();
    }
  }

  double _defaultFallbackValueForLane(String laneId) {
    return switch (laneId) {
      'scale' => 0.0,
      'opacity' => 100.0,
      'position' => 0.0,
      'rotation' => 0.0,
      'gaussian_blur' => 0.0,
      'edge_fill' => 0.0,
      'motion_blur' => 0.0,
      'transform.motion_blur' => 0.0,
      'position.motion_blur' => 0.0,
      'scale.motion_blur' => 0.0,
      'rotation.motion_blur' => 0.0,
      _ => 0.0,
    };
  }

  double _scaleValueFromPercent(double percent) {
    return (1.0 + (percent / 100.0)).clamp(0.1, 4.0).toDouble();
  }

  double _opacityValueFromPercent(double percent) {
    return (percent / 100.0).clamp(0.0, 1.0).toDouble();
  }
}

class _LaneKeyframe {
  const _LaneKeyframe({
    required this.id,
    required this.time,
    required this.value,
    this.interpolationToNext = const MotionInterpolationSpec.linear(),
  });

  final String id;
  final TimelineTime time;
  final double value;
  final MotionInterpolationSpec interpolationToNext;
}

extension on MotionPropertyTarget {
  MotionPropertyTarget copyWith({
    MotionTargetKind? kind,
    String? targetId,
    String? projectId,
    String? sceneId,
    String? layerId,
    String? elementId,
  }) {
    return MotionPropertyTarget(
      kind: kind ?? this.kind,
      targetId: targetId ?? this.targetId,
      projectId: projectId ?? this.projectId,
      sceneId: sceneId ?? this.sceneId,
      layerId: layerId ?? this.layerId,
      elementId: elementId ?? this.elementId,
    );
  }
}
