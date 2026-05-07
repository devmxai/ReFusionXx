import 'package:flutter/foundation.dart';

import '../../presentation/models/timeline_time.dart';
import '../models/professional_motion_animation_models.dart';
import '../models/professional_motion_models.dart';

typedef UnifiedKeyframeChannelIdFactory = String Function({
  required MotionPropertyTarget target,
  required MotionPropertyDefinition definition,
});

typedef UnifiedKeyframeIdFactory = String Function({
  required String channelId,
  required TimelineTime time,
});

enum UnifiedKeyframeIssueCode {
  emptyRange,
  emptySelection,
  missingChannel,
  missingKeyframe,
  nonAnimatableProperty,
  unsupportedTarget,
  valueKindMismatch,
  keyframeTimeCollision,
  keyframeTimeOutOfRange,
}

enum UnifiedKeyframeAddCollisionPolicy {
  updateExistingAtTime,
  reject,
}

enum UnifiedEasyEaseMode {
  easyEase,
  easyEaseIn,
  easyEaseOut,
  removeEase,
}

@immutable
class UnifiedKeyframeIssue {
  const UnifiedKeyframeIssue({
    required this.code,
    required this.message,
    this.channelId,
    this.keyframeId,
    this.propertyId,
  });

  final UnifiedKeyframeIssueCode code;
  final String message;
  final String? channelId;
  final String? keyframeId;
  final String? propertyId;
}

@immutable
class UnifiedKeyframeOperationResult {
  UnifiedKeyframeOperationResult({
    required List<MotionPropertyChannelModel> channels,
    List<UnifiedKeyframeIssue> issues = const <UnifiedKeyframeIssue>[],
    Set<String> selectedKeyframeIds = const <String>{},
    Set<String> changedKeyframeIds = const <String>{},
  })  : channels = List.unmodifiable(channels),
        issues = List.unmodifiable(issues),
        selectedKeyframeIds = Set.unmodifiable(selectedKeyframeIds),
        changedKeyframeIds = Set.unmodifiable(changedKeyframeIds);

  final List<MotionPropertyChannelModel> channels;
  final List<UnifiedKeyframeIssue> issues;
  final Set<String> selectedKeyframeIds;
  final Set<String> changedKeyframeIds;

  bool get hasIssues => issues.isNotEmpty;
}

@immutable
class UnifiedKeyframeAddRequest {
  UnifiedKeyframeAddRequest({
    required List<MotionPropertyChannelModel> channels,
    required this.target,
    required this.activeRange,
    required this.definition,
    required this.time,
    required this.value,
    this.interpolation = const MotionInterpolationSpec.linear(),
    this.collisionPolicy =
        UnifiedKeyframeAddCollisionPolicy.updateExistingAtTime,
  }) : channels = List.unmodifiable(channels);

  final List<MotionPropertyChannelModel> channels;
  final MotionPropertyTarget target;
  final TimelineTimeRange activeRange;
  final MotionPropertyDefinition definition;
  final TimelineTime time;
  final MotionPropertyValue value;
  final MotionInterpolationSpec interpolation;
  final UnifiedKeyframeAddCollisionPolicy collisionPolicy;
}

@immutable
class UnifiedKeyframeMoveRequest {
  UnifiedKeyframeMoveRequest({
    required List<MotionPropertyChannelModel> channels,
    required this.channelId,
    required this.keyframeId,
    required this.time,
    this.activeRange,
  }) : channels = List.unmodifiable(channels);

  final List<MotionPropertyChannelModel> channels;
  final String channelId;
  final String keyframeId;
  final TimelineTime time;
  final TimelineTimeRange? activeRange;
}

@immutable
class UnifiedKeyframeMoveSelectionRequest {
  UnifiedKeyframeMoveSelectionRequest({
    required List<MotionPropertyChannelModel> channels,
    required Set<String> keyframeIds,
    required this.anchorKeyframeId,
    required this.anchorTargetTime,
    this.activeRange,
  })  : channels = List.unmodifiable(channels),
        keyframeIds = Set.unmodifiable(keyframeIds);

  final List<MotionPropertyChannelModel> channels;
  final Set<String> keyframeIds;
  final String anchorKeyframeId;
  final TimelineTime anchorTargetTime;
  final TimelineTimeRange? activeRange;
}

@immutable
class UnifiedKeyframeValueRequest {
  UnifiedKeyframeValueRequest({
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
class UnifiedKeyframeInterpolationRequest {
  UnifiedKeyframeInterpolationRequest({
    required List<MotionPropertyChannelModel> channels,
    required this.channelId,
    required this.keyframeId,
    required this.interpolation,
  }) : channels = List.unmodifiable(channels);

  final List<MotionPropertyChannelModel> channels;
  final String channelId;
  final String keyframeId;
  final MotionInterpolationSpec interpolation;
}

@immutable
class UnifiedKeyframeDeleteRequest {
  UnifiedKeyframeDeleteRequest({
    required List<MotionPropertyChannelModel> channels,
    required this.channelId,
    required this.keyframeId,
  }) : channels = List.unmodifiable(channels);

  final List<MotionPropertyChannelModel> channels;
  final String channelId;
  final String keyframeId;
}

@immutable
class UnifiedKeyframeEasyEaseRequest {
  UnifiedKeyframeEasyEaseRequest({
    required List<MotionPropertyChannelModel> channels,
    required Set<String> keyframeIds,
    required this.mode,
    Set<String> selection = const <String>{},
  })  : channels = List.unmodifiable(channels),
        keyframeIds = Set.unmodifiable(keyframeIds),
        selection = Set.unmodifiable(selection);

  final List<MotionPropertyChannelModel> channels;
  final Set<String> keyframeIds;
  final UnifiedEasyEaseMode mode;
  final Set<String> selection;
}

@immutable
class UnifiedKeyframeSelectionResult {
  const UnifiedKeyframeSelectionResult({
    required this.selectedKeyframeIds,
    this.primaryKeyframeId,
  });

  final Set<String> selectedKeyframeIds;
  final String? primaryKeyframeId;
}

class UnifiedKeyframeOperations {
  const UnifiedKeyframeOperations({
    UnifiedKeyframeChannelIdFactory? channelIdFactory,
    UnifiedKeyframeIdFactory? keyframeIdFactory,
  })  : _channelIdFactory = channelIdFactory ?? _defaultChannelIdFor,
        _keyframeIdFactory = keyframeIdFactory ?? _defaultKeyframeIdFor;

  final UnifiedKeyframeChannelIdFactory _channelIdFactory;
  final UnifiedKeyframeIdFactory _keyframeIdFactory;
  static const MotionInterpolationSpec _afterEffectsEasyEaseInterpolation =
      MotionInterpolationSpec.cubicBezier(
    bezier: MotionBezierControlPoints(
      x1: 0.3333,
      y1: 0.0,
      x2: 0.6667,
      y2: 1.0,
    ),
  );
  static const MotionKeyframeVelocity _easyEaseVelocity =
      MotionKeyframeVelocity(
    incomingSpeed: 0.0,
    outgoingSpeed: 0.0,
    incomingInfluence: 33.333,
    outgoingInfluence: 33.333,
    incomingHandleLocked: false,
    outgoingHandleLocked: false,
    continuous: true,
    roving: false,
    presetId: 'easyEase',
  );

  UnifiedKeyframeOperationResult addKeyframe(
    UnifiedKeyframeAddRequest request,
  ) {
    final issue = _validateEdit(
      target: request.target,
      activeRange: request.activeRange,
      definition: request.definition,
      value: request.value,
    );
    if (issue != null) {
      return UnifiedKeyframeOperationResult(
        channels: request.channels,
        issues: <UnifiedKeyframeIssue>[issue],
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
    final keyframeTime = _clampKeyframeTime(request.time, request.activeRange);
    final existingIndex = channel.keyframes.indexWhere(
      (keyframe) => keyframe.time.inProjectTicks == keyframeTime.inProjectTicks,
    );

    if (existingIndex >= 0) {
      if (request.collisionPolicy == UnifiedKeyframeAddCollisionPolicy.reject) {
        return UnifiedKeyframeOperationResult(
          channels: request.channels,
          issues: <UnifiedKeyframeIssue>[
            UnifiedKeyframeIssue(
              code: UnifiedKeyframeIssueCode.keyframeTimeCollision,
              message:
                  'A keyframe already exists at ${keyframeTime.inProjectTicks}.',
              channelId: channel.id,
              keyframeId: channel.keyframes[existingIndex].id,
              propertyId: channel.definition.id,
            ),
          ],
        );
      }
      final updated = channel.keyframes[existingIndex].copyWith(
        value: request.value,
        interpolationToNext: request.interpolation,
      );
      final nextKeyframes = List<MotionKeyframeModel>.from(channel.keyframes)
        ..[existingIndex] = updated;
      return UnifiedKeyframeOperationResult(
        channels: _replaceOrAppend(
          request.channels,
          channelIndex: channelIndex,
          channel: channel.copyWith(
            activeRange: request.activeRange,
            keyframes: _normalizedKeyframes(nextKeyframes),
          ),
        ),
        selectedKeyframeIds: <String>{updated.id},
        changedKeyframeIds: <String>{updated.id},
      );
    }

    final keyframe = MotionKeyframeModel(
      id: _keyframeIdFor(channelId: channel.id, time: keyframeTime),
      channelId: channel.id,
      time: keyframeTime,
      value: request.value,
      interpolationToNext: request.interpolation,
    );
    return UnifiedKeyframeOperationResult(
      channels: _replaceOrAppend(
        request.channels,
        channelIndex: channelIndex,
        channel: channel.copyWith(
          activeRange: request.activeRange,
          keyframes: _normalizedKeyframes(
            <MotionKeyframeModel>[...channel.keyframes, keyframe],
          ),
        ),
      ),
      selectedKeyframeIds: <String>{keyframe.id},
      changedKeyframeIds: <String>{keyframe.id},
    );
  }

  UnifiedKeyframeOperationResult moveKeyframe(
    UnifiedKeyframeMoveRequest request,
  ) {
    return moveSelectedKeyframesToTime(
      UnifiedKeyframeMoveSelectionRequest(
        channels: request.channels,
        keyframeIds: <String>{request.keyframeId},
        anchorKeyframeId: request.keyframeId,
        anchorTargetTime: request.time,
        activeRange: request.activeRange,
      ),
    );
  }

  UnifiedKeyframeOperationResult moveSelectedKeyframesToTime(
    UnifiedKeyframeMoveSelectionRequest request,
  ) {
    if (request.keyframeIds.isEmpty) {
      return UnifiedKeyframeOperationResult(
        channels: request.channels,
        issues: const <UnifiedKeyframeIssue>[
          UnifiedKeyframeIssue(
            code: UnifiedKeyframeIssueCode.emptySelection,
            message: 'No keyframes were selected.',
          ),
        ],
      );
    }
    if (!request.keyframeIds.contains(request.anchorKeyframeId)) {
      return UnifiedKeyframeOperationResult(
        channels: request.channels,
        issues: <UnifiedKeyframeIssue>[
          UnifiedKeyframeIssue(
            code: UnifiedKeyframeIssueCode.missingKeyframe,
            message:
                'Anchor keyframe `${request.anchorKeyframeId}` is not selected.',
            keyframeId: request.anchorKeyframeId,
          ),
        ],
      );
    }

    final located = _locateKeyframes(
      request.channels,
      keyframeIds: request.keyframeIds,
    );
    if (located.issues.isNotEmpty) {
      return UnifiedKeyframeOperationResult(
        channels: request.channels,
        issues: located.issues,
      );
    }
    final anchor = located.entries[request.anchorKeyframeId];
    if (anchor == null) {
      return UnifiedKeyframeOperationResult(
        channels: request.channels,
        issues: <UnifiedKeyframeIssue>[
          UnifiedKeyframeIssue(
            code: UnifiedKeyframeIssueCode.missingKeyframe,
            message:
                'Anchor keyframe `${request.anchorKeyframeId}` was not found.',
            keyframeId: request.anchorKeyframeId,
          ),
        ],
      );
    }

    final targetRange = request.activeRange ??
        request.channels[anchor.channelIndex].activeRange ??
        _rangeForChannel(request.channels[anchor.channelIndex]);
    if (targetRange.endExclusive <= targetRange.start) {
      return UnifiedKeyframeOperationResult(
        channels: request.channels,
        issues: const <UnifiedKeyframeIssue>[
          UnifiedKeyframeIssue(
            code: UnifiedKeyframeIssueCode.emptyRange,
            message: 'Cannot move keyframes inside an empty active range.',
          ),
        ],
      );
    }

    final anchorTarget = _clampKeyframeTime(
      request.anchorTargetTime,
      targetRange,
    );
    final delta = anchorTarget - anchor.keyframe.time;
    final proposedByKeyframeId = <String, TimelineTime>{};
    for (final entry in located.entries.entries) {
      final source = entry.value;
      final channel = request.channels[source.channelIndex];
      final range = request.activeRange ??
          channel.activeRange ??
          _rangeForChannel(channel);
      final proposed = source.keyframe.time + delta;
      if (proposed < range.start || proposed >= range.endExclusive) {
        return UnifiedKeyframeOperationResult(
          channels: request.channels,
          issues: <UnifiedKeyframeIssue>[
            UnifiedKeyframeIssue(
              code: UnifiedKeyframeIssueCode.keyframeTimeOutOfRange,
              message: 'Moving `${entry.key}` would leave its active range.',
              channelId: channel.id,
              keyframeId: entry.key,
              propertyId: channel.definition.id,
            ),
          ],
        );
      }
      proposedByKeyframeId[entry.key] = proposed;
    }

    for (final channel in request.channels) {
      final selectedInChannel = <String>{
        for (final keyframe in channel.keyframes)
          if (request.keyframeIds.contains(keyframe.id)) keyframe.id,
      };
      if (selectedInChannel.isEmpty) {
        continue;
      }
      for (final keyframe in channel.keyframes) {
        if (selectedInChannel.contains(keyframe.id)) {
          continue;
        }
        final collides = selectedInChannel.any((selectedId) {
          final proposed = proposedByKeyframeId[selectedId];
          return proposed != null &&
              proposed.inProjectTicks == keyframe.time.inProjectTicks;
        });
        if (collides) {
          return UnifiedKeyframeOperationResult(
            channels: request.channels,
            issues: <UnifiedKeyframeIssue>[
              UnifiedKeyframeIssue(
                code: UnifiedKeyframeIssueCode.keyframeTimeCollision,
                message:
                    'Cannot move selected keyframes onto another keyframe.',
                channelId: channel.id,
                keyframeId: keyframe.id,
                propertyId: channel.definition.id,
              ),
            ],
          );
        }
      }
    }

    final nextChannels = <MotionPropertyChannelModel>[];
    final changedIds = <String>{};
    for (final channel in request.channels) {
      final keyframes = channel.keyframes.map((keyframe) {
        final proposed = proposedByKeyframeId[keyframe.id];
        if (proposed == null) {
          return keyframe;
        }
        changedIds.add(keyframe.id);
        return keyframe.copyWith(time: proposed);
      });
      nextChannels
          .add(channel.copyWith(keyframes: _normalizedKeyframes(keyframes)));
    }

    return UnifiedKeyframeOperationResult(
      channels: nextChannels,
      selectedKeyframeIds: request.keyframeIds,
      changedKeyframeIds: changedIds,
    );
  }

  UnifiedKeyframeOperationResult setKeyframeValue(
    UnifiedKeyframeValueRequest request,
  ) {
    final found = _findChannelAndKeyframe(
      request.channels,
      channelId: request.channelId,
      keyframeId: request.keyframeId,
    );
    if (found.issue != null) {
      return UnifiedKeyframeOperationResult(
        channels: request.channels,
        issues: <UnifiedKeyframeIssue>[found.issue!],
      );
    }
    final channel = request.channels[found.channelIndex];
    if (request.value.kind != channel.definition.valueKind) {
      return UnifiedKeyframeOperationResult(
        channels: request.channels,
        issues: <UnifiedKeyframeIssue>[
          UnifiedKeyframeIssue(
            code: UnifiedKeyframeIssueCode.valueKindMismatch,
            message: 'Value kind does not match `${channel.definition.id}`.',
            channelId: request.channelId,
            keyframeId: request.keyframeId,
            propertyId: channel.definition.id,
          ),
        ],
      );
    }
    final nextKeyframe = channel.keyframes[found.keyframeIndex].copyWith(
      value: request.value,
    );
    final nextKeyframes = List<MotionKeyframeModel>.from(channel.keyframes)
      ..[found.keyframeIndex] = nextKeyframe;
    return UnifiedKeyframeOperationResult(
      channels: _replaceOrAppend(
        request.channels,
        channelIndex: found.channelIndex,
        channel: channel.copyWith(keyframes: nextKeyframes),
      ),
      selectedKeyframeIds: <String>{request.keyframeId},
      changedKeyframeIds: <String>{request.keyframeId},
    );
  }

  UnifiedKeyframeOperationResult setKeyframeInterpolation(
    UnifiedKeyframeInterpolationRequest request,
  ) {
    final found = _findChannelAndKeyframe(
      request.channels,
      channelId: request.channelId,
      keyframeId: request.keyframeId,
    );
    if (found.issue != null) {
      return UnifiedKeyframeOperationResult(
        channels: request.channels,
        issues: <UnifiedKeyframeIssue>[found.issue!],
      );
    }
    final channel = request.channels[found.channelIndex];
    final nextKeyframe = channel.keyframes[found.keyframeIndex].copyWith(
      interpolationToNext: request.interpolation,
    );
    final nextKeyframes = List<MotionKeyframeModel>.from(channel.keyframes)
      ..[found.keyframeIndex] = nextKeyframe;
    return UnifiedKeyframeOperationResult(
      channels: _replaceOrAppend(
        request.channels,
        channelIndex: found.channelIndex,
        channel: channel.copyWith(keyframes: nextKeyframes),
      ),
      selectedKeyframeIds: <String>{request.keyframeId},
      changedKeyframeIds: <String>{request.keyframeId},
    );
  }

  UnifiedKeyframeOperationResult deleteKeyframe(
    UnifiedKeyframeDeleteRequest request,
  ) {
    final found = _findChannelAndKeyframe(
      request.channels,
      channelId: request.channelId,
      keyframeId: request.keyframeId,
    );
    if (found.issue != null) {
      return UnifiedKeyframeOperationResult(
        channels: request.channels,
        issues: <UnifiedKeyframeIssue>[found.issue!],
      );
    }
    final channel = request.channels[found.channelIndex];
    final nextKeyframes = <MotionKeyframeModel>[
      for (final keyframe in channel.keyframes)
        if (keyframe.id != request.keyframeId) keyframe,
    ];
    return UnifiedKeyframeOperationResult(
      channels: _replaceOrAppend(
        request.channels,
        channelIndex: found.channelIndex,
        channel: channel.copyWith(keyframes: nextKeyframes),
      ),
      changedKeyframeIds: <String>{request.keyframeId},
    );
  }

  UnifiedKeyframeOperationResult applyEasyEase(
    UnifiedKeyframeEasyEaseRequest request,
  ) {
    if (request.keyframeIds.isEmpty) {
      return UnifiedKeyframeOperationResult(
        channels: request.channels,
        issues: const <UnifiedKeyframeIssue>[
          UnifiedKeyframeIssue(
            code: UnifiedKeyframeIssueCode.emptySelection,
            message: 'No keyframes were selected.',
          ),
        ],
      );
    }
    final located = _locateKeyframes(
      request.channels,
      keyframeIds: request.keyframeIds,
    );
    if (located.issues.isNotEmpty) {
      return UnifiedKeyframeOperationResult(
        channels: request.channels,
        issues: located.issues,
      );
    }
    final changedIds = <String>{};
    final nextChannels = <MotionPropertyChannelModel>[];
    for (final channel in request.channels) {
      var updated = false;
      final nextKeyframes = channel.keyframes.map((keyframe) {
        if (!request.keyframeIds.contains(keyframe.id)) {
          return keyframe;
        }
        updated = true;
        changedIds.add(keyframe.id);
        return keyframe.copyWith(
          interpolationToNext: _interpolationForEasyEase(
            original: keyframe.interpolationToNext,
            mode: request.mode,
          ),
        );
      }).toList(growable: false);
      nextChannels.add(
        updated ? channel.copyWith(keyframes: nextKeyframes) : channel,
      );
    }

    return UnifiedKeyframeOperationResult(
      channels: nextChannels,
      selectedKeyframeIds:
          request.selection.isEmpty ? request.keyframeIds : request.selection,
      changedKeyframeIds: changedIds,
    );
  }

  UnifiedKeyframeSelectionResult selectKeyframe({
    required Iterable<MotionPropertyChannelModel> channels,
    required String keyframeId,
    Set<String> currentSelection = const <String>{},
    bool additive = false,
  }) {
    final exists = channels.any(
      (channel) => channel.keyframes.any(
        (keyframe) => keyframe.id == keyframeId,
      ),
    );
    if (!exists) {
      return const UnifiedKeyframeSelectionResult(
        selectedKeyframeIds: <String>{},
      );
    }
    final selected = additive
        ? <String>{...currentSelection, keyframeId}
        : <String>{keyframeId};
    return UnifiedKeyframeSelectionResult(
      selectedKeyframeIds: Set.unmodifiable(selected),
      primaryKeyframeId: keyframeId,
    );
  }

  UnifiedKeyframeIssue? _validateEdit({
    required MotionPropertyTarget target,
    required TimelineTimeRange activeRange,
    required MotionPropertyDefinition definition,
    required MotionPropertyValue value,
  }) {
    if (activeRange.endExclusive <= activeRange.start) {
      return UnifiedKeyframeIssue(
        code: UnifiedKeyframeIssueCode.emptyRange,
        message: 'Cannot author `${definition.id}` inside an empty range.',
        propertyId: definition.id,
      );
    }
    if (!definition.isAnimatable) {
      return UnifiedKeyframeIssue(
        code: UnifiedKeyframeIssueCode.nonAnimatableProperty,
        message: 'Property `${definition.id}` is not animatable.',
        propertyId: definition.id,
      );
    }
    if (!definition.supportedTargets.contains(target.kind)) {
      return UnifiedKeyframeIssue(
        code: UnifiedKeyframeIssueCode.unsupportedTarget,
        message: 'Property `${definition.id}` cannot target `${target.kind}`.',
        propertyId: definition.id,
      );
    }
    if (value.kind != definition.valueKind) {
      return UnifiedKeyframeIssue(
        code: UnifiedKeyframeIssueCode.valueKindMismatch,
        message: 'Value kind does not match `${definition.id}`.',
        propertyId: definition.id,
      );
    }
    return null;
  }

  _LocatedKeyframes _locateKeyframes(
    List<MotionPropertyChannelModel> channels, {
    required Set<String> keyframeIds,
  }) {
    final entries = <String, _LocatedKeyframe>{};
    for (var channelIndex = 0;
        channelIndex < channels.length;
        channelIndex += 1) {
      final channel = channels[channelIndex];
      for (var keyframeIndex = 0;
          keyframeIndex < channel.keyframes.length;
          keyframeIndex += 1) {
        final keyframe = channel.keyframes[keyframeIndex];
        if (keyframeIds.contains(keyframe.id)) {
          entries[keyframe.id] = _LocatedKeyframe(
            channelIndex: channelIndex,
            keyframeIndex: keyframeIndex,
            keyframe: keyframe,
          );
        }
      }
    }
    final issues = <UnifiedKeyframeIssue>[
      for (final keyframeId in keyframeIds)
        if (!entries.containsKey(keyframeId))
          UnifiedKeyframeIssue(
            code: UnifiedKeyframeIssueCode.missingKeyframe,
            message: 'Keyframe `$keyframeId` was not found.',
            keyframeId: keyframeId,
          ),
    ];
    return _LocatedKeyframes(entries: entries, issues: issues);
  }

  _FoundKeyframe _findChannelAndKeyframe(
    List<MotionPropertyChannelModel> channels, {
    required String channelId,
    required String keyframeId,
  }) {
    final channelIndex = channels.indexWhere(
      (channel) => channel.id == channelId,
    );
    if (channelIndex < 0) {
      return _FoundKeyframe(
        issue: UnifiedKeyframeIssue(
          code: UnifiedKeyframeIssueCode.missingChannel,
          message: 'Channel `$channelId` was not found.',
          channelId: channelId,
        ),
      );
    }
    final channel = channels[channelIndex];
    final keyframeIndex = channel.keyframes.indexWhere(
      (keyframe) => keyframe.id == keyframeId,
    );
    if (keyframeIndex < 0) {
      return _FoundKeyframe(
        issue: UnifiedKeyframeIssue(
          code: UnifiedKeyframeIssueCode.missingKeyframe,
          message: 'Keyframe `$keyframeId` was not found.',
          channelId: channelId,
          keyframeId: keyframeId,
          propertyId: channel.definition.id,
        ),
      );
    }
    return _FoundKeyframe(
      channelIndex: channelIndex,
      keyframeIndex: keyframeIndex,
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
    final sorted = keyframes.toList(growable: false)
      ..sort((left, right) {
        final timeCompare =
            left.time.inProjectTicks.compareTo(right.time.inProjectTicks);
        if (timeCompare != 0) {
          return timeCompare;
        }
        return left.id.compareTo(right.id);
      });
    return List<MotionKeyframeModel>.unmodifiable(sorted);
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

  MotionInterpolationSpec _interpolationForEasyEase({
    required MotionInterpolationSpec original,
    required UnifiedEasyEaseMode mode,
  }) {
    switch (mode) {
      case UnifiedEasyEaseMode.easyEase:
        return _afterEffectsEasyEaseInterpolation.copyWith(
          velocity: _easyEaseVelocity,
        );
      case UnifiedEasyEaseMode.easyEaseIn:
        final currentVelocity = original.velocity;
        return _afterEffectsEasyEaseInterpolation.copyWith(
          velocity: (currentVelocity ?? _easyEaseVelocity).copyWith(
            incomingSpeed: 0.0,
            incomingInfluence: 33.333,
            presetId: 'easyEaseIn',
          ),
        );
      case UnifiedEasyEaseMode.easyEaseOut:
        final currentVelocity = original.velocity;
        return _afterEffectsEasyEaseInterpolation.copyWith(
          velocity: (currentVelocity ?? _easyEaseVelocity).copyWith(
            outgoingSpeed: 0.0,
            outgoingInfluence: 33.333,
            presetId: 'easyEaseOut',
          ),
        );
      case UnifiedEasyEaseMode.removeEase:
        return const MotionInterpolationSpec.linear();
    }
  }

  TimelineTimeRange _rangeForChannel(MotionPropertyChannelModel channel) {
    if (channel.keyframes.isEmpty) {
      return TimelineTimeRange(
        start: TimelineTime.zero,
        endExclusive: TimelineTime.fromProjectTicks(1),
      );
    }
    final first = channel.keyframes.first.time;
    final last = channel.keyframes.last.time;
    return TimelineTimeRange(
      start: first,
      endExclusive: TimelineTime.fromProjectTicks(last.inProjectTicks + 1),
    );
  }

  String _channelIdFor({
    required MotionPropertyTarget target,
    required MotionPropertyDefinition definition,
  }) {
    return _channelIdFactory(target: target, definition: definition);
  }

  String _keyframeIdFor({
    required String channelId,
    required TimelineTime time,
  }) {
    return _keyframeIdFactory(channelId: channelId, time: time);
  }

  static String _defaultChannelIdFor({
    required MotionPropertyTarget target,
    required MotionPropertyDefinition definition,
  }) {
    return 'unifiedKeyframe.${target.canonicalAddress}.${definition.id}';
  }

  static String _defaultKeyframeIdFor({
    required String channelId,
    required TimelineTime time,
  }) {
    return '$channelId.${time.inProjectTicks}';
  }
}

@immutable
class _FoundKeyframe {
  const _FoundKeyframe({
    this.channelIndex = -1,
    this.keyframeIndex = -1,
    this.issue,
  });

  final int channelIndex;
  final int keyframeIndex;
  final UnifiedKeyframeIssue? issue;
}

@immutable
class _LocatedKeyframe {
  const _LocatedKeyframe({
    required this.channelIndex,
    required this.keyframeIndex,
    required this.keyframe,
  });

  final int channelIndex;
  final int keyframeIndex;
  final MotionKeyframeModel keyframe;
}

@immutable
class _LocatedKeyframes {
  const _LocatedKeyframes({
    required this.entries,
    required this.issues,
  });

  final Map<String, _LocatedKeyframe> entries;
  final List<UnifiedKeyframeIssue> issues;
}
