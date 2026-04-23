import 'package:flutter/foundation.dart';

import '../../presentation/models/timeline_time.dart';
import 'professional_motion_compilation_models.dart';
import 'professional_motion_fx_models.dart';
import 'professional_motion_models.dart';
import 'professional_motion_text_models.dart';

enum MotionEvaluationReason {
  previewPlayback,
  liveScrub,
  settleAfterScrub,
  exportFrame,
  thumbnailRender,
  diagnostics,
}

enum MotionEvaluationStatus {
  resolved,
  defaulted,
  inactive,
  outOfRange,
  unsupported,
  missingData,
}

enum MotionActivationState {
  inactive,
  active,
}

@immutable
class MotionEvaluationRequest {
  const MotionEvaluationRequest({
    required this.composition,
    required this.time,
    this.reason = MotionEvaluationReason.previewPlayback,
    this.includeInactiveScenes = false,
    this.includeInactiveLayers = false,
    this.includeInactiveElements = false,
  });

  final MotionNormalizedComposition composition;
  final TimelineTime time;
  final MotionEvaluationReason reason;
  final bool includeInactiveScenes;
  final bool includeInactiveLayers;
  final bool includeInactiveElements;
}

@immutable
class MotionEvaluationDiagnostic {
  const MotionEvaluationDiagnostic({
    required this.code,
    required this.message,
    this.sceneId,
    this.layerId,
    this.elementId,
    this.propertyId,
    this.channelId,
  });

  final String code;
  final String message;
  final String? sceneId;
  final String? layerId;
  final String? elementId;
  final String? propertyId;
  final String? channelId;
}

@immutable
class MotionEvaluatedPropertyValue {
  const MotionEvaluatedPropertyValue({
    required this.target,
    required this.definition,
    required this.value,
    required this.status,
    this.channelId,
  });

  final MotionPropertyTarget target;
  final MotionPropertyDefinition definition;
  final MotionPropertyValue value;
  final MotionEvaluationStatus status;
  final String? channelId;
}

@immutable
class MotionEvaluatedElementState {
  MotionEvaluatedElementState({
    required this.id,
    required this.sourceElementId,
    required this.sceneId,
    required this.layerId,
    required this.kind,
    required this.projectRange,
    required this.activationState,
    required List<MotionEvaluatedPropertyValue> properties,
    this.name,
    this.shapeKind,
  }) : properties = List.unmodifiable(properties);

  final String id;
  final String sourceElementId;
  final String sceneId;
  final String layerId;
  final MotionElementKind kind;
  final TimelineTimeRange projectRange;
  final MotionActivationState activationState;
  final String? name;
  final MotionShapeKind? shapeKind;
  final List<MotionEvaluatedPropertyValue> properties;
}

@immutable
class MotionEvaluatedLayerState {
  MotionEvaluatedLayerState({
    required this.id,
    required this.sourceLayerId,
    required this.sceneId,
    required this.kind,
    required this.projectRange,
    required this.activationState,
    required List<MotionEvaluatedPropertyValue> properties,
    required List<MotionEvaluatedElementState> elements,
    this.name,
    this.zIndex = 0,
    this.blendMode = MotionBlendMode.normal,
  })  : properties = List.unmodifiable(properties),
        elements = List.unmodifiable(elements);

  final String id;
  final String sourceLayerId;
  final String sceneId;
  final MotionLayerKind kind;
  final TimelineTimeRange projectRange;
  final MotionActivationState activationState;
  final String? name;
  final int zIndex;
  final MotionBlendMode blendMode;
  final List<MotionEvaluatedPropertyValue> properties;
  final List<MotionEvaluatedElementState> elements;
}

@immutable
class MotionEvaluatedSceneState {
  MotionEvaluatedSceneState({
    required this.id,
    required this.sourceSceneId,
    required this.projectRange,
    required this.activationState,
    required List<MotionEvaluatedLayerState> layers,
    required List<MotionEvaluatedPropertyValue> properties,
    this.name,
    this.cameraLayerId,
  })  : layers = List.unmodifiable(layers),
        properties = List.unmodifiable(properties);

  final String id;
  final String sourceSceneId;
  final TimelineTimeRange projectRange;
  final MotionActivationState activationState;
  final String? name;
  final String? cameraLayerId;
  final List<MotionEvaluatedLayerState> layers;
  final List<MotionEvaluatedPropertyValue> properties;
}

@immutable
class MotionTransitionEvaluationState {
  MotionTransitionEvaluationState({
    required this.id,
    required this.targetRange,
    required this.progress,
    required this.activationState,
    Map<String, MotionPropertyValue> parameters =
        const <String, MotionPropertyValue>{},
  }) : parameters = Map.unmodifiable(parameters);

  final String id;
  final TimelineTimeRange targetRange;
  final double progress;
  final MotionActivationState activationState;
  final Map<String, MotionPropertyValue> parameters;
}

@immutable
class MotionEffectEvaluationState {
  MotionEffectEvaluationState({
    required this.id,
    required this.targetAddress,
    required this.activationState,
    Map<String, MotionPropertyValue> parameters =
        const <String, MotionPropertyValue>{},
  }) : parameters = Map.unmodifiable(parameters);

  final String id;
  final String targetAddress;
  final MotionActivationState activationState;
  final Map<String, MotionPropertyValue> parameters;
}

@immutable
class MotionEvaluatedCameraState {
  MotionEvaluatedCameraState({
    required this.id,
    required this.scope,
    required this.targetAddress,
    required this.activationState,
    required List<MotionEvaluatedPropertyValue> properties,
    this.name,
  }) : properties = List.unmodifiable(properties);

  final String id;
  final MotionCameraBindingScope scope;
  final String targetAddress;
  final MotionActivationState activationState;
  final List<MotionEvaluatedPropertyValue> properties;
  final String? name;
}

@immutable
class MotionEvaluatedTextAnimationState {
  MotionEvaluatedTextAnimationState({
    required this.id,
    required this.targetElementId,
    required this.targetAddress,
    required this.activationState,
    required this.revealUnit,
    this.revealDirection = MotionTextRevealDirection.forward,
    required List<MotionTextAnimationKind> animationKinds,
    this.presetId,
    this.revealProgress,
  }) : animationKinds = List.unmodifiable(animationKinds);

  final String id;
  final String targetElementId;
  final String targetAddress;
  final MotionActivationState activationState;
  final String? presetId;
  final double? revealProgress;
  final MotionTextRevealUnit revealUnit;
  final MotionTextRevealDirection revealDirection;
  final List<MotionTextAnimationKind> animationKinds;
}

@immutable
class MotionEvaluationSnapshot {
  MotionEvaluationSnapshot({
    required this.projectId,
    required this.time,
    required List<MotionEvaluatedSceneState> scenes,
    List<MotionTransitionEvaluationState> transitions =
        const <MotionTransitionEvaluationState>[],
    List<MotionEffectEvaluationState> effects =
        const <MotionEffectEvaluationState>[],
    List<MotionEvaluatedCameraState> cameras =
        const <MotionEvaluatedCameraState>[],
    List<MotionEvaluatedTextAnimationState> textAnimations =
        const <MotionEvaluatedTextAnimationState>[],
    List<MotionEvaluationDiagnostic> diagnostics =
        const <MotionEvaluationDiagnostic>[],
  })  : scenes = List.unmodifiable(scenes),
        transitions = List.unmodifiable(transitions),
        effects = List.unmodifiable(effects),
        cameras = List.unmodifiable(cameras),
        textAnimations = List.unmodifiable(textAnimations),
        diagnostics = List.unmodifiable(diagnostics);

  final String projectId;
  final TimelineTime time;
  final List<MotionEvaluatedSceneState> scenes;
  final List<MotionTransitionEvaluationState> transitions;
  final List<MotionEffectEvaluationState> effects;
  final List<MotionEvaluatedCameraState> cameras;
  final List<MotionEvaluatedTextAnimationState> textAnimations;
  final List<MotionEvaluationDiagnostic> diagnostics;

  MotionEvaluatedSceneState? get activeScene {
    for (final scene in scenes) {
      if (scene.activationState == MotionActivationState.active) {
        return scene;
      }
    }
    return null;
  }
}

abstract class MotionPropertyChannelSampler {
  const MotionPropertyChannelSampler();

  MotionEvaluatedPropertyValue sample({
    required MotionResolvedPropertyChannel channel,
    required TimelineTime time,
  });
}

abstract class MotionRuntimeEvaluator {
  const MotionRuntimeEvaluator();

  MotionEvaluationSnapshot evaluate(MotionEvaluationRequest request);
}
