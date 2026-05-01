import 'package:flutter/foundation.dart';

import '../../domain/services/professional_video_transition_compositor.dart';
import '../models/timeline_mock_models.dart';
import '../models/timeline_time.dart';

typedef ProfessionalVideoTransitionSourceUriResolver = String? Function(
  String assetId,
);

@immutable
class ProfessionalVideoTransitionRenderPlanRequest {
  const ProfessionalVideoTransitionRenderPlanRequest({
    required this.transition,
    required this.definitionId,
    required this.outgoingClip,
    required this.incomingClip,
    required this.boundaryTime,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.sourceUriForAsset,
    this.requiredCapabilities = _requiredProfessionalCapabilities,
    this.parameters = const <String, Object?>{},
    this.samplingPolicy = const <String, Object?>{},
    this.edgePolicy = const <String, Object?>{},
    this.motionBlurPolicy = const <String, Object?>{},
  });

  final TimelineTrackTransitionData transition;
  final String definitionId;
  final TimelineClipData outgoingClip;
  final TimelineClipData incomingClip;
  final TimelineTime boundaryTime;
  final int canvasWidth;
  final int canvasHeight;
  final ProfessionalVideoTransitionSourceUriResolver sourceUriForAsset;
  final List<String> requiredCapabilities;
  final Map<String, Object?> parameters;
  final Map<String, Object?> samplingPolicy;
  final Map<String, Object?> edgePolicy;
  final Map<String, Object?> motionBlurPolicy;
}

@immutable
class ProfessionalVideoTransitionRenderPlanBuildResult {
  const ProfessionalVideoTransitionRenderPlanBuildResult._({
    required this.plan,
    required this.issues,
  });

  factory ProfessionalVideoTransitionRenderPlanBuildResult.success(
    ProfessionalVideoTransitionRenderPlan plan,
  ) {
    return ProfessionalVideoTransitionRenderPlanBuildResult._(
      plan: plan,
      issues: const <ProfessionalVideoTransitionRenderPlanBuildIssue>[],
    );
  }

  factory ProfessionalVideoTransitionRenderPlanBuildResult.failure(
    List<ProfessionalVideoTransitionRenderPlanBuildIssue> issues,
  ) {
    return ProfessionalVideoTransitionRenderPlanBuildResult._(
      plan: null,
      issues:
          List<ProfessionalVideoTransitionRenderPlanBuildIssue>.unmodifiable(
              issues),
    );
  }

  final ProfessionalVideoTransitionRenderPlan? plan;
  final List<ProfessionalVideoTransitionRenderPlanBuildIssue> issues;

  bool get canBuild => plan != null && issues.isEmpty;
}

@immutable
class ProfessionalVideoTransitionRenderPlanBuildIssue {
  const ProfessionalVideoTransitionRenderPlanBuildIssue({
    required this.code,
    required this.path,
    required this.message,
  });

  final String code;
  final String path;
  final String message;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'code': code,
      'path': path,
      'message': message,
    };
  }
}

class ProfessionalVideoTransitionRenderPlanAdapter {
  const ProfessionalVideoTransitionRenderPlanAdapter();

  ProfessionalVideoTransitionRenderPlanBuildResult build(
    ProfessionalVideoTransitionRenderPlanRequest request,
  ) {
    final issues = <ProfessionalVideoTransitionRenderPlanBuildIssue>[];
    final definitionId = request.definitionId.trim();
    if (definitionId.isEmpty) {
      issues.add(
        const ProfessionalVideoTransitionRenderPlanBuildIssue(
          code: 'definition_id_missing',
          path: 'definitionId',
          message: 'Transition definition id is required.',
        ),
      );
    }
    if (request.canvasWidth <= 0 || request.canvasHeight <= 0) {
      issues.add(
        const ProfessionalVideoTransitionRenderPlanBuildIssue(
          code: 'canvas_invalid',
          path: 'canvas',
          message: 'Canvas width and height must be positive.',
        ),
      );
    }

    final leadingDuration = request.transition.resolvedLeadingDurationTime;
    final trailingDuration = request.transition.resolvedTrailingDurationTime;
    if (leadingDuration < TimelineTime.zero ||
        trailingDuration < TimelineTime.zero ||
        leadingDuration + trailingDuration <= TimelineTime.zero) {
      issues.add(
        const ProfessionalVideoTransitionRenderPlanBuildIssue(
          code: 'transition_duration_invalid',
          path: 'transition.durationTime',
          message:
              'Transition leading and trailing durations must be positive.',
        ),
      );
    }

    final transitionStart = request.boundaryTime - leadingDuration;
    if (transitionStart < TimelineTime.zero) {
      issues.add(
        const ProfessionalVideoTransitionRenderPlanBuildIssue(
          code: 'transition_start_before_zero',
          path: 'boundaryTime',
          message:
              'Transition leading window cannot start before timeline zero.',
        ),
      );
    }

    final outgoingSource = _buildSource(
      role: 'outgoing',
      path: 'sources[0]',
      clip: request.outgoingClip,
      boundaryTime: request.boundaryTime,
      timelineDuration: leadingDuration,
      timelineRange: TimelineTimeRange(
        start: request.boundaryTime - leadingDuration,
        endExclusive: request.boundaryTime,
      ),
      sourceUriForAsset: request.sourceUriForAsset,
      sourceStartTime: request.outgoingClip.sourceEndTime - leadingDuration,
      issues: issues,
    );
    final incomingSource = _buildSource(
      role: 'incoming',
      path: 'sources[1]',
      clip: request.incomingClip,
      boundaryTime: request.boundaryTime,
      timelineDuration: trailingDuration,
      timelineRange: TimelineTimeRange(
        start: request.boundaryTime,
        endExclusive: request.boundaryTime + trailingDuration,
      ),
      sourceUriForAsset: request.sourceUriForAsset,
      sourceStartTime: request.incomingClip.sourceStartTime,
      issues: issues,
    );

    if (issues.isNotEmpty || outgoingSource == null || incomingSource == null) {
      return ProfessionalVideoTransitionRenderPlanBuildResult.failure(issues);
    }

    return ProfessionalVideoTransitionRenderPlanBuildResult.success(
      ProfessionalVideoTransitionRenderPlan(
        definitionId: definitionId,
        transitionId: request.transition.id,
        canvasWidth: request.canvasWidth,
        canvasHeight: request.canvasHeight,
        boundaryTime: request.boundaryTime,
        leadingDuration: leadingDuration,
        trailingDuration: trailingDuration,
        sources: <ProfessionalVideoTransitionCompositorSource>[
          outgoingSource,
          incomingSource,
        ],
        requiredCapabilities: List<String>.unmodifiable(
          request.requiredCapabilities,
        ),
        parameters: Map<String, Object?>.unmodifiable(request.parameters),
        samplingPolicy: Map<String, Object?>.unmodifiable(
          <String, Object?>{
            'sourceCount': 2,
            'sourceRoles': const <String>['outgoing', 'incoming'],
            ...request.samplingPolicy,
          },
        ),
        edgePolicy: Map<String, Object?>.unmodifiable(request.edgePolicy),
        motionBlurPolicy: Map<String, Object?>.unmodifiable(
          request.motionBlurPolicy,
        ),
      ),
    );
  }

  ProfessionalVideoTransitionCompositorSource? _buildSource({
    required String role,
    required String path,
    required TimelineClipData clip,
    required TimelineTime boundaryTime,
    required TimelineTime timelineDuration,
    required TimelineTimeRange timelineRange,
    required ProfessionalVideoTransitionSourceUriResolver sourceUriForAsset,
    required TimelineTime sourceStartTime,
    required List<ProfessionalVideoTransitionRenderPlanBuildIssue> issues,
  }) {
    final assetId = clip.assetId?.trim();
    if (assetId == null || assetId.isEmpty) {
      issues.add(
        ProfessionalVideoTransitionRenderPlanBuildIssue(
          code: '${role}_asset_id_missing',
          path: '$path.assetId',
          message: 'The $role transition source must reference a real asset.',
        ),
      );
    }

    final sourceUri =
        assetId == null || assetId.isEmpty ? null : sourceUriForAsset(assetId);
    if (sourceUri == null || sourceUri.trim().isEmpty) {
      issues.add(
        ProfessionalVideoTransitionRenderPlanBuildIssue(
          code: '${role}_source_uri_missing',
          path: '$path.sourceUri',
          message:
              'The $role transition source must carry a concrete sourceUri.',
        ),
      );
    }

    if (clip.hasSpeedOverride) {
      issues.add(
        ProfessionalVideoTransitionRenderPlanBuildIssue(
          code: '${role}_playback_rate_unsupported',
          path: '$path.playbackRate',
          message:
              'Professional transition render plans do not support speed-overridden clips until source-rate mapping is part of the compositor source contract.',
        ),
      );
    }

    if (timelineDuration <= TimelineTime.zero) {
      issues.add(
        ProfessionalVideoTransitionRenderPlanBuildIssue(
          code: '${role}_timeline_window_invalid',
          path: '$path.timelineRange',
          message: 'The $role transition timeline window must be positive.',
        ),
      );
    }
    if (clip.durationTime < timelineDuration) {
      issues.add(
        ProfessionalVideoTransitionRenderPlanBuildIssue(
          code: '${role}_visible_handle_too_short',
          path: '$path.timelineRange',
          message:
              'The $role clip does not have enough visible timeline duration for this transition window.',
        ),
      );
    }
    if (clip.sourceDurationTime < timelineDuration) {
      issues.add(
        ProfessionalVideoTransitionRenderPlanBuildIssue(
          code: '${role}_source_handle_too_short',
          path: '$path.sourceRange',
          message:
              'The $role clip does not have enough real source duration for this transition window.',
        ),
      );
    }
    if (sourceStartTime < TimelineTime.zero ||
        sourceStartTime < clip.sourceStartTime ||
        sourceStartTime + timelineDuration > clip.sourceEndTime) {
      issues.add(
        ProfessionalVideoTransitionRenderPlanBuildIssue(
          code: '${role}_source_range_outside_clip',
          path: '$path.sourceRange',
          message:
              'The $role source sample range must stay inside the clip source range.',
        ),
      );
    }
    if (role == 'outgoing' && timelineRange.endExclusive < boundaryTime) {
      issues.add(
        ProfessionalVideoTransitionRenderPlanBuildIssue(
          code: 'outgoing_does_not_reach_boundary',
          path: '$path.timelineRange',
          message: 'The outgoing source must reach the transition boundary.',
        ),
      );
    }
    if (role == 'incoming' && timelineRange.start > boundaryTime) {
      issues.add(
        ProfessionalVideoTransitionRenderPlanBuildIssue(
          code: 'incoming_starts_after_boundary',
          path: '$path.timelineRange',
          message:
              'The incoming source must start at or before the transition boundary.',
        ),
      );
    }

    if (assetId == null ||
        assetId.isEmpty ||
        sourceUri == null ||
        sourceUri.trim().isEmpty ||
        issues.any((issue) => issue.path.startsWith(path))) {
      return null;
    }

    return ProfessionalVideoTransitionCompositorSource(
      clipId: clip.id,
      assetId: assetId,
      sourceUri: sourceUri.trim(),
      timelineRange: timelineRange,
      sourceStartTime: sourceStartTime,
      sourceDuration: timelineDuration,
    );
  }
}

const List<String> _requiredProfessionalCapabilities = <String>[
  'dualVideoSampling',
  'temporalMotionBlur',
  'mirrorEdgeTiling',
  'previewParity',
  'liveScrubParity',
  'playbackParity',
  'exportParity',
];
