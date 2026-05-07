import 'dart:developer' as developer;

import '../models/professional_motion_animation_models.dart';
import 'motion_bezier_velocity_bridge.dart';
import 'professional_speed_graph_preset_catalog.dart';

enum MotionInterpolationCompileInputMode {
  preset,
  velocityNumbers,
  directBezier,
  existingSpec,
  legacyEasing,
  aiScript,
}

enum ProfessionalSpeedGraphPresetId {
  linear,
  easyEase,
  easyEaseIn,
  easyEaseOut,
  slowFastSlow,
  fastSlowFast,
  fastSlow,
  slowFast,
  whipSnap,
  customSpeedGraph,
}

class MotionInterpolationCompileResult {
  const MotionInterpolationCompileResult({
    required this.interpolation,
    required this.inputMode,
    required this.executionTruth,
    required this.curveHash,
    required this.velocityHash,
    required this.compiled,
    this.fallbackReason,
    this.presetId,
  });

  final MotionInterpolationSpec interpolation;
  final MotionInterpolationCompileInputMode inputMode;
  final String executionTruth;
  final String curveHash;
  final String velocityHash;
  final bool compiled;
  final String? fallbackReason;
  final String? presetId;
}

class MotionInterpolationTruthCompiler {
  const MotionInterpolationTruthCompiler({
    MotionBezierVelocityBridge? bridge,
    ProfessionalSpeedGraphPresetCatalog? presetCatalog,
  })  : _bridge = bridge ?? const MotionBezierVelocityBridge(),
        _presetCatalog =
            presetCatalog ?? const ProfessionalSpeedGraphPresetCatalog();

  final MotionBezierVelocityBridge _bridge;
  final ProfessionalSpeedGraphPresetCatalog _presetCatalog;

  static const MotionInterpolationSpec _easyEaseBase =
      MotionInterpolationSpec.cubicBezier(
    bezier: MotionBezierControlPoints(
      x1: 0.3333,
      y1: 0.0,
      x2: 0.6667,
      y2: 1.0,
    ),
  );

  static String canonicalPresetId(String? rawPresetId) {
    final normalized = (rawPresetId ?? '')
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '');
    if (normalized == 'smoothstart') {
      return 'smoothStart';
    }
    if (normalized == 'smoothstop') {
      return 'smoothStop';
    }
    final catalog = ProfessionalSpeedGraphPresetCatalog();
    return catalog.canonicalId(rawPresetId);
  }

  MotionInterpolationCompileResult compileFromPresetId(String presetId) {
    final canonical = canonicalPresetId(presetId);
    final interpolation = _interpolationForPresetId(canonical);
    final result = _result(
      interpolation: interpolation,
      inputMode: MotionInterpolationCompileInputMode.preset,
      executionTruth: _executionTruthFor(interpolation),
      presetId: canonical,
    );
    _emitTruthCompilerProof(
      inputMode: MotionInterpolationCompileInputMode.preset,
      interpolation: result.interpolation,
      compiled: result.compiled,
      fallbackReason: result.fallbackReason,
      presetId: result.presetId,
      curveHash: result.curveHash,
      velocityHash: result.velocityHash,
    );
    return result;
  }

  MotionInterpolationCompileResult compileFromVelocity({
    required MotionKeyframeVelocity velocity,
    MotionInterpolationSpec? fallback,
    MotionPropertyOvershootPolicy overshootPolicy =
        MotionPropertyOvershootPolicy.disallow,
    MotionInterpolationCompileInputMode inputMode =
        MotionInterpolationCompileInputMode.velocityNumbers,
  }) {
    final canonicalPreset = canonicalPresetId(velocity.presetId);
    if (canonicalPreset != 'customSpeedGraph' && canonicalPreset != 'linear') {
      final presetInterpolation = _interpolationForPresetId(canonicalPreset);
      final result = _result(
        interpolation: presetInterpolation.copyWith(
          velocity: velocity.copyWith(presetId: canonicalPreset),
        ),
        inputMode: inputMode,
        executionTruth: _executionTruthFor(presetInterpolation),
        presetId: canonicalPreset,
      );
      _emitTruthCompilerProof(
        inputMode: inputMode,
        interpolation: result.interpolation,
        compiled: result.compiled,
        fallbackReason: result.fallbackReason,
        presetId: result.presetId,
        curveHash: result.curveHash,
        velocityHash: result.velocityHash,
      );
      return result;
    }

    final base = fallback ?? _easyEaseBase;
    final allowOvershoot =
        overshootPolicy == MotionPropertyOvershootPolicy.allowBezierOvershoot;
    final bezier = _bridge.velocityToBezier(
      velocity: velocity,
      allowOvershoot: allowOvershoot,
    );
    final interpolation = MotionInterpolationSpec.cubicBezier(
      bezier: bezier,
    ).copyWith(
      velocity: velocity.copyWith(presetId: 'customSpeedGraph'),
    );
    final result = _result(
      interpolation: interpolation,
      inputMode: inputMode,
      executionTruth: _executionTruthFor(base),
      presetId: 'customSpeedGraph',
    );
    _emitTruthCompilerProof(
      inputMode: inputMode,
      interpolation: result.interpolation,
      compiled: result.compiled,
      fallbackReason: result.fallbackReason,
      presetId: result.presetId,
      curveHash: result.curveHash,
      velocityHash: result.velocityHash,
    );
    return result;
  }

  MotionInterpolationCompileResult compileFromInterpolation({
    required MotionInterpolationSpec interpolation,
    MotionInterpolationCompileInputMode inputMode =
        MotionInterpolationCompileInputMode.existingSpec,
  }) {
    final normalized = interpolation.kind == MotionInterpolationKind.cubicBezier
        ? interpolation.copyWith(
            velocity: _bridge.bezierToVelocity(
              bezier: interpolation.bezier ?? _easyEaseBase.bezier!,
              presetId: canonicalPresetId(interpolation.velocity?.presetId),
              continuous: interpolation.velocity?.continuous ?? false,
            ),
          )
        : interpolation;
    final result = _result(
      interpolation: normalized,
      inputMode: inputMode,
      executionTruth: _executionTruthFor(normalized),
      presetId: normalized.velocity?.presetId,
    );
    _emitTruthCompilerProof(
      inputMode: inputMode,
      interpolation: result.interpolation,
      compiled: result.compiled,
      fallbackReason: result.fallbackReason,
      presetId: result.presetId,
      curveHash: result.curveHash,
      velocityHash: result.velocityHash,
    );
    return result;
  }

  MotionInterpolationCompileResult compileFromGraphPresetIndex(int index) {
    final presetId = switch (index.clamp(0, 9)) {
      0 => 'linear',
      1 => 'easyEase',
      2 => 'easyEaseIn',
      3 => 'easyEaseOut',
      4 => 'slowFastSlow',
      5 => 'fastSlow',
      6 => 'slowFast',
      7 => 'whipSnap',
      8 => 'customSpeedGraph',
      9 => 'fastSlowFast',
      _ => 'linear',
    };
    return compileFromPresetId(presetId);
  }

  MotionInterpolationSpec _interpolationForPresetId(String presetId) {
    switch (canonicalPresetId(presetId)) {
      case 'linear':
        return const MotionInterpolationSpec.linear().copyWith(
          velocity: const MotionKeyframeVelocity(
            incomingSpeed: 0.0,
            outgoingSpeed: 0.0,
            incomingInfluence: 0.0,
            outgoingInfluence: 0.0,
            incomingHandleLocked: true,
            outgoingHandleLocked: true,
            continuous: true,
            presetId: 'linear',
          ),
        );
      case 'easyEase':
        return _easyEaseBase.copyWith(
          velocity: const MotionKeyframeVelocity(
            incomingSpeed: 0.0,
            outgoingSpeed: 0.0,
            incomingInfluence: 33.333,
            outgoingInfluence: 33.333,
            incomingHandleLocked: true,
            outgoingHandleLocked: true,
            continuous: true,
            presetId: 'easyEase',
          ),
        );
      case 'easyEaseIn':
        return const MotionInterpolationSpec.cubicBezier(
          bezier: MotionBezierControlPoints(
            x1: 0.65,
            y1: 0.0,
            x2: 0.95,
            y2: 0.1,
          ),
        ).copyWith(
          velocity: const MotionKeyframeVelocity(
            incomingSpeed: 0.0,
            incomingInfluence: 33.333,
            incomingHandleLocked: true,
            continuous: true,
            presetId: 'easyEaseIn',
          ),
        );
      case 'easyEaseOut':
        return const MotionInterpolationSpec.cubicBezier(
          bezier: MotionBezierControlPoints(
            x1: 0.05,
            y1: 0.9,
            x2: 0.35,
            y2: 1.0,
          ),
        ).copyWith(
          velocity: const MotionKeyframeVelocity(
            outgoingSpeed: 0.0,
            outgoingInfluence: 33.333,
            outgoingHandleLocked: true,
            continuous: true,
            presetId: 'easyEaseOut',
          ),
        );
      case 'smoothStart':
        return const MotionInterpolationSpec.cubicBezier(
          bezier: MotionBezierControlPoints(
            x1: 0.65,
            y1: 0.0,
            x2: 0.95,
            y2: 0.1,
          ),
        ).copyWith(
          velocity: const MotionKeyframeVelocity(
            presetId: 'smoothStart',
          ),
        );
      case 'smoothStop':
        return const MotionInterpolationSpec.cubicBezier(
          bezier: MotionBezierControlPoints(
            x1: 0.05,
            y1: 0.9,
            x2: 0.35,
            y2: 1.0,
          ),
        ).copyWith(
          velocity: const MotionKeyframeVelocity(
            presetId: 'smoothStop',
          ),
        );
      case 'slowFastSlow':
        return const MotionInterpolationSpec.cubicBezier(
          bezier: MotionBezierControlPoints(
            x1: 0.2,
            y1: 0.0,
            x2: 0.8,
            y2: 1.0,
          ),
        ).copyWith(
          velocity: const MotionKeyframeVelocity(
            incomingInfluence: 85.0,
            outgoingInfluence: 85.0,
            continuous: true,
            presetId: 'slowFastSlow',
          ),
        );
      case 'fastSlowFast':
        return const MotionInterpolationSpec.cubicBezier(
          bezier: MotionBezierControlPoints(
            x1: 0.12,
            y1: 0.72,
            x2: 0.88,
            y2: 0.28,
          ),
        ).copyWith(
          velocity: const MotionKeyframeVelocity(
            incomingInfluence: 88.0,
            outgoingInfluence: 88.0,
            continuous: false,
            presetId: 'fastSlowFast',
          ),
        );
      case 'fastSlow':
        return const MotionInterpolationSpec.cubicBezier(
          bezier: MotionBezierControlPoints(
            x1: 0.05,
            y1: 0.9,
            x2: 0.35,
            y2: 1.0,
          ),
        ).copyWith(
          velocity: const MotionKeyframeVelocity(
            incomingSpeed: 70.0,
            outgoingSpeed: 20.0,
            incomingInfluence: 15.0,
            outgoingInfluence: 75.0,
            continuous: false,
            presetId: 'fastSlow',
          ),
        );
      case 'slowFast':
        return const MotionInterpolationSpec.cubicBezier(
          bezier: MotionBezierControlPoints(
            x1: 0.65,
            y1: 0.0,
            x2: 0.95,
            y2: 0.1,
          ),
        ).copyWith(
          velocity: const MotionKeyframeVelocity(
            incomingSpeed: 20.0,
            outgoingSpeed: 70.0,
            incomingInfluence: 75.0,
            outgoingInfluence: 15.0,
            continuous: false,
            presetId: 'slowFast',
          ),
        );
      case 'whipSnap':
        return const MotionInterpolationSpec.cubicBezier(
          bezier: MotionBezierControlPoints(
            x1: 0.05,
            y1: 0.0,
            x2: 0.25,
            y2: 1.0,
          ),
        ).copyWith(
          velocity: const MotionKeyframeVelocity(
            incomingSpeed: 30.0,
            outgoingSpeed: 120.0,
            incomingInfluence: 10.0,
            outgoingInfluence: 95.0,
            continuous: false,
            presetId: 'whipSnap',
          ),
        );
      case 'customSpeedGraph':
        final customPreset = _presetCatalog.findById('customSpeedGraph');
        return MotionInterpolationSpec.cubicBezier(
          bezier: customPreset?.bezier ?? _easyEaseBase.bezier!,
        ).copyWith(
          velocity: const MotionKeyframeVelocity(
            continuous: false,
            presetId: 'customSpeedGraph',
          ),
        );
      default:
        final preset = _presetCatalog.findByAlias(presetId);
        if (preset == null) {
          return const MotionInterpolationSpec.linear();
        }
        if (preset.linear) {
          return const MotionInterpolationSpec.linear().copyWith(
            velocity: const MotionKeyframeVelocity(
              presetId: 'linear',
              incomingInfluence: 0.0,
              outgoingInfluence: 0.0,
              incomingSpeed: 0.0,
              outgoingSpeed: 0.0,
              incomingHandleLocked: true,
              outgoingHandleLocked: true,
              continuous: true,
            ),
          );
        }
        return MotionInterpolationSpec.cubicBezier(
          bezier: preset.bezier,
        ).copyWith(
          velocity: MotionKeyframeVelocity(
            presetId: preset.id,
            continuous: true,
          ),
        );
    }
  }

  MotionInterpolationCompileResult _result({
    required MotionInterpolationSpec interpolation,
    required MotionInterpolationCompileInputMode inputMode,
    required String executionTruth,
    String? presetId,
    String? fallbackReason,
  }) {
    final bezier = interpolation.bezier;
    final velocity = interpolation.velocity;
    final curveHash = '${interpolation.kind.name}:'
        '${bezier?.x1.toStringAsFixed(6) ?? 'na'}:'
        '${bezier?.y1.toStringAsFixed(6) ?? 'na'}:'
        '${bezier?.x2.toStringAsFixed(6) ?? 'na'}:'
        '${bezier?.y2.toStringAsFixed(6) ?? 'na'}';
    final velocityHash = '${velocity?.presetId ?? 'none'}:'
        '${velocity?.incomingSpeed?.toStringAsFixed(4) ?? 'na'}:'
        '${velocity?.outgoingSpeed?.toStringAsFixed(4) ?? 'na'}:'
        '${velocity?.incomingInfluence?.toStringAsFixed(4) ?? 'na'}:'
        '${velocity?.outgoingInfluence?.toStringAsFixed(4) ?? 'na'}:'
        '${velocity?.continuous ?? false}';
    return MotionInterpolationCompileResult(
      interpolation: interpolation,
      inputMode: inputMode,
      executionTruth: executionTruth,
      curveHash: curveHash,
      velocityHash: velocityHash,
      compiled: true,
      fallbackReason: fallbackReason,
      presetId: presetId,
    );
  }

  String _executionTruthFor(MotionInterpolationSpec interpolation) {
    return switch (interpolation.kind) {
      MotionInterpolationKind.cubicBezier => 'bezier',
      MotionInterpolationKind.spring => 'spring',
      MotionInterpolationKind.bounce => 'bounce',
      MotionInterpolationKind.elastic => 'elastic',
      MotionInterpolationKind.hold => 'hold',
      MotionInterpolationKind.linear => 'linear',
      MotionInterpolationKind.easeIn => 'easeIn',
      MotionInterpolationKind.easeOut => 'easeOut',
      MotionInterpolationKind.easeInOut => 'easeInOut',
    };
  }

  void _emitTruthCompilerProof({
    required MotionInterpolationCompileInputMode inputMode,
    required MotionInterpolationSpec interpolation,
    required bool compiled,
    required String? fallbackReason,
    required String? presetId,
    required String curveHash,
    required String velocityHash,
  }) {
    developer.log(
      'TF_SPEED_GRAPH_TRUTH_COMPILER_PROOF '
      'inputMode=${inputMode.name} '
      'executionTruth=${_executionTruthFor(interpolation)} '
      'presetId=${presetId ?? 'none'} '
      'curveHash=$curveHash '
      'velocityHash=$velocityHash '
      'compiled=$compiled '
      'fallbackReason=${fallbackReason ?? 'none'}',
      name: 'ReFusionXx.SpeedGraph',
    );
  }
}
