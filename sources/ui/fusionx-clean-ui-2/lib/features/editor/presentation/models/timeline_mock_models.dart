import 'timeline_time.dart';
import 'ai_transition_models.dart';

enum TimelineTrackKind {
  video,
  image,
  audio,
  text,
  lipSync,
}

enum TimelineTrackContentKind {
  video,
  image,
  audio,
  text,
  lipSync,
  scene,
}

enum TimelineVisualKind {
  video,
  image,
  audio,
  text,
  lipSync,
  composition,
  shape,
  camera,
  control,
}

enum TimelineTransitionPreset {
  manual,
  crossDissolve,
  fadeBlack,
  zoomInCamera,
  zoomInPro,
  aiGenerated,
}

enum TimelineTransitionCurve {
  linear,
  easeIn,
  easeOut,
  easeInOut,
}

extension TimelineTransitionPresetPresentation on TimelineTransitionPreset {
  String get label {
    return switch (this) {
      TimelineTransitionPreset.manual => 'Manual',
      TimelineTransitionPreset.crossDissolve => 'Cross Dissolve',
      TimelineTransitionPreset.fadeBlack => 'Fade Black',
      TimelineTransitionPreset.zoomInCamera => 'Zoom In Camera',
      TimelineTransitionPreset.zoomInPro => 'Zoom In Pro',
      TimelineTransitionPreset.aiGenerated => 'AI Transition',
    };
  }

  String get summary {
    return switch (this) {
      TimelineTransitionPreset.manual =>
        'Build the transition lane by lane on a focused seam timeline.',
      TimelineTransitionPreset.crossDissolve =>
        'Blend outgoing and incoming clips with a clean opacity handoff.',
      TimelineTransitionPreset.fadeBlack =>
        'Dip through black between two clips.',
      TimelineTransitionPreset.zoomInCamera =>
        'Push into the next clip with a camera-style zoom.',
      TimelineTransitionPreset.zoomInPro =>
        'Experimental live-surface zoom trial for testing the transition engine path.',
      TimelineTransitionPreset.aiGenerated =>
        'Generate a seam bridge from the last frame of A to the first frame of B.',
    };
  }

  TimelineTime get defaultDurationTime {
    return switch (this) {
      TimelineTransitionPreset.manual => TimelineTime.fromMilliseconds(2000),
      TimelineTransitionPreset.crossDissolve =>
        TimelineTime.fromMilliseconds(2000),
      TimelineTransitionPreset.fadeBlack => TimelineTime.fromMilliseconds(540),
      TimelineTransitionPreset.zoomInCamera =>
        TimelineTime.fromMilliseconds(4000),
      TimelineTransitionPreset.zoomInPro => TimelineTime.fromMilliseconds(4000),
      TimelineTransitionPreset.aiGenerated =>
        TimelineTime.fromMilliseconds(3000),
    };
  }

  Map<String, double> get defaultParameterValues {
    return switch (this) {
      TimelineTransitionPreset.manual => const <String, double>{},
      TimelineTransitionPreset.crossDissolve => <String, double>{
          'softness': 0.5,
        },
      TimelineTransitionPreset.fadeBlack => <String, double>{
          'blackPeak': 0.94,
        },
      TimelineTransitionPreset.zoomInCamera => <String, double>{
          'incomingStartScale': 0.28,
          'outgoingBoostScale': 3.0,
          'entryDelay': 0.12,
          'bridgeDarkness': 0.12,
          'motionBlurAmount': 18.0,
          'shakeAmount': 5.0,
        },
      TimelineTransitionPreset.zoomInPro => <String, double>{
          'incomingStartScale': 0.42,
          'outgoingBoostScale': 2.4,
          'entryDelay': 0.0,
          'bridgeDarkness': 0.0,
          'motionBlurAmount': 0.0,
          'shakeAmount': 0.0,
        },
      TimelineTransitionPreset.aiGenerated => const <String, double>{},
    };
  }

  bool get isZoomCameraFamily {
    return this == TimelineTransitionPreset.zoomInCamera ||
        this == TimelineTransitionPreset.zoomInPro;
  }
}

extension TimelineTransitionCurvePresentation on TimelineTransitionCurve {
  String get label {
    return switch (this) {
      TimelineTransitionCurve.linear => 'Linear',
      TimelineTransitionCurve.easeIn => 'Ease In',
      TimelineTransitionCurve.easeOut => 'Ease Out',
      TimelineTransitionCurve.easeInOut => 'Ease In Out',
    };
  }
}

enum TimelineClipTone {
  hero,
  heroMuted,
  aiGenerated,
  placeholder,
}

enum TimelineClipType {
  media,
  placeholder,
}

enum TimelineClipContentKind {
  media,
  placeholder,
  scene,
}

enum TimelineClipSpeedMode {
  normal,
  curve,
}

enum TimelineTrimEdge {
  start,
  end,
}

class TimelineClipData {
  TimelineClipData({
    required this.id,
    required this.type,
    required this.tone,
    double? duration,
    TimelineTime? durationTime,
    double? sourceDuration,
    TimelineTime? sourceDurationTime,
    this.assetId,
    double? sourceOffsetSeconds,
    TimelineTime? sourceStartTime,
    this.label,
    this.splitGroupId,
    this.speedMode = TimelineClipSpeedMode.normal,
    double playbackRate = 1.0,
    this.aiTransition,
    TimelineClipContentKind? contentKind,
    TimelineVisualKind? visualKind,
    this.sourceSceneId,
  })  : _durationTime =
            durationTime ?? TimelineTime.fromSecondsDouble(duration ?? 0),
        _sourceDurationTime = sourceDurationTime ??
            (sourceDuration != null
                ? TimelineTime.fromSecondsDouble(sourceDuration)
                : (durationTime ??
                    TimelineTime.fromSecondsDouble(duration ?? 0))),
        _sourceStartTime = sourceStartTime ??
            TimelineTime.fromSecondsDouble(sourceOffsetSeconds ?? 0),
        playbackRate = playbackRate <= 0 ? 1.0 : playbackRate,
        contentKind = contentKind ?? _defaultContentKindFor(type),
        visualKind = visualKind ?? _defaultClipVisualKindFor(contentKind, type);

  final String id;
  final TimelineClipType type;
  final TimelineClipTone tone;
  final String? assetId;
  final String? label;
  final String? splitGroupId;
  final TimelineClipSpeedMode speedMode;
  final double playbackRate;
  final AiTransitionDraftData? aiTransition;
  final TimelineClipContentKind contentKind;
  final TimelineVisualKind visualKind;
  final String? sourceSceneId;
  final TimelineTime _durationTime;
  final TimelineTime _sourceDurationTime;
  final TimelineTime _sourceStartTime;

  TimelineTime get durationTime => _durationTime;

  TimelineTime get sourceDurationTime => _sourceDurationTime;

  TimelineTime get sourceStartTime => _sourceStartTime;

  TimelineTime get sourceEndTime => _sourceStartTime + _sourceDurationTime;

  TimelineTimeRange get sourceRange => TimelineTimeRange(
        start: sourceStartTime,
        endExclusive: sourceEndTime,
      );

  double get duration => _durationTime.inSecondsDouble;

  double get sourceDuration => _sourceDurationTime.inSecondsDouble;

  double get sourceOffsetSeconds => _sourceStartTime.inSecondsDouble;

  bool get hasSpeedOverride =>
      speedMode != TimelineClipSpeedMode.normal ||
      (playbackRate - 1.0).abs() > 0.001;

  bool get isGapPlaceholder =>
      type == TimelineClipType.placeholder &&
      (label == null || label!.trim().isEmpty);

  bool get isSceneClip => contentKind == TimelineClipContentKind.scene;

  TimelineClipData copyWith({
    String? id,
    double? duration,
    TimelineTime? durationTime,
    double? sourceDuration,
    TimelineTime? sourceDurationTime,
    TimelineClipType? type,
    TimelineClipTone? tone,
    String? assetId,
    double? sourceOffsetSeconds,
    TimelineTime? sourceStartTime,
    String? label,
    String? splitGroupId,
    TimelineClipSpeedMode? speedMode,
    double? playbackRate,
    AiTransitionDraftData? aiTransition,
    TimelineClipContentKind? contentKind,
    TimelineVisualKind? visualKind,
    String? sourceSceneId,
    bool clearSplitGroupId = false,
    bool clearAiTransition = false,
    bool clearSourceSceneId = false,
  }) {
    final resolvedDurationTime = durationTime ??
        (duration != null
            ? TimelineTime.fromSecondsDouble(duration)
            : this.durationTime);
    final resolvedSourceDurationTime = sourceDurationTime ??
        (sourceDuration != null
            ? TimelineTime.fromSecondsDouble(sourceDuration)
            : this.sourceDurationTime);
    return TimelineClipData(
      id: id ?? this.id,
      durationTime: resolvedDurationTime,
      sourceDurationTime: resolvedSourceDurationTime,
      type: type ?? this.type,
      tone: tone ?? this.tone,
      assetId: assetId ?? this.assetId,
      sourceStartTime: sourceStartTime ??
          (sourceOffsetSeconds != null
              ? TimelineTime.fromSecondsDouble(sourceOffsetSeconds)
              : this.sourceStartTime),
      label: label ?? this.label,
      splitGroupId:
          clearSplitGroupId ? null : (splitGroupId ?? this.splitGroupId),
      speedMode: speedMode ?? this.speedMode,
      playbackRate: playbackRate ?? this.playbackRate,
      aiTransition:
          clearAiTransition ? null : aiTransition ?? this.aiTransition,
      contentKind: contentKind ?? this.contentKind,
      visualKind: visualKind ?? this.visualKind,
      sourceSceneId:
          clearSourceSceneId ? null : sourceSceneId ?? this.sourceSceneId,
    );
  }

  double visualWidth(double secondsWidth) {
    final baseWidth = duration * secondsWidth;
    final isSceneVideoLayerProxy =
        contentKind == TimelineClipContentKind.scene &&
            visualKind == TimelineVisualKind.video;
    if (type == TimelineClipType.media ||
        isGapPlaceholder ||
        isSceneVideoLayerProxy) {
      return baseWidth <= 0 ? 1.0 : baseWidth;
    }
    const minWidth = 118.0;
    return baseWidth < minWidth ? minWidth : baseWidth;
  }
}

TimelineClipContentKind _defaultContentKindFor(TimelineClipType type) {
  return switch (type) {
    TimelineClipType.media => TimelineClipContentKind.media,
    TimelineClipType.placeholder => TimelineClipContentKind.placeholder,
  };
}

TimelineVisualKind _defaultClipVisualKindFor(
  TimelineClipContentKind? contentKind,
  TimelineClipType type,
) {
  return switch (contentKind ?? _defaultContentKindFor(type)) {
    TimelineClipContentKind.media => TimelineVisualKind.video,
    TimelineClipContentKind.placeholder => TimelineVisualKind.control,
    TimelineClipContentKind.scene => TimelineVisualKind.composition,
  };
}

class TimelineTrackTransitionData {
  TimelineTrackTransitionData({
    required this.id,
    required this.leftClipId,
    required this.rightClipId,
    required this.preset,
    required this.durationTime,
    this.leadingDurationTime,
    this.trailingDurationTime,
    this.curve = TimelineTransitionCurve.easeInOut,
    Map<String, double> parameterValues = const <String, double>{},
    List<String> manualEffectIds = const <String>[],
    List<TimelineAnimationLaneData> manualAnimationLanes =
        const <TimelineAnimationLaneData>[],
    this.aiTransition,
  })  : parameterValues = Map.unmodifiable(parameterValues),
        manualEffectIds = List.unmodifiable(manualEffectIds),
        manualAnimationLanes = List.unmodifiable(manualAnimationLanes);

  final String id;
  final String leftClipId;
  final String rightClipId;
  final TimelineTransitionPreset preset;
  final TimelineTime durationTime;
  final TimelineTime? leadingDurationTime;
  final TimelineTime? trailingDurationTime;
  final TimelineTransitionCurve curve;
  final Map<String, double> parameterValues;
  final List<String> manualEffectIds;
  final List<TimelineAnimationLaneData> manualAnimationLanes;
  final AiTransitionDraftData? aiTransition;

  TimelineTime get resolvedLeadingDurationTime {
    final explicitLeading = leadingDurationTime;
    if (explicitLeading != null) {
      return explicitLeading;
    }
    final explicitTrailing = trailingDurationTime;
    if (explicitTrailing != null) {
      return durationTime - explicitTrailing;
    }
    return TimelineTime.fromMilliseconds(durationTime.inMilliseconds ~/ 2);
  }

  TimelineTime get resolvedTrailingDurationTime {
    final explicitTrailing = trailingDurationTime;
    if (explicitTrailing != null) {
      return explicitTrailing;
    }
    return durationTime - resolvedLeadingDurationTime;
  }

  double parameterValue(String key, {double fallback = 0}) {
    return parameterValues[key] ?? fallback;
  }

  TimelineAnimationLaneData? manualAnimationLaneById(String laneId) {
    for (final lane in manualAnimationLanes) {
      if (lane.id == laneId) {
        return lane;
      }
    }
    return null;
  }

  double manualLaneValueAtProgress(
    String laneId,
    double progress, {
    required double fallbackValue,
  }) {
    final lane = manualAnimationLaneById(laneId);
    if (lane == null) {
      return fallbackValue;
    }
    return lane.evaluateValueAtProgress(
      progress,
      fallbackValue: fallbackValue,
    );
  }

  TimelineTrackTransitionData copyWith({
    String? id,
    String? leftClipId,
    String? rightClipId,
    TimelineTransitionPreset? preset,
    TimelineTime? durationTime,
    TimelineTime? leadingDurationTime,
    TimelineTime? trailingDurationTime,
    TimelineTransitionCurve? curve,
    Map<String, double>? parameterValues,
    List<String>? manualEffectIds,
    List<TimelineAnimationLaneData>? manualAnimationLanes,
    AiTransitionDraftData? aiTransition,
    bool clearAiTransition = false,
  }) {
    return TimelineTrackTransitionData(
      id: id ?? this.id,
      leftClipId: leftClipId ?? this.leftClipId,
      rightClipId: rightClipId ?? this.rightClipId,
      preset: preset ?? this.preset,
      durationTime: durationTime ?? this.durationTime,
      leadingDurationTime: leadingDurationTime ?? this.leadingDurationTime,
      trailingDurationTime: trailingDurationTime ?? this.trailingDurationTime,
      curve: curve ?? this.curve,
      parameterValues: parameterValues ?? this.parameterValues,
      manualEffectIds: manualEffectIds ?? this.manualEffectIds,
      manualAnimationLanes: manualAnimationLanes ?? this.manualAnimationLanes,
      aiTransition:
          clearAiTransition ? null : aiTransition ?? this.aiTransition,
    );
  }
}

class TimelineTrackData {
  TimelineTrackData({
    required this.kind,
    required this.clips,
    this.placeholderLabel,
    this.animationLanes = const <TimelineAnimationLaneData>[],
    this.transitions = const <TimelineTrackTransitionData>[],
    TimelineTrackContentKind? contentKind,
    TimelineVisualKind? visualKind,
  })  : contentKind = contentKind ?? _defaultTrackContentKindFor(kind),
        visualKind = visualKind ??
            _defaultTrackVisualKindFor(
              kind,
              contentKind ?? _defaultTrackContentKindFor(kind),
            );

  final TimelineTrackKind kind;
  final List<TimelineClipData> clips;
  final String? placeholderLabel;
  final List<TimelineAnimationLaneData> animationLanes;
  final List<TimelineTrackTransitionData> transitions;
  final TimelineTrackContentKind contentKind;
  final TimelineVisualKind visualKind;

  bool get isSceneTrack => contentKind == TimelineTrackContentKind.scene;

  TimelineTrackTransitionData? transitionForBoundary(
    String leftClipId,
    String rightClipId,
  ) {
    for (final transition in transitions) {
      if (transition.leftClipId == leftClipId &&
          transition.rightClipId == rightClipId) {
        return transition;
      }
    }
    return null;
  }

  TimelineTrackData copyWith({
    TimelineTrackKind? kind,
    List<TimelineClipData>? clips,
    String? placeholderLabel,
    List<TimelineAnimationLaneData>? animationLanes,
    List<TimelineTrackTransitionData>? transitions,
    TimelineTrackContentKind? contentKind,
    TimelineVisualKind? visualKind,
  }) {
    return TimelineTrackData(
      kind: kind ?? this.kind,
      clips: clips ?? this.clips,
      placeholderLabel: placeholderLabel ?? this.placeholderLabel,
      animationLanes: animationLanes ?? this.animationLanes,
      transitions: transitions ?? this.transitions,
      contentKind: contentKind ?? this.contentKind,
      visualKind: visualKind ?? this.visualKind,
    );
  }
}

TimelineTrackContentKind _defaultTrackContentKindFor(TimelineTrackKind kind) {
  return switch (kind) {
    TimelineTrackKind.video => TimelineTrackContentKind.video,
    TimelineTrackKind.image => TimelineTrackContentKind.image,
    TimelineTrackKind.audio => TimelineTrackContentKind.audio,
    TimelineTrackKind.text => TimelineTrackContentKind.text,
    TimelineTrackKind.lipSync => TimelineTrackContentKind.lipSync,
  };
}

TimelineVisualKind _defaultTrackVisualKindFor(
  TimelineTrackKind kind,
  TimelineTrackContentKind contentKind,
) {
  if (contentKind == TimelineTrackContentKind.scene) {
    return TimelineVisualKind.composition;
  }
  return switch (kind) {
    TimelineTrackKind.video => TimelineVisualKind.video,
    TimelineTrackKind.image => TimelineVisualKind.image,
    TimelineTrackKind.audio => TimelineVisualKind.audio,
    TimelineTrackKind.text => TimelineVisualKind.text,
    TimelineTrackKind.lipSync => TimelineVisualKind.lipSync,
  };
}

class TimelineAnimationLaneData {
  const TimelineAnimationLaneData({
    required this.id,
    required this.label,
    required this.targetClipId,
    this.normalizedKeyframeStops = const <double>[0.0, 0.52, 1.0],
    this.keyframeIds = const <String>[],
    this.keyframeValues = const <double>[],
    this.trackSpanStartProgress,
    this.trackSpanEndProgress,
  });

  final String id;
  final String label;
  final String targetClipId;
  final List<double> normalizedKeyframeStops;
  final List<String> keyframeIds;
  final List<double> keyframeValues;
  final double? trackSpanStartProgress;
  final double? trackSpanEndProgress;

  TimelineAnimationLaneData copyWith({
    String? id,
    String? label,
    String? targetClipId,
    List<double>? normalizedKeyframeStops,
    List<String>? keyframeIds,
    List<double>? keyframeValues,
    double? trackSpanStartProgress,
    double? trackSpanEndProgress,
  }) {
    return TimelineAnimationLaneData(
      id: id ?? this.id,
      label: label ?? this.label,
      targetClipId: targetClipId ?? this.targetClipId,
      normalizedKeyframeStops:
          normalizedKeyframeStops ?? this.normalizedKeyframeStops,
      keyframeIds: keyframeIds ?? this.keyframeIds,
      keyframeValues: keyframeValues ?? this.keyframeValues,
      trackSpanStartProgress:
          trackSpanStartProgress ?? this.trackSpanStartProgress,
      trackSpanEndProgress: trackSpanEndProgress ?? this.trackSpanEndProgress,
    );
  }
}

extension TimelineAnimationLaneEvaluation on TimelineAnimationLaneData {
  List<double> alignedKeyframeValues({
    double fallbackValue = 0.0,
    bool clampToPercent = true,
  }) {
    final stopCount = normalizedKeyframeStops.length;
    if (stopCount == 0) {
      return <double>[];
    }
    final values = List<double>.from(keyframeValues);
    final resolvedFallback = clampToPercent
        ? fallbackValue.clamp(0.0, 100.0).toDouble()
        : fallbackValue.toDouble();
    if (values.isEmpty) {
      return List<double>.filled(stopCount, resolvedFallback, growable: false);
    }
    while (values.length < stopCount) {
      values.add(values.last);
    }
    if (values.length > stopCount) {
      values.removeRange(stopCount, values.length);
    }
    return values.map((value) {
      if (!clampToPercent) {
        return value.toDouble();
      }
      return value.clamp(0.0, 100.0).toDouble();
    }).toList(growable: false);
  }

  double evaluateValueAtProgress(
    double progress, {
    double fallbackValue = 0.0,
    bool clampToPercent = false,
  }) {
    final resolvedFallback = clampToPercent
        ? fallbackValue.clamp(0.0, 100.0).toDouble()
        : fallbackValue.toDouble();
    if (normalizedKeyframeStops.isEmpty) {
      return resolvedFallback;
    }
    final values = alignedKeyframeValues(
      fallbackValue: resolvedFallback,
      clampToPercent: clampToPercent,
    );
    final keyframes = <({double stop, double value})>[
      for (var index = 0; index < normalizedKeyframeStops.length; index++)
        (
          stop: normalizedKeyframeStops[index].clamp(0.0, 1.0).toDouble(),
          value: values[index],
        ),
    ]..sort((left, right) => left.stop.compareTo(right.stop));
    if (keyframes.isEmpty) {
      return resolvedFallback;
    }
    if (keyframes.length == 1) {
      return keyframes.first.value;
    }
    final clampedProgress = progress.clamp(0.0, 1.0).toDouble();
    if (clampedProgress <= keyframes.first.stop) {
      return keyframes.first.value;
    }
    for (var index = 1; index < keyframes.length; index++) {
      final previous = keyframes[index - 1];
      final current = keyframes[index];
      if (clampedProgress > current.stop) {
        continue;
      }
      final span = current.stop - previous.stop;
      if (span.abs() <= 0.000001) {
        return current.value;
      }
      final t = ((clampedProgress - previous.stop) / span).clamp(0.0, 1.0);
      return previous.value + ((current.value - previous.value) * t);
    }
    return keyframes.last.value;
  }

  double evaluatePercentAtProgress(
    double progress, {
    double fallbackPercent = 100.0,
  }) {
    return evaluateValueAtProgress(
      progress,
      fallbackValue: fallbackPercent,
      clampToPercent: true,
    );
  }

  bool matchesPropertyLabel(String value) =>
      label.trim().toLowerCase() == value.trim().toLowerCase();
}

class TimelineTrimSelection {
  const TimelineTrimSelection({
    required this.clipId,
    required this.trackKind,
    required this.clipStartTime,
    required this.durationTime,
    required this.sourceStartTime,
    required this.sourceDurationTime,
    required this.playbackRate,
    required this.minDurationTime,
    this.playheadBarrierTime,
    this.assetDurationTime,
  });

  final String clipId;
  final TimelineTrackKind trackKind;
  final TimelineTime clipStartTime;
  final TimelineTime durationTime;
  final TimelineTime sourceStartTime;
  final TimelineTime sourceDurationTime;
  final double playbackRate;
  final TimelineTime minDurationTime;
  final TimelineTime? playheadBarrierTime;
  final TimelineTime? assetDurationTime;

  TimelineTime get clipEndTime => clipStartTime + durationTime;

  TimelineTime get sourceEndTime => sourceStartTime + sourceDurationTime;
}

class TimelineTrimCommitRequest {
  const TimelineTrimCommitRequest({
    required this.clipId,
    required this.edge,
    required this.sourceStartTime,
    required this.durationTime,
  });

  final String clipId;
  final TimelineTrimEdge edge;
  final TimelineTime sourceStartTime;
  final TimelineTime durationTime;
}

class TimelineTrimPreviewRequest {
  const TimelineTrimPreviewRequest({
    required this.clipId,
    required this.edge,
    required this.sourceStartTime,
    required this.durationTime,
    required this.timelinePreviewTime,
    required this.sourcePreviewTime,
  });

  final String clipId;
  final TimelineTrimEdge edge;
  final TimelineTime sourceStartTime;
  final TimelineTime durationTime;
  final TimelineTime timelinePreviewTime;
  final TimelineTime sourcePreviewTime;
}

List<TimelineTrackData> buildMockTimelineTracks() => const [];
