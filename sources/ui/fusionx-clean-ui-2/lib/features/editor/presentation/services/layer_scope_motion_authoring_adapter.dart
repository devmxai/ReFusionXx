import 'package:flutter/foundation.dart';

import '../../domain/models/professional_canvas_timeline_authoring_models.dart';
import '../../domain/models/professional_motion_animation_models.dart';
import '../../domain/models/professional_motion_models.dart';
import '../../domain/services/unified_keyframe_operations.dart';
import '../models/timeline_mock_models.dart';
import '../models/timeline_time.dart';
import 'layer_scope_motion_projection_adapter.dart';

enum LayerScopeMotionAuthoringIssueCode {
  operationIssue,
  projectionIssue,
}

@immutable
class LayerScopeMotionAuthoringIssue {
  const LayerScopeMotionAuthoringIssue({
    required this.code,
    required this.message,
    this.channelId,
    this.keyframeId,
    this.propertyId,
  });

  final LayerScopeMotionAuthoringIssueCode code;
  final String message;
  final String? channelId;
  final String? keyframeId;
  final String? propertyId;
}

@immutable
class LayerScopeMotionAuthoringTarget {
  const LayerScopeMotionAuthoringTarget({
    required this.elementId,
    required this.targetClipId,
    required this.motionTarget,
    required this.activeRange,
    required this.projectionWindow,
  });

  final String elementId;
  final String targetClipId;
  final MotionPropertyTarget motionTarget;
  final TimelineTimeRange activeRange;
  final TimelineTimeRange projectionWindow;
}

@immutable
class LayerScopeMotionAuthoringResult {
  LayerScopeMotionAuthoringResult({
    required List<MotionPropertyChannelModel> channels,
    List<TimelineAnimationLaneData> lanes = const <TimelineAnimationLaneData>[],
    List<LayerScopeMotionAuthoringIssue> issues =
        const <LayerScopeMotionAuthoringIssue>[],
  })  : channels = List.unmodifiable(channels),
        lanes = List.unmodifiable(lanes),
        issues = List.unmodifiable(issues);

  final List<MotionPropertyChannelModel> channels;
  final List<TimelineAnimationLaneData> lanes;
  final List<LayerScopeMotionAuthoringIssue> issues;

  bool get hasIssues => issues.isNotEmpty;
  bool get canApply => issues.isEmpty;
}

class LayerScopeMotionAuthoringAdapter {
  const LayerScopeMotionAuthoringAdapter({
    this.operations = const UnifiedKeyframeOperationService(),
    this.projection = const LayerScopeMotionProjectionAdapter(),
  });

  final UnifiedKeyframeOperationService operations;
  final LayerScopeMotionProjectionAdapter projection;

  LayerScopeMotionAuthoringResult projectOpacity({
    required List<MotionPropertyChannelModel> channels,
    required LayerScopeMotionAuthoringTarget target,
  }) {
    return _project(
      channels: channels,
      target: target,
    );
  }

  LayerScopeMotionAuthoringResult addOpacityKeyframe({
    required List<MotionPropertyChannelModel> channels,
    required LayerScopeMotionAuthoringTarget target,
    required TimelineTime time,
    required double percent,
  }) {
    final result = operations.addKeyframe(
      CanvasTimelineKeyframeRequest(
        channels: channels,
        target: target.motionTarget,
        activeRange: target.activeRange,
        definition: MotionPropertyCatalog.opacity,
        time: time,
        value: MotionPropertyValue.scalar(_opacityPercentToScalar(percent)),
      ),
    );
    return _fromOperationResult(result, target);
  }

  LayerScopeMotionAuthoringResult moveKeyframe({
    required List<MotionPropertyChannelModel> channels,
    required LayerScopeMotionAuthoringTarget target,
    required String channelId,
    required String keyframeId,
    required TimelineTime time,
  }) {
    final result = operations.moveKeyframe(
      CanvasTimelineMoveKeyframeRequest(
        channels: channels,
        channelId: channelId,
        keyframeId: keyframeId,
        activeRange: target.activeRange,
        time: time,
      ),
    );
    return _fromOperationResult(result, target);
  }

  LayerScopeMotionAuthoringResult setOpacityKeyframeValue({
    required List<MotionPropertyChannelModel> channels,
    required LayerScopeMotionAuthoringTarget target,
    required String channelId,
    required String keyframeId,
    required double percent,
  }) {
    final result = operations.setKeyframeValue(
      CanvasTimelineKeyframeValueRequest(
        channels: channels,
        channelId: channelId,
        keyframeId: keyframeId,
        value: MotionPropertyValue.scalar(_opacityPercentToScalar(percent)),
      ),
    );
    return _fromOperationResult(result, target);
  }

  LayerScopeMotionAuthoringResult deleteKeyframe({
    required List<MotionPropertyChannelModel> channels,
    required LayerScopeMotionAuthoringTarget target,
    required String channelId,
    required String keyframeId,
  }) {
    final result = operations.deleteKeyframe(
      CanvasTimelineDeleteKeyframeRequest(
        channels: channels,
        channelId: channelId,
        keyframeId: keyframeId,
      ),
    );
    return _fromOperationResult(result, target);
  }

  LayerScopeMotionAuthoringResult _fromOperationResult(
    CanvasTimelineAuthoringResult result,
    LayerScopeMotionAuthoringTarget target,
  ) {
    if (result.hasIssues) {
      return LayerScopeMotionAuthoringResult(
        channels: result.channels,
        issues: <LayerScopeMotionAuthoringIssue>[
          for (final issue in result.issues)
            LayerScopeMotionAuthoringIssue(
              code: LayerScopeMotionAuthoringIssueCode.operationIssue,
              message: issue.message,
              channelId: issue.channelId,
              keyframeId: issue.keyframeId,
              propertyId: issue.propertyId,
            ),
        ],
      );
    }
    return _project(
      channels: result.channels,
      target: target,
    );
  }

  LayerScopeMotionAuthoringResult _project({
    required List<MotionPropertyChannelModel> channels,
    required LayerScopeMotionAuthoringTarget target,
  }) {
    final projected = projection.projectElement(
      channels: channels,
      elementId: target.elementId,
      targetClipId: target.targetClipId,
      window: target.projectionWindow,
    );
    return LayerScopeMotionAuthoringResult(
      channels: channels,
      lanes: projected.lanes,
      issues: <LayerScopeMotionAuthoringIssue>[
        for (final issue in projected.issues)
          LayerScopeMotionAuthoringIssue(
            code: LayerScopeMotionAuthoringIssueCode.projectionIssue,
            message: issue.message,
            channelId: issue.channelId,
          ),
      ],
    );
  }

  double _opacityPercentToScalar(double percent) {
    return (percent / 100.0).clamp(0.0, 1.0).toDouble();
  }
}
