import 'timeline_time.dart';

enum TimelineTrackKind {
  video,
  image,
  audio,
  text,
  lipSync,
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

class TimelineTrackData {
  const TimelineTrackData({
    required this.kind,
    required this.clips,
    this.placeholderLabel,
    this.animationLanes = const <TimelineAnimationLaneData>[],
  });

  final TimelineTrackKind kind;
  final List<TimelineClipData> clips;
  final String? placeholderLabel;
  final List<TimelineAnimationLaneData> animationLanes;

  TimelineTrackData copyWith({
    TimelineTrackKind? kind,
    List<TimelineClipData>? clips,
    String? placeholderLabel,
    List<TimelineAnimationLaneData>? animationLanes,
  }) {
    return TimelineTrackData(
      kind: kind ?? this.kind,
      clips: clips ?? this.clips,
      placeholderLabel: placeholderLabel ?? this.placeholderLabel,
      animationLanes: animationLanes ?? this.animationLanes,
    );
  }
}

class TimelineAnimationLaneData {
  const TimelineAnimationLaneData({
    required this.id,
    required this.label,
    required this.targetClipId,
    this.normalizedKeyframeStops = const <double>[0.0, 0.52, 1.0],
  });

  final String id;
  final String label;
  final String targetClipId;
  final List<double> normalizedKeyframeStops;

  TimelineAnimationLaneData copyWith({
    String? id,
    String? label,
    String? targetClipId,
    List<double>? normalizedKeyframeStops,
  }) {
    return TimelineAnimationLaneData(
      id: id ?? this.id,
      label: label ?? this.label,
      targetClipId: targetClipId ?? this.targetClipId,
      normalizedKeyframeStops:
          normalizedKeyframeStops ?? this.normalizedKeyframeStops,
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
