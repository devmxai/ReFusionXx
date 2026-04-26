import 'package:flutter/foundation.dart';

import '../../domain/models/motion_authoring_bundle_models.dart';
import '../../domain/models/professional_motion_models.dart';
import '../models/timeline_mock_models.dart';
import '../models/timeline_time.dart';
import 'unified_keyframe_timeline_projection.dart';

enum MotionAuthoringBundleTimelineAdapterIssueCode {
  projectionIssue,
}

@immutable
class MotionAuthoringBundleTimelineAdapterIssue {
  const MotionAuthoringBundleTimelineAdapterIssue({
    required this.code,
    required this.message,
    required this.channelId,
    required this.targetId,
  });

  final MotionAuthoringBundleTimelineAdapterIssueCode code;
  final String message;
  final String channelId;
  final String targetId;
}

@immutable
class MotionAuthoringBundleTimelineAdapterResult {
  MotionAuthoringBundleTimelineAdapterResult({
    List<TimelineAnimationLaneData> lanes = const <TimelineAnimationLaneData>[],
    List<MotionAuthoringBundleTimelineAdapterIssue> issues =
        const <MotionAuthoringBundleTimelineAdapterIssue>[],
  })  : lanes = List.unmodifiable(lanes),
        issues = List.unmodifiable(issues);

  final List<TimelineAnimationLaneData> lanes;
  final List<MotionAuthoringBundleTimelineAdapterIssue> issues;

  bool get hasIssues => issues.isNotEmpty;
}

class MotionAuthoringBundleTimelineAdapter {
  const MotionAuthoringBundleTimelineAdapter({
    this.projectionService = const UnifiedKeyframeTimelineProjectionService(),
  });

  final UnifiedKeyframeTimelineProjectionService projectionService;

  MotionAuthoringBundleTimelineAdapterResult projectBundle({
    required MotionAuthoringBundle bundle,
    required TimelineTimeRange window,
    Map<String, String> targetClipIdsByTargetId = const <String, String>{},
    Map<String, String> labelsByChannelId = const <String, String>{},
    Map<String, double> valueScalesByPropertyId = const <String, double>{},
  }) {
    final lanes = <TimelineAnimationLaneData>[];
    final issues = <MotionAuthoringBundleTimelineAdapterIssue>[];
    for (final channel in bundle.propertyChannels) {
      final targetClipId = targetClipIdsByTargetId[channel.target.targetId] ??
          channel.target.targetId;
      final result = projectionService.projectChannel(
        channel: channel,
        window: window,
        targetClipId: targetClipId,
        label: labelsByChannelId[channel.id],
        valueScale: valueScalesByPropertyId[channel.definition.id] ??
            _defaultValueScaleFor(channel.definition),
      );
      if (result.lane != null) {
        lanes.add(result.lane!);
      }
      for (final issue in result.issues) {
        issues.add(
          MotionAuthoringBundleTimelineAdapterIssue(
            code: MotionAuthoringBundleTimelineAdapterIssueCode.projectionIssue,
            message: issue.message,
            channelId: channel.id,
            targetId: channel.target.targetId,
          ),
        );
      }
    }

    return MotionAuthoringBundleTimelineAdapterResult(
      lanes: lanes,
      issues: issues,
    );
  }

  double _defaultValueScaleFor(MotionPropertyDefinition definition) {
    if (definition.id == MotionPropertyCatalog.opacity.id ||
        definition.id == MotionPropertyCatalog.scaleX.id ||
        definition.id == MotionPropertyCatalog.scaleY.id) {
      return 100.0;
    }
    return 1.0;
  }
}
