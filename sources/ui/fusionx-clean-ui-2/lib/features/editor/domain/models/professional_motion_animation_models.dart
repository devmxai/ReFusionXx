import 'package:flutter/foundation.dart';

import '../../presentation/models/timeline_time.dart';
import 'professional_motion_models.dart';

enum MotionInterpolationKind {
  hold,
  linear,
  easeIn,
  easeOut,
  easeInOut,
  cubicBezier,
  spring,
  bounce,
  elastic,
}

enum MotionChannelExtrapolationMode {
  clamp,
  hold,
  loop,
  mirror,
}

@immutable
class MotionBezierControlPoints {
  const MotionBezierControlPoints({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
  });

  final double x1;
  final double y1;
  final double x2;
  final double y2;
}

@immutable
class MotionSpringSpec {
  const MotionSpringSpec({
    required this.stiffness,
    required this.damping,
    this.mass = 1.0,
    this.initialVelocity = 0.0,
  });

  final double stiffness;
  final double damping;
  final double mass;
  final double initialVelocity;
}

@immutable
class MotionInterpolationSpec {
  const MotionInterpolationSpec({
    required this.kind,
    this.bezier,
    this.spring,
  });

  const MotionInterpolationSpec.hold()
    : this(kind: MotionInterpolationKind.hold);

  const MotionInterpolationSpec.linear()
    : this(kind: MotionInterpolationKind.linear);

  const MotionInterpolationSpec.easeIn()
    : this(kind: MotionInterpolationKind.easeIn);

  const MotionInterpolationSpec.easeOut()
    : this(kind: MotionInterpolationKind.easeOut);

  const MotionInterpolationSpec.easeInOut()
    : this(kind: MotionInterpolationKind.easeInOut);

  const MotionInterpolationSpec.cubicBezier({
    required MotionBezierControlPoints bezier,
  }) : this(
         kind: MotionInterpolationKind.cubicBezier,
         bezier: bezier,
       );

  const MotionInterpolationSpec.spring({
    required MotionSpringSpec spring,
  }) : this(
         kind: MotionInterpolationKind.spring,
         spring: spring,
       );

  final MotionInterpolationKind kind;
  final MotionBezierControlPoints? bezier;
  final MotionSpringSpec? spring;
}

@immutable
class MotionKeyframeModel {
  const MotionKeyframeModel({
    required this.id,
    required this.channelId,
    required this.time,
    required this.value,
    required this.interpolationToNext,
  });

  final String id;
  final String channelId;
  final TimelineTime time;
  final MotionPropertyValue value;
  final MotionInterpolationSpec interpolationToNext;

  MotionKeyframeModel copyWith({
    String? id,
    String? channelId,
    TimelineTime? time,
    MotionPropertyValue? value,
    MotionInterpolationSpec? interpolationToNext,
  }) {
    return MotionKeyframeModel(
      id: id ?? this.id,
      channelId: channelId ?? this.channelId,
      time: time ?? this.time,
      value: value ?? this.value,
      interpolationToNext: interpolationToNext ?? this.interpolationToNext,
    );
  }
}

@immutable
class MotionPropertyChannelModel {
  MotionPropertyChannelModel({
    required this.id,
    required this.target,
    required this.definition,
    this.activeRange,
    this.baseValue,
    this.beforeStart = MotionChannelExtrapolationMode.clamp,
    this.afterEnd = MotionChannelExtrapolationMode.clamp,
    List<MotionKeyframeModel> keyframes = const <MotionKeyframeModel>[],
  }) : keyframes = List.unmodifiable(keyframes) {
    assert(_validateKeyframes(keyframes), 'keyframes must be sorted by time');
    assert(
      _validateKeyframeKinds(keyframes, definition),
      'all keyframe values must match the property definition kind',
    );
    assert(
      baseValue == null || baseValue?.kind == definition.valueKind,
      'base value kind must match the property definition kind',
    );
  }

  final String id;
  final MotionPropertyTarget target;
  final MotionPropertyDefinition definition;
  final TimelineTimeRange? activeRange;
  final MotionPropertyValue? baseValue;
  final MotionChannelExtrapolationMode beforeStart;
  final MotionChannelExtrapolationMode afterEnd;
  final List<MotionKeyframeModel> keyframes;

  bool get isAnimated => keyframes.isNotEmpty;

  MotionPropertyValue get fallbackValue => baseValue ?? definition.defaultValue;

  MotionPropertyChannelModel copyWith({
    String? id,
    MotionPropertyTarget? target,
    MotionPropertyDefinition? definition,
    TimelineTimeRange? activeRange,
    bool clearActiveRange = false,
    MotionPropertyValue? baseValue,
    bool clearBaseValue = false,
    MotionChannelExtrapolationMode? beforeStart,
    MotionChannelExtrapolationMode? afterEnd,
    List<MotionKeyframeModel>? keyframes,
  }) {
    return MotionPropertyChannelModel(
      id: id ?? this.id,
      target: target ?? this.target,
      definition: definition ?? this.definition,
      activeRange: clearActiveRange ? null : (activeRange ?? this.activeRange),
      baseValue: clearBaseValue ? null : (baseValue ?? this.baseValue),
      beforeStart: beforeStart ?? this.beforeStart,
      afterEnd: afterEnd ?? this.afterEnd,
      keyframes: keyframes ?? this.keyframes,
    );
  }

  static bool _validateKeyframes(List<MotionKeyframeModel> keyframes) {
    for (var index = 1; index < keyframes.length; index += 1) {
      if (keyframes[index - 1].time > keyframes[index].time) {
        return false;
      }
    }
    return true;
  }

  static bool _validateKeyframeKinds(
    List<MotionKeyframeModel> keyframes,
    MotionPropertyDefinition definition,
  ) {
    for (final keyframe in keyframes) {
      if (keyframe.value.kind != definition.valueKind) {
        return false;
      }
    }
    return true;
  }
}
