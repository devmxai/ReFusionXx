import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../../presentation/models/timeline_time.dart';
import 'professional_motion_animation_models.dart';
import 'professional_motion_fx_models.dart';
import 'professional_motion_models.dart';
import 'professional_motion_text_models.dart';

enum MotionAuthoringSourceKind {
  manualTimeline,
  manualKeyframes,
  script,
  preset,
  template,
  aiGenerated,
}

enum MotionCompileIssueSeverity {
  info,
  warning,
  error,
}

enum MotionCompileIssueCode {
  duplicateId,
  missingScene,
  missingLayer,
  missingElement,
  missingTarget,
  invalidRange,
  invalidPropertyValue,
  unsupportedTarget,
  unresolvedSource,
  unresolvedScriptInstruction,
  unresolvedTemplateParameter,
  unresolvedPresetReference,
  emptyComposition,
}

@immutable
class MotionAuthoringOrigin {
  MotionAuthoringOrigin({
    required this.kind,
    required this.id,
    this.label,
    Map<String, String> metadata = const <String, String>{},
  }) : metadata = Map.unmodifiable(metadata);

  final MotionAuthoringSourceKind kind;
  final String id;
  final String? label;
  final Map<String, String> metadata;
}

@immutable
class MotionCompileOptions {
  const MotionCompileOptions({
    this.includeDisabledScenes = false,
    this.includeDisabledLayers = false,
    this.includeDisabledElements = false,
    this.flattenStaticAssignments = true,
    this.keepEmptyLayers = false,
    this.keepEmptyScenes = false,
  });

  final bool includeDisabledScenes;
  final bool includeDisabledLayers;
  final bool includeDisabledElements;
  final bool flattenStaticAssignments;
  final bool keepEmptyLayers;
  final bool keepEmptyScenes;
}

@immutable
class MotionCompileRequest {
  MotionCompileRequest({
    required this.project,
    this.projectRange,
    this.options = const MotionCompileOptions(),
    List<MotionPropertyChannelModel> propertyChannels =
        const <MotionPropertyChannelModel>[],
    List<MotionEffectBindingModel> effectBindings =
        const <MotionEffectBindingModel>[],
    List<MotionTransitionBindingModel> transitionBindings =
        const <MotionTransitionBindingModel>[],
    List<MotionCameraBindingModel> cameraBindings =
        const <MotionCameraBindingModel>[],
    List<MotionTextAnimationBindingModel> textAnimationBindings =
        const <MotionTextAnimationBindingModel>[],
    List<MotionAuthoringOrigin> authoringOrigins =
        const <MotionAuthoringOrigin>[],
    Map<String, String> templateParameters = const <String, String>{},
  }) : propertyChannels = List.unmodifiable(propertyChannels),
       effectBindings = List.unmodifiable(effectBindings),
       transitionBindings = List.unmodifiable(transitionBindings),
       cameraBindings = List.unmodifiable(cameraBindings),
       textAnimationBindings = List.unmodifiable(textAnimationBindings),
       authoringOrigins = List.unmodifiable(authoringOrigins),
       templateParameters = Map.unmodifiable(templateParameters);

  final MotionProjectModel project;
  final TimelineTimeRange? projectRange;
  final MotionCompileOptions options;
  final List<MotionPropertyChannelModel> propertyChannels;
  final List<MotionEffectBindingModel> effectBindings;
  final List<MotionTransitionBindingModel> transitionBindings;
  final List<MotionCameraBindingModel> cameraBindings;
  final List<MotionTextAnimationBindingModel> textAnimationBindings;
  final List<MotionAuthoringOrigin> authoringOrigins;
  final Map<String, String> templateParameters;
}

@immutable
class MotionCompileIssue {
  const MotionCompileIssue({
    required this.code,
    required this.severity,
    required this.message,
    this.sceneId,
    this.layerId,
    this.elementId,
    this.channelId,
    this.propertyId,
  });

  final MotionCompileIssueCode code;
  final MotionCompileIssueSeverity severity;
  final String message;
  final String? sceneId;
  final String? layerId;
  final String? elementId;
  final String? channelId;
  final String? propertyId;
}

@immutable
class MotionResolvedPropertyChannel {
  const MotionResolvedPropertyChannel({
    required this.channel,
    required this.projectRange,
    required this.targetAddress,
  });

  final MotionPropertyChannelModel channel;
  final TimelineTimeRange projectRange;
  final String targetAddress;
}

@immutable
class MotionResolvedEffectModel {
  const MotionResolvedEffectModel({
    required this.id,
    required this.kind,
    required this.targetAddress,
    required this.projectRange,
    required this.parameters,
    this.name,
    this.isEnabled = true,
  });

  final String id;
  final MotionEffectKind kind;
  final String targetAddress;
  final TimelineTimeRange projectRange;
  final Map<String, MotionPropertyValue> parameters;
  final String? name;
  final bool isEnabled;
}

@immutable
class MotionResolvedTransitionModel {
  const MotionResolvedTransitionModel({
    required this.id,
    required this.kind,
    required this.leftTargetId,
    required this.rightTargetId,
    required this.projectRange,
    required this.parameters,
    this.name,
    this.isEnabled = true,
  });

  final String id;
  final MotionTransitionKind kind;
  final String leftTargetId;
  final String rightTargetId;
  final TimelineTimeRange projectRange;
  final Map<String, MotionPropertyValue> parameters;
  final String? name;
  final bool isEnabled;
}

@immutable
class MotionResolvedCameraModel {
  MotionResolvedCameraModel({
    required this.id,
    required this.scope,
    required this.targetAddress,
    required this.projectRange,
    required List<MotionPropertyAssignment> staticProperties,
    required List<MotionResolvedPropertyChannel> propertyChannels,
    this.name,
    this.isEnabled = true,
  }) : staticProperties = List.unmodifiable(staticProperties),
       propertyChannels = List.unmodifiable(propertyChannels);

  final String id;
  final MotionCameraBindingScope scope;
  final String targetAddress;
  final TimelineTimeRange projectRange;
  final String? name;
  final bool isEnabled;
  final List<MotionPropertyAssignment> staticProperties;
  final List<MotionResolvedPropertyChannel> propertyChannels;
}

@immutable
class MotionResolvedTextAnimationBlockModel {
  MotionResolvedTextAnimationBlockModel({
    required this.id,
    required this.kind,
    required this.projectRange,
    required this.interpolation,
    this.revealSpec,
    Map<String, MotionPropertyValue> parameters =
        const <String, MotionPropertyValue>{},
  }) : parameters = Map.unmodifiable(parameters);

  final String id;
  final MotionTextAnimationKind kind;
  final TimelineTimeRange projectRange;
  final MotionInterpolationSpec interpolation;
  final MotionTextRevealSpec? revealSpec;
  final Map<String, MotionPropertyValue> parameters;
}

@immutable
class MotionResolvedTextAnimationModel {
  MotionResolvedTextAnimationModel({
    required this.id,
    required this.targetElementId,
    required this.targetAddress,
    required this.projectRange,
    required List<MotionTextAnimationKind> animationKinds,
    required List<String> generatedChannelIds,
    List<MotionResolvedTextAnimationBlockModel> animationBlocks =
        const <MotionResolvedTextAnimationBlockModel>[],
    Map<String, MotionPropertyValue> parameterValues =
        const <String, MotionPropertyValue>{},
    this.presetId,
  }) : animationKinds = List.unmodifiable(animationKinds),
       generatedChannelIds = List.unmodifiable(generatedChannelIds),
       animationBlocks = List.unmodifiable(animationBlocks),
       parameterValues = Map.unmodifiable(parameterValues);

  final String id;
  final String targetElementId;
  final String targetAddress;
  final TimelineTimeRange projectRange;
  final String? presetId;
  final List<MotionTextAnimationKind> animationKinds;
  final List<String> generatedChannelIds;
  final List<MotionResolvedTextAnimationBlockModel> animationBlocks;
  final Map<String, MotionPropertyValue> parameterValues;
}

@immutable
class MotionResolvedElementModel {
  MotionResolvedElementModel({
    required this.id,
    required this.sourceElementId,
    required this.sceneId,
    required this.layerId,
    required this.kind,
    required this.projectRange,
    required this.localRange,
    required List<MotionPropertyAssignment> staticProperties,
    required List<MotionResolvedPropertyChannel> propertyChannels,
    this.name,
    this.shapeKind,
    this.sourceBinding,
    this.isEnabled = true,
  }) : staticProperties = List.unmodifiable(staticProperties),
       propertyChannels = List.unmodifiable(propertyChannels);

  final String id;
  final String sourceElementId;
  final String sceneId;
  final String layerId;
  final MotionElementKind kind;
  final TimelineTimeRange projectRange;
  final TimelineTimeRange localRange;
  final String? name;
  final MotionShapeKind? shapeKind;
  final MotionElementSourceBinding? sourceBinding;
  final bool isEnabled;
  final List<MotionPropertyAssignment> staticProperties;
  final List<MotionResolvedPropertyChannel> propertyChannels;
}

@immutable
class MotionResolvedLayerModel {
  MotionResolvedLayerModel({
    required this.id,
    required this.sourceLayerId,
    required this.sceneId,
    required this.kind,
    required this.projectRange,
    required List<MotionResolvedElementModel> elements,
    required List<MotionPropertyAssignment> staticProperties,
    required List<MotionResolvedPropertyChannel> propertyChannels,
    this.name,
    this.zIndex = 0,
    this.isEnabled = true,
    this.blendMode = MotionBlendMode.normal,
  }) : elements = List.unmodifiable(elements),
       staticProperties = List.unmodifiable(staticProperties),
       propertyChannels = List.unmodifiable(propertyChannels);

  final String id;
  final String sourceLayerId;
  final String sceneId;
  final MotionLayerKind kind;
  final TimelineTimeRange projectRange;
  final String? name;
  final int zIndex;
  final bool isEnabled;
  final MotionBlendMode blendMode;
  final List<MotionResolvedElementModel> elements;
  final List<MotionPropertyAssignment> staticProperties;
  final List<MotionResolvedPropertyChannel> propertyChannels;
}

@immutable
class MotionResolvedSceneModel {
  MotionResolvedSceneModel({
    required this.id,
    required this.sourceSceneId,
    required this.projectRange,
    required List<MotionResolvedLayerModel> layers,
    required List<MotionPropertyAssignment> staticProperties,
    required List<MotionResolvedPropertyChannel> propertyChannels,
    this.name,
    this.cameraLayerId,
    this.isEnabled = true,
    Map<String, String> metadata = const <String, String>{},
  }) : layers = List.unmodifiable(layers),
       staticProperties = List.unmodifiable(staticProperties),
       propertyChannels = List.unmodifiable(propertyChannels),
       metadata = Map.unmodifiable(metadata);

  final String id;
  final String sourceSceneId;
  final TimelineTimeRange projectRange;
  final List<MotionResolvedLayerModel> layers;
  final List<MotionPropertyAssignment> staticProperties;
  final List<MotionResolvedPropertyChannel> propertyChannels;
  final String? name;
  final String? cameraLayerId;
  final bool isEnabled;
  final Map<String, String> metadata;
}

@immutable
class MotionNormalizedComposition {
  MotionNormalizedComposition({
    required this.projectId,
    required this.projectRange,
    required this.format,
    required this.frameRate,
    required List<MotionResolvedSceneModel> scenes,
    required List<MotionResolvedPropertyChannel> globalChannels,
    required List<MotionResolvedEffectModel> effects,
    required List<MotionResolvedTransitionModel> transitions,
    required List<MotionResolvedCameraModel> cameras,
    required List<MotionResolvedTextAnimationModel> textAnimations,
    List<MotionAuthoringOrigin> authoringOrigins =
        const <MotionAuthoringOrigin>[],
    Map<String, String> metadata = const <String, String>{},
  }) : scenes = List.unmodifiable(scenes),
       globalChannels = List.unmodifiable(globalChannels),
       effects = List.unmodifiable(effects),
       transitions = List.unmodifiable(transitions),
       cameras = List.unmodifiable(cameras),
       textAnimations = List.unmodifiable(textAnimations),
       authoringOrigins = List.unmodifiable(authoringOrigins),
       metadata = Map.unmodifiable(metadata);

  final String projectId;
  final TimelineTimeRange projectRange;
  final MotionProjectFormat format;
  final MotionFrameRate frameRate;
  final List<MotionResolvedSceneModel> scenes;
  final List<MotionResolvedPropertyChannel> globalChannels;
  final List<MotionResolvedEffectModel> effects;
  final List<MotionResolvedTransitionModel> transitions;
  final List<MotionResolvedCameraModel> cameras;
  final List<MotionResolvedTextAnimationModel> textAnimations;
  final List<MotionAuthoringOrigin> authoringOrigins;
  final Map<String, String> metadata;

  UnmodifiableListView<MotionResolvedLayerModel> get allLayers {
    return UnmodifiableListView<MotionResolvedLayerModel>(
      <MotionResolvedLayerModel>[
        for (final scene in scenes) ...scene.layers,
      ],
    );
  }

  UnmodifiableListView<MotionResolvedElementModel> get allElements {
    return UnmodifiableListView<MotionResolvedElementModel>(
      <MotionResolvedElementModel>[
        for (final scene in scenes)
          for (final layer in scene.layers)
            ...layer.elements,
      ],
    );
  }

  UnmodifiableListView<MotionResolvedPropertyChannel> get allPropertyChannels {
    return UnmodifiableListView<MotionResolvedPropertyChannel>(
      <MotionResolvedPropertyChannel>[
        ...globalChannels,
        for (final scene in scenes)
          for (final layer in scene.layers) ...<MotionResolvedPropertyChannel>[
            ...layer.propertyChannels,
            for (final element in layer.elements) ...element.propertyChannels,
          ],
      ],
    );
  }
}

@immutable
class MotionCompileResult {
  MotionCompileResult({
    required this.request,
    required List<MotionCompileIssue> issues,
    this.composition,
  }) : issues = List.unmodifiable(issues);

  final MotionCompileRequest request;
  final MotionNormalizedComposition? composition;
  final List<MotionCompileIssue> issues;

  bool get hasErrors => issues.any(
    (issue) => issue.severity == MotionCompileIssueSeverity.error,
  );
}

abstract class MotionCompositionCompiler {
  const MotionCompositionCompiler();

  MotionCompileResult compile(MotionCompileRequest request);
}
