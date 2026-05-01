import 'package:flutter/foundation.dart';

import '../../presentation/models/timeline_time.dart';

enum ProfessionalVideoTransitionCompositorKind {
  zoomInCamera,
}

@immutable
class ProfessionalVideoTransitionCompositorCapabilities {
  const ProfessionalVideoTransitionCompositorCapabilities({
    required this.dualVideoSampling,
    required this.temporalMotionBlur,
    required this.mirrorEdgeTiling,
    required this.previewParity,
    required this.liveScrubParity,
    required this.playbackParity,
    required this.exportParity,
  });

  static const unavailable = ProfessionalVideoTransitionCompositorCapabilities(
    dualVideoSampling: false,
    temporalMotionBlur: false,
    mirrorEdgeTiling: false,
    previewParity: false,
    liveScrubParity: false,
    playbackParity: false,
    exportParity: false,
  );

  final bool dualVideoSampling;
  final bool temporalMotionBlur;
  final bool mirrorEdgeTiling;
  final bool previewParity;
  final bool liveScrubParity;
  final bool playbackParity;
  final bool exportParity;

  bool get canExposeProfessionalZoomInCamera =>
      dualVideoSampling &&
      temporalMotionBlur &&
      mirrorEdgeTiling &&
      previewParity &&
      liveScrubParity &&
      playbackParity &&
      exportParity;

  List<String> get missingForProfessionalZoomInCamera {
    final missing = <String>[];
    if (!dualVideoSampling) {
      missing.add('dualVideoSampling');
    }
    if (!temporalMotionBlur) {
      missing.add('temporalMotionBlur');
    }
    if (!mirrorEdgeTiling) {
      missing.add('mirrorEdgeTiling');
    }
    if (!previewParity) {
      missing.add('previewParity');
    }
    if (!liveScrubParity) {
      missing.add('liveScrubParity');
    }
    if (!playbackParity) {
      missing.add('playbackParity');
    }
    if (!exportParity) {
      missing.add('exportParity');
    }
    return List.unmodifiable(missing);
  }
}

const ProfessionalVideoTransitionCompositorCapabilities
    kCurrentProfessionalVideoTransitionCompositorCapabilities =
    ProfessionalVideoTransitionCompositorCapabilities.unavailable;

@immutable
class ProfessionalVideoTransitionCompositorSource {
  const ProfessionalVideoTransitionCompositorSource({
    required this.clipId,
    required this.assetId,
    required this.timelineRange,
    required this.sourceStartTime,
    required this.sourceDuration,
  });

  final String clipId;
  final String assetId;
  final TimelineTimeRange timelineRange;
  final TimelineTime sourceStartTime;
  final TimelineTime sourceDuration;

  TimelineTime get sourceEndExclusive => sourceStartTime + sourceDuration;

  TimelineTime sourceTimeForTimelineTime(TimelineTime timelineTime) {
    final localTime = timelineTime - timelineRange.start;
    final unclamped = sourceStartTime + localTime;
    return unclamped.clamp(sourceStartTime, sourceEndExclusive);
  }
}

@immutable
class ProfessionalVideoTransitionMotionTilePlan {
  const ProfessionalVideoTransitionMotionTilePlan({
    required this.enabled,
    required this.mirrorEdges,
    required this.outputScaleX,
    required this.outputScaleY,
  });

  final bool enabled;
  final bool mirrorEdges;
  final double outputScaleX;
  final double outputScaleY;
}

@immutable
class ProfessionalVideoTransitionShutterPlan {
  const ProfessionalVideoTransitionShutterPlan({
    required this.shutterAngleDegrees,
    required this.frameRate,
    required this.sampleCount,
    required this.sampleTimes,
  });

  final double shutterAngleDegrees;
  final double frameRate;
  final int sampleCount;
  final List<TimelineTime> sampleTimes;
}

@immutable
class ProfessionalZoomCameraFramePlan {
  const ProfessionalZoomCameraFramePlan({
    required this.transitionId,
    required this.progress,
    required this.seamProgress,
    required this.outgoingSourceTime,
    required this.incomingSourceTime,
    required this.outgoingScale,
    required this.incomingScale,
    required this.motionTile,
    required this.shutter,
  });

  final String transitionId;
  final double progress;
  final double seamProgress;
  final TimelineTime outgoingSourceTime;
  final TimelineTime incomingSourceTime;
  final double outgoingScale;
  final double incomingScale;
  final ProfessionalVideoTransitionMotionTilePlan motionTile;
  final ProfessionalVideoTransitionShutterPlan shutter;
}

@immutable
class ProfessionalZoomCameraPlanRequest {
  const ProfessionalZoomCameraPlanRequest({
    required this.transitionId,
    required this.timelineTime,
    required this.boundaryTime,
    required this.leadingDuration,
    required this.trailingDuration,
    required this.outgoing,
    required this.incoming,
    this.outgoingBoostScale = 3.0,
    this.incomingStartScale = 0.28,
    this.shutterAngleDegrees = 360.0,
    this.frameRate = 30.0,
    this.shutterSampleCount = 8,
    this.motionTileOutputScaleX = 4.0,
    this.motionTileOutputScaleY = 3.5,
  });

  final String transitionId;
  final TimelineTime timelineTime;
  final TimelineTime boundaryTime;
  final TimelineTime leadingDuration;
  final TimelineTime trailingDuration;
  final ProfessionalVideoTransitionCompositorSource outgoing;
  final ProfessionalVideoTransitionCompositorSource incoming;
  final double outgoingBoostScale;
  final double incomingStartScale;
  final double shutterAngleDegrees;
  final double frameRate;
  final int shutterSampleCount;
  final double motionTileOutputScaleX;
  final double motionTileOutputScaleY;
}

class ProfessionalZoomCameraCompositorPlanner {
  const ProfessionalZoomCameraCompositorPlanner();

  ProfessionalZoomCameraFramePlan planFrame(
    ProfessionalZoomCameraPlanRequest request,
  ) {
    final start = request.boundaryTime - request.leadingDuration;
    final end = request.boundaryTime + request.trailingDuration;
    final total = end - start;
    final progress = total <= TimelineTime.zero
        ? 0.0
        : ((request.timelineTime - start).inProjectTicks / total.inProjectTicks)
            .clamp(0.0, 1.0)
            .toDouble();
    final seamProgress = total <= TimelineTime.zero
        ? 0.5
        : (request.leadingDuration.inProjectTicks / total.inProjectTicks)
            .clamp(0.0, 1.0)
            .toDouble();
    final outgoingPhase =
        (progress / _safePositive(seamProgress)).clamp(0.0, 1.0).toDouble();
    final incomingPhase =
        ((progress - seamProgress) / _safePositive(1 - seamProgress))
            .clamp(0.0, 1.0)
            .toDouble();

    return ProfessionalZoomCameraFramePlan(
      transitionId: request.transitionId,
      progress: progress,
      seamProgress: seamProgress,
      outgoingSourceTime:
          request.outgoing.sourceTimeForTimelineTime(request.timelineTime),
      incomingSourceTime:
          request.incoming.sourceTimeForTimelineTime(request.timelineTime),
      outgoingScale: _lerp(
        1.0,
        request.outgoingBoostScale,
        _easeInCubic(outgoingPhase),
      ),
      incomingScale: _lerp(
        request.incomingStartScale,
        1.0,
        _easeOutCubic(incomingPhase),
      ),
      motionTile: ProfessionalVideoTransitionMotionTilePlan(
        enabled: true,
        mirrorEdges: true,
        outputScaleX: request.motionTileOutputScaleX,
        outputScaleY: request.motionTileOutputScaleY,
      ),
      shutter: ProfessionalVideoTransitionShutterPlan(
        shutterAngleDegrees: request.shutterAngleDegrees,
        frameRate: request.frameRate,
        sampleCount: request.shutterSampleCount,
        sampleTimes: _shutterSampleTimes(
          timelineTime: request.timelineTime,
          transitionStart: start,
          transitionEnd: end,
          shutterAngleDegrees: request.shutterAngleDegrees,
          frameRate: request.frameRate,
          sampleCount: request.shutterSampleCount,
        ),
      ),
    );
  }

  static List<TimelineTime> _shutterSampleTimes({
    required TimelineTime timelineTime,
    required TimelineTime transitionStart,
    required TimelineTime transitionEnd,
    required double shutterAngleDegrees,
    required double frameRate,
    required int sampleCount,
  }) {
    final safeFrameRate =
        frameRate.isFinite && frameRate > 0 ? frameRate : 30.0;
    final safeSampleCount = sampleCount.clamp(1, 32);
    final exposureSeconds =
        shutterAngleDegrees.clamp(0.0, 720.0) / (360.0 * safeFrameRate);
    if (safeSampleCount == 1 || exposureSeconds <= 0) {
      return <TimelineTime>[
        timelineTime.clamp(transitionStart, transitionEnd),
      ];
    }
    final firstOffsetSeconds = -exposureSeconds / 2;
    final stepSeconds = exposureSeconds / (safeSampleCount - 1);
    return List<TimelineTime>.unmodifiable(
      List<TimelineTime>.generate(safeSampleCount, (index) {
        final sampleTime = timelineTime +
            TimelineTime.fromSecondsDouble(
              firstOffsetSeconds + (stepSeconds * index),
            );
        return sampleTime.clamp(transitionStart, transitionEnd);
      }),
    );
  }

  static double _safePositive(double value) {
    return value.abs() < 0.0001 ? 0.0001 : value;
  }

  static double _lerp(double start, double end, double t) {
    return start + ((end - start) * t.clamp(0.0, 1.0));
  }

  static double _easeInCubic(double t) {
    final clamped = t.clamp(0.0, 1.0);
    return clamped * clamped * clamped;
  }

  static double _easeOutCubic(double t) {
    final clamped = t.clamp(0.0, 1.0);
    final inverse = 1 - clamped;
    return 1 - (inverse * inverse * inverse);
  }
}
