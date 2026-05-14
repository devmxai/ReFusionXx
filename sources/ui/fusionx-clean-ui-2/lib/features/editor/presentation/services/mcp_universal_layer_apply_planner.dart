import 'mcp_universal_layer_identity.dart';

enum UniversalLayerApplyDecisionType {
  insertNewLayer,
  updateExistingLayer,
  applyStyleToExistingLayer,
  applyTransformToExistingLayer,
  applyEffectToExistingLayer,
  applyMotionToExistingLayer,
  skipDuplicatePayload,
  blockUnresolvedUpdate,
  blockAmbiguousTarget,
  blockUnsupportedTarget,
  blockUnsafeFallback,
}

class UniversalLayerApplyDiagnostic {
  const UniversalLayerApplyDiagnostic({
    required this.decision,
    required this.remoteLayerId,
    required this.canonicalTargetId,
    required this.targetKind,
    required this.targetFamily,
    required this.resolutionSource,
    required this.payloadSignature,
    required this.createdNewLayer,
    required this.updatedExistingLayer,
    required this.appliedStyle,
    required this.appliedTransform,
    required this.appliedEffect,
    required this.appliedMotion,
    required this.blockedUnresolvedUpdate,
    required this.blockedAmbiguousTarget,
    required this.blockedUnsafeFallback,
    required this.layerCountBefore,
    required this.layerCountAfter,
    required this.blockers,
  });

  final UniversalLayerApplyDecisionType decision;
  final String remoteLayerId;
  final String? canonicalTargetId;
  final UniversalLayerTargetKind targetKind;
  final String targetFamily;
  final String resolutionSource;
  final String payloadSignature;
  final bool createdNewLayer;
  final bool updatedExistingLayer;
  final bool appliedStyle;
  final bool appliedTransform;
  final bool appliedEffect;
  final bool appliedMotion;
  final bool blockedUnresolvedUpdate;
  final bool blockedAmbiguousTarget;
  final bool blockedUnsafeFallback;
  final int layerCountBefore;
  final int layerCountAfter;
  final List<String> blockers;
}

class UniversalLayerRuntimeUpdatePlanner {
  const UniversalLayerRuntimeUpdatePlanner();

  UniversalLayerApplyDiagnostic plan({
    required String remoteLayerId,
    required String payloadSignature,
    required int layerCountBefore,
    required UniversalLayerApplyIntent intent,
    required UniversalLayerResolution resolution,
    required String? previousPayloadSignature,
  }) {
    if (resolution.result == UniversalLayerResolutionResult.resolvedSingle &&
        previousPayloadSignature != null &&
        previousPayloadSignature == payloadSignature) {
      return _diagnostic(
        decision: UniversalLayerApplyDecisionType.skipDuplicatePayload,
        remoteLayerId: remoteLayerId,
        payloadSignature: payloadSignature,
        resolution: resolution,
        layerCountBefore: layerCountBefore,
        layerCountAfter: layerCountBefore,
        blockers: const <String>[],
      );
    }
    if (_requiresResolvedTarget(intent)) {
      if (resolution.result ==
          UniversalLayerResolutionResult.resolvedAmbiguous) {
        return _diagnostic(
          decision: UniversalLayerApplyDecisionType.blockAmbiguousTarget,
          remoteLayerId: remoteLayerId,
          payloadSignature: payloadSignature,
          resolution: resolution,
          layerCountBefore: layerCountBefore,
          layerCountAfter: layerCountBefore,
          blockers: const <String>['AMBIGUOUS_TARGET'],
        );
      }
      if (resolution.result == UniversalLayerResolutionResult.missingTarget) {
        return _diagnostic(
          decision: UniversalLayerApplyDecisionType.blockUnresolvedUpdate,
          remoteLayerId: remoteLayerId,
          payloadSignature: payloadSignature,
          resolution: resolution,
          layerCountBefore: layerCountBefore,
          layerCountAfter: layerCountBefore,
          blockers: const <String>['TARGET_NOT_FOUND'],
        );
      }
      if (resolution.result ==
          UniversalLayerResolutionResult.blockedUnsafeFallback) {
        return _diagnostic(
          decision: UniversalLayerApplyDecisionType.blockUnsafeFallback,
          remoteLayerId: remoteLayerId,
          payloadSignature: payloadSignature,
          resolution: resolution,
          layerCountBefore: layerCountBefore,
          layerCountAfter: layerCountBefore,
          blockers: const <String>['UNSAFE_FALLBACK_BLOCKED'],
        );
      }
    }
    if (intent == UniversalLayerApplyIntent.insert &&
        resolution.result != UniversalLayerResolutionResult.resolvedSingle) {
      return _diagnostic(
        decision: UniversalLayerApplyDecisionType.insertNewLayer,
        remoteLayerId: remoteLayerId,
        payloadSignature: payloadSignature,
        resolution: resolution,
        layerCountBefore: layerCountBefore,
        layerCountAfter: layerCountBefore + 1,
        blockers: const <String>[],
      );
    }
    return _diagnostic(
      decision: _decisionForIntent(intent),
      remoteLayerId: remoteLayerId,
      payloadSignature: payloadSignature,
      resolution: resolution,
      layerCountBefore: layerCountBefore,
      layerCountAfter: layerCountBefore,
      blockers: const <String>[],
    );
  }

  bool _requiresResolvedTarget(UniversalLayerApplyIntent intent) {
    return intent == UniversalLayerApplyIntent.update ||
        intent == UniversalLayerApplyIntent.styleMutation ||
        intent == UniversalLayerApplyIntent.transformMutation ||
        intent == UniversalLayerApplyIntent.effectMutation ||
        intent == UniversalLayerApplyIntent.motionMutation;
  }

  UniversalLayerApplyDecisionType _decisionForIntent(
    UniversalLayerApplyIntent intent,
  ) {
    switch (intent) {
      case UniversalLayerApplyIntent.styleMutation:
        return UniversalLayerApplyDecisionType.applyStyleToExistingLayer;
      case UniversalLayerApplyIntent.transformMutation:
        return UniversalLayerApplyDecisionType.applyTransformToExistingLayer;
      case UniversalLayerApplyIntent.effectMutation:
        return UniversalLayerApplyDecisionType.applyEffectToExistingLayer;
      case UniversalLayerApplyIntent.motionMutation:
        return UniversalLayerApplyDecisionType.applyMotionToExistingLayer;
      case UniversalLayerApplyIntent.insert:
        return UniversalLayerApplyDecisionType.insertNewLayer;
      case UniversalLayerApplyIntent.update:
      case UniversalLayerApplyIntent.deleteOperation:
      case UniversalLayerApplyIntent.unknown:
        return UniversalLayerApplyDecisionType.updateExistingLayer;
    }
  }

  UniversalLayerApplyDiagnostic _diagnostic({
    required UniversalLayerApplyDecisionType decision,
    required String remoteLayerId,
    required String payloadSignature,
    required UniversalLayerResolution resolution,
    required int layerCountBefore,
    required int layerCountAfter,
    required List<String> blockers,
  }) {
    final target = resolution.target;
    return UniversalLayerApplyDiagnostic(
      decision: decision,
      remoteLayerId: remoteLayerId,
      canonicalTargetId: target?.canonicalTargetId,
      targetKind: target?.targetKind ?? UniversalLayerTargetKind.unknownLayer,
      targetFamily: target?.targetFamily ?? 'unknown',
      resolutionSource: target?.resolutionSource ?? 'none',
      payloadSignature: payloadSignature,
      createdNewLayer:
          decision == UniversalLayerApplyDecisionType.insertNewLayer,
      updatedExistingLayer:
          decision == UniversalLayerApplyDecisionType.updateExistingLayer,
      appliedStyle:
          decision == UniversalLayerApplyDecisionType.applyStyleToExistingLayer,
      appliedTransform: decision ==
          UniversalLayerApplyDecisionType.applyTransformToExistingLayer,
      appliedEffect: decision ==
          UniversalLayerApplyDecisionType.applyEffectToExistingLayer,
      appliedMotion: decision ==
          UniversalLayerApplyDecisionType.applyMotionToExistingLayer,
      blockedUnresolvedUpdate:
          decision == UniversalLayerApplyDecisionType.blockUnresolvedUpdate,
      blockedAmbiguousTarget:
          decision == UniversalLayerApplyDecisionType.blockAmbiguousTarget,
      blockedUnsafeFallback:
          decision == UniversalLayerApplyDecisionType.blockUnsafeFallback,
      layerCountBefore: layerCountBefore,
      layerCountAfter: layerCountAfter,
      blockers: blockers,
    );
  }
}
