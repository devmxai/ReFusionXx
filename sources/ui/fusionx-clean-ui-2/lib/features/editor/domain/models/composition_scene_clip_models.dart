import 'package:flutter/foundation.dart';

import '../../presentation/models/timeline_time.dart';

enum CompositionSceneClipIssueCode {
  invalidDuration,
  invalidSourceRange,
  invalidTimeScale,
  localTimeOutOfRange,
}

@immutable
class CompositionSceneClipIssue {
  const CompositionSceneClipIssue({
    required this.code,
    required this.message,
    this.clipId,
    this.sceneId,
  });

  final CompositionSceneClipIssueCode code;
  final String message;
  final String? clipId;
  final String? sceneId;
}

@immutable
class CompositionSceneClipModel {
  CompositionSceneClipModel({
    required this.id,
    required this.sourceSceneId,
    required this.startTime,
    required this.durationTime,
    TimelineTime? sourceInTime,
    TimelineTime? sourceOutTime,
    this.name,
    this.timeScale = 1.0,
    this.isEnabled = true,
    this.isLocked = false,
    Map<String, String> metadata = const <String, String>{},
  })  : sourceInTime = sourceInTime ?? TimelineTime.zero,
        sourceOutTime = sourceOutTime ??
            (sourceInTime ?? TimelineTime.zero) +
                _scaleTime(durationTime, _safeTimeScaleFor(timeScale)),
        metadata = Map.unmodifiable(metadata);

  final String id;
  final String sourceSceneId;
  final String? name;
  final TimelineTime startTime;
  final TimelineTime durationTime;
  final TimelineTime sourceInTime;
  final TimelineTime sourceOutTime;
  final double timeScale;
  final bool isEnabled;
  final bool isLocked;
  final Map<String, String> metadata;

  TimelineTime get endTime => startTime + durationTime;

  TimelineTimeRange get rootRange => TimelineTimeRange(
        start: startTime,
        endExclusive: endTime,
      );

  TimelineTimeRange get sourceRange => TimelineTimeRange(
        start: sourceInTime,
        endExclusive: sourceOutTime,
      );

  TimelineTimeRange get sourceLocalRange => TimelineTimeRange(
        start: TimelineTime.zero,
        endExclusive: sourceDurationTime,
      );

  TimelineTime get sourceDurationTime => sourceRange.duration;

  bool containsRootTime(TimelineTime rootTime) => rootRange.contains(rootTime);

  bool containsSourceTime(TimelineTime sourceTime) {
    return sourceRange.contains(sourceTime);
  }

  bool containsSceneLocalTime(TimelineTime localTime) {
    return sourceLocalRange.contains(localTime);
  }

  TimelineTime rootToSourceTime(TimelineTime rootTime) {
    final clamped = rootTime.clamp(startTime, endTime);
    final elapsed = clamped - startTime;
    final scaledElapsed = _scaleTime(elapsed, _safeTimeScale);
    return (sourceInTime + scaledElapsed).clamp(
      sourceInTime,
      sourceOutTime,
    );
  }

  TimelineTime sourceToRootTime(TimelineTime sourceTime) {
    final clamped = sourceTime.clamp(sourceInTime, sourceOutTime);
    final elapsed = clamped - sourceInTime;
    final rootElapsed = _scaleTime(elapsed, 1 / _safeTimeScale);
    return (startTime + rootElapsed).clamp(startTime, endTime);
  }

  TimelineTime rootToLocalTime(TimelineTime rootTime) {
    return rootToSourceTime(rootTime) - sourceInTime;
  }

  TimelineTime localToRootTime(TimelineTime localTime) {
    final sourceTime = sourceInTime +
        localTime.clamp(
          TimelineTime.zero,
          sourceDurationTime,
        );
    return sourceToRootTime(sourceTime);
  }

  List<CompositionSceneClipIssue> validate() {
    final issues = <CompositionSceneClipIssue>[];
    if (durationTime <= TimelineTime.zero) {
      issues.add(
        CompositionSceneClipIssue(
          code: CompositionSceneClipIssueCode.invalidDuration,
          message: 'Scene clip `$id` must have a positive duration.',
          clipId: id,
          sceneId: sourceSceneId,
        ),
      );
    }
    if (sourceOutTime <= sourceInTime) {
      issues.add(
        CompositionSceneClipIssue(
          code: CompositionSceneClipIssueCode.invalidSourceRange,
          message:
              'Scene clip `$id` must point to a non-empty source scene range.',
          clipId: id,
          sceneId: sourceSceneId,
        ),
      );
    }
    if (!_isValidTimeScale(timeScale)) {
      issues.add(
        CompositionSceneClipIssue(
          code: CompositionSceneClipIssueCode.invalidTimeScale,
          message: 'Scene clip `$id` must have a positive finite timeScale.',
          clipId: id,
          sceneId: sourceSceneId,
        ),
      );
    }
    return issues;
  }

  CompositionSceneClipModel copyWith({
    String? id,
    String? sourceSceneId,
    String? name,
    TimelineTime? startTime,
    TimelineTime? durationTime,
    TimelineTime? sourceInTime,
    TimelineTime? sourceOutTime,
    double? timeScale,
    bool? isEnabled,
    bool? isLocked,
    Map<String, String>? metadata,
  }) {
    return CompositionSceneClipModel(
      id: id ?? this.id,
      sourceSceneId: sourceSceneId ?? this.sourceSceneId,
      name: name ?? this.name,
      startTime: startTime ?? this.startTime,
      durationTime: durationTime ?? this.durationTime,
      sourceInTime: sourceInTime ?? this.sourceInTime,
      sourceOutTime: sourceOutTime ?? this.sourceOutTime,
      timeScale: timeScale ?? this.timeScale,
      isEnabled: isEnabled ?? this.isEnabled,
      isLocked: isLocked ?? this.isLocked,
      metadata: metadata ?? this.metadata,
    );
  }

  double get _safeTimeScale {
    return _safeTimeScaleFor(timeScale);
  }
}

bool _isValidTimeScale(double value) => value.isFinite && value > 0;

double _safeTimeScaleFor(double value) {
  if (!_isValidTimeScale(value)) {
    return 1.0;
  }
  return value;
}

TimelineTime _scaleTime(TimelineTime time, double scale) {
  final safeScale = _safeTimeScaleFor(scale);
  return TimelineTime.fromProjectTicks(
    (time.inProjectTicks * safeScale).round(),
  );
}

@immutable
class CompositionSceneClipCollection {
  CompositionSceneClipCollection({
    List<CompositionSceneClipModel> clips = const <CompositionSceneClipModel>[],
  }) : clips = List.unmodifiable(clips);

  final List<CompositionSceneClipModel> clips;

  CompositionSceneClipModel? clipAtRootTime(TimelineTime rootTime) {
    for (final clip in clips) {
      if (clip.isEnabled && clip.containsRootTime(rootTime)) {
        return clip;
      }
    }
    return null;
  }

  List<CompositionSceneClipModel> clipsForSourceScene(String sourceSceneId) {
    return clips
        .where((clip) => clip.sourceSceneId == sourceSceneId)
        .toList(growable: false);
  }

  List<CompositionSceneClipIssue> validate() {
    return <CompositionSceneClipIssue>[
      for (final clip in clips) ...clip.validate(),
    ];
  }
}
