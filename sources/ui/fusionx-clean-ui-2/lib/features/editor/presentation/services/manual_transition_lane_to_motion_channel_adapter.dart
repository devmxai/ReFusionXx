import '../../domain/models/professional_motion_animation_models.dart';
import '../../domain/models/professional_motion_models.dart';
import '../models/timeline_mock_models.dart';
import '../models/timeline_time.dart';

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
      default:
        return null;
    }
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
      'gaussian_blur' =>
        true,
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
  }) {
    return <MotionKeyframeModel>[
      for (final keyframe in keyframes)
        MotionKeyframeModel(
          id: keyframe.id,
          channelId: channelId,
          time: keyframe.time,
          value: MotionPropertyValue.scalar(valueResolver(keyframe.value)),
          interpolationToNext: const MotionInterpolationSpec.linear(),
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
        ),
    ]..sort((left, right) => left.time.compareTo(right.time));
    return List<_LaneKeyframe>.unmodifiable(paired);
  }

  double _defaultFallbackValueForLane(String laneId) {
    return switch (laneId) {
      'scale' => 0.0,
      'opacity' => 100.0,
      'position' => 0.0,
      'rotation' => 0.0,
      'gaussian_blur' => 0.0,
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
  });

  final String id;
  final TimelineTime time;
  final double value;
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
