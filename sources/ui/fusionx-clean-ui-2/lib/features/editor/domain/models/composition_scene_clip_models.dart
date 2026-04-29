import 'package:flutter/foundation.dart';

import '../../presentation/models/timeline_time.dart';
import 'professional_motion_models.dart';

enum CompositionSceneClipIssueCode {
  invalidDuration,
  invalidSourceRange,
  invalidTimeScale,
  localTimeOutOfRange,
  invalidInstanceTransform,
  invalidInstanceOpacity,
  invalidInstanceCrop,
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
class CompositionSceneClipInstanceTransform {
  const CompositionSceneClipInstanceTransform({
    this.positionX = 0,
    this.positionY = 0,
    this.scaleX = 1,
    this.scaleY = 1,
    this.rotationDegrees = 0,
  });

  final double positionX;
  final double positionY;
  final double scaleX;
  final double scaleY;
  final double rotationDegrees;

  static const identity = CompositionSceneClipInstanceTransform();

  bool get isIdentity =>
      positionX == 0 &&
      positionY == 0 &&
      scaleX == 1 &&
      scaleY == 1 &&
      rotationDegrees == 0;

  bool get isValid =>
      positionX.isFinite &&
      positionY.isFinite &&
      scaleX.isFinite &&
      scaleY.isFinite &&
      rotationDegrees.isFinite &&
      scaleX > 0 &&
      scaleY > 0;

  CompositionSceneClipInstanceTransform copyWith({
    double? positionX,
    double? positionY,
    double? scaleX,
    double? scaleY,
    double? rotationDegrees,
  }) {
    return CompositionSceneClipInstanceTransform(
      positionX: positionX ?? this.positionX,
      positionY: positionY ?? this.positionY,
      scaleX: scaleX ?? this.scaleX,
      scaleY: scaleY ?? this.scaleY,
      rotationDegrees: rotationDegrees ?? this.rotationDegrees,
    );
  }
}

@immutable
class CompositionSceneClipInstanceVisualStyle {
  CompositionSceneClipInstanceVisualStyle({
    this.transform = CompositionSceneClipInstanceTransform.identity,
    this.opacity = 1,
    this.cropRect,
    this.zIndex = 0,
    List<String> effectIds = const <String>[],
    Map<String, String> metadata = const <String, String>{},
  })  : effectIds = List.unmodifiable(effectIds),
        metadata = Map.unmodifiable(metadata);

  final CompositionSceneClipInstanceTransform transform;
  final double opacity;
  final MotionRect? cropRect;
  final int zIndex;
  final List<String> effectIds;
  final Map<String, String> metadata;

  static final identity = CompositionSceneClipInstanceVisualStyle();

  bool get hasVisualAdjustment =>
      !transform.isIdentity ||
      opacity != 1 ||
      cropRect != null ||
      zIndex != 0 ||
      effectIds.isNotEmpty ||
      metadata.isNotEmpty;

  bool get hasValidOpacity => opacity.isFinite && opacity >= 0 && opacity <= 1;

  bool get hasValidCrop {
    final crop = cropRect;
    if (crop == null) {
      return true;
    }
    return crop.left.isFinite &&
        crop.top.isFinite &&
        crop.width.isFinite &&
        crop.height.isFinite &&
        crop.width > 0 &&
        crop.height > 0;
  }

  CompositionSceneClipInstanceVisualStyle copyWith({
    CompositionSceneClipInstanceTransform? transform,
    double? opacity,
    MotionRect? cropRect,
    bool clearCropRect = false,
    int? zIndex,
    List<String>? effectIds,
    Map<String, String>? metadata,
  }) {
    return CompositionSceneClipInstanceVisualStyle(
      transform: transform ?? this.transform,
      opacity: opacity ?? this.opacity,
      cropRect: clearCropRect ? null : cropRect ?? this.cropRect,
      zIndex: zIndex ?? this.zIndex,
      effectIds: effectIds ?? this.effectIds,
      metadata: metadata ?? this.metadata,
    );
  }
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
    CompositionSceneClipInstanceVisualStyle? instanceVisualStyle,
    this.isEnabled = true,
    this.isLocked = false,
    Map<String, String> metadata = const <String, String>{},
  })  : sourceInTime = sourceInTime ?? TimelineTime.zero,
        sourceOutTime = sourceOutTime ??
            (sourceInTime ?? TimelineTime.zero) +
                _scaleTime(durationTime, _safeTimeScaleFor(timeScale)),
        instanceVisualStyle = instanceVisualStyle ??
            CompositionSceneClipInstanceVisualStyle.identity,
        metadata = Map.unmodifiable(metadata);

  final String id;
  final String sourceSceneId;
  final String? name;
  final TimelineTime startTime;
  final TimelineTime durationTime;
  final TimelineTime sourceInTime;
  final TimelineTime sourceOutTime;
  final double timeScale;
  final CompositionSceneClipInstanceVisualStyle instanceVisualStyle;
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
    if (!instanceVisualStyle.transform.isValid) {
      issues.add(
        CompositionSceneClipIssue(
          code: CompositionSceneClipIssueCode.invalidInstanceTransform,
          message: 'Scene clip `$id` has invalid instance transform values.',
          clipId: id,
          sceneId: sourceSceneId,
        ),
      );
    }
    if (!instanceVisualStyle.hasValidOpacity) {
      issues.add(
        CompositionSceneClipIssue(
          code: CompositionSceneClipIssueCode.invalidInstanceOpacity,
          message: 'Scene clip `$id` instance opacity must be between 0 and 1.',
          clipId: id,
          sceneId: sourceSceneId,
        ),
      );
    }
    if (!instanceVisualStyle.hasValidCrop) {
      issues.add(
        CompositionSceneClipIssue(
          code: CompositionSceneClipIssueCode.invalidInstanceCrop,
          message: 'Scene clip `$id` has an invalid instance crop rectangle.',
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
    CompositionSceneClipInstanceVisualStyle? instanceVisualStyle,
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
      instanceVisualStyle: instanceVisualStyle ?? this.instanceVisualStyle,
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

  List<CompositionSceneClipModel> clipsAtRootTimeInDrawOrder(
    TimelineTime rootTime,
  ) {
    final visibleClips = clips
        .where((clip) => clip.isEnabled && clip.containsRootTime(rootTime))
        .toList(growable: false);
    visibleClips.sort((left, right) {
      final zCompare = left.instanceVisualStyle.zIndex
          .compareTo(right.instanceVisualStyle.zIndex);
      if (zCompare != 0) {
        return zCompare;
      }
      final startCompare = left.startTime.compareTo(right.startTime);
      if (startCompare != 0) {
        return startCompare;
      }
      return left.id.compareTo(right.id);
    });
    return List<CompositionSceneClipModel>.unmodifiable(visibleClips);
  }

  CompositionSceneClipModel? topClipAtRootTime(TimelineTime rootTime) {
    final visibleClips = clipsAtRootTimeInDrawOrder(rootTime);
    if (visibleClips.isEmpty) {
      return null;
    }
    return visibleClips.last;
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
