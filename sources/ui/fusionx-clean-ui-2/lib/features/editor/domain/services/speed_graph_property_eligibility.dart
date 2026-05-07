import 'dart:developer' as developer;

import '../models/professional_motion_models.dart';

class SpeedGraphPropertyEligibility {
  const SpeedGraphPropertyEligibility({
    required this.supportsSpeedGraph,
    required this.supportsValueGraph,
    required this.supportsOvershoot,
    required this.decomposedChannels,
    required this.reason,
  });

  final bool supportsSpeedGraph;
  final bool supportsValueGraph;
  final bool supportsOvershoot;
  final List<String> decomposedChannels;
  final String reason;
}

class SpeedGraphPropertyEligibilityResolver {
  const SpeedGraphPropertyEligibilityResolver();

  SpeedGraphPropertyEligibility resolve(MotionPropertyDefinition definition) {
    final result = !definition.isAnimatable
        ? const SpeedGraphPropertyEligibility(
            supportsSpeedGraph: false,
            supportsValueGraph: false,
            supportsOvershoot: false,
            decomposedChannels: <String>[],
            reason: 'property_not_animatable',
          )
        : switch (definition.valueKind) {
            MotionPropertyValueKind.scalar ||
            MotionPropertyValueKind.integer =>
              SpeedGraphPropertyEligibility(
                supportsSpeedGraph: true,
                supportsValueGraph: true,
                supportsOvershoot: _supportsOvershoot(definition),
                decomposedChannels: const <String>['scalar'],
                reason: 'supported_scalar_channel',
              ),
            MotionPropertyValueKind.point2D =>
              const SpeedGraphPropertyEligibility(
                supportsSpeedGraph: true,
                supportsValueGraph: true,
                supportsOvershoot: true,
                decomposedChannels: <String>['x', 'y'],
                reason: 'supported_point2d_requires_channel_decomposition',
              ),
            MotionPropertyValueKind.size2D =>
              const SpeedGraphPropertyEligibility(
                supportsSpeedGraph: true,
                supportsValueGraph: true,
                supportsOvershoot: true,
                decomposedChannels: <String>['width', 'height'],
                reason: 'supported_size2d_requires_channel_decomposition',
              ),
            MotionPropertyValueKind.colorArgb =>
              const SpeedGraphPropertyEligibility(
                supportsSpeedGraph: false,
                supportsValueGraph: false,
                supportsOvershoot: false,
                decomposedChannels: <String>['a', 'r', 'g', 'b'],
                reason:
                    'unsupported_colorargb_requires_explicit_channel_mapper',
              ),
            MotionPropertyValueKind.rect => const SpeedGraphPropertyEligibility(
                supportsSpeedGraph: false,
                supportsValueGraph: false,
                supportsOvershoot: false,
                decomposedChannels: <String>['left', 'top', 'width', 'height'],
                reason: 'unsupported_rect_requires_explicit_channel_mapper',
              ),
            MotionPropertyValueKind.boolean =>
              const SpeedGraphPropertyEligibility(
                supportsSpeedGraph: false,
                supportsValueGraph: false,
                supportsOvershoot: false,
                decomposedChannels: <String>[],
                reason: 'unsupported_boolean',
              ),
            MotionPropertyValueKind.stringValue =>
              const SpeedGraphPropertyEligibility(
                supportsSpeedGraph: false,
                supportsValueGraph: false,
                supportsOvershoot: false,
                decomposedChannels: <String>[],
                reason: 'unsupported_string',
              ),
            MotionPropertyValueKind.enumValue =>
              const SpeedGraphPropertyEligibility(
                supportsSpeedGraph: false,
                supportsValueGraph: false,
                supportsOvershoot: false,
                decomposedChannels: <String>[],
                reason: 'unsupported_enum',
              ),
          };
    _emitPropertyEligibilityProof(definition, result);
    return result;
  }

  bool _supportsOvershoot(MotionPropertyDefinition definition) {
    final key = definition.path.canonicalKey;
    if (key.contains('opacity')) {
      return false;
    }
    if (key.contains('blur')) {
      return false;
    }
    return true;
  }

  void _emitPropertyEligibilityProof(
    MotionPropertyDefinition definition,
    SpeedGraphPropertyEligibility result,
  ) {
    developer.log(
      'TF_SPEED_GRAPH_PROPERTY_ELIGIBILITY_PROOF '
      'scope=global '
      'targetKind=${definition.supportedTargets.isNotEmpty ? definition.supportedTargets.first.name : 'unknown'} '
      'targetId=unknown '
      'propertyPath=${definition.path.canonicalKey} '
      'propertyKind=${definition.valueKind.name} '
      'decomposedChannels=${result.decomposedChannels.join("|")} '
      'supportsSpeedGraph=${result.supportsSpeedGraph} '
      'supportsValueGraph=${result.supportsValueGraph} '
      'supportsOvershoot=${result.supportsOvershoot} '
      'disabledReason=${result.reason}',
      name: 'ReFusionXx.SpeedGraph',
    );
  }
}
