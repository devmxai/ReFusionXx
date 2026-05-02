import 'package:flutter/foundation.dart';

import '../../presentation/models/timeline_time.dart';
import '../services/timeline_clock_coordinator.dart';

enum MasterClockPhase {
  idle,
  paused,
  scrubbing,
  scrubSettling,
  playStarting,
  playing,
  pausing,
  seeking,
  zooming,
  structuralEditing,
  exporting,
}

enum MasterClockAuthority {
  none,
  user,
  nativeTransport,
  geometry,
  structuralEdit,
  export,
  test,
}

enum MasterRenderMode {
  preview,
  playback,
  liveScrub,
  settle,
  export,
  test,
}

enum MasterTimeScope {
  rootComposition,
  sourceComposition,
  scene,
  layer,
  transition,
  sourceMedia,
}

enum MasterTimeDomainKind {
  root,
  composition,
  scene,
  layer,
  transition,
  sourceMedia,
}

enum MasterTimeProjectionPolicy {
  strict,
  clamp,
  rejectOutsideRange,
  allowGapAsBlank,
  sourceRateAdjusted,
  transitionProgress,
}

@immutable
class MasterTimeDomain {
  const MasterTimeDomain._({
    required this.kind,
    this.id,
  });

  const MasterTimeDomain.root() : this._(kind: MasterTimeDomainKind.root);

  const MasterTimeDomain.composition(String compositionId)
      : this._(kind: MasterTimeDomainKind.composition, id: compositionId);

  const MasterTimeDomain.scene(String sceneId)
      : this._(kind: MasterTimeDomainKind.scene, id: sceneId);

  const MasterTimeDomain.layer(String layerId)
      : this._(kind: MasterTimeDomainKind.layer, id: layerId);

  const MasterTimeDomain.transition(String transitionId)
      : this._(kind: MasterTimeDomainKind.transition, id: transitionId);

  const MasterTimeDomain.sourceMedia(String mediaId)
      : this._(kind: MasterTimeDomainKind.sourceMedia, id: mediaId);

  final MasterTimeDomainKind kind;
  final String? id;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MasterTimeDomain && other.kind == kind && other.id == id;
  }

  @override
  int get hashCode => Object.hash(kind, id);
}

@immutable
class MasterTimeSnapshot {
  const MasterTimeSnapshot({
    required this.rootTime,
    required this.presentationTime,
    required this.frameIndex,
    required this.frameRate,
    required this.commitFrameNumber,
    required this.monotonicTimeUs,
    required this.phase,
    required this.authority,
    required this.renderMode,
    required this.sourceScope,
  });

  final TimelineTime rootTime;
  final TimelineTime presentationTime;
  final int frameIndex;
  final double frameRate;
  final int commitFrameNumber;
  final int monotonicTimeUs;
  final MasterClockPhase phase;
  final MasterClockAuthority authority;
  final MasterRenderMode renderMode;
  final MasterTimeScope sourceScope;

  static MasterTimeSnapshot fromClockSnapshot({
    required TimelineClockSnapshot clock,
    required double frameRate,
    required MasterRenderMode renderMode,
    required MasterTimeScope sourceScope,
    int monotonicTimeUs = 0,
  }) {
    final safeFrameRate =
        (frameRate.isFinite && frameRate > 0 ? frameRate : 30.0).toDouble();
    final rootTime = clock.time;
    return MasterTimeSnapshot(
      rootTime: rootTime,
      presentationTime: clock.presentationTime,
      frameIndex:
          frameIndexForTime(rootTime: rootTime, frameRate: safeFrameRate),
      frameRate: safeFrameRate,
      commitFrameNumber: clock.commitFrameNumber,
      monotonicTimeUs: monotonicTimeUs,
      phase: _mapClockPhase(clock.phase),
      authority: _mapClockAuthority(clock.authority),
      renderMode: renderMode,
      sourceScope: sourceScope,
    );
  }

  static int frameIndexForTime({
    required TimelineTime rootTime,
    required double frameRate,
  }) {
    final safeFrameRate =
        (frameRate.isFinite && frameRate > 0 ? frameRate : 30.0).toDouble();
    final frames = rootTime.inSecondsDouble * safeFrameRate;
    if (!frames.isFinite) {
      return 0;
    }
    return frames.floor();
  }

  static TimelineTime timeForFrameIndex({
    required int frameIndex,
    required double frameRate,
  }) {
    final safeFrameRate =
        (frameRate.isFinite && frameRate > 0 ? frameRate : 30.0).toDouble();
    final frameSeconds = frameIndex / safeFrameRate;
    return TimelineTime.fromSecondsDouble(frameSeconds);
  }
}

@immutable
class MasterTimeProjection {
  const MasterTimeProjection({
    required this.fromDomain,
    required this.toDomain,
    required this.inputTime,
    required this.outputTime,
    this.validRange,
    required this.policy,
    required this.reason,
    this.isValid = true,
  });

  final MasterTimeDomain fromDomain;
  final MasterTimeDomain toDomain;
  final TimelineTime inputTime;
  final TimelineTime outputTime;
  final TimelineTimeRange? validRange;
  final MasterTimeProjectionPolicy policy;
  final String reason;
  final bool isValid;
}

MasterClockPhase _mapClockPhase(TimelineClockPhase phase) {
  switch (phase) {
    case TimelineClockPhase.idle:
      return MasterClockPhase.idle;
    case TimelineClockPhase.paused:
      return MasterClockPhase.paused;
    case TimelineClockPhase.scrubbing:
      return MasterClockPhase.scrubbing;
    case TimelineClockPhase.scrubSettling:
      return MasterClockPhase.scrubSettling;
    case TimelineClockPhase.playStarting:
      return MasterClockPhase.playStarting;
    case TimelineClockPhase.playing:
      return MasterClockPhase.playing;
    case TimelineClockPhase.pausing:
      return MasterClockPhase.pausing;
    case TimelineClockPhase.seeking:
      return MasterClockPhase.seeking;
    case TimelineClockPhase.zooming:
      return MasterClockPhase.zooming;
    case TimelineClockPhase.structuralEditing:
      return MasterClockPhase.structuralEditing;
  }
}

MasterClockAuthority _mapClockAuthority(TimelineClockAuthority authority) {
  switch (authority) {
    case TimelineClockAuthority.none:
      return MasterClockAuthority.none;
    case TimelineClockAuthority.user:
      return MasterClockAuthority.user;
    case TimelineClockAuthority.nativeTransport:
      return MasterClockAuthority.nativeTransport;
    case TimelineClockAuthority.geometry:
      return MasterClockAuthority.geometry;
    case TimelineClockAuthority.structuralEdit:
      return MasterClockAuthority.structuralEdit;
  }
}
