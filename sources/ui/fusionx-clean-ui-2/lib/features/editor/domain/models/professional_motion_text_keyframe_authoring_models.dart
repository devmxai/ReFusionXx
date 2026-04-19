import 'package:flutter/foundation.dart';

import '../../presentation/models/timeline_time.dart';
import 'professional_motion_animation_models.dart';
import 'professional_motion_models.dart';

@immutable
class TextMotionScalarKeyframeAuthoringRequest {
  TextMotionScalarKeyframeAuthoringRequest({
    required List<MotionPropertyChannelModel> channels,
    required this.target,
    required this.activeRange,
    required this.time,
    required Map<MotionPropertyDefinition, double> scalarValues,
    Map<String, double> baseScalarValues = const <String, double>{},
  })  : channels = List.unmodifiable(channels),
        scalarValues = Map.unmodifiable(scalarValues),
        baseScalarValues = Map.unmodifiable(baseScalarValues);

  final List<MotionPropertyChannelModel> channels;
  final MotionPropertyTarget target;
  final TimelineTimeRange activeRange;
  final TimelineTime time;
  final Map<MotionPropertyDefinition, double> scalarValues;
  final Map<String, double> baseScalarValues;
}

@immutable
class TextMotionChannelRetimingRequest {
  TextMotionChannelRetimingRequest({
    required List<MotionPropertyChannelModel> channels,
    required this.targetId,
    required this.previousRange,
    required this.nextRange,
  }) : channels = List.unmodifiable(channels);

  final List<MotionPropertyChannelModel> channels;
  final String targetId;
  final TimelineTimeRange previousRange;
  final TimelineTimeRange nextRange;
}

@immutable
class TextMotionChannelDuplicationRequest {
  TextMotionChannelDuplicationRequest({
    required List<MotionPropertyChannelModel> channels,
    required this.sourceTargetId,
    required this.nextTarget,
    required this.sourceRange,
    required this.nextRange,
  }) : channels = List.unmodifiable(channels);

  final List<MotionPropertyChannelModel> channels;
  final String sourceTargetId;
  final MotionPropertyTarget nextTarget;
  final TimelineTimeRange sourceRange;
  final TimelineTimeRange nextRange;
}

class TextMotionKeyframeAuthoringService {
  const TextMotionKeyframeAuthoringService();

  List<MotionPropertyChannelModel> setScalarKeyframes(
    TextMotionScalarKeyframeAuthoringRequest request,
  ) {
    if (request.scalarValues.isEmpty ||
        request.activeRange.endExclusive <= request.activeRange.start) {
      return request.channels;
    }

    var nextChannels = List<MotionPropertyChannelModel>.from(request.channels);
    for (final entry in request.scalarValues.entries) {
      final definition = entry.key;
      if (definition.valueKind != MotionPropertyValueKind.scalar) {
        continue;
      }
      nextChannels = _upsertScalarChannel(
        channels: nextChannels,
        target: request.target,
        activeRange: request.activeRange,
        requestedTime: request.time,
        definition: definition,
        nextValue: entry.value,
        baseValue: request.baseScalarValues[definition.id] ??
            _scalarDefaultFor(definition),
      );
    }
    return List<MotionPropertyChannelModel>.unmodifiable(nextChannels);
  }

  List<MotionPropertyChannelModel> removeChannelsForTarget({
    required List<MotionPropertyChannelModel> channels,
    required String targetId,
  }) {
    return List<MotionPropertyChannelModel>.unmodifiable(
      channels.where((channel) => channel.target.targetId != targetId),
    );
  }

  List<MotionPropertyChannelModel> retimeChannelsForTarget(
    TextMotionChannelRetimingRequest request,
  ) {
    if (request.nextRange.endExclusive <= request.nextRange.start) {
      return removeChannelsForTarget(
        channels: request.channels,
        targetId: request.targetId,
      );
    }
    final delta = request.nextRange.start - request.previousRange.start;
    return List<MotionPropertyChannelModel>.unmodifiable(
      request.channels.map((channel) {
        if (channel.target.targetId != request.targetId) {
          return channel;
        }
        return channel.copyWith(
          activeRange: request.nextRange,
          keyframes: _normalizedKeyframes(
            channel.keyframes.map((keyframe) {
              return keyframe.copyWith(
                time: _clampKeyframeTime(
                  keyframe.time + delta,
                  request.nextRange,
                ),
              );
            }),
          ),
        );
      }),
    );
  }

  List<MotionPropertyChannelModel> duplicateChannelsForTarget(
    TextMotionChannelDuplicationRequest request,
  ) {
    if (request.nextRange.endExclusive <= request.nextRange.start) {
      return request.channels;
    }
    final duplicatedChannels = <MotionPropertyChannelModel>[];
    final delta = request.nextRange.start - request.sourceRange.start;
    for (final channel in request.channels) {
      if (channel.target.targetId != request.sourceTargetId) {
        continue;
      }
      final nextChannelId = _channelIdFor(
        targetId: request.nextTarget.targetId,
        definition: channel.definition,
      );
      duplicatedChannels.add(
        MotionPropertyChannelModel(
          id: nextChannelId,
          target: request.nextTarget,
          definition: channel.definition,
          activeRange: request.nextRange,
          baseValue: channel.baseValue,
          beforeStart: channel.beforeStart,
          afterEnd: channel.afterEnd,
          keyframes: _normalizedKeyframes(
            channel.keyframes.map((keyframe) {
              final nextTime = _clampKeyframeTime(
                keyframe.time + delta,
                request.nextRange,
              );
              return MotionKeyframeModel(
                id: _keyframeIdFor(
                  channelId: nextChannelId,
                  time: nextTime,
                ),
                channelId: nextChannelId,
                time: nextTime,
                value: keyframe.value,
                interpolationToNext: keyframe.interpolationToNext,
              );
            }),
          ),
        ),
      );
    }
    return List<MotionPropertyChannelModel>.unmodifiable(
      <MotionPropertyChannelModel>[
        ...request.channels,
        ...duplicatedChannels,
      ],
    );
  }

  List<MotionPropertyChannelModel> _upsertScalarChannel({
    required List<MotionPropertyChannelModel> channels,
    required MotionPropertyTarget target,
    required TimelineTimeRange activeRange,
    required TimelineTime requestedTime,
    required MotionPropertyDefinition definition,
    required double nextValue,
    required double baseValue,
  }) {
    final channelIndex = channels.indexWhere(
      (channel) =>
          channel.target.kind == target.kind &&
          channel.target.targetId == target.targetId &&
          channel.definition.id == definition.id,
    );
    final channelId = channelIndex >= 0
        ? channels[channelIndex].id
        : _channelIdFor(targetId: target.targetId, definition: definition);
    final keyframeTime = _clampKeyframeTime(requestedTime, activeRange);
    final keyframes = <MotionKeyframeModel>[
      if (channelIndex >= 0) ...channels[channelIndex].keyframes,
    ];

    if (keyframes.isEmpty &&
        keyframeTime > activeRange.start &&
        baseValue != nextValue) {
      keyframes.add(
        MotionKeyframeModel(
          id: _keyframeIdFor(channelId: channelId, time: activeRange.start),
          channelId: channelId,
          time: activeRange.start,
          value: MotionPropertyValue.scalar(baseValue),
          interpolationToNext: const MotionInterpolationSpec.easeInOut(),
        ),
      );
    }

    keyframes.add(
      MotionKeyframeModel(
        id: _keyframeIdFor(channelId: channelId, time: keyframeTime),
        channelId: channelId,
        time: keyframeTime,
        value: MotionPropertyValue.scalar(nextValue),
        interpolationToNext: const MotionInterpolationSpec.easeInOut(),
      ),
    );

    final nextChannel = MotionPropertyChannelModel(
      id: channelId,
      target: target,
      definition: definition,
      activeRange: activeRange,
      baseValue: MotionPropertyValue.scalar(baseValue),
      beforeStart: channelIndex >= 0
          ? channels[channelIndex].beforeStart
          : MotionChannelExtrapolationMode.clamp,
      afterEnd: channelIndex >= 0
          ? channels[channelIndex].afterEnd
          : MotionChannelExtrapolationMode.clamp,
      keyframes: _normalizedKeyframes(keyframes),
    );

    if (channelIndex < 0) {
      return List<MotionPropertyChannelModel>.unmodifiable(
        <MotionPropertyChannelModel>[...channels, nextChannel],
      );
    }
    final updated = List<MotionPropertyChannelModel>.from(channels)
      ..[channelIndex] = nextChannel;
    return List<MotionPropertyChannelModel>.unmodifiable(updated);
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
    if (activeRange.endExclusive <= activeRange.start) {
      return activeRange.start;
    }
    final endTick = activeRange.endExclusive.inProjectTicks;
    final startTick = activeRange.start.inProjectTicks;
    final upperTick = endTick > startTick ? endTick - 1 : startTick;
    final upper = TimelineTime.fromProjectTicks(upperTick);
    return time.clamp(activeRange.start, upper);
  }

  String _channelIdFor({
    required String targetId,
    required MotionPropertyDefinition definition,
  }) {
    return 'manual.$targetId.${definition.id}';
  }

  String _keyframeIdFor({
    required String channelId,
    required TimelineTime time,
  }) {
    return '$channelId.${time.inProjectTicks}';
  }

  double _scalarDefaultFor(MotionPropertyDefinition definition) {
    final value = definition.defaultValue;
    if (value.kind == MotionPropertyValueKind.scalar) {
      return value.rawValue as double;
    }
    return 0;
  }
}
