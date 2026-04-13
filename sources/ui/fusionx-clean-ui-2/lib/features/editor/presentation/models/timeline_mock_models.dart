import 'timeline_time.dart';

enum TimelineTrackKind {
  video,
  image,
  audio,
  text,
  lipSync,
}

enum TimelineTransitionPreset {
  manual,
  fadeBlack,
  zoomInCamera,
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
      TimelineTransitionPreset.fadeBlack => 'Fade Black',
      TimelineTransitionPreset.zoomInCamera => 'Zoom In Camera',
    };
  }

  String get summary {
    return switch (this) {
      TimelineTransitionPreset.manual =>
        'Build the transition lane by lane on a focused seam timeline.',
      TimelineTransitionPreset.fadeBlack =>
        'Dip through black between two clips.',
      TimelineTransitionPreset.zoomInCamera =>
        'Push into the next clip with a camera-style zoom.',
    };
  }

  TimelineTime get defaultDurationTime {
    return switch (this) {
      TimelineTransitionPreset.manual => TimelineTime.fromMilliseconds(620),
      TimelineTransitionPreset.fadeBlack => TimelineTime.fromMilliseconds(540),
      TimelineTransitionPreset.zoomInCamera =>
        TimelineTime.fromMilliseconds(620),
    };
  }

  Map<String, double> get defaultParameterValues {
    return switch (this) {
      TimelineTransitionPreset.manual => const <String, double>{},
      TimelineTransitionPreset.fadeBlack => <String, double>{
          'blackPeak': 0.94,
        },
      TimelineTransitionPreset.zoomInCamera => <String, double>{
          'incomingStartScale': 1.18,
          'outgoingBoostScale': 1.05,
          'entryDelay': 0.18,
          'bridgeDarkness': 0.22,
        },
    };
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
  placeholder,
}

enum TimelineClipType {
  media,
  placeholder,
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
  })  : _durationTime =
            durationTime ?? TimelineTime.fromSecondsDouble(duration ?? 0),
        _sourceDurationTime = sourceDurationTime ??
            (sourceDuration != null
                ? TimelineTime.fromSecondsDouble(sourceDuration)
                : (durationTime ??
                    TimelineTime.fromSecondsDouble(duration ?? 0))),
        _sourceStartTime = sourceStartTime ??
            TimelineTime.fromSecondsDouble(sourceOffsetSeconds ?? 0),
        playbackRate = playbackRate <= 0 ? 1.0 : playbackRate;

  final String id;
  final TimelineClipType type;
  final TimelineClipTone tone;
  final String? assetId;
  final String? label;
  final String? splitGroupId;
  final TimelineClipSpeedMode speedMode;
  final double playbackRate;
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
    bool clearSplitGroupId = false,
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
    );
  }

  double visualWidth(double secondsWidth) {
    final baseWidth = duration * secondsWidth;
    if (type == TimelineClipType.media || isGapPlaceholder) {
      return baseWidth <= 0 ? 1.0 : baseWidth;
    }
    const minWidth = 118.0;
    return baseWidth < minWidth ? minWidth : baseWidth;
  }
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
  })  : parameterValues = Map.unmodifiable(parameterValues),
        manualEffectIds = List.unmodifiable(manualEffectIds);

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
    );
  }
}

class TimelineTrackData {
  const TimelineTrackData({
    required this.kind,
    required this.clips,
    this.placeholderLabel,
    this.animationLanes = const <TimelineAnimationLaneData>[],
    this.transitions = const <TimelineTrackTransitionData>[],
  });

  final TimelineTrackKind kind;
  final List<TimelineClipData> clips;
  final String? placeholderLabel;
  final List<TimelineAnimationLaneData> animationLanes;
  final List<TimelineTrackTransitionData> transitions;

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
  }) {
    return TimelineTrackData(
      kind: kind ?? this.kind,
      clips: clips ?? this.clips,
      placeholderLabel: placeholderLabel ?? this.placeholderLabel,
      animationLanes: animationLanes ?? this.animationLanes,
      transitions: transitions ?? this.transitions,
    );
  }
}

class TimelineAnimationLaneData {
  const TimelineAnimationLaneData({
    required this.id,
    required this.label,
    required this.targetClipId,
    this.normalizedKeyframeStops = const <double>[0.0, 0.52, 1.0],
    this.trackSpanStartProgress,
    this.trackSpanEndProgress,
  });

  final String id;
  final String label;
  final String targetClipId;
  final List<double> normalizedKeyframeStops;
  final double? trackSpanStartProgress;
  final double? trackSpanEndProgress;

  TimelineAnimationLaneData copyWith({
    String? id,
    String? label,
    String? targetClipId,
    List<double>? normalizedKeyframeStops,
    double? trackSpanStartProgress,
    double? trackSpanEndProgress,
  }) {
    return TimelineAnimationLaneData(
      id: id ?? this.id,
      label: label ?? this.label,
      targetClipId: targetClipId ?? this.targetClipId,
      normalizedKeyframeStops:
          normalizedKeyframeStops ?? this.normalizedKeyframeStops,
      trackSpanStartProgress:
          trackSpanStartProgress ?? this.trackSpanStartProgress,
      trackSpanEndProgress: trackSpanEndProgress ?? this.trackSpanEndProgress,
    );
  }
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
