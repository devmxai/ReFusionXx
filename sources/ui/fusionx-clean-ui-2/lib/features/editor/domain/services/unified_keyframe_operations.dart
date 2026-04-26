import 'package:flutter/foundation.dart';

import '../../presentation/models/timeline_time.dart';
import '../models/professional_canvas_timeline_authoring_models.dart';
import '../models/professional_motion_animation_models.dart';

@immutable
class UnifiedKeyframeReference {
  const UnifiedKeyframeReference({
    required this.channelId,
    required this.keyframeId,
  });

  final String channelId;
  final String keyframeId;
}

@immutable
class UnifiedKeyframeGroupMoveRequest {
  UnifiedKeyframeGroupMoveRequest({
    required List<MotionPropertyChannelModel> channels,
    required List<UnifiedKeyframeReference> keyframes,
    required this.activeRange,
    required this.time,
  })  : channels = List.unmodifiable(channels),
        keyframes = List.unmodifiable(keyframes);

  final List<MotionPropertyChannelModel> channels;
  final List<UnifiedKeyframeReference> keyframes;
  final TimelineTimeRange activeRange;
  final TimelineTime time;
}

class UnifiedKeyframeOperationService {
  const UnifiedKeyframeOperationService({
    this.canvasAuthoring = const ProfessionalCanvasTimelineAuthoringService(),
  });

  final ProfessionalCanvasTimelineAuthoringService canvasAuthoring;

  CanvasTimelineAuthoringResult addKeyframe(
    CanvasTimelineKeyframeRequest request,
  ) {
    return canvasAuthoring.addKeyframe(request);
  }

  CanvasTimelineAuthoringResult moveKeyframe(
    CanvasTimelineMoveKeyframeRequest request,
  ) {
    return canvasAuthoring.moveKeyframe(request);
  }

  CanvasTimelineAuthoringResult setKeyframeValue(
    CanvasTimelineKeyframeValueRequest request,
  ) {
    return canvasAuthoring.setKeyframeValue(request);
  }

  CanvasTimelineAuthoringResult setKeyframeInterpolation(
    CanvasTimelineKeyframeInterpolationRequest request,
  ) {
    return canvasAuthoring.setKeyframeInterpolation(request);
  }

  CanvasTimelineAuthoringResult deleteKeyframe(
    CanvasTimelineDeleteKeyframeRequest request,
  ) {
    return canvasAuthoring.deleteKeyframe(request);
  }

  CanvasTimelineAuthoringResult moveKeyframeGroup(
    UnifiedKeyframeGroupMoveRequest request,
  ) {
    if (request.keyframes.isEmpty) {
      return CanvasTimelineAuthoringResult(
        channels: request.channels,
        issues: const <CanvasTimelineAuthoringIssue>[
          CanvasTimelineAuthoringIssue(
            code: CanvasTimelineAuthoringIssueCode.missingKeyframe,
            message: 'No keyframes were selected for the group move.',
          ),
        ],
      );
    }

    var nextChannels = request.channels;
    for (final keyframe in request.keyframes) {
      final result = canvasAuthoring.moveKeyframe(
        CanvasTimelineMoveKeyframeRequest(
          channels: nextChannels,
          channelId: keyframe.channelId,
          keyframeId: keyframe.keyframeId,
          activeRange: request.activeRange,
          time: request.time,
        ),
      );
      if (result.hasIssues) {
        return CanvasTimelineAuthoringResult(
          channels: request.channels,
          issues: result.issues,
        );
      }
      nextChannels = result.channels;
    }

    return CanvasTimelineAuthoringResult(channels: nextChannels);
  }
}
