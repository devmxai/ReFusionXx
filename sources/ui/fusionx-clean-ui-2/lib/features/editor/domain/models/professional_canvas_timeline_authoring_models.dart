import 'package:flutter/foundation.dart';

import '../../presentation/models/timeline_time.dart';
import 'professional_motion_animation_models.dart';
import 'professional_motion_models.dart';

enum CanvasTimelineAuthoringIssueCode {
  emptyRange,
  unsupportedTarget,
  nonAnimatableProperty,
  valueKindMismatch,
  missingChannel,
  missingKeyframe,
}

@immutable
class CanvasTimelineAuthoringIssue {
  const CanvasTimelineAuthoringIssue({
    required this.code,
    required this.message,
    this.channelId,
    this.keyframeId,
    this.propertyId,
  });

  final CanvasTimelineAuthoringIssueCode code;
  final String message;
  final String? channelId;
  final String? keyframeId;
  final String? propertyId;
}

@immutable
class CanvasTimelineAuthoringResult {
  CanvasTimelineAuthoringResult({
    required List<MotionPropertyChannelModel> channels,
    List<CanvasTimelineAuthoringIssue> issues =
        const <CanvasTimelineAuthoringIssue>[],
  })  : channels = List.unmodifiable(channels),
        issues = List.unmodifiable(issues);

  final List<MotionPropertyChannelModel> channels;
  final List<CanvasTimelineAuthoringIssue> issues;

  bool get hasIssues => issues.isNotEmpty;
}

@immutable
class CanvasTimelineSetPropertyRequest {
  CanvasTimelineSetPropertyRequest({
    required List<MotionPropertyChannelModel> channels,
    required this.target,
    required this.activeRange,
    required this.definition,
    required this.value,
    this.time = TimelineTime.zero,
    this.autoKey = false,
    this.interpolation = const MotionInterpolationSpec.linear(),
  }) : channels = List.unmodifiable(channels);

  final List<MotionPropertyChannelModel> channels;
  final MotionPropertyTarget target;
  final TimelineTimeRange activeRange;
  final MotionPropertyDefinition definition;
  final MotionPropertyValue value;
  final TimelineTime time;
  final bool autoKey;
  final MotionInterpolationSpec interpolation;
}

@immutable
class CanvasTimelineKeyframeRequest {
  CanvasTimelineKeyframeRequest({
    required List<MotionPropertyChannelModel> channels,
    required this.target,
    required this.activeRange,
    required this.definition,
    required this.time,
    required this.value,
    this.interpolation = const MotionInterpolationSpec.linear(),
  }) : channels = List.unmodifiable(channels);

  final List<MotionPropertyChannelModel> channels;
  final MotionPropertyTarget target;
  final TimelineTimeRange activeRange;
  final MotionPropertyDefinition definition;
  final TimelineTime time;
  final MotionPropertyValue value;
  final MotionInterpolationSpec interpolation;
}

@immutable
class CanvasTimelineKeyframeValueRequest {
  CanvasTimelineKeyframeValueRequest({
    required List<MotionPropertyChannelModel> channels,
    required this.channelId,
    required this.keyframeId,
    required this.value,
  }) : channels = List.unmodifiable(channels);

  final List<MotionPropertyChannelModel> channels;
  final String channelId;
  final String keyframeId;
  final MotionPropertyValue value;
}

@immutable
class CanvasTimelineMoveKeyframeRequest {
  CanvasTimelineMoveKeyframeRequest({
    required List<MotionPropertyChannelModel> channels,
    required this.channelId,
    required this.keyframeId,
    required this.activeRange,
    required this.time,
  }) : channels = List.unmodifiable(channels);

  final List<MotionPropertyChannelModel> channels;
  final String channelId;
  final String keyframeId;
  final TimelineTimeRange activeRange;
  final TimelineTime time;
}

@immutable
class CanvasTimelineDeleteKeyframeRequest {
  CanvasTimelineDeleteKeyframeRequest({
    required List<MotionPropertyChannelModel> channels,
    required this.channelId,
    required this.keyframeId,
  }) : channels = List.unmodifiable(channels);

  final List<MotionPropertyChannelModel> channels;
  final String channelId;
  final String keyframeId;
}

class ProfessionalCanvasTimelineAuthoringService {
  const ProfessionalCanvasTimelineAuthoringService();

  CanvasTimelineAuthoringResult setProperty(
    CanvasTimelineSetPropertyRequest request,
  ) {
    final issue = _validateEdit(
      target: request.target,
      activeRange: request.activeRange,
      definition: request.definition,
      value: request.value,
    );
    if (issue != null) {
      return CanvasTimelineAuthoringResult(
        channels: request.channels,
        issues: <CanvasTimelineAuthoringIssue>[issue],
      );
    }
    if (request.autoKey) {
      return addKeyframe(
        CanvasTimelineKeyframeRequest(
          channels: request.channels,
          target: request.target,
          activeRange: request.activeRange,
          definition: request.definition,
          time: request.time,
          value: request.value,
          interpolation: request.interpolation,
        ),
      );
    }

    final channelIndex = _findChannelIndex(
      request.channels,
      target: request.target,
      definition: request.definition,
    );
    final channel = channelIndex >= 0
        ? request.channels[channelIndex]
        : _newChannel(
            target: request.target,
            activeRange: request.activeRange,
            definition: request.definition,
          );
    final nextChannel = channel.copyWith(
      activeRange: request.activeRange,
      baseValue: request.value,
    );
    return CanvasTimelineAuthoringResult(
      channels: _replaceOrAppend(
        request.channels,
        channelIndex: channelIndex,
        channel: nextChannel,
      ),
    );
  }

  CanvasTimelineAuthoringResult addKeyframe(
    CanvasTimelineKeyframeRequest request,
  ) {
    final issue = _validateEdit(
      target: request.target,
      activeRange: request.activeRange,
      definition: request.definition,
      value: request.value,
    );
    if (issue != null) {
      return CanvasTimelineAuthoringResult(
        channels: request.channels,
        issues: <CanvasTimelineAuthoringIssue>[issue],
      );
    }

    final channelIndex = _findChannelIndex(
      request.channels,
      target: request.target,
      definition: request.definition,
    );
    final channel = channelIndex >= 0
        ? request.channels[channelIndex]
        : _newChannel(
            target: request.target,
            activeRange: request.activeRange,
            definition: request.definition,
          );
    final time = _clampKeyframeTime(request.time, request.activeRange);
    final nextKeyframe = MotionKeyframeModel(
      id: _keyframeIdFor(channelId: channel.id, time: time),
      channelId: channel.id,
      time: time,
      value: request.value,
      interpolationToNext: request.interpolation,
    );
    final nextChannel = channel.copyWith(
      activeRange: request.activeRange,
      keyframes: _normalizedKeyframes(
        <MotionKeyframeModel>[...channel.keyframes, nextKeyframe],
      ),
    );
    return CanvasTimelineAuthoringResult(
      channels: _replaceOrAppend(
        request.channels,
        channelIndex: channelIndex,
        channel: nextChannel,
      ),
    );
  }

  CanvasTimelineAuthoringResult setKeyframeValue(
    CanvasTimelineKeyframeValueRequest request,
  ) {
    final channelIndex = request.channels.indexWhere(
      (channel) => channel.id == request.channelId,
    );
    if (channelIndex < 0) {
      return CanvasTimelineAuthoringResult(
        channels: request.channels,
        issues: <CanvasTimelineAuthoringIssue>[
          CanvasTimelineAuthoringIssue(
            code: CanvasTimelineAuthoringIssueCode.missingChannel,
            message: 'Channel `${request.channelId}` was not found.',
            channelId: request.channelId,
          ),
        ],
      );
    }
    final channel = request.channels[channelIndex];
    if (request.value.kind != channel.definition.valueKind) {
      return CanvasTimelineAuthoringResult(
        channels: request.channels,
        issues: <CanvasTimelineAuthoringIssue>[
          CanvasTimelineAuthoringIssue(
            code: CanvasTimelineAuthoringIssueCode.valueKindMismatch,
            message: 'Value kind does not match `${channel.definition.id}`.',
            channelId: request.channelId,
            keyframeId: request.keyframeId,
            propertyId: channel.definition.id,
          ),
        ],
      );
    }
    final keyframeIndex = channel.keyframes.indexWhere(
      (keyframe) => keyframe.id == request.keyframeId,
    );
    if (keyframeIndex < 0) {
      return CanvasTimelineAuthoringResult(
        channels: request.channels,
        issues: <CanvasTimelineAuthoringIssue>[
          CanvasTimelineAuthoringIssue(
            code: CanvasTimelineAuthoringIssueCode.missingKeyframe,
            message: 'Keyframe `${request.keyframeId}` was not found.',
            channelId: request.channelId,
            keyframeId: request.keyframeId,
            propertyId: channel.definition.id,
          ),
        ],
      );
    }
    final nextKeyframes = List<MotionKeyframeModel>.from(channel.keyframes)
      ..[keyframeIndex] = channel.keyframes[keyframeIndex].copyWith(
        value: request.value,
      );
    return CanvasTimelineAuthoringResult(
      channels: _replaceOrAppend(
        request.channels,
        channelIndex: channelIndex,
        channel: channel.copyWith(keyframes: nextKeyframes),
      ),
    );
  }

  CanvasTimelineAuthoringResult moveKeyframe(
    CanvasTimelineMoveKeyframeRequest request,
  ) {
    if (request.activeRange.endExclusive <= request.activeRange.start) {
      return CanvasTimelineAuthoringResult(
        channels: request.channels,
        issues: const <CanvasTimelineAuthoringIssue>[
          CanvasTimelineAuthoringIssue(
            code: CanvasTimelineAuthoringIssueCode.emptyRange,
            message: 'Cannot move a keyframe inside an empty active range.',
          ),
        ],
      );
    }
    final channelIndex = request.channels.indexWhere(
      (channel) => channel.id == request.channelId,
    );
    if (channelIndex < 0) {
      return CanvasTimelineAuthoringResult(
        channels: request.channels,
        issues: <CanvasTimelineAuthoringIssue>[
          CanvasTimelineAuthoringIssue(
            code: CanvasTimelineAuthoringIssueCode.missingChannel,
            message: 'Channel `${request.channelId}` was not found.',
            channelId: request.channelId,
          ),
        ],
      );
    }
    final channel = request.channels[channelIndex];
    final keyframeIndex = channel.keyframes.indexWhere(
      (keyframe) => keyframe.id == request.keyframeId,
    );
    if (keyframeIndex < 0) {
      return CanvasTimelineAuthoringResult(
        channels: request.channels,
        issues: <CanvasTimelineAuthoringIssue>[
          CanvasTimelineAuthoringIssue(
            code: CanvasTimelineAuthoringIssueCode.missingKeyframe,
            message: 'Keyframe `${request.keyframeId}` was not found.',
            channelId: request.channelId,
            keyframeId: request.keyframeId,
            propertyId: channel.definition.id,
          ),
        ],
      );
    }
    final moved = channel.keyframes[keyframeIndex].copyWith(
      time: _clampKeyframeTime(request.time, request.activeRange),
    );
    final remaining = <MotionKeyframeModel>[
      for (final keyframe in channel.keyframes)
        if (keyframe.id != request.keyframeId) keyframe,
      moved,
    ];
    return CanvasTimelineAuthoringResult(
      channels: _replaceOrAppend(
        request.channels,
        channelIndex: channelIndex,
        channel: channel.copyWith(
          activeRange: request.activeRange,
          keyframes: _normalizedKeyframes(remaining),
        ),
      ),
    );
  }

  CanvasTimelineAuthoringResult deleteKeyframe(
    CanvasTimelineDeleteKeyframeRequest request,
  ) {
    final channelIndex = request.channels.indexWhere(
      (channel) => channel.id == request.channelId,
    );
    if (channelIndex < 0) {
      return CanvasTimelineAuthoringResult(
        channels: request.channels,
        issues: <CanvasTimelineAuthoringIssue>[
          CanvasTimelineAuthoringIssue(
            code: CanvasTimelineAuthoringIssueCode.missingChannel,
            message: 'Channel `${request.channelId}` was not found.',
            channelId: request.channelId,
          ),
        ],
      );
    }
    final channel = request.channels[channelIndex];
    final nextKeyframes = channel.keyframes
        .where((keyframe) => keyframe.id != request.keyframeId)
        .toList(growable: false);
    if (nextKeyframes.length == channel.keyframes.length) {
      return CanvasTimelineAuthoringResult(
        channels: request.channels,
        issues: <CanvasTimelineAuthoringIssue>[
          CanvasTimelineAuthoringIssue(
            code: CanvasTimelineAuthoringIssueCode.missingKeyframe,
            message: 'Keyframe `${request.keyframeId}` was not found.',
            channelId: request.channelId,
            keyframeId: request.keyframeId,
            propertyId: channel.definition.id,
          ),
        ],
      );
    }
    return CanvasTimelineAuthoringResult(
      channels: _replaceOrAppend(
        request.channels,
        channelIndex: channelIndex,
        channel: channel.copyWith(keyframes: nextKeyframes),
      ),
    );
  }

  CanvasTimelineAuthoringIssue? _validateEdit({
    required MotionPropertyTarget target,
    required TimelineTimeRange activeRange,
    required MotionPropertyDefinition definition,
    required MotionPropertyValue value,
  }) {
    if (activeRange.endExclusive <= activeRange.start) {
      return CanvasTimelineAuthoringIssue(
        code: CanvasTimelineAuthoringIssueCode.emptyRange,
        message: 'Cannot author `${definition.id}` inside an empty range.',
        propertyId: definition.id,
      );
    }
    if (!definition.isAnimatable) {
      return CanvasTimelineAuthoringIssue(
        code: CanvasTimelineAuthoringIssueCode.nonAnimatableProperty,
        message: 'Property `${definition.id}` is not animatable.',
        propertyId: definition.id,
      );
    }
    if (!definition.supportedTargets.contains(target.kind)) {
      return CanvasTimelineAuthoringIssue(
        code: CanvasTimelineAuthoringIssueCode.unsupportedTarget,
        message: 'Property `${definition.id}` cannot target `${target.kind}`.',
        propertyId: definition.id,
      );
    }
    if (value.kind != definition.valueKind) {
      return CanvasTimelineAuthoringIssue(
        code: CanvasTimelineAuthoringIssueCode.valueKindMismatch,
        message: 'Value kind does not match `${definition.id}`.',
        propertyId: definition.id,
      );
    }
    return null;
  }

  MotionPropertyChannelModel _newChannel({
    required MotionPropertyTarget target,
    required TimelineTimeRange activeRange,
    required MotionPropertyDefinition definition,
  }) {
    return MotionPropertyChannelModel(
      id: _channelIdFor(target: target, definition: definition),
      target: target,
      definition: definition,
      activeRange: activeRange,
    );
  }

  int _findChannelIndex(
    List<MotionPropertyChannelModel> channels, {
    required MotionPropertyTarget target,
    required MotionPropertyDefinition definition,
  }) {
    return channels.indexWhere(
      (channel) =>
          channel.target.kind == target.kind &&
          channel.target.targetId == target.targetId &&
          channel.definition.id == definition.id,
    );
  }

  List<MotionPropertyChannelModel> _replaceOrAppend(
    List<MotionPropertyChannelModel> channels, {
    required int channelIndex,
    required MotionPropertyChannelModel channel,
  }) {
    if (channelIndex < 0) {
      return List<MotionPropertyChannelModel>.unmodifiable(
        <MotionPropertyChannelModel>[...channels, channel],
      );
    }
    final next = List<MotionPropertyChannelModel>.from(channels)
      ..[channelIndex] = channel;
    return List<MotionPropertyChannelModel>.unmodifiable(next);
  }

  List<MotionKeyframeModel> _normalizedKeyframes(
    Iterable<MotionKeyframeModel> keyframes,
  ) {
    final byTick = <int, MotionKeyframeModel>{};
    for (final keyframe in keyframes) {
      byTick[keyframe.time.inProjectTicks] = keyframe;
    }
    final sortedTicks = byTick.keys.toList()..sort();
    return List<MotionKeyframeModel>.unmodifiable(
      sortedTicks.map((tick) => byTick[tick]!),
    );
  }

  TimelineTime _clampKeyframeTime(
    TimelineTime time,
    TimelineTimeRange activeRange,
  ) {
    final endTick = activeRange.endExclusive.inProjectTicks;
    final startTick = activeRange.start.inProjectTicks;
    final upperTick = endTick > startTick ? endTick - 1 : startTick;
    final upper = TimelineTime.fromProjectTicks(upperTick);
    return time.clamp(activeRange.start, upper);
  }

  String _channelIdFor({
    required MotionPropertyTarget target,
    required MotionPropertyDefinition definition,
  }) {
    return 'canvasTimeline.${target.canonicalAddress}.${definition.id}';
  }

  String _keyframeIdFor({
    required String channelId,
    required TimelineTime time,
  }) {
    return '$channelId.${time.inProjectTicks}';
  }
}
