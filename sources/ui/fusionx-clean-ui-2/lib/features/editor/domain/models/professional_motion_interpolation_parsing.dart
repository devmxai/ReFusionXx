import 'dart:developer' as developer;

import 'professional_motion_animation_models.dart';
import '../services/motion_interpolation_truth_compiler.dart';

class MotionInterpolationParseException implements Exception {
  const MotionInterpolationParseException(this.message);

  final String message;
}

final MotionInterpolationTruthCompiler _truthCompiler =
    MotionInterpolationTruthCompiler();

MotionInterpolationKind? tryParseCanonicalMotionInterpolationKind(String raw) {
  switch (_normalizeInterpolationToken(raw)) {
    case 'hold':
      return MotionInterpolationKind.hold;
    case 'linear':
      return MotionInterpolationKind.linear;
    case 'easein':
      return MotionInterpolationKind.easeIn;
    case 'easeout':
      return MotionInterpolationKind.easeOut;
    case 'easeinout':
      return MotionInterpolationKind.easeInOut;
    case 'cubicbezier':
      return MotionInterpolationKind.cubicBezier;
    case 'spring':
      return MotionInterpolationKind.spring;
    case 'bounce':
      return MotionInterpolationKind.bounce;
    case 'elastic':
      return MotionInterpolationKind.elastic;
  }
  return null;
}

MotionInterpolationSpec canonicalInterpolationSpecFromKind(
  MotionInterpolationKind kind,
) {
  switch (kind) {
    case MotionInterpolationKind.hold:
      return const MotionInterpolationSpec.hold();
    case MotionInterpolationKind.linear:
      return const MotionInterpolationSpec.linear();
    case MotionInterpolationKind.easeIn:
      return const MotionInterpolationSpec.easeIn();
    case MotionInterpolationKind.easeOut:
      return const MotionInterpolationSpec.easeOut();
    case MotionInterpolationKind.easeInOut:
      return const MotionInterpolationSpec.easeInOut();
    case MotionInterpolationKind.cubicBezier:
      return const MotionInterpolationSpec.cubicBezier(
        bezier: MotionBezierControlPoints(
          x1: 0.25,
          y1: 0.1,
          x2: 0.25,
          y2: 1.0,
        ),
      );
    case MotionInterpolationKind.spring:
      return const MotionInterpolationSpec.spring();
    case MotionInterpolationKind.bounce:
      return const MotionInterpolationSpec.bounce();
    case MotionInterpolationKind.elastic:
      return const MotionInterpolationSpec.elastic();
  }
}

MotionInterpolationSpec? tryParseNamedMotionInterpolationSpec(String raw) {
  final normalized = _normalizeInterpolationToken(raw);
  if (const <String>{
    'easyease',
    'f9',
    'slowfastslow',
    'cinematicease',
    'easyeasein',
    'easyeaseout',
    'fastslow',
    'slowfast',
    'whip',
    'whipsnap',
    'smoothstart',
    'smoothstop',
    'speedgraph',
    'velocitygraph',
    'customspeedgraph',
    'fastslowfast',
    'plateau',
    'holdmiddle',
  }.contains(normalized)) {
    return _truthCompiler.compileFromPresetId(raw).interpolation;
  }
  final kind = tryParseCanonicalMotionInterpolationKind(raw);
  if (kind == null) {
    return null;
  }
  return canonicalInterpolationSpecFromKind(kind);
}

MotionInterpolationSpec parseCanonicalMotionInterpolationObject(
  Map<String, dynamic> json,
) {
  final velocity = _readOptionalVelocityContract(json);
  final rawKind = _readOptionalStringAlias(json, const <String>['kind']);
  if ((rawKind == null || rawKind.trim().isEmpty) && velocity != null) {
    final interpolation = _truthCompiler
        .compileFromVelocity(
          velocity: velocity.copyWith(
            presetId: velocity.presetId ?? 'customSpeedGraph',
          ),
          inputMode: MotionInterpolationCompileInputMode.aiScript,
        )
        .interpolation;
    _emitVelocityAiScriptProof(
      inputShape: 'velocity_only',
      presetId: interpolation.velocity?.presetId,
      interpolation: interpolation,
    );
    return interpolation;
  }
  if (rawKind == null || rawKind.trim().isEmpty) {
    throw MotionInterpolationParseException(
      'Missing required `kind`.',
    );
  }
  final normalizedKind = _normalizeInterpolationToken(rawKind);
  final named = tryParseNamedMotionInterpolationSpec(normalizedKind);
  if (named != null &&
      tryParseCanonicalMotionInterpolationKind(normalizedKind) == null) {
    if (velocity == null) {
      _emitVelocityAiScriptProof(
        inputShape: 'named_preset',
        presetId: MotionInterpolationTruthCompiler.canonicalPresetId(rawKind),
        interpolation: named,
      );
      return named;
    }
    final interpolation = _truthCompiler
        .compileFromVelocity(
          velocity: velocity.copyWith(
            presetId: velocity.presetId ??
                MotionInterpolationTruthCompiler.canonicalPresetId(rawKind),
          ),
          fallback: named,
          inputMode: MotionInterpolationCompileInputMode.aiScript,
        )
        .interpolation;
    _emitVelocityAiScriptProof(
      inputShape: 'named_preset_with_velocity',
      presetId: interpolation.velocity?.presetId,
      interpolation: interpolation,
    );
    return interpolation;
  }
  final kind = tryParseCanonicalMotionInterpolationKind(rawKind);
  if (kind == null) {
    throw MotionInterpolationParseException(
      'Unsupported interpolation kind `$rawKind`.',
    );
  }
  switch (kind) {
    case MotionInterpolationKind.cubicBezier:
      final interpolation = MotionInterpolationSpec.cubicBezier(
        bezier: MotionBezierControlPoints(
          x1: _readRequiredDoubleAlias(json, const <String>['x1']),
          y1: _readRequiredDoubleAlias(json, const <String>['y1']),
          x2: _readRequiredDoubleAlias(json, const <String>['x2']),
          y2: _readRequiredDoubleAlias(json, const <String>['y2']),
        ),
      );
      if (velocity == null) {
        final compiled = _truthCompiler
            .compileFromInterpolation(
              interpolation: interpolation,
              inputMode: MotionInterpolationCompileInputMode.aiScript,
            )
            .interpolation;
        _emitVelocityAiScriptProof(
          inputShape: 'direct_bezier',
          presetId: compiled.velocity?.presetId,
          interpolation: compiled,
        );
        return compiled;
      }
      final compiled = _truthCompiler
          .compileFromVelocity(
            velocity: velocity,
            fallback: interpolation,
            inputMode: MotionInterpolationCompileInputMode.aiScript,
          )
          .interpolation;
      _emitVelocityAiScriptProof(
        inputShape: 'direct_bezier_with_velocity',
        presetId: compiled.velocity?.presetId,
        interpolation: compiled,
      );
      return compiled;
    case MotionInterpolationKind.spring:
      final spring = MotionInterpolationSpec.spring(
        spring: MotionSpringSpec(
          stiffness:
              _readOptionalDoubleAlias(json, const <String>['stiffness']) ??
                  kDefaultMotionSpringSpec.stiffness,
          damping: _readOptionalDoubleAlias(json, const <String>['damping']) ??
              kDefaultMotionSpringSpec.damping,
          mass: _readOptionalDoubleAlias(json, const <String>['mass']) ??
              kDefaultMotionSpringSpec.mass,
          initialVelocity: _readOptionalDoubleAlias(
                json,
                const <String>['initialVelocity', 'initial_velocity'],
              ) ??
              kDefaultMotionSpringSpec.initialVelocity,
        ),
      ).copyWith(velocity: velocity);
      _emitVelocityAiScriptProof(
        inputShape: 'spring',
        presetId: spring.velocity?.presetId,
        interpolation: spring,
      );
      return spring;
    case MotionInterpolationKind.bounce:
      final bounce = MotionInterpolationSpec.bounce(
        bounce: MotionBounceSpec(
          amplitude:
              _readOptionalDoubleAlias(json, const <String>['amplitude']) ??
                  kDefaultMotionBounceSpec.amplitude,
          bounces: _readOptionalIntAlias(
                json,
                const <String>['bounces', 'bounceCount', 'bounce_count'],
              ) ??
              kDefaultMotionBounceSpec.bounces,
          decay: _readOptionalDoubleAlias(json, const <String>['decay']) ??
              kDefaultMotionBounceSpec.decay,
        ),
      ).copyWith(velocity: velocity);
      _emitVelocityAiScriptProof(
        inputShape: 'bounce',
        presetId: bounce.velocity?.presetId,
        interpolation: bounce,
      );
      return bounce;
    case MotionInterpolationKind.elastic:
      final elastic = MotionInterpolationSpec.elastic(
        elastic: MotionElasticSpec(
          amplitude:
              _readOptionalDoubleAlias(json, const <String>['amplitude']) ??
                  kDefaultMotionElasticSpec.amplitude,
          period: _readOptionalDoubleAlias(json, const <String>['period']) ??
              kDefaultMotionElasticSpec.period,
          decay: _readOptionalDoubleAlias(json, const <String>['decay']) ??
              kDefaultMotionElasticSpec.decay,
        ),
      ).copyWith(velocity: velocity);
      _emitVelocityAiScriptProof(
        inputShape: 'elastic',
        presetId: elastic.velocity?.presetId,
        interpolation: elastic,
      );
      return elastic;
    case MotionInterpolationKind.hold:
    case MotionInterpolationKind.linear:
    case MotionInterpolationKind.easeIn:
    case MotionInterpolationKind.easeOut:
    case MotionInterpolationKind.easeInOut:
      final temporal = canonicalInterpolationSpecFromKind(kind).copyWith(
        velocity: velocity,
      );
      _emitVelocityAiScriptProof(
        inputShape: 'canonical_kind',
        presetId: temporal.velocity?.presetId,
        interpolation: temporal,
      );
      return temporal;
  }
}

void _emitVelocityAiScriptProof({
  required String inputShape,
  required MotionInterpolationSpec interpolation,
  String? presetId,
  List<String> unsupportedKeys = const <String>[],
  String fallbackReason = 'none',
}) {
  final compiled = _truthCompiler.compileFromInterpolation(
    interpolation: interpolation,
    inputMode: MotionInterpolationCompileInputMode.aiScript,
  );
  final bezier = compiled.interpolation.bezier;
  developer.log(
    'TF_VELOCITY_AI_SCRIPT_PROOF '
    'inputShape=$inputShape '
    'presetId=${presetId ?? compiled.interpolation.velocity?.presetId ?? 'none'} '
    'parsedKind=${compiled.interpolation.kind.name} '
    'bezier='
    '${bezier?.x1.toStringAsFixed(4) ?? 'na'},'
    '${bezier?.y1.toStringAsFixed(4) ?? 'na'},'
    '${bezier?.x2.toStringAsFixed(4) ?? 'na'},'
    '${bezier?.y2.toStringAsFixed(4) ?? 'na'} '
    'curveHash=${compiled.curveHash} '
    'unsupportedKeys=${unsupportedKeys.join("|")} '
    'compiledToExecutionTruth=${compiled.executionTruth} '
    'fallbackReason=$fallbackReason',
    name: 'ReFusionXx.SpeedGraph',
  );
}

MotionKeyframeVelocity? _readOptionalVelocityContract(
  Map<String, dynamic> json,
) {
  final dynamic rawVelocity = json['velocity'] ?? json['velocityContract'];
  if (rawVelocity is! Map<Object?, Object?>) {
    return null;
  }
  final velocity = <String, dynamic>{};
  for (final entry in rawVelocity.entries) {
    final key = entry.key;
    if (key is String) {
      velocity[key] = entry.value;
    }
  }
  return MotionKeyframeVelocity(
    incomingSpeed: _readOptionalDoubleAlias(velocity, const <String>[
      'incomingSpeed',
      'inSpeed',
      'in_speed',
    ]),
    outgoingSpeed: _readOptionalDoubleAlias(velocity, const <String>[
      'outgoingSpeed',
      'outSpeed',
      'out_speed',
    ]),
    incomingInfluence: _readOptionalDoubleAlias(velocity, const <String>[
      'incomingInfluence',
      'inInfluence',
      'in_influence',
    ]),
    outgoingInfluence: _readOptionalDoubleAlias(velocity, const <String>[
      'outgoingInfluence',
      'outInfluence',
      'out_influence',
    ]),
    incomingHandleLocked: _readOptionalBoolAlias(velocity, const <String>[
          'incomingHandleLocked',
          'inHandleLocked',
          'in_handle_locked',
        ]) ??
        false,
    outgoingHandleLocked: _readOptionalBoolAlias(velocity, const <String>[
          'outgoingHandleLocked',
          'outHandleLocked',
          'out_handle_locked',
        ]) ??
        false,
    continuous:
        _readOptionalBoolAlias(velocity, const <String>['continuous']) ?? false,
    roving: _readOptionalBoolAlias(velocity, const <String>['roving']) ?? false,
    presetId: _readOptionalStringAlias(velocity, const <String>[
      'presetId',
      'preset',
      'profile',
    ]),
  );
}

String _normalizeInterpolationToken(String raw) =>
    raw.trim().toLowerCase().replaceAll('_', '').replaceAll('-', '');

String _readRequiredStringAlias(
  Map<String, dynamic> json,
  List<String> keys,
) {
  for (final key in keys) {
    final value = json[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  throw MotionInterpolationParseException(
    'Missing required `${keys.join(' or ')}`.',
  );
}

double _readRequiredDoubleAlias(
  Map<String, dynamic> json,
  List<String> keys,
) {
  final value = _readOptionalDoubleAlias(json, keys);
  if (value != null) {
    return value;
  }
  throw MotionInterpolationParseException(
    'Missing required `${keys.join(' or ')}`.',
  );
}

double? _readOptionalDoubleAlias(
  Map<String, dynamic> json,
  List<String> keys,
) {
  for (final key in keys) {
    final value = json[key];
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      final parsed = double.tryParse(value.trim());
      if (parsed != null) {
        return parsed;
      }
    }
  }
  return null;
}

int? _readOptionalIntAlias(
  Map<String, dynamic> json,
  List<String> keys,
) {
  for (final key in keys) {
    final value = json[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null) {
        return parsed;
      }
    }
  }
  return null;
}

bool? _readOptionalBoolAlias(
  Map<String, dynamic> json,
  List<String> keys,
) {
  for (final key in keys) {
    final value = json[key];
    if (value is bool) {
      return value;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
        return true;
      }
      if (normalized == 'false' || normalized == '0' || normalized == 'no') {
        return false;
      }
    }
    if (value is num) {
      return value != 0;
    }
  }
  return null;
}

String? _readOptionalStringAlias(
  Map<String, dynamic> json,
  List<String> keys,
) {
  for (final key in keys) {
    final value = json[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  return null;
}
