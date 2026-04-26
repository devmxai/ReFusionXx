import '../models/professional_canvas_timeline_authoring_models.dart';
import '../models/professional_motion_models.dart';
import '../../presentation/models/timeline_time.dart';
import 'unified_keyframe_operations.dart';

class CanvasTimelineUnifiedKeyframeAdapter {
  CanvasTimelineUnifiedKeyframeAdapter({
    UnifiedKeyframeOperations? operations,
  }) : operations = operations ??
            const UnifiedKeyframeOperations(
              channelIdFactory: _channelIdFor,
              keyframeIdFactory: _keyframeIdFor,
            );

  final UnifiedKeyframeOperations operations;

  CanvasTimelineAuthoringResult addKeyframe(
    CanvasTimelineKeyframeRequest request,
  ) {
    return _toCanvasResult(
      operations.addKeyframe(
        UnifiedKeyframeAddRequest(
          channels: request.channels,
          target: request.target,
          activeRange: request.activeRange,
          definition: request.definition,
          time: request.time,
          value: request.value,
          interpolation: request.interpolation,
        ),
      ),
    );
  }

  CanvasTimelineAuthoringResult moveKeyframe(
    CanvasTimelineMoveKeyframeRequest request,
  ) {
    return _toCanvasResult(
      operations.moveKeyframe(
        UnifiedKeyframeMoveRequest(
          channels: request.channels,
          channelId: request.channelId,
          keyframeId: request.keyframeId,
          time: request.time,
          activeRange: request.activeRange,
        ),
      ),
    );
  }

  CanvasTimelineAuthoringResult setKeyframeValue(
    CanvasTimelineKeyframeValueRequest request,
  ) {
    return _toCanvasResult(
      operations.setKeyframeValue(
        UnifiedKeyframeValueRequest(
          channels: request.channels,
          channelId: request.channelId,
          keyframeId: request.keyframeId,
          value: request.value,
        ),
      ),
    );
  }

  CanvasTimelineAuthoringResult setKeyframeInterpolation(
    CanvasTimelineKeyframeInterpolationRequest request,
  ) {
    return _toCanvasResult(
      operations.setKeyframeInterpolation(
        UnifiedKeyframeInterpolationRequest(
          channels: request.channels,
          channelId: request.channelId,
          keyframeId: request.keyframeId,
          interpolation: request.interpolation,
        ),
      ),
    );
  }

  CanvasTimelineAuthoringResult deleteKeyframe(
    CanvasTimelineDeleteKeyframeRequest request,
  ) {
    return _toCanvasResult(
      operations.deleteKeyframe(
        UnifiedKeyframeDeleteRequest(
          channels: request.channels,
          channelId: request.channelId,
          keyframeId: request.keyframeId,
        ),
      ),
    );
  }

  CanvasTimelineAuthoringResult _toCanvasResult(
    UnifiedKeyframeOperationResult result,
  ) {
    return CanvasTimelineAuthoringResult(
      channels: result.channels,
      issues: result.issues.map(_toCanvasIssue).toList(growable: false),
    );
  }

  CanvasTimelineAuthoringIssue _toCanvasIssue(UnifiedKeyframeIssue issue) {
    return CanvasTimelineAuthoringIssue(
      code: switch (issue.code) {
        UnifiedKeyframeIssueCode.emptyRange =>
          CanvasTimelineAuthoringIssueCode.emptyRange,
        UnifiedKeyframeIssueCode.missingChannel =>
          CanvasTimelineAuthoringIssueCode.missingChannel,
        UnifiedKeyframeIssueCode.missingKeyframe ||
        UnifiedKeyframeIssueCode.emptySelection ||
        UnifiedKeyframeIssueCode.keyframeTimeOutOfRange =>
          CanvasTimelineAuthoringIssueCode.missingKeyframe,
        UnifiedKeyframeIssueCode.nonAnimatableProperty =>
          CanvasTimelineAuthoringIssueCode.nonAnimatableProperty,
        UnifiedKeyframeIssueCode.unsupportedTarget =>
          CanvasTimelineAuthoringIssueCode.unsupportedTarget,
        UnifiedKeyframeIssueCode.valueKindMismatch =>
          CanvasTimelineAuthoringIssueCode.valueKindMismatch,
        UnifiedKeyframeIssueCode.keyframeTimeCollision =>
          CanvasTimelineAuthoringIssueCode.keyframeTimeCollision,
      },
      message: issue.message,
      channelId: issue.channelId,
      keyframeId: issue.keyframeId,
      propertyId: issue.propertyId,
    );
  }

  static String _channelIdFor({
    required MotionPropertyTarget target,
    required MotionPropertyDefinition definition,
  }) {
    return 'canvasTimeline.${target.canonicalAddress}.${definition.id}';
  }

  static String _keyframeIdFor({
    required String channelId,
    required TimelineTime time,
  }) {
    return '$channelId.${time.inProjectTicks}';
  }
}
