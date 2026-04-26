import 'package:flutter/foundation.dart';

import '../../presentation/models/timeline_time.dart';
import '../models/professional_motion_animation_models.dart';
import '../models/professional_motion_interpolation_parsing.dart';
import '../models/professional_motion_models.dart';
import '../models/professional_normal_transition_models.dart';

@immutable
class NormalTransitionMotionGraphLoweringRequest {
  const NormalTransitionMotionGraphLoweringRequest({
    required this.node,
    required this.instance,
    required this.window,
    required this.outgoingTarget,
    required this.incomingTarget,
  });

  final NormalTransitionNode node;
  final NormalTransitionInstance instance;
  final NormalTransitionOverlapWindow window;
  final MotionPropertyTarget outgoingTarget;
  final MotionPropertyTarget incomingTarget;
}

@immutable
class NormalTransitionMotionGraphLoweringResult {
  NormalTransitionMotionGraphLoweringResult({
    required List<MotionPropertyChannelModel> channels,
    List<NormalTransitionIssue> issues = const <NormalTransitionIssue>[],
  })  : channels = List.unmodifiable(channels),
        issues = List.unmodifiable(issues);

  final List<MotionPropertyChannelModel> channels;
  final List<NormalTransitionIssue> issues;

  bool get hasErrors => issues.any(
        (issue) => issue.severity == NormalTransitionIssueSeverity.error,
      );
}

class NormalTransitionMotionGraphLowerer {
  const NormalTransitionMotionGraphLowerer();

  NormalTransitionMotionGraphLoweringResult lower(
    NormalTransitionMotionGraphLoweringRequest request,
  ) {
    final issues = <NormalTransitionIssue>[];
    final channels = <MotionPropertyChannelModel>[];
    final seenChannelIds = <String>{};
    final activeRange = TimelineTimeRange(
      start: TimelineTime.zero,
      endExclusive: request.window.duration,
    );

    for (var index = 0; index < request.instance.channels.length; index += 1) {
      final spec = request.instance.channels[index];
      final path = 'channels[$index]';
      final target = _targetForSpec(
        spec: spec,
        request: request,
        path: path,
        issues: issues,
      );
      final definition = _definitionForProperty(
        spec.property,
        path: '$path.property',
        issues: issues,
      );
      if (target == null || definition == null) {
        continue;
      }
      final keyframes = _lowerKeyframes(
        spec: spec,
        target: target,
        definition: definition,
        request: request,
        path: path,
        issues: issues,
      );
      if (keyframes.isEmpty) {
        issues.add(
          NormalTransitionIssue(
            severity: NormalTransitionIssueSeverity.error,
            message:
                'Transition channel `${spec.target}.${spec.property}` has no valid keyframes.',
            path: '$path.keyframes',
          ),
        );
        continue;
      }
      final channelId = _channelIdFor(
        nodeId: request.node.id,
        instanceId: request.instance.id,
        targetToken: spec.target,
        target: target,
        definition: definition,
      );
      if (!seenChannelIds.add(channelId)) {
        issues.add(
          NormalTransitionIssue(
            severity: NormalTransitionIssueSeverity.error,
            message:
                'Transition recipe produced duplicate channel `$channelId`.',
            path: path,
          ),
        );
        continue;
      }
      channels.add(
        MotionPropertyChannelModel(
          id: channelId,
          target: target,
          definition: definition,
          activeRange: activeRange,
          baseValue: definition.defaultValue,
          beforeStart: MotionChannelExtrapolationMode.clamp,
          afterEnd: MotionChannelExtrapolationMode.clamp,
          keyframes: keyframes,
        ),
      );
    }

    return NormalTransitionMotionGraphLoweringResult(
      channels: channels,
      issues: issues,
    );
  }

  MotionPropertyTarget? _targetForSpec({
    required NormalTransitionChannelSpec spec,
    required NormalTransitionMotionGraphLoweringRequest request,
    required String path,
    required List<NormalTransitionIssue> issues,
  }) {
    switch (_normalizeToken(spec.target)) {
      case 'from':
      case 'outgoing':
      case 'left':
      case 'a':
        return request.outgoingTarget;
      case 'to':
      case 'incoming':
      case 'right':
      case 'b':
        return request.incomingTarget;
    }
    issues.add(
      NormalTransitionIssue(
        severity: NormalTransitionIssueSeverity.error,
        message:
            'Unsupported transition target `${spec.target}`. Use `from` or `to`.',
        path: '$path.target',
      ),
    );
    return null;
  }

  MotionPropertyDefinition? _definitionForProperty(
    String property, {
    required String path,
    required List<NormalTransitionIssue> issues,
  }) {
    final normalized = _normalizeToken(property);
    final definition = switch (normalized) {
      'opacity' || 'alpha' || 'visualopacity' => MotionPropertyCatalog.opacity,
      'blur' ||
      'bluramount' ||
      'visualbluramount' =>
        MotionPropertyCatalog.blurAmount,
      'blurhorizontal' ||
      'visualblurhorizontal' =>
        MotionPropertyCatalog.blurHorizontal,
      'blurvertical' ||
      'visualblurvertical' =>
        MotionPropertyCatalog.blurVertical,
      'blurmix' || 'visualblurmix' => MotionPropertyCatalog.blurMix,
      'positionx' || 'transformpositionx' => MotionPropertyCatalog.positionX,
      'positiony' || 'transformpositiony' => MotionPropertyCatalog.positionY,
      'scalex' || 'transformscalex' => MotionPropertyCatalog.scaleX,
      'scaley' || 'transformscaley' => MotionPropertyCatalog.scaleY,
      'rotation' ||
      'rotationdegrees' ||
      'transformrotationdegrees' =>
        MotionPropertyCatalog.rotationDegrees,
      'shake' ||
      'shakeamount' ||
      'effectshakeamount' =>
        MotionPropertyCatalog.shakeAmount,
      _ => null,
    };
    if (definition == null) {
      issues.add(
        NormalTransitionIssue(
          severity: NormalTransitionIssueSeverity.error,
          message:
              'Unsupported transition property `$property` for graph lowering.',
          path: path,
        ),
      );
    }
    return definition;
  }

  List<MotionKeyframeModel> _lowerKeyframes({
    required NormalTransitionChannelSpec spec,
    required MotionPropertyTarget target,
    required MotionPropertyDefinition definition,
    required NormalTransitionMotionGraphLoweringRequest request,
    required String path,
    required List<NormalTransitionIssue> issues,
  }) {
    final channelId = _channelIdFor(
      nodeId: request.node.id,
      instanceId: request.instance.id,
      targetToken: spec.target,
      target: target,
      definition: definition,
    );
    final keyframes = <MotionKeyframeModel>[];
    final usedTimes = <int>{};
    for (var index = 0; index < spec.keyframes.length; index += 1) {
      final keyframe = spec.keyframes[index];
      final keyframePath = '$path.keyframes[$index]';
      final time = _timeForNormalizedPosition(
        normalizedTime: keyframe.normalizedTime,
        duration: request.window.duration,
      );
      if (!usedTimes.add(time.inProjectTicks)) {
        issues.add(
          NormalTransitionIssue(
            severity: NormalTransitionIssueSeverity.error,
            message:
                'Duplicate transition keyframe time `${keyframe.normalizedTime}`.',
            path: '$keyframePath.t',
          ),
        );
        continue;
      }
      final value = _valueForDefinition(
        raw: keyframe.value,
        definition: definition,
        parameterValues: request.instance.parameterValues,
        path: '$keyframePath.value',
        issues: issues,
      );
      if (value == null) {
        continue;
      }
      keyframes.add(
        MotionKeyframeModel(
          id: '$channelId.${time.inProjectTicks}',
          channelId: channelId,
          time: time,
          value: value,
          interpolationToNext: _interpolationFor(
            keyframe.easing,
            path: '$keyframePath.easing',
            issues: issues,
          ),
        ),
      );
    }
    keyframes.sort((left, right) => left.time.compareTo(right.time));
    return keyframes;
  }

  TimelineTime _timeForNormalizedPosition({
    required double normalizedTime,
    required TimelineTime duration,
  }) {
    if (normalizedTime <= 0) {
      return TimelineTime.zero;
    }
    if (normalizedTime >= 1) {
      return duration;
    }
    return TimelineTime.fromProjectTicks(
      (duration.inProjectTicks * normalizedTime).round(),
    );
  }

  MotionPropertyValue? _valueForDefinition({
    required Object raw,
    required MotionPropertyDefinition definition,
    required Map<String, Object> parameterValues,
    required String path,
    required List<NormalTransitionIssue> issues,
  }) {
    final resolved = _resolveParameterValue(raw, parameterValues);
    final value = switch (definition.valueKind) {
      MotionPropertyValueKind.scalar when resolved is num =>
        MotionPropertyValue.scalar(resolved.toDouble()),
      MotionPropertyValueKind.integer when resolved is int =>
        MotionPropertyValue.integer(resolved),
      MotionPropertyValueKind.boolean when resolved is bool =>
        MotionPropertyValue.boolean(resolved),
      MotionPropertyValueKind.stringValue when resolved is String =>
        MotionPropertyValue.stringValue(resolved),
      MotionPropertyValueKind.enumValue when resolved is String =>
        MotionPropertyValue.enumValue(resolved),
      MotionPropertyValueKind.colorArgb when resolved is int =>
        MotionPropertyValue.colorArgb(resolved),
      _ => null,
    };
    if (value == null) {
      issues.add(
        NormalTransitionIssue(
          severity: NormalTransitionIssueSeverity.error,
          message:
              'Value `$raw` cannot be lowered to `${definition.valueKind.name}`.',
          path: path,
        ),
      );
    }
    return value;
  }

  Object _resolveParameterValue(
    Object raw,
    Map<String, Object> parameterValues,
  ) {
    if (raw is! String) {
      return raw;
    }
    var token = raw.trim();
    if (token.startsWith(r'${') && token.endsWith('}')) {
      token = token.substring(2, token.length - 1);
    } else if (token.startsWith(r'$')) {
      token = token.substring(1);
    }
    token = token.trim();
    if (token.startsWith('parameters.')) {
      token = token.substring('parameters.'.length);
    }
    return parameterValues[token] ?? raw;
  }

  MotionInterpolationSpec _interpolationFor(
    String easing, {
    required String path,
    required List<NormalTransitionIssue> issues,
  }) {
    final parsed = tryParseNamedMotionInterpolationSpec(easing);
    if (parsed != null) {
      return parsed;
    }
    issues.add(
      NormalTransitionIssue(
        severity: NormalTransitionIssueSeverity.warning,
        message:
            'Unsupported transition easing `$easing` was replaced with linear.',
        path: path,
      ),
    );
    return const MotionInterpolationSpec.linear();
  }

  String _channelIdFor({
    required String nodeId,
    required String instanceId,
    required String targetToken,
    required MotionPropertyTarget target,
    required MotionPropertyDefinition definition,
  }) {
    return <String>[
      'transitionGraph',
      nodeId,
      instanceId,
      targetToken,
      target.canonicalAddress,
      definition.id,
    ].map(_sanitizeId).join('.');
  }

  String _normalizeToken(String value) {
    return value.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '').toLowerCase();
  }

  String _sanitizeId(String value) {
    final sanitized = value.replaceAll(RegExp(r'[^a-zA-Z0-9_\\-]+'), '_');
    return sanitized.isEmpty ? 'item' : sanitized;
  }
}
