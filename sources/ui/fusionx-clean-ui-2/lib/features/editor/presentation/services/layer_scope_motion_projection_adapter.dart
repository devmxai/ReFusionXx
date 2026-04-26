import 'package:flutter/foundation.dart';

import '../../domain/models/professional_motion_animation_models.dart';
import '../../domain/models/professional_motion_models.dart';
import '../models/timeline_mock_models.dart';
import '../models/timeline_time.dart';
import 'unified_keyframe_timeline_projection.dart';

enum LayerScopeMotionProjectionIssueCode {
  projectionIssue,
}

@immutable
class LayerScopeMotionProjectionIssue {
  const LayerScopeMotionProjectionIssue({
    required this.code,
    required this.channelId,
    required this.targetId,
    required this.message,
  });

  final LayerScopeMotionProjectionIssueCode code;
  final String channelId;
  final String targetId;
  final String message;
}

@immutable
class LayerScopeMotionProjectionResult {
  LayerScopeMotionProjectionResult({
    List<TimelineAnimationLaneData> lanes = const <TimelineAnimationLaneData>[],
    List<LayerScopeMotionProjectionIssue> issues =
        const <LayerScopeMotionProjectionIssue>[],
  })  : lanes = List.unmodifiable(lanes),
        issues = List.unmodifiable(issues);

  final List<TimelineAnimationLaneData> lanes;
  final List<LayerScopeMotionProjectionIssue> issues;

  bool get hasIssues => issues.isNotEmpty;
}

class LayerScopeMotionProjectionAdapter {
  const LayerScopeMotionProjectionAdapter({
    this.projectionService = const UnifiedKeyframeTimelineProjectionService(),
  });

  static const Set<String> opacityOnlyPropertyIds = <String>{
    'visual.opacity',
  };

  final UnifiedKeyframeTimelineProjectionService projectionService;

  LayerScopeMotionProjectionResult projectElement({
    required Iterable<MotionPropertyChannelModel> channels,
    required String elementId,
    required String targetClipId,
    required TimelineTimeRange window,
    Set<String> propertyIds = opacityOnlyPropertyIds,
    Map<String, String> labelsByPropertyId = const <String, String>{},
    Map<String, double> valueScalesByPropertyId = const <String, double>{},
  }) {
    final lanes = <TimelineAnimationLaneData>[];
    final issues = <LayerScopeMotionProjectionIssue>[];
    for (final channel in channels) {
      if (!_targetsElement(channel.target, elementId)) {
        continue;
      }
      if (!propertyIds.contains(channel.definition.id)) {
        continue;
      }

      final result = projectionService.projectChannel(
        channel: channel,
        window: window,
        targetClipId: targetClipId,
        label: labelsByPropertyId[channel.definition.id] ??
            _defaultLabelForProperty(channel.definition),
        valueScale: valueScalesByPropertyId[channel.definition.id] ??
            _defaultValueScaleForProperty(channel.definition),
      );
      if (result.lane != null) {
        lanes.add(result.lane!);
      }
      for (final issue in result.issues) {
        issues.add(
          LayerScopeMotionProjectionIssue(
            code: LayerScopeMotionProjectionIssueCode.projectionIssue,
            channelId: channel.id,
            targetId: channel.target.targetId,
            message: issue.message,
          ),
        );
      }
    }

    return LayerScopeMotionProjectionResult(
      lanes: lanes,
      issues: issues,
    );
  }

  bool _targetsElement(MotionPropertyTarget target, String elementId) {
    return target.kind == MotionTargetKind.element &&
        (target.targetId == elementId || target.elementId == elementId);
  }

  String _defaultLabelForProperty(MotionPropertyDefinition definition) {
    switch (definition.id) {
      case 'visual.opacity':
        return 'Opacity';
      case 'transform.scale.x':
        return 'Scale X';
      case 'transform.scale.y':
        return 'Scale Y';
      default:
        final component = definition.path.component;
        if (component == null || component.isEmpty) {
          return definition.path.name;
        }
        return '${definition.path.name}.${definition.path.component}';
    }
  }

  double _defaultValueScaleForProperty(MotionPropertyDefinition definition) {
    switch (definition.id) {
      case 'visual.opacity':
      case 'transform.scale.x':
      case 'transform.scale.y':
        return 100;
      default:
        return 1;
    }
  }
}
