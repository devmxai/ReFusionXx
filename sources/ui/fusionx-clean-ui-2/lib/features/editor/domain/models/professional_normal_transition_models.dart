import 'package:flutter/foundation.dart';

import '../../presentation/models/timeline_time.dart';

const String kNormalTransitionSchemaVersion = '1.0.0';
const TimelineTime kNormalTransitionMinimumDuration =
    TimelineTime(value: 100000);
const TimelineTime kNormalTransitionMaximumDuration =
    TimelineTime(value: 5000000);

enum NormalTransitionCategory {
  basic,
  motion,
  blur,
  wipe,
  light,
  distort,
  custom,
}

enum NormalTransitionRendererTier {
  primitive,
  glsl,
  multiPassDeferred,
}

enum NormalTransitionAlignment {
  symmetric,
  outgoingHeavy,
  incomingHeavy,
}

enum NormalTransitionSourceKind {
  builtInPreset,
  importedScript,
  manual,
  detachedManual,
}

enum NormalTransitionParameterType {
  number,
  boolean,
  enumeration,
}

enum NormalTransitionIssueSeverity {
  error,
  warning,
  info,
}

@immutable
class NormalTransitionIssue {
  const NormalTransitionIssue({
    required this.severity,
    required this.message,
    this.path,
  });

  final NormalTransitionIssueSeverity severity;
  final String message;
  final String? path;
}

@immutable
class NormalTransitionNumberRange {
  const NormalTransitionNumberRange({
    required this.min,
    required this.max,
  }) : assert(min <= max, 'min must be <= max');

  final double min;
  final double max;

  bool contains(num value) => value >= min && value <= max;
}

@immutable
class NormalTransitionParameterSchema {
  NormalTransitionParameterSchema({
    required this.name,
    required this.type,
    required this.defaultValue,
    this.range,
    this.uiControl,
    List<String> values = const <String>[],
  }) : values = List.unmodifiable(values);

  final String name;
  final NormalTransitionParameterType type;
  final Object defaultValue;
  final NormalTransitionNumberRange? range;
  final String? uiControl;
  final List<String> values;

  bool accepts(Object? value) {
    return switch (type) {
      NormalTransitionParameterType.number =>
        value is num && (range?.contains(value) ?? true),
      NormalTransitionParameterType.boolean => value is bool,
      NormalTransitionParameterType.enumeration =>
        value is String && values.contains(value),
    };
  }
}

@immutable
class NormalTransitionKeyframeSpec {
  const NormalTransitionKeyframeSpec({
    required this.normalizedTime,
    required this.value,
    this.easing = 'linear',
  }) : assert(
          normalizedTime >= 0 && normalizedTime <= 1,
          'normalizedTime must be in [0, 1]',
        );

  final double normalizedTime;
  final Object value;
  final String easing;
}

@immutable
class NormalTransitionChannelSpec {
  NormalTransitionChannelSpec({
    required this.target,
    required this.property,
    List<NormalTransitionKeyframeSpec> keyframes =
        const <NormalTransitionKeyframeSpec>[],
  }) : keyframes = List.unmodifiable(keyframes) {
    assert(_areKeyframesSorted(keyframes), 'keyframes must be sorted by time');
  }

  final String target;
  final String property;
  final List<NormalTransitionKeyframeSpec> keyframes;

  static bool _areKeyframesSorted(
    List<NormalTransitionKeyframeSpec> keyframes,
  ) {
    for (var index = 1; index < keyframes.length; index += 1) {
      if (keyframes[index - 1].normalizedTime >
          keyframes[index].normalizedTime) {
        return false;
      }
    }
    return true;
  }
}

@immutable
class NormalTransitionDefinition {
  NormalTransitionDefinition({
    required this.definitionId,
    required this.schemaVersion,
    required this.label,
    required this.category,
    required this.rendererTier,
    required this.defaultDuration,
    this.minDuration = kNormalTransitionMinimumDuration,
    this.maxDuration = kNormalTransitionMaximumDuration,
    List<String> capabilities = const <String>[],
    List<NormalTransitionParameterSchema> parameters =
        const <NormalTransitionParameterSchema>[],
    List<NormalTransitionChannelSpec> channels =
        const <NormalTransitionChannelSpec>[],
    this.shaderAssetPath,
    this.thumbnailPath,
    this.integrityHash,
  })  : capabilities = List.unmodifiable(capabilities),
        parameters = List.unmodifiable(parameters),
        channels = List.unmodifiable(channels) {
    assert(defaultDuration >= minDuration);
    assert(defaultDuration <= maxDuration);
  }

  final String definitionId;
  final String schemaVersion;
  final String label;
  final NormalTransitionCategory category;
  final NormalTransitionRendererTier rendererTier;
  final TimelineTime defaultDuration;
  final TimelineTime minDuration;
  final TimelineTime maxDuration;
  final List<String> capabilities;
  final List<NormalTransitionParameterSchema> parameters;
  final List<NormalTransitionChannelSpec> channels;
  final String? shaderAssetPath;
  final String? thumbnailPath;
  final String? integrityHash;

  Map<String, Object> get defaultParameterValues {
    return Map<String, Object>.unmodifiable({
      for (final parameter in parameters)
        parameter.name: parameter.defaultValue,
    });
  }
}

@immutable
class NormalTransitionNode {
  NormalTransitionNode({
    required this.id,
    required this.trackId,
    required this.leftClipId,
    required this.rightClipId,
    required this.definitionId,
    required this.duration,
    this.alignment = NormalTransitionAlignment.symmetric,
    this.enabled = true,
    this.schemaVersion = kNormalTransitionSchemaVersion,
    Map<String, Object> parameterValues = const <String, Object>{},
    this.instanceId,
  }) : parameterValues = Map.unmodifiable(parameterValues) {
    assert(duration > TimelineTime.zero, 'duration must be positive');
  }

  final String id;
  final String trackId;
  final String leftClipId;
  final String rightClipId;
  final String definitionId;
  final TimelineTime duration;
  final NormalTransitionAlignment alignment;
  final bool enabled;
  final String schemaVersion;
  final Map<String, Object> parameterValues;
  final String? instanceId;

  NormalTransitionNode copyWith({
    String? id,
    String? trackId,
    String? leftClipId,
    String? rightClipId,
    String? definitionId,
    TimelineTime? duration,
    NormalTransitionAlignment? alignment,
    bool? enabled,
    String? schemaVersion,
    Map<String, Object>? parameterValues,
    String? instanceId,
  }) {
    return NormalTransitionNode(
      id: id ?? this.id,
      trackId: trackId ?? this.trackId,
      leftClipId: leftClipId ?? this.leftClipId,
      rightClipId: rightClipId ?? this.rightClipId,
      definitionId: definitionId ?? this.definitionId,
      duration: duration ?? this.duration,
      alignment: alignment ?? this.alignment,
      enabled: enabled ?? this.enabled,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      parameterValues: parameterValues ?? this.parameterValues,
      instanceId: instanceId ?? this.instanceId,
    );
  }

  NormalTransitionOverlapWindow resolveOverlap({
    required TimelineTime boundaryTime,
  }) {
    final split = _resolveDurationSplit(duration, alignment);
    return NormalTransitionOverlapWindow(
      nodeId: id,
      boundaryTime: boundaryTime,
      start: boundaryTime - split.leading,
      endExclusive: boundaryTime + split.trailing,
      leadingDuration: split.leading,
      trailingDuration: split.trailing,
    );
  }

  NormalTransitionHandleValidationResult validateHandles({
    required TimelineTime boundaryTime,
    required TimelineTime leftAvailableTail,
    required TimelineTime rightAvailableHead,
  }) {
    final window = resolveOverlap(boundaryTime: boundaryTime);
    final issues = <NormalTransitionIssue>[];
    if (duration < kNormalTransitionMinimumDuration) {
      issues.add(
        const NormalTransitionIssue(
          severity: NormalTransitionIssueSeverity.error,
          message: 'Transition duration is shorter than the minimum overlap.',
          path: 'duration',
        ),
      );
    }
    if (duration > kNormalTransitionMaximumDuration) {
      issues.add(
        const NormalTransitionIssue(
          severity: NormalTransitionIssueSeverity.error,
          message: 'Transition duration is longer than the maximum overlap.',
          path: 'duration',
        ),
      );
    }
    if (window.leadingDuration > leftAvailableTail) {
      issues.add(
        const NormalTransitionIssue(
          severity: NormalTransitionIssueSeverity.error,
          message: 'The outgoing clip does not have enough tail handle.',
          path: 'leftClipId',
        ),
      );
    }
    if (window.trailingDuration > rightAvailableHead) {
      issues.add(
        const NormalTransitionIssue(
          severity: NormalTransitionIssueSeverity.error,
          message: 'The incoming clip does not have enough head handle.',
          path: 'rightClipId',
        ),
      );
    }
    return NormalTransitionHandleValidationResult(
      window: window,
      issues: List.unmodifiable(issues),
    );
  }
}

@immutable
class NormalTransitionInstance {
  NormalTransitionInstance({
    required this.id,
    required this.nodeId,
    required this.definitionId,
    required this.sourceKind,
    required this.sourceHash,
    required this.schemaVersion,
    Map<String, Object> parameterValues = const <String, Object>{},
    List<NormalTransitionChannelSpec> channels =
        const <NormalTransitionChannelSpec>[],
  })  : parameterValues = Map.unmodifiable(parameterValues),
        channels = List.unmodifiable(channels);

  final String id;
  final String nodeId;
  final String definitionId;
  final NormalTransitionSourceKind sourceKind;
  final String sourceHash;
  final String schemaVersion;
  final Map<String, Object> parameterValues;
  final List<NormalTransitionChannelSpec> channels;

  NormalTransitionInstance copyWith({
    String? id,
    String? nodeId,
    String? definitionId,
    NormalTransitionSourceKind? sourceKind,
    String? sourceHash,
    String? schemaVersion,
    Map<String, Object>? parameterValues,
    List<NormalTransitionChannelSpec>? channels,
  }) {
    return NormalTransitionInstance(
      id: id ?? this.id,
      nodeId: nodeId ?? this.nodeId,
      definitionId: definitionId ?? this.definitionId,
      sourceKind: sourceKind ?? this.sourceKind,
      sourceHash: sourceHash ?? this.sourceHash,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      parameterValues: parameterValues ?? this.parameterValues,
      channels: channels ?? this.channels,
    );
  }
}

@immutable
class NormalTransitionOverlapWindow {
  const NormalTransitionOverlapWindow({
    required this.nodeId,
    required this.boundaryTime,
    required this.start,
    required this.endExclusive,
    required this.leadingDuration,
    required this.trailingDuration,
  })  : assert(start <= boundaryTime),
        assert(boundaryTime <= endExclusive);

  final String nodeId;
  final TimelineTime boundaryTime;
  final TimelineTime start;
  final TimelineTime endExclusive;
  final TimelineTime leadingDuration;
  final TimelineTime trailingDuration;

  TimelineTime get duration => endExclusive - start;

  bool contains(TimelineTime time) => time >= start && time < endExclusive;

  double progressAt(TimelineTime time) {
    if (duration.isZero) {
      return 0;
    }
    final elapsed = time - start;
    return (elapsed.inProjectTicks / duration.inProjectTicks)
        .clamp(0.0, 1.0)
        .toDouble();
  }
}

@immutable
class NormalTransitionHandleValidationResult {
  const NormalTransitionHandleValidationResult({
    required this.window,
    required this.issues,
  });

  final NormalTransitionOverlapWindow window;
  final List<NormalTransitionIssue> issues;

  bool get isValid => !issues.any(
        (issue) => issue.severity == NormalTransitionIssueSeverity.error,
      );
}

@immutable
class _NormalTransitionDurationSplit {
  const _NormalTransitionDurationSplit({
    required this.leading,
    required this.trailing,
  });

  final TimelineTime leading;
  final TimelineTime trailing;
}

_NormalTransitionDurationSplit _resolveDurationSplit(
  TimelineTime duration,
  NormalTransitionAlignment alignment,
) {
  final ticks = duration.inProjectTicks;
  final leadingTicks = switch (alignment) {
    NormalTransitionAlignment.symmetric => ticks ~/ 2,
    NormalTransitionAlignment.outgoingHeavy => (ticks * 2 / 3).round(),
    NormalTransitionAlignment.incomingHeavy => (ticks / 3).round(),
  };
  final leading = TimelineTime.fromProjectTicks(leadingTicks);
  final trailing = duration - leading;
  return _NormalTransitionDurationSplit(
    leading: leading,
    trailing: trailing,
  );
}
