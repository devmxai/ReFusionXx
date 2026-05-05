import 'package:flutter/foundation.dart';

import '../../presentation/models/timeline_time.dart';
import 'export_authored_visual_surface_models.dart';
import 'export_motion_text_program_models.dart';
import 'professional_motion_animation_models.dart';
import 'professional_motion_compilation_models.dart';
import 'professional_motion_models.dart';
import 'professional_motion_text_raster_models.dart';
import 'professional_motion_text_render_models.dart';

const String kExportGraphSchemaVersion = 'export-graph.v1alpha1';

enum ExportTrackKind {
  video,
  image,
  audio,
  text,
  lipSync,
}

enum ExportAssetKind {
  video,
  image,
  audio,
  text,
  lipSync,
  unknown,
}

enum ExportClipSpeedMode {
  normal,
  curve,
}

enum ExportCompositionIssueSeverity {
  warning,
  error,
}

enum ExportCapabilityStatus {
  supported,
  baselineOnly,
  approximation,
  fallbackOnly,
  blocked,
  unknown,
}

enum ExportCapabilityScope {
  system,
  trackType,
  nodeType,
  property,
}

enum ExportTruthSourceKind {
  canonicalTracks,
  motionComposition,
  motionTextProgram,
  motionTextRenderTrack,
  previewState,
  playerState,
}

enum ExportTruthSourceRole {
  primary,
  auxiliary,
  fallback,
  excluded,
}

enum ExportVisualLayerKind {
  mediaTrack,
  motionTextOverlay,
  authoredOverlay,
}

enum ExportVisualAssemblyPolicyKind {
  gap,
  mediaOnly,
  mediaWithAuthoredOverlay,
  compositorRequired,
}

enum ExportVisualExecutionOwnerKind {
  none,
  media3BaselineRoute,
  nativeVisualCompositor,
}

enum ExportCompositorExecutionInputRoleKind {
  baseMedia,
  overlayMedia,
  authoredOverlay,
}

enum ExportBaselineBlockerCode {
  unresolvedCompositionErrors,
  missingMotionTextProgram,
  compositorRequiredVisualWindow,
  unsupportedNonTextMotion,
  unsupportedMotionCamera,
  unsupportedMotionEffect,
  unsupportedMotionTransition,
  noMediaClips,
  noVisualBaselineTrack,
  multipleVisualTracks,
  multipleAudioTracks,
  unsupportedTrackKind,
  curveSpeed,
  unsupportedInterpolationKind,
}

enum ExportParityLimitationCode {
  textMotionRendererParity,
  typographyParity,
  interpolationParity,
  nonTextMotionParity,
  motionCameraParity,
  motionEffectParity,
  motionTransitionParity,
  multiVisualCompositingParity,
  multiAudioParity,
  textTrackParity,
  lipSyncTrackParity,
  curveSpeedParity,
}

enum ExportCompositionIssueCode {
  missingAsset,
  missingSourceUri,
  placeholderClip,
  unsupportedClipType,
}

@immutable
class ExportCapabilityDescriptor {
  const ExportCapabilityDescriptor({
    required this.id,
    required this.label,
    required this.scope,
    required this.status,
    required this.detail,
  });

  final String id;
  final String label;
  final ExportCapabilityScope scope;
  final ExportCapabilityStatus status;
  final String detail;

  Map<String, Object?> toBridgeMap() => <String, Object?>{
        'id': id,
        'label': label,
        'scope': scope.name,
        'status': status.name,
        'detail': detail,
      };
}

@immutable
class ExportInterpolationSupportDescriptor {
  const ExportInterpolationSupportDescriptor({
    required this.kind,
    required this.status,
    required this.detail,
    required this.encountered,
  });

  final String kind;
  final ExportCapabilityStatus status;
  final String detail;
  final bool encountered;

  Map<String, Object?> toBridgeMap() => <String, Object?>{
        'kind': kind,
        'status': status.name,
        'detail': detail,
        'encountered': encountered,
      };
}

@immutable
class ExportTruthSourceDescriptor {
  const ExportTruthSourceDescriptor({
    required this.kind,
    required this.role,
    required this.detail,
  });

  final ExportTruthSourceKind kind;
  final ExportTruthSourceRole role;
  final String detail;

  Map<String, Object?> toBridgeMap() => <String, Object?>{
        'kind': kind.name,
        'role': role.name,
        'detail': detail,
      };
}

@immutable
class ExportBackendProfileDescriptor {
  const ExportBackendProfileDescriptor({
    required this.primaryBackendId,
    required this.visualRendererId,
    required this.audioRendererId,
    required this.outputTopology,
    required this.detail,
  });

  final String primaryBackendId;
  final String visualRendererId;
  final String audioRendererId;
  final String outputTopology;
  final String detail;

  Map<String, Object?> toBridgeMap() => <String, Object?>{
        'primaryBackendId': primaryBackendId,
        'visualRendererId': visualRendererId,
        'audioRendererId': audioRendererId,
        'outputTopology': outputTopology,
        'detail': detail,
      };
}

@immutable
class ExportPropertyCapabilityDescriptor {
  const ExportPropertyCapabilityDescriptor({
    required this.propertyId,
    required this.label,
    required this.scope,
    required this.status,
    required this.rendererOwnerId,
    required this.detail,
  });

  final String propertyId;
  final String label;
  final ExportCapabilityScope scope;
  final ExportCapabilityStatus status;
  final String rendererOwnerId;
  final String detail;

  Map<String, Object?> toBridgeMap() => <String, Object?>{
        'propertyId': propertyId,
        'label': label,
        'scope': scope.name,
        'status': status.name,
        'rendererOwnerId': rendererOwnerId,
        'detail': detail,
      };
}

@immutable
class ExportRendererOwnershipDescriptor {
  const ExportRendererOwnershipDescriptor({
    required this.id,
    required this.label,
    required this.primaryRendererId,
    required this.fallbackAllowed,
    required this.detail,
    this.fallbackRendererId,
  });

  final String id;
  final String label;
  final String primaryRendererId;
  final String? fallbackRendererId;
  final bool fallbackAllowed;
  final String detail;

  Map<String, Object?> toBridgeMap() => <String, Object?>{
        'id': id,
        'label': label,
        'primaryRendererId': primaryRendererId,
        'fallbackRendererId': fallbackRendererId,
        'fallbackAllowed': fallbackAllowed,
        'detail': detail,
      };
}

@immutable
class ExportVisualLayerDescriptor {
  const ExportVisualLayerDescriptor({
    required this.id,
    required this.label,
    required this.kind,
    required this.sourceTruthKind,
    required this.rendererOwnerId,
    required this.zOrder,
    required this.supportsCurrentBackend,
    required this.detail,
    this.trackKind,
  });

  final String id;
  final String label;
  final ExportVisualLayerKind kind;
  final ExportTruthSourceKind sourceTruthKind;
  final String rendererOwnerId;
  final int zOrder;
  final bool supportsCurrentBackend;
  final String detail;
  final ExportTrackKind? trackKind;

  Map<String, Object?> toBridgeMap() => <String, Object?>{
        'id': id,
        'label': label,
        'kind': kind.name,
        'sourceTruthKind': sourceTruthKind.name,
        'rendererOwnerId': rendererOwnerId,
        'zOrder': zOrder,
        'supportsCurrentBackend': supportsCurrentBackend,
        'detail': detail,
        'trackKind': trackKind?.name,
      };
}

@immutable
class ExportVisualSegmentDescriptor {
  const ExportVisualSegmentDescriptor({
    required this.id,
    required this.layerId,
    required this.sourceTruthKind,
    required this.rendererOwnerId,
    required this.timelineRange,
    required this.zOrder,
    required this.detail,
    this.trackKind,
    this.clipId,
    this.nodeId,
  });

  final String id;
  final String layerId;
  final ExportTruthSourceKind sourceTruthKind;
  final String rendererOwnerId;
  final TimelineTimeRange timelineRange;
  final int zOrder;
  final String detail;
  final ExportTrackKind? trackKind;
  final String? clipId;
  final String? nodeId;

  Map<String, Object?> toBridgeMap() => <String, Object?>{
        'id': id,
        'layerId': layerId,
        'sourceTruthKind': sourceTruthKind.name,
        'rendererOwnerId': rendererOwnerId,
        'timelineRange': _timelineTimeRangeBridgeMap(timelineRange),
        'zOrder': zOrder,
        'detail': detail,
        'trackKind': trackKind?.name,
        'clipId': clipId,
        'nodeId': nodeId,
      };
}

@immutable
class ExportVisualCompositorGraph {
  ExportVisualCompositorGraph({
    required List<ExportVisualLayerDescriptor> layers,
    required List<ExportVisualSegmentDescriptor> segments,
    required List<ExportVisualAssemblyWindowDescriptor> windows,
    required List<ExportCompositorWindowExecutionPlanDescriptor>
        compositorWindowExecutionPlans,
    required this.maxConcurrentVisualSegments,
    required this.requiresVisualCompositor,
    required List<String> requirementReasons,
  })  : layers = List.unmodifiable(layers),
        segments = List.unmodifiable(segments),
        windows = List.unmodifiable(windows),
        compositorWindowExecutionPlans =
            List.unmodifiable(compositorWindowExecutionPlans),
        requirementReasons = List.unmodifiable(requirementReasons);

  final List<ExportVisualLayerDescriptor> layers;
  final List<ExportVisualSegmentDescriptor> segments;
  final List<ExportVisualAssemblyWindowDescriptor> windows;
  final List<ExportCompositorWindowExecutionPlanDescriptor>
      compositorWindowExecutionPlans;
  final int maxConcurrentVisualSegments;
  final bool requiresVisualCompositor;
  final List<String> requirementReasons;

  int get layerCount => layers.length;

  int get mediaLayerCount => layers
      .where((layer) => layer.kind == ExportVisualLayerKind.mediaTrack)
      .length;

  int get authoredLayerCount => layerCount - mediaLayerCount;

  int get gapWindowCount => windows
      .where((window) => window.policy == ExportVisualAssemblyPolicyKind.gap)
      .length;

  int get compositorRequiredWindowCount => windows
      .where(
        (window) =>
            window.policy == ExportVisualAssemblyPolicyKind.compositorRequired,
      )
      .length;

  int get supportedCompositorWindowCount => windows
      .where(
        (window) =>
            window.policy ==
                ExportVisualAssemblyPolicyKind.compositorRequired &&
            window.supportsCurrentBackend,
      )
      .length;

  int get unsupportedCompositorWindowCount => windows
      .where(
        (window) =>
            window.policy ==
                ExportVisualAssemblyPolicyKind.compositorRequired &&
            !window.supportsCurrentBackend,
      )
      .length;

  int get mediaOnlyWindowCount => windows
      .where(
          (window) => window.policy == ExportVisualAssemblyPolicyKind.mediaOnly)
      .length;

  int get mediaWithAuthoredOverlayWindowCount => windows
      .where(
        (window) =>
            window.policy ==
            ExportVisualAssemblyPolicyKind.mediaWithAuthoredOverlay,
      )
      .length;

  List<ExportVisualAssemblyWindowDescriptor> get compositorRequiredWindows =>
      windows
          .where(
            (window) => !window.supportsCurrentBackend,
          )
          .toList(growable: false);

  int get compositorWindowExecutionPlanCount =>
      compositorWindowExecutionPlans.length;

  Map<String, Object?> toSummaryBridgeMap() => <String, Object?>{
        'layerCount': layerCount,
        'segmentCount': segments.length,
        'windowCount': windows.length,
        'gapWindowCount': gapWindowCount,
        'mediaOnlyWindowCount': mediaOnlyWindowCount,
        'mediaWithAuthoredOverlayWindowCount':
            mediaWithAuthoredOverlayWindowCount,
        'compositorRequiredWindowCount': compositorRequiredWindowCount,
        'supportedCompositorWindowCount': supportedCompositorWindowCount,
        'unsupportedCompositorWindowCount': unsupportedCompositorWindowCount,
        'compositorWindowExecutionPlanCount':
            compositorWindowExecutionPlanCount,
        'mediaLayerCount': mediaLayerCount,
        'authoredLayerCount': authoredLayerCount,
        'maxConcurrentVisualSegments': maxConcurrentVisualSegments,
        'requiresVisualCompositor': requiresVisualCompositor,
        'requirementReasons': requirementReasons,
      };

  Map<String, Object?> toBridgeMap() => <String, Object?>{
        ...toSummaryBridgeMap(),
        'layers': layers.map((entry) => entry.toBridgeMap()).toList(),
        'segments': segments.map((entry) => entry.toBridgeMap()).toList(),
        'windows': windows.map((entry) => entry.toBridgeMap()).toList(),
        'compositorWindowExecutionPlans': compositorWindowExecutionPlans
            .map((entry) => entry.toBridgeMap())
            .toList(),
      };
}

@immutable
class ExportVisualAssemblyWindowDescriptor {
  ExportVisualAssemblyWindowDescriptor({
    required this.id,
    required this.timelineRange,
    required this.policy,
    required this.executionOwner,
    required this.requiresVisualCompositor,
    required this.supportsCurrentBackend,
    required List<String> activeLayerIds,
    required List<String> activeSegmentIds,
    required this.detail,
  })  : activeLayerIds = List.unmodifiable(activeLayerIds),
        activeSegmentIds = List.unmodifiable(activeSegmentIds);

  final String id;
  final TimelineTimeRange timelineRange;
  final ExportVisualAssemblyPolicyKind policy;
  final ExportVisualExecutionOwnerKind executionOwner;
  final bool requiresVisualCompositor;
  final bool supportsCurrentBackend;
  final List<String> activeLayerIds;
  final List<String> activeSegmentIds;
  final String detail;

  Map<String, Object?> toBridgeMap() => <String, Object?>{
        'id': id,
        'timelineRange': _timelineTimeRangeBridgeMap(timelineRange),
        'policy': policy.name,
        'executionOwner': executionOwner.name,
        'requiresVisualCompositor': requiresVisualCompositor,
        'supportsCurrentBackend': supportsCurrentBackend,
        'activeLayerIds': activeLayerIds,
        'activeSegmentIds': activeSegmentIds,
        'detail': detail,
      };
}

@immutable
class ExportCompositorExecutionInputDescriptor {
  const ExportCompositorExecutionInputDescriptor({
    required this.segmentId,
    required this.layerId,
    required this.role,
    required this.sourceTruthKind,
    required this.rendererOwnerId,
    required this.zOrder,
    required this.trackKind,
    required this.clipId,
    required this.nodeId,
  });

  final String segmentId;
  final String layerId;
  final ExportCompositorExecutionInputRoleKind role;
  final ExportTruthSourceKind sourceTruthKind;
  final String rendererOwnerId;
  final int zOrder;
  final ExportTrackKind? trackKind;
  final String? clipId;
  final String? nodeId;

  Map<String, Object?> toBridgeMap() => <String, Object?>{
        'segmentId': segmentId,
        'layerId': layerId,
        'role': role.name,
        'sourceTruthKind': sourceTruthKind.name,
        'rendererOwnerId': rendererOwnerId,
        'zOrder': zOrder,
        'trackKind': trackKind?.name,
        'clipId': clipId,
        'nodeId': nodeId,
      };
}

@immutable
class ExportCompositorWindowExecutionPlanDescriptor {
  ExportCompositorWindowExecutionPlanDescriptor({
    required this.windowId,
    required this.timelineRange,
    required this.executionOwner,
    required List<String> orderedLayerIds,
    required List<String> orderedSegmentIds,
    required List<String> mediaSegmentIds,
    required List<String> authoredSegmentIds,
    required List<ExportCompositorExecutionInputDescriptor> executionInputs,
    required this.detail,
  })  : orderedLayerIds = List.unmodifiable(orderedLayerIds),
        orderedSegmentIds = List.unmodifiable(orderedSegmentIds),
        mediaSegmentIds = List.unmodifiable(mediaSegmentIds),
        authoredSegmentIds = List.unmodifiable(authoredSegmentIds),
        executionInputs = List.unmodifiable(executionInputs);

  final String windowId;
  final TimelineTimeRange timelineRange;
  final ExportVisualExecutionOwnerKind executionOwner;
  final List<String> orderedLayerIds;
  final List<String> orderedSegmentIds;
  final List<String> mediaSegmentIds;
  final List<String> authoredSegmentIds;
  final List<ExportCompositorExecutionInputDescriptor> executionInputs;
  final String detail;

  Map<String, Object?> toBridgeMap() => <String, Object?>{
        'windowId': windowId,
        'timelineRange': _timelineTimeRangeBridgeMap(timelineRange),
        'executionOwner': executionOwner.name,
        'orderedLayerIds': orderedLayerIds,
        'orderedSegmentIds': orderedSegmentIds,
        'mediaSegmentIds': mediaSegmentIds,
        'authoredSegmentIds': authoredSegmentIds,
        'executionInputs':
            executionInputs.map((entry) => entry.toBridgeMap()).toList(),
        'detail': detail,
      };
}

@immutable
class ExportInterpolationContractDescriptor {
  const ExportInterpolationContractDescriptor({
    required this.kind,
    required this.status,
    required this.requiredParameters,
    required this.evaluatorId,
    required this.detail,
    required this.encountered,
  });

  final String kind;
  final ExportCapabilityStatus status;
  final List<String> requiredParameters;
  final String evaluatorId;
  final String detail;
  final bool encountered;

  Map<String, Object?> toBridgeMap() => <String, Object?>{
        'kind': kind,
        'status': status.name,
        'requiredParameters': requiredParameters,
        'evaluatorId': evaluatorId,
        'detail': detail,
        'encountered': encountered,
      };
}

@immutable
class ExportCompositionIssue {
  const ExportCompositionIssue({
    required this.code,
    required this.severity,
    required this.message,
    this.trackKind,
    this.clipId,
    this.assetId,
  });

  final ExportCompositionIssueCode code;
  final ExportCompositionIssueSeverity severity;
  final String message;
  final ExportTrackKind? trackKind;
  final String? clipId;
  final String? assetId;
}

@immutable
class ExportProjectFormatDescriptor {
  const ExportProjectFormatDescriptor({
    required this.canvasWidth,
    required this.canvasHeight,
    required this.pixelAspectRatio,
    required this.frameRateNumerator,
    required this.frameRateDenominator,
    required this.durationTime,
  });

  final int canvasWidth;
  final int canvasHeight;
  final double pixelAspectRatio;
  final int frameRateNumerator;
  final int frameRateDenominator;
  final TimelineTime durationTime;

  double get framesPerSecond => frameRateNumerator / frameRateDenominator;
}

@immutable
class ExportAssetDescriptor {
  const ExportAssetDescriptor({
    required this.assetId,
    required this.kind,
    required this.label,
    this.sourceUri,
    this.durationTime,
    this.width,
    this.height,
    this.isImported = false,
  });

  final String assetId;
  final ExportAssetKind kind;
  final String label;
  final String? sourceUri;
  final TimelineTime? durationTime;
  final int? width;
  final int? height;
  final bool isImported;

  bool get hasSourceUri => sourceUri != null && sourceUri!.isNotEmpty;
}

@immutable
class ExportClipDescriptor {
  const ExportClipDescriptor({
    required this.clipId,
    required this.trackKind,
    required this.assetId,
    required this.timelineRange,
    required this.sourceRange,
    required this.playbackRate,
    required this.speedMode,
    this.splitGroupId,
    this.label,
  });

  final String clipId;
  final ExportTrackKind trackKind;
  final String assetId;
  final TimelineTimeRange timelineRange;
  final TimelineTimeRange sourceRange;
  final double playbackRate;
  final ExportClipSpeedMode speedMode;
  final String? splitGroupId;
  final String? label;

  bool get hasSpeedOverride =>
      speedMode != ExportClipSpeedMode.normal ||
      (playbackRate - 1.0).abs() > 0.001;
}

@immutable
class ExportTrackDescriptor {
  ExportTrackDescriptor({
    required this.kind,
    required List<ExportClipDescriptor> clips,
  }) : clips = List.unmodifiable(clips);

  final ExportTrackKind kind;
  final List<ExportClipDescriptor> clips;

  bool get isEmpty => clips.isEmpty;
}

enum ExportCanonicalEffectsNodeKind {
  mediaClip,
  textElement,
  imageElement,
  shapeElement,
  genericElement,
}

enum ExportCanonicalEffectOperationKind {
  transform,
  opacity,
  blur,
  crop,
  typography,
  textReveal,
  blendMode,
  textAnimation,
  motionEffect,
  motionTransition,
  camera,
  propertyAssignment,
  propertyChannel,
}

enum ExportEffectsBackendId {
  flutterPreviewRenderer,
  media3CanvasOverlayRenderer,
  media3GlEffectsRenderer,
  bmfRenderGraph,
}

@immutable
class ExportEffectsBackendSupportDescriptor {
  const ExportEffectsBackendSupportDescriptor({
    required this.backendId,
    required this.status,
    required this.detail,
  });

  final ExportEffectsBackendId backendId;
  final ExportCapabilityStatus status;
  final String detail;

  Map<String, Object?> toBridgeMap() => <String, Object?>{
        'backendId': backendId.name,
        'status': status.name,
        'detail': detail,
      };
}

@immutable
class ExportCanonicalEffectsNodeDescriptor {
  ExportCanonicalEffectsNodeDescriptor({
    required this.id,
    required this.label,
    required this.kind,
    required this.sourceTruthKind,
    required this.timelineRange,
    required List<ExportEffectsBackendSupportDescriptor> backendSupport,
    this.targetAddress,
    this.trackKind,
    this.clipId,
    this.sceneId,
    this.layerId,
    this.elementId,
    this.zOrder,
    this.detail,
  }) : backendSupport = List.unmodifiable(backendSupport);

  final String id;
  final String label;
  final ExportCanonicalEffectsNodeKind kind;
  final ExportTruthSourceKind sourceTruthKind;
  final TimelineTimeRange timelineRange;
  final List<ExportEffectsBackendSupportDescriptor> backendSupport;
  final String? targetAddress;
  final ExportTrackKind? trackKind;
  final String? clipId;
  final String? sceneId;
  final String? layerId;
  final String? elementId;
  final int? zOrder;
  final String? detail;

  Map<String, Object?> toBridgeMap() => <String, Object?>{
        'id': id,
        'label': label,
        'kind': kind.name,
        'sourceTruthKind': sourceTruthKind.name,
        'timelineRange': _timelineTimeRangeBridgeMap(timelineRange),
        'targetAddress': targetAddress,
        'trackKind': trackKind?.name,
        'clipId': clipId,
        'sceneId': sceneId,
        'layerId': layerId,
        'elementId': elementId,
        'zOrder': zOrder,
        'detail': detail,
        'backendSupport':
            backendSupport.map((entry) => entry.toBridgeMap()).toList(),
      };
}

@immutable
class ExportCanonicalEffectOperationDescriptor {
  ExportCanonicalEffectOperationDescriptor({
    required this.id,
    required this.label,
    required this.kind,
    required this.sourceTruthKind,
    required this.timelineRange,
    required List<ExportEffectsBackendSupportDescriptor> backendSupport,
    this.targetNodeId,
    this.targetAddress,
    this.propertyId,
    this.originId,
    Map<String, Object?> parameters = const <String, Object?>{},
    this.detail,
  })  : backendSupport = List.unmodifiable(backendSupport),
        parameters = Map.unmodifiable(parameters);

  final String id;
  final String label;
  final ExportCanonicalEffectOperationKind kind;
  final ExportTruthSourceKind sourceTruthKind;
  final TimelineTimeRange timelineRange;
  final List<ExportEffectsBackendSupportDescriptor> backendSupport;
  final String? targetNodeId;
  final String? targetAddress;
  final String? propertyId;
  final String? originId;
  final Map<String, Object?> parameters;
  final String? detail;

  Map<String, Object?> toBridgeMap() => <String, Object?>{
        'id': id,
        'label': label,
        'kind': kind.name,
        'sourceTruthKind': sourceTruthKind.name,
        'timelineRange': _timelineTimeRangeBridgeMap(timelineRange),
        'targetNodeId': targetNodeId,
        'targetAddress': targetAddress,
        'propertyId': propertyId,
        'originId': originId,
        'parameters': parameters,
        'detail': detail,
        'backendSupport':
            backendSupport.map((entry) => entry.toBridgeMap()).toList(),
      };
}

@immutable
class ExportCanonicalEffectsGraph {
  ExportCanonicalEffectsGraph({
    required this.schemaVersion,
    required List<ExportCanonicalEffectsNodeDescriptor> nodes,
    required List<ExportCanonicalEffectOperationDescriptor> operations,
  })  : nodes = List.unmodifiable(nodes),
        operations = List.unmodifiable(operations);

  final String schemaVersion;
  final List<ExportCanonicalEffectsNodeDescriptor> nodes;
  final List<ExportCanonicalEffectOperationDescriptor> operations;

  List<String> get nodeKinds =>
      nodes.map((node) => node.kind.name).toSet().toList(growable: false);

  List<String> get operationKinds => operations
      .map((operation) => operation.kind.name)
      .toSet()
      .toList(growable: false);

  List<Map<String, Object?>> get backendStatusSummary {
    final summary =
        <ExportEffectsBackendId, Map<ExportCapabilityStatus, int>>{};
    void collectStatuses(
      List<ExportEffectsBackendSupportDescriptor> descriptors,
    ) {
      for (final descriptor in descriptors) {
        final backendSummary = summary.putIfAbsent(
            descriptor.backendId, () => <ExportCapabilityStatus, int>{});
        backendSummary.update(
          descriptor.status,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
    }

    for (final node in nodes) {
      collectStatuses(node.backendSupport);
    }
    for (final operation in operations) {
      collectStatuses(operation.backendSupport);
    }

    return summary.entries
        .map(
          (entry) => <String, Object?>{
            'backendId': entry.key.name,
            'statusCounts': entry.value.map(
              (status, count) => MapEntry<String, Object?>(status.name, count),
            ),
          },
        )
        .toList(growable: false);
  }

  Map<String, Object?> toSummaryBridgeMap() => <String, Object?>{
        'schemaVersion': schemaVersion,
        'nodeCount': nodes.length,
        'operationCount': operations.length,
        'nodeKinds': nodeKinds,
        'operationKinds': operationKinds,
        'backendStatusSummary': backendStatusSummary,
      };

  Map<String, Object?> toBridgeMap() => <String, Object?>{
        'schemaVersion': schemaVersion,
        'summary': toSummaryBridgeMap(),
        'nodes': nodes.map((node) => node.toBridgeMap()).toList(),
        'operations': operations.map((op) => op.toBridgeMap()).toList(),
      };
}

@immutable
class ExportComposition {
  ExportComposition({
    required this.contractVersion,
    required this.projectId,
    required this.format,
    required List<ExportAssetDescriptor> assets,
    required List<ExportTrackDescriptor> tracks,
    required List<ExportCompositionIssue> issues,
    required this.canonicalEffectsGraph,
    this.motionTextRasterContract,
    this.motionTextRasterProgram,
    this.authoredVisualSurfaceProgram,
    this.motionComposition,
    this.motionTextProgram,
    this.motionTextRenderTrack,
  })  : assets = List.unmodifiable(assets),
        tracks = List.unmodifiable(tracks),
        issues = List.unmodifiable(issues);

  final String contractVersion;
  final String projectId;
  final ExportProjectFormatDescriptor format;
  final List<ExportAssetDescriptor> assets;
  final List<ExportTrackDescriptor> tracks;
  final ExportCanonicalEffectsGraph canonicalEffectsGraph;
  final MotionTextRasterContract? motionTextRasterContract;
  final MotionTextRasterExportProgram? motionTextRasterProgram;
  final ExportAuthoredVisualSurfaceProgram? authoredVisualSurfaceProgram;
  final MotionNormalizedComposition? motionComposition;
  final ExportMotionTextProgram? motionTextProgram;
  final ExportMotionTextRenderTrack? motionTextRenderTrack;
  final List<ExportCompositionIssue> issues;

  bool get hasErrors => issues
      .any((issue) => issue.severity == ExportCompositionIssueSeverity.error);

  int get totalClipCount => tracks.fold<int>(
        0,
        (count, track) => count + track.clips.length,
      );

  bool get hasMotionContract => motionComposition != null;

  int get motionElementCount => motionComposition?.allElements.length ?? 0;

  int get motionTextAnimationCount =>
      motionComposition?.textAnimations.length ?? 0;

  int get motionEffectCount => motionComposition?.effects.length ?? 0;

  int get motionTransitionCount => motionComposition?.transitions.length ?? 0;

  int get motionSceneCount => motionComposition?.scenes.length ?? 0;

  int get motionCameraCount => motionComposition?.cameras.length ?? 0;

  int get motionChannelCount =>
      motionComposition?.allPropertyChannels.length ?? 0;

  int get motionTextElementCount =>
      motionComposition?.allElements
          .where((element) => element.kind == MotionElementKind.text)
          .length ??
      0;

  int get motionNonTextElementCount =>
      motionComposition?.allElements
          .where((element) => element.kind != MotionElementKind.text)
          .length ??
      0;

  int get motionTextRenderSampleCount =>
      motionTextRenderTrack?.samples.length ?? 0;

  String get graphSchemaVersion => kExportGraphSchemaVersion;

  ExportBackendProfileDescriptor get backendProfile =>
      const ExportBackendProfileDescriptor(
        primaryBackendId: 'media3_transformer',
        visualRendererId: 'media3_overlay_canvas_renderer',
        audioRendererId: 'media3_sequence_audio_path',
        outputTopology: 'single_video_plus_single_audio',
        detail:
            'Media-native clips export through Transformer; authored visuals still pass through an app-owned renderer path.',
      );

  List<ExportTruthSourceDescriptor> get truthSources =>
      <ExportTruthSourceDescriptor>[
        const ExportTruthSourceDescriptor(
          kind: ExportTruthSourceKind.canonicalTracks,
          role: ExportTruthSourceRole.primary,
          detail:
              'Canonical export tracks are the primary truth for media sequencing, trim, ordering, and speed.',
        ),
        if (motionComposition != null)
          const ExportTruthSourceDescriptor(
            kind: ExportTruthSourceKind.motionComposition,
            role: ExportTruthSourceRole.auxiliary,
            detail:
                'Normalized motion composition provides authored motion semantics and source node structure.',
          ),
        if (motionTextProgram != null)
          const ExportTruthSourceDescriptor(
            kind: ExportTruthSourceKind.motionTextProgram,
            role: ExportTruthSourceRole.primary,
            detail:
                'Deterministic text-motion export program is the primary truth for authored text-motion export.',
          ),
        if (motionTextRenderTrack != null)
          const ExportTruthSourceDescriptor(
            kind: ExportTruthSourceKind.motionTextRenderTrack,
            role: ExportTruthSourceRole.fallback,
            detail:
                'Sampled render track remains available only as fallback/debug tooling and is not final truth.',
          ),
        const ExportTruthSourceDescriptor(
          kind: ExportTruthSourceKind.previewState,
          role: ExportTruthSourceRole.excluded,
          detail: 'Preview UI state is explicitly excluded from export truth.',
        ),
        const ExportTruthSourceDescriptor(
          kind: ExportTruthSourceKind.playerState,
          role: ExportTruthSourceRole.excluded,
          detail:
              'Live player/transport state is explicitly excluded from export truth.',
        ),
      ];

  ExportVisualCompositorGraph get visualCompositorGraph {
    final layers = <ExportVisualLayerDescriptor>[];
    final segments = <ExportVisualSegmentDescriptor>[];

    var mediaLayerOrdinal = 0;
    for (var index = 0; index < tracks.length; index++) {
      final track = tracks[index];
      if (track.clips.isEmpty) {
        continue;
      }
      final isVisualTrack = track.kind == ExportTrackKind.video ||
          track.kind == ExportTrackKind.image;
      if (!isVisualTrack) {
        continue;
      }
      final layerId = 'media.track.$index';
      final zOrder = mediaLayerOrdinal;
      layers.add(
        ExportVisualLayerDescriptor(
          id: layerId,
          label: '${track.kind.name} visual track ${mediaLayerOrdinal + 1}',
          kind: ExportVisualLayerKind.mediaTrack,
          sourceTruthKind: ExportTruthSourceKind.canonicalTracks,
          rendererOwnerId: 'media3_transformer_visual_track',
          zOrder: zOrder,
          supportsCurrentBackend: nonEmptyVisualTrackCount <= 1,
          detail:
              'Canonical ${track.kind.name} track segments feed the media-native export backbone.',
          trackKind: track.kind,
        ),
      );
      for (final clip in track.clips) {
        segments.add(
          ExportVisualSegmentDescriptor(
            id: 'media.segment.${clip.clipId}',
            layerId: layerId,
            sourceTruthKind: ExportTruthSourceKind.canonicalTracks,
            rendererOwnerId: 'media3_transformer_visual_track',
            timelineRange: clip.timelineRange,
            zOrder: zOrder,
            detail:
                'Canonical media clip segment `${clip.clipId}` on ${track.kind.name} visual track.',
            trackKind: track.kind,
            clipId: clip.clipId,
          ),
        );
      }
      mediaLayerOrdinal += 1;
    }

    final program = motionTextProgram;
    if (program != null && program.nodes.isNotEmpty) {
      const layerId = 'motion.text.program';
      const zOrder = 1000;
      layers.add(
        const ExportVisualLayerDescriptor(
          id: layerId,
          label: 'motion text overlay program',
          kind: ExportVisualLayerKind.motionTextOverlay,
          sourceTruthKind: ExportTruthSourceKind.motionTextProgram,
          rendererOwnerId: 'app_motion_text_program_renderer',
          zOrder: zOrder,
          supportsCurrentBackend: true,
          detail:
              'Deterministic motion-text program renders as an authored overlay above the media backbone.',
        ),
      );
      for (final node in program.nodes) {
        segments.add(
          ExportVisualSegmentDescriptor(
            id: 'motion.text.segment.${node.id}',
            layerId: layerId,
            sourceTruthKind: ExportTruthSourceKind.motionTextProgram,
            rendererOwnerId: 'app_motion_text_program_renderer',
            timelineRange: node.projectRange,
            zOrder: zOrder,
            detail:
                'Motion-text node `${node.id}` contributes an authored overlay range to the export graph.',
            nodeId: node.id,
          ),
        );
      }
    }

    final composition = motionComposition;
    if (composition != null) {
      for (final layer in composition.allLayers) {
        final authoredElements = layer.elements
            .where(
                (element) => _isGraphOwnedAuthoredVisualElement(element.kind))
            .toList(growable: false);
        if (authoredElements.isEmpty) {
          continue;
        }
        final layerId = 'authored.layer.${layer.id}';
        final zOrder = 1000 + layer.zIndex;
        layers.add(
          ExportVisualLayerDescriptor(
            id: layerId,
            label: layer.name ?? 'authored visual layer ${layer.id}',
            kind: ExportVisualLayerKind.authoredOverlay,
            sourceTruthKind: ExportTruthSourceKind.motionComposition,
            rendererOwnerId: 'app_authored_visual_surface_renderer',
            zOrder: zOrder,
            supportsCurrentBackend: false,
            detail:
                'Resolved authored visual layer `${layer.id}` contributes non-text overlay surfaces that require the wider compositor/effects backend.',
          ),
        );
        for (final element in authoredElements) {
          segments.add(
            ExportVisualSegmentDescriptor(
              id: 'authored.segment.${element.id}',
              layerId: layerId,
              sourceTruthKind: ExportTruthSourceKind.motionComposition,
              rendererOwnerId: 'app_authored_visual_surface_renderer',
              timelineRange: element.projectRange,
              zOrder: zOrder,
              detail:
                  'Authored ${element.kind.name} element `${element.id}` contributes a compositor-owned overlay surface range to the export graph.',
              nodeId:
                  _canonicalEffectsNodeIdForAddress('element:${element.id}'),
            ),
          );
        }
      }
    }

    final requirementReasons = <String>[
      if (nonEmptyVisualTrackCount > 1) 'multiple_visual_media_tracks',
      if (motionNonTextElementCount > 0) 'non_text_authored_visuals_present',
      if (motionEffectCount > 0) 'motion_effects_present',
      if (motionTransitionCount > 0) 'motion_transitions_present',
      if (motionCameraCount > 0) 'motion_cameras_present',
    ];
    final windows = _buildVisualAssemblyWindows(
      segments: segments,
      durationMs: format.durationTime.inMilliseconds,
    );
    final rawCompositorWindowExecutionPlans =
        _buildCompositorWindowExecutionPlans(
      windows: windows,
      segments: segments,
    );
    final supportedCompositorWindowIds =
        _resolveSupportedBackendCompositorWindowIds(
      compositorWindowExecutionPlans: rawCompositorWindowExecutionPlans,
      segments: segments,
    );
    final compositorWindowExecutionPlans = rawCompositorWindowExecutionPlans;
    final normalizedWindows = windows
        .map(
          (window) =>
              window.policy == ExportVisualAssemblyPolicyKind.compositorRequired
                  ? ExportVisualAssemblyWindowDescriptor(
                      id: window.id,
                      timelineRange: window.timelineRange,
                      policy: window.policy,
                      executionOwner: window.executionOwner,
                      requiresVisualCompositor: window.requiresVisualCompositor,
                      supportsCurrentBackend:
                          supportedCompositorWindowIds.contains(window.id),
                      activeLayerIds: window.activeLayerIds,
                      activeSegmentIds: window.activeSegmentIds,
                      detail: supportedCompositorWindowIds.contains(window.id)
                          ? 'This compositor-owned window matches the narrow current backend compositor path.'
                          : window.detail,
                    )
                  : window,
        )
        .toList(growable: false);

    return ExportVisualCompositorGraph(
      layers: layers,
      segments: segments,
      windows: normalizedWindows,
      compositorWindowExecutionPlans: compositorWindowExecutionPlans,
      maxConcurrentVisualSegments:
          _computeMaxConcurrentVisualSegments(segments),
      requiresVisualCompositor: requirementReasons.isNotEmpty,
      requirementReasons: requirementReasons,
    );
  }

  List<ExportTrackDescriptor> get _nonEmptyTracks =>
      tracks.where((track) => track.clips.isNotEmpty).toList(growable: false);

  int get nonEmptyVisualTrackCount => _nonEmptyTracks
      .where(
        (track) =>
            track.kind == ExportTrackKind.video ||
            track.kind == ExportTrackKind.image,
      )
      .length;

  int get nonEmptyAudioTrackCount => _nonEmptyTracks
      .where((track) => track.kind == ExportTrackKind.audio)
      .length;

  bool get expectedHasAudio => nonEmptyAudioTrackCount > 0;

  bool get hasCurveSpeedClips => _nonEmptyTracks.any(
        (track) => track.clips.any(
          (clip) => clip.speedMode == ExportClipSpeedMode.curve,
        ),
      );

  Set<String> get encounteredInterpolationKinds {
    final kinds = <String>{};
    final program = motionTextProgram;
    if (program == null) {
      return kinds;
    }
    for (final node in program.nodes) {
      for (final block in node.animationBlocks) {
        kinds.add(block.interpolationKind);
      }
      for (final channel in node.channels) {
        for (final keyframe in channel.keyframes) {
          kinds.add(keyframe.interpolationKind);
        }
      }
      for (final channel in node.layerChannels) {
        for (final keyframe in channel.keyframes) {
          kinds.add(keyframe.interpolationKind);
        }
      }
    }
    return kinds;
  }

  static const Set<String> _registeredInterpolationKinds = <String>{
    'linear',
    'hold',
    'easeIn',
    'easeOut',
    'easeInOut',
    'cubicBezier',
    'spring',
    'bounce',
    'elastic',
  };

  List<String> get unsupportedInterpolationKinds =>
      encounteredInterpolationKinds
          .where((kind) => !_registeredInterpolationKinds.contains(kind))
          .toList(growable: false)
        ..sort();

  bool get hasUnsupportedInterpolationKinds =>
      unsupportedInterpolationKinds.isNotEmpty;

  String get baselineProfileLabel => 'single visual + optional single audio';

  int get visualWindowCount => visualCompositorGraph.windows.length;

  int get visualGapWindowCount => visualCompositorGraph.gapWindowCount;

  int get visualMediaOnlyWindowCount =>
      visualCompositorGraph.mediaOnlyWindowCount;

  int get visualMediaWithOverlayWindowCount =>
      visualCompositorGraph.mediaWithAuthoredOverlayWindowCount;

  int get visualCompositorRequiredWindowCount =>
      visualCompositorGraph.compositorRequiredWindowCount;

  List<ExportVisualAssemblyWindowDescriptor> get blockedVisualAssemblyWindows =>
      visualCompositorGraph.compositorRequiredWindows;

  ExportVisualAssemblyWindowDescriptor? get firstBlockedVisualAssemblyWindow =>
      blockedVisualAssemblyWindows.isEmpty
          ? null
          : blockedVisualAssemblyWindows.first;

  List<ExportParityLimitationCode> get currentParityLimitationCodes {
    final limitations = <ExportParityLimitationCode>[];
    final hasUnsupportedCompositorWindows =
        visualCompositorGraph.compositorRequiredWindows.isNotEmpty;
    if (motionTextElementCount > 0) {
      if (motionTextProgram == null) {
        limitations.add(ExportParityLimitationCode.textMotionRendererParity);
      }
      limitations.add(ExportParityLimitationCode.typographyParity);
      limitations.add(ExportParityLimitationCode.interpolationParity);
    }
    if (motionNonTextElementCount > 0 && hasUnsupportedCompositorWindows) {
      limitations.add(ExportParityLimitationCode.nonTextMotionParity);
    }
    if (motionCameraCount > 0) {
      limitations.add(ExportParityLimitationCode.motionCameraParity);
    }
    if (motionEffectCount > 0 && hasUnsupportedCompositorWindows) {
      limitations.add(ExportParityLimitationCode.motionEffectParity);
    }
    if (motionTransitionCount > 0 && hasUnsupportedCompositorWindows) {
      limitations.add(ExportParityLimitationCode.motionTransitionParity);
    }
    if (nonEmptyVisualTrackCount > 1 && hasUnsupportedCompositorWindows) {
      limitations.add(ExportParityLimitationCode.multiVisualCompositingParity);
    }
    if (nonEmptyAudioTrackCount > 1) {
      limitations.add(ExportParityLimitationCode.multiAudioParity);
    }
    for (final track in _nonEmptyTracks) {
      if (track.kind == ExportTrackKind.text) {
        limitations.add(ExportParityLimitationCode.textTrackParity);
      }
      if (track.kind == ExportTrackKind.lipSync) {
        limitations.add(ExportParityLimitationCode.lipSyncTrackParity);
      }
    }
    if (hasCurveSpeedClips) {
      limitations.add(ExportParityLimitationCode.curveSpeedParity);
    }
    return limitations.toSet().toList(growable: false);
  }

  List<String> get currentParityLimitations => currentParityLimitationCodes
      .map(_parityLimitationMessage)
      .toList(growable: false);

  List<ExportBaselineBlockerCode> get firstBaselineBlockingCodes {
    final reasons = <ExportBaselineBlockerCode>[];
    final unsupportedCompositorWindows =
        visualCompositorGraph.compositorRequiredWindows;
    final hasUnsupportedCompositorWindows =
        unsupportedCompositorWindows.isNotEmpty;
    if (hasErrors) {
      reasons.add(ExportBaselineBlockerCode.unresolvedCompositionErrors);
    }
    if (unsupportedCompositorWindows.isNotEmpty) {
      reasons.add(ExportBaselineBlockerCode.compositorRequiredVisualWindow);
    }
    if (motionComposition != null) {
      if (motionNonTextElementCount > 0 && hasUnsupportedCompositorWindows) {
        reasons.add(ExportBaselineBlockerCode.unsupportedNonTextMotion);
      }
      if (motionCameraCount > 0) {
        reasons.add(ExportBaselineBlockerCode.unsupportedMotionCamera);
      }
      if (motionEffectCount > 0 && hasUnsupportedCompositorWindows) {
        reasons.add(ExportBaselineBlockerCode.unsupportedMotionEffect);
      }
      if (motionTransitionCount > 0 && hasUnsupportedCompositorWindows) {
        reasons.add(ExportBaselineBlockerCode.unsupportedMotionTransition);
      }
      if (motionTextElementCount > 0 && motionTextProgram == null) {
        reasons.add(ExportBaselineBlockerCode.missingMotionTextProgram);
      }
    }
    final nonEmptyTracks = _nonEmptyTracks;
    if (nonEmptyTracks.isEmpty) {
      reasons.add(ExportBaselineBlockerCode.noMediaClips);
    }
    final nonEmptyVisualTracks = nonEmptyTracks
        .where(
          (track) =>
              track.kind == ExportTrackKind.video ||
              track.kind == ExportTrackKind.image,
        )
        .toList(growable: false);
    final nonEmptyAudioTracks = nonEmptyTracks
        .where((track) => track.kind == ExportTrackKind.audio)
        .toList(growable: false);
    if (nonEmptyVisualTracks.isEmpty) {
      reasons.add(ExportBaselineBlockerCode.noVisualBaselineTrack);
    }
    if (nonEmptyVisualTracks.length > 1 &&
        unsupportedCompositorWindows.isNotEmpty) {
      reasons.add(ExportBaselineBlockerCode.multipleVisualTracks);
    }
    if (nonEmptyAudioTracks.length > 1) {
      reasons.add(ExportBaselineBlockerCode.multipleAudioTracks);
    }
    for (final track in nonEmptyTracks) {
      if (track.clips.isEmpty) {
        continue;
      }
      if (track.kind != ExportTrackKind.video &&
          track.kind != ExportTrackKind.image &&
          track.kind != ExportTrackKind.audio) {
        reasons.add(ExportBaselineBlockerCode.unsupportedTrackKind);
      }
      for (final clip in track.clips) {
        if (clip.speedMode == ExportClipSpeedMode.curve) {
          reasons.add(ExportBaselineBlockerCode.curveSpeed);
        }
      }
    }
    if (hasUnsupportedInterpolationKinds) {
      reasons.add(ExportBaselineBlockerCode.unsupportedInterpolationKind);
    }
    return reasons.toSet().toList(growable: false);
  }

  List<String> get firstBaselineBlockingReasons => firstBaselineBlockingCodes
      .map(_baselineBlockerMessage)
      .toList(growable: false);

  List<ExportCapabilityDescriptor> get capabilityMatrix =>
      <ExportCapabilityDescriptor>[
        const ExportCapabilityDescriptor(
          id: 'track.video',
          label: 'Video Track Export',
          scope: ExportCapabilityScope.trackType,
          status: ExportCapabilityStatus.supported,
          detail:
              'Video clips export through the media-native Transformer path with trim, sequencing, and constant speed support.',
        ),
        const ExportCapabilityDescriptor(
          id: 'track.image',
          label: 'Image Track Export',
          scope: ExportCapabilityScope.trackType,
          status: ExportCapabilityStatus.baselineOnly,
          detail:
              'Image clips are supported within the current single-visual baseline path only.',
        ),
        const ExportCapabilityDescriptor(
          id: 'track.audio.single',
          label: 'Single Audio Track Export',
          scope: ExportCapabilityScope.trackType,
          status: ExportCapabilityStatus.baselineOnly,
          detail:
              'One audio track can join the current baseline export path as a separate sequence.',
        ),
        const ExportCapabilityDescriptor(
          id: 'track.audio.multi',
          label: 'Multi-Audio Export',
          scope: ExportCapabilityScope.trackType,
          status: ExportCapabilityStatus.blocked,
          detail: 'A full audio graph and mix engine are not yet implemented.',
        ),
        const ExportCapabilityDescriptor(
          id: 'track.text',
          label: 'Dedicated Text Track Export',
          scope: ExportCapabilityScope.trackType,
          status: ExportCapabilityStatus.blocked,
          detail:
              'Dedicated text-track export parity is not implemented outside the authored motion-text path.',
        ),
        const ExportCapabilityDescriptor(
          id: 'track.lip_sync',
          label: 'Lip Sync Track Export',
          scope: ExportCapabilityScope.trackType,
          status: ExportCapabilityStatus.blocked,
          detail: 'Lip sync track export parity is not implemented.',
        ),
        const ExportCapabilityDescriptor(
          id: 'node.text_motion',
          label: 'Text Motion Export',
          scope: ExportCapabilityScope.nodeType,
          status: ExportCapabilityStatus.approximation,
          detail:
              'Text motion now uses a deterministic program path, but final renderer parity is not complete.',
        ),
        const ExportCapabilityDescriptor(
          id: 'node.non_text_motion',
          label: 'Non-Text Motion Export',
          scope: ExportCapabilityScope.nodeType,
          status: ExportCapabilityStatus.blocked,
          detail:
              'Non-text motion elements are not yet represented by a supported export renderer.',
        ),
        const ExportCapabilityDescriptor(
          id: 'node.effect',
          label: 'Effect Node Export',
          scope: ExportCapabilityScope.nodeType,
          status: ExportCapabilityStatus.blocked,
          detail: 'Authored effect-node export parity is not implemented.',
        ),
        const ExportCapabilityDescriptor(
          id: 'node.transition',
          label: 'Transition Node Export',
          scope: ExportCapabilityScope.nodeType,
          status: ExportCapabilityStatus.blocked,
          detail: 'Authored transition-node export parity is not implemented.',
        ),
        const ExportCapabilityDescriptor(
          id: 'node.camera',
          label: 'Camera Node Export',
          scope: ExportCapabilityScope.nodeType,
          status: ExportCapabilityStatus.blocked,
          detail: 'Camera-node export parity is not implemented.',
        ),
        const ExportCapabilityDescriptor(
          id: 'property.constant_speed',
          label: 'Constant Speed Export',
          scope: ExportCapabilityScope.property,
          status: ExportCapabilityStatus.supported,
          detail:
              'Constant clip speed is handled natively through the Transformer export path.',
        ),
        const ExportCapabilityDescriptor(
          id: 'property.curve_speed',
          label: 'Curve Speed Export',
          scope: ExportCapabilityScope.property,
          status: ExportCapabilityStatus.blocked,
          detail: 'Curve speed export parity is not implemented.',
        ),
        ExportCapabilityDescriptor(
          id: 'property.interpolation',
          label: 'Interpolation Parity',
          scope: ExportCapabilityScope.property,
          status: hasUnsupportedInterpolationKinds
              ? ExportCapabilityStatus.blocked
              : ExportCapabilityStatus.approximation,
          detail: hasUnsupportedInterpolationKinds
              ? 'Encountered interpolation kinds are not in the authoritative export registry: ${unsupportedInterpolationKinds.join(', ')}'
              : 'Interpolation support is partial and must still be aligned across preview and export runtimes.',
        ),
        const ExportCapabilityDescriptor(
          id: 'property.typography',
          label: 'Typography Parity',
          scope: ExportCapabilityScope.property,
          status: ExportCapabilityStatus.approximation,
          detail:
              'Typography semantics still require explicit parity work across preview and export renderers.',
        ),
        const ExportCapabilityDescriptor(
          id: 'system.multi_visual_compositing',
          label: 'Multi-Visual Compositing',
          scope: ExportCapabilityScope.system,
          status: ExportCapabilityStatus.blocked,
          detail:
              'The current export baseline is not a full visual compositor and does not support multi-visual parity.',
        ),
        const ExportCapabilityDescriptor(
          id: 'system.audio_graph',
          label: 'Audio Graph',
          scope: ExportCapabilityScope.system,
          status: ExportCapabilityStatus.blocked,
          detail:
              'Audio is currently baseline inclusion, not a full deterministic audio graph.',
        ),
        const ExportCapabilityDescriptor(
          id: 'fallback.motion_text_render_track',
          label: 'Motion Text Sampled Fallback',
          scope: ExportCapabilityScope.system,
          status: ExportCapabilityStatus.fallbackOnly,
          detail:
              'Sampled text render snapshots remain fallback/debug input only and are not final truth.',
        ),
      ];

  List<ExportRendererOwnershipDescriptor> get rendererOwnershipMatrix =>
      const <ExportRendererOwnershipDescriptor>[
        ExportRendererOwnershipDescriptor(
          id: 'renderer.media3_transformer',
          label: 'Media-Native Export Lane',
          primaryRendererId: 'media3_transformer',
          fallbackAllowed: false,
          detail:
              'Owns decode/transform/encode/mux for media-native clips, trim, sequencing, preset sizing, and constant speed.',
        ),
        ExportRendererOwnershipDescriptor(
          id: 'renderer.motion_text_program',
          label: 'Deterministic Motion Text Lane',
          primaryRendererId:
              'motion_text_program->media3_overlay_canvas_renderer',
          fallbackRendererId: 'motion_text_render_track_fallback',
          fallbackAllowed: true,
          detail:
              'Owns authored text-motion evaluation from the canonical program. Sampled render-track input is fallback/debug only.',
        ),
        ExportRendererOwnershipDescriptor(
          id: 'renderer.authored_visual_surface',
          label: 'Authored Visual Surface Lane',
          primaryRendererId: 'canonical_effects_graph->visual_compositor_graph',
          fallbackAllowed: false,
          detail:
              'Owns non-text authored visual surfaces such as image and shape overlays once they are promoted onto the shared compositor/effects backend.',
        ),
        ExportRendererOwnershipDescriptor(
          id: 'renderer.audio_sequence',
          label: 'Baseline Audio Export Lane',
          primaryRendererId: 'media3_sequence_audio_path',
          fallbackAllowed: false,
          detail:
              'Owns current baseline audio export through a dedicated audio sequence, not a full audio graph.',
        ),
      ];

  List<ExportPropertyCapabilityDescriptor> get propertyCapabilityMatrix =>
      <ExportPropertyCapabilityDescriptor>[
        const ExportPropertyCapabilityDescriptor(
          propertyId: 'transform.position.x',
          label: 'Position X',
          scope: ExportCapabilityScope.property,
          status: ExportCapabilityStatus.approximation,
          rendererOwnerId: 'renderer.motion_text_program',
          detail:
              'Represented end-to-end for motion text, but preview/export parity is not yet fully verified.',
        ),
        const ExportPropertyCapabilityDescriptor(
          propertyId: 'transform.position.y',
          label: 'Position Y',
          scope: ExportCapabilityScope.property,
          status: ExportCapabilityStatus.approximation,
          rendererOwnerId: 'renderer.motion_text_program',
          detail:
              'Represented end-to-end for motion text, but preview/export parity is not yet fully verified.',
        ),
        const ExportPropertyCapabilityDescriptor(
          propertyId: 'transform.scale.x',
          label: 'Scale X',
          scope: ExportCapabilityScope.property,
          status: ExportCapabilityStatus.approximation,
          rendererOwnerId: 'renderer.motion_text_program',
          detail:
              'Represented in the deterministic program and native export path, pending parity hardening.',
        ),
        const ExportPropertyCapabilityDescriptor(
          propertyId: 'transform.scale.y',
          label: 'Scale Y',
          scope: ExportCapabilityScope.property,
          status: ExportCapabilityStatus.approximation,
          rendererOwnerId: 'renderer.motion_text_program',
          detail:
              'Represented in the deterministic program and native export path, pending parity hardening.',
        ),
        const ExportPropertyCapabilityDescriptor(
          propertyId: 'transform.rotation.degrees',
          label: 'Rotation',
          scope: ExportCapabilityScope.property,
          status: ExportCapabilityStatus.approximation,
          rendererOwnerId: 'renderer.motion_text_program',
          detail:
              'Represented for motion text, but export parity remains approximate rather than accepted.',
        ),
        const ExportPropertyCapabilityDescriptor(
          propertyId: 'visual.opacity',
          label: 'Opacity',
          scope: ExportCapabilityScope.property,
          status: ExportCapabilityStatus.approximation,
          rendererOwnerId: 'renderer.motion_text_program',
          detail:
              'Represented for text-motion export through deterministic scalar channels and native draw state.',
        ),
        const ExportPropertyCapabilityDescriptor(
          propertyId: 'visual.blur.amount',
          label: 'Blur Amount',
          scope: ExportCapabilityScope.property,
          status: ExportCapabilityStatus.approximation,
          rendererOwnerId: 'renderer.motion_text_program',
          detail:
              'Represented in export, but blur-model parity with preview is not yet guaranteed.',
        ),
        const ExportPropertyCapabilityDescriptor(
          propertyId: 'visual.blendMode',
          label: 'Blend Mode',
          scope: ExportCapabilityScope.property,
          status: ExportCapabilityStatus.approximation,
          rendererOwnerId: 'renderer.motion_text_program',
          detail:
              'Blend semantics have first-path export wiring, but not full parity coverage.',
        ),
        const ExportPropertyCapabilityDescriptor(
          propertyId: 'text.content',
          label: 'Text Content',
          scope: ExportCapabilityScope.property,
          status: ExportCapabilityStatus.approximation,
          rendererOwnerId: 'renderer.motion_text_program',
          detail:
              'Full text content is exported, but final layout/render parity remains incomplete.',
        ),
        const ExportPropertyCapabilityDescriptor(
          propertyId: 'text.fontSize',
          label: 'Font Size',
          scope: ExportCapabilityScope.property,
          status: ExportCapabilityStatus.approximation,
          rendererOwnerId: 'renderer.motion_text_program',
          detail:
              'Font size is represented in the export program, but overall typography parity is not yet accepted.',
        ),
        const ExportPropertyCapabilityDescriptor(
          propertyId: 'text.letterSpacing',
          label: 'Letter Spacing',
          scope: ExportCapabilityScope.property,
          status: ExportCapabilityStatus.approximation,
          rendererOwnerId: 'renderer.motion_text_program',
          detail:
              'Letter spacing is represented, but heavy cinematic presets still require renderer parity work.',
        ),
        const ExportPropertyCapabilityDescriptor(
          propertyId: 'text.revealProgress',
          label: 'Reveal Progress',
          scope: ExportCapabilityScope.property,
          status: ExportCapabilityStatus.approximation,
          rendererOwnerId: 'renderer.motion_text_program',
          detail:
              'Reveal progress is represented, but reveal semantics are not yet fully parity-locked.',
        ),
        const ExportPropertyCapabilityDescriptor(
          propertyId: 'text.color',
          label: 'Text Color',
          scope: ExportCapabilityScope.property,
          status: ExportCapabilityStatus.baselineOnly,
          rendererOwnerId: 'renderer.motion_text_program',
          detail:
              'Shared canonical text color is represented end-to-end, but authored color controls are not yet exposed.',
        ),
        const ExportPropertyCapabilityDescriptor(
          propertyId: 'text.fontFamily',
          label: 'Font Family',
          scope: ExportCapabilityScope.property,
          status: ExportCapabilityStatus.blocked,
          rendererOwnerId: 'renderer.motion_text_program',
          detail: 'Font-family parity is not represented end-to-end in export.',
        ),
        const ExportPropertyCapabilityDescriptor(
          propertyId: 'text.fontWeight',
          label: 'Font Weight/Style',
          scope: ExportCapabilityScope.property,
          status: ExportCapabilityStatus.baselineOnly,
          rendererOwnerId: 'renderer.motion_text_program',
          detail:
              'Shared canonical font-weight/style semantics are represented end-to-end, but authored font controls are not yet exposed.',
        ),
        const ExportPropertyCapabilityDescriptor(
          propertyId: 'text.lineHeight',
          label: 'Line Height',
          scope: ExportCapabilityScope.property,
          status: ExportCapabilityStatus.baselineOnly,
          rendererOwnerId: 'renderer.motion_text_program',
          detail:
              'Shared canonical line-height semantics are represented end-to-end, but authored line-height controls are not yet exposed.',
        ),
        const ExportPropertyCapabilityDescriptor(
          propertyId: 'text.alignment',
          label: 'Text Alignment',
          scope: ExportCapabilityScope.property,
          status: ExportCapabilityStatus.baselineOnly,
          rendererOwnerId: 'renderer.motion_text_program',
          detail:
              'Shared canonical text alignment semantics are represented end-to-end, but authored alignment controls are not yet exposed.',
        ),
        const ExportPropertyCapabilityDescriptor(
          propertyId: 'text.anchor',
          label: 'Text Anchor',
          scope: ExportCapabilityScope.property,
          status: ExportCapabilityStatus.baselineOnly,
          rendererOwnerId: 'renderer.motion_text_program',
          detail:
              'Shared canonical anchor semantics are represented end-to-end, but authored anchor controls are not yet exposed.',
        ),
        const ExportPropertyCapabilityDescriptor(
          propertyId: 'text.stroke',
          label: 'Text Stroke',
          scope: ExportCapabilityScope.property,
          status: ExportCapabilityStatus.blocked,
          rendererOwnerId: 'renderer.motion_text_program',
          detail:
              'Stroke semantics are not represented in the current export contract.',
        ),
        const ExportPropertyCapabilityDescriptor(
          propertyId: 'text.shadow',
          label: 'Text Shadow',
          scope: ExportCapabilityScope.property,
          status: ExportCapabilityStatus.blocked,
          rendererOwnerId: 'renderer.motion_text_program',
          detail:
              'Shadow semantics are not represented as a canonical export property.',
        ),
        const ExportPropertyCapabilityDescriptor(
          propertyId: 'channel.beforeStart',
          label: 'Before-Start Behavior',
          scope: ExportCapabilityScope.property,
          status: ExportCapabilityStatus.blocked,
          rendererOwnerId: 'renderer.motion_text_program',
          detail:
              'Before-start channel behavior is not yet evaluated as a supported export semantic.',
        ),
        const ExportPropertyCapabilityDescriptor(
          propertyId: 'channel.afterEnd',
          label: 'After-End Behavior',
          scope: ExportCapabilityScope.property,
          status: ExportCapabilityStatus.blocked,
          rendererOwnerId: 'renderer.motion_text_program',
          detail:
              'After-end channel behavior is not yet evaluated as a supported export semantic.',
        ),
      ];

  static const Map<String, List<String>> _knownInterpolationParameters =
      <String, List<String>>{
    'linear': <String>[],
    'hold': <String>[],
    'easeIn': <String>[],
    'easeOut': <String>[],
    'easeInOut': <String>[],
    'cubicBezier': <String>['x1', 'y1', 'x2', 'y2'],
    'spring': <String>['stiffness', 'damping', 'mass', 'initialVelocity'],
    'bounce': <String>['amplitude', 'bounces', 'decay'],
    'elastic': <String>['amplitude', 'period', 'decay'],
  };

  List<ExportInterpolationContractDescriptor>
      get interpolationContractRegistry {
    final descriptors = <ExportInterpolationContractDescriptor>[];
    final encountered = encounteredInterpolationKinds;
    final knownKinds = <String>{
      ..._registeredInterpolationKinds,
      ...encountered,
    }.toList(growable: false)
      ..sort();
    for (final kind in knownKinds) {
      final isRegistered = _registeredInterpolationKinds.contains(kind);
      descriptors.add(
        ExportInterpolationContractDescriptor(
          kind: kind,
          status: isRegistered
              ? ExportCapabilityStatus.supported
              : ExportCapabilityStatus.blocked,
          requiredParameters: List<String>.unmodifiable(
              _knownInterpolationParameters[kind] ?? const <String>[]),
          evaluatorId:
              isRegistered ? 'native_scalar_channel_evaluator' : 'unassigned',
          detail: isRegistered
              ? 'Registered export interpolation kind with an explicit native evaluator path.'
              : 'Encountered interpolation kind is not registered for export and must block rather than downgrade silently.',
          encountered: encountered.contains(kind),
        ),
      );
    }
    return descriptors;
  }

  List<ExportInterpolationSupportDescriptor> get interpolationRegistry =>
      interpolationContractRegistry
          .map(
            (entry) => ExportInterpolationSupportDescriptor(
              kind: entry.kind,
              status: entry.status,
              detail: entry.detail,
              encountered: entry.encountered,
            ),
          )
          .toList(growable: false);

  Map<String, Object?> get graphMetadata => <String, Object?>{
        'schemaVersion': graphSchemaVersion,
        'backendProfile': backendProfile.toBridgeMap(),
        'visualCompositorGraph': visualCompositorGraph.toSummaryBridgeMap(),
        'canonicalEffectsGraph': canonicalEffectsGraph.toSummaryBridgeMap(),
        'motionTextRasterContract': motionTextRasterContract?.toBridgeMap(),
        'motionTextRasterProgramNodeCount':
            motionTextRasterProgram?.nodes.length,
        'authoredVisualSurfaceProgramNodeCount':
            authoredVisualSurfaceProgram?.nodes.length,
        'truthSources':
            truthSources.map((source) => source.toBridgeMap()).toList(),
        'capabilityMatrix':
            capabilityMatrix.map((entry) => entry.toBridgeMap()).toList(),
        'propertyCapabilityMatrix': propertyCapabilityMatrix
            .map((entry) => entry.toBridgeMap())
            .toList(),
        'rendererOwnershipMatrix': rendererOwnershipMatrix
            .map((entry) => entry.toBridgeMap())
            .toList(),
        'interpolationRegistry':
            interpolationRegistry.map((entry) => entry.toBridgeMap()).toList(),
        'interpolationContractRegistry': interpolationContractRegistry
            .map((entry) => entry.toBridgeMap())
            .toList(),
        'unsupportedInterpolationKinds': unsupportedInterpolationKinds,
      };

  Map<String, Object?> get preflightSummary => <String, Object?>{
        'graphSchemaVersion': graphSchemaVersion,
        'backendProfile': backendProfile.toBridgeMap(),
        'baselineProfile': baselineProfileLabel,
        'visualCompositorGraph': visualCompositorGraph.toSummaryBridgeMap(),
        'canonicalEffectsGraph': canonicalEffectsGraph.toSummaryBridgeMap(),
        'motionTextRasterContractIncluded': motionTextRasterContract != null,
        'motionTextRasterProgramIncluded': motionTextRasterProgram != null,
        'authoredVisualSurfaceProgramIncluded':
            authoredVisualSurfaceProgram != null,
        'nonEmptyTrackCount': _nonEmptyTracks.length,
        'visualTrackCount': nonEmptyVisualTrackCount,
        'audioTrackCount': nonEmptyAudioTrackCount,
        'expectedHasAudio': expectedHasAudio,
        'hasCurveSpeedClips': hasCurveSpeedClips,
        'motionTextProgramIncluded': motionTextProgram != null,
        'motionTextRenderTrackIncluded': motionTextRenderTrack != null,
        'isFirstBaselineEligible': isFirstBaselineEligible,
        'firstBaselineBlockingCodes':
            firstBaselineBlockingCodes.map((code) => code.name).toList(),
        'firstBaselineBlockingReasons': firstBaselineBlockingReasons,
        'currentParityLimitationCodes':
            currentParityLimitationCodes.map((code) => code.name).toList(),
        'currentParityLimitations': currentParityLimitations,
        'unsupportedInterpolationKinds': unsupportedInterpolationKinds,
        'rendererOwnershipMatrix': rendererOwnershipMatrix
            .map((entry) => entry.toBridgeMap())
            .toList(),
        'propertyCapabilityMatrix': propertyCapabilityMatrix
            .map((entry) => entry.toBridgeMap())
            .toList(),
        'interpolationContractRegistry': interpolationContractRegistry
            .map((entry) => entry.toBridgeMap())
            .toList(),
        'truthSources':
            truthSources.map((source) => source.toBridgeMap()).toList(),
      };

  bool get isFirstBaselineEligible => firstBaselineBlockingReasons.isEmpty;

  Map<String, Object?> toDiagnosticMap() {
    return <String, Object?>{
      'contractVersion': contractVersion,
      'graphSchemaVersion': graphSchemaVersion,
      'projectId': projectId,
      'graphMetadata': graphMetadata,
      'visualCompositorGraph': visualCompositorGraph.toBridgeMap(),
      'canonicalEffectsGraph': canonicalEffectsGraph.toBridgeMap(),
      'motionTextRasterContract': motionTextRasterContract?.toBridgeMap(),
      'motionTextRasterProgram': motionTextRasterProgram?.toBridgeMap(),
      'authoredVisualSurfaceProgram':
          authoredVisualSurfaceProgram?.toBridgeMap(),
      'format': <String, Object?>{
        'canvasWidth': format.canvasWidth,
        'canvasHeight': format.canvasHeight,
        'pixelAspectRatio': format.pixelAspectRatio,
        'frameRateNumerator': format.frameRateNumerator,
        'frameRateDenominator': format.frameRateDenominator,
        'durationMs': format.durationTime.inMilliseconds,
      },
      'assets': assets
          .map(
            (asset) => <String, Object?>{
              'assetId': asset.assetId,
              'kind': asset.kind.name,
              'label': asset.label,
              'sourceUri': asset.sourceUri,
              'durationMs': asset.durationTime?.inMilliseconds,
              'width': asset.width,
              'height': asset.height,
              'isImported': asset.isImported,
            },
          )
          .toList(growable: false),
      'tracks': tracks
          .map(
            (track) => <String, Object?>{
              'kind': track.kind.name,
              'clips': track.clips
                  .map(
                    (clip) => <String, Object?>{
                      'clipId': clip.clipId,
                      'assetId': clip.assetId,
                      'timelineStartMs':
                          clip.timelineRange.start.inMilliseconds,
                      'timelineDurationMs':
                          clip.timelineRange.duration.inMilliseconds,
                      'sourceStartMs': clip.sourceRange.start.inMilliseconds,
                      'sourceDurationMs':
                          clip.sourceRange.duration.inMilliseconds,
                      'playbackRate': clip.playbackRate,
                      'speedMode': clip.speedMode.name,
                      'splitGroupId': clip.splitGroupId,
                      'label': clip.label,
                    },
                  )
                  .toList(growable: false),
            },
          )
          .toList(growable: false),
      'motionIncluded': motionComposition != null,
      'motionTextProgramIncluded': motionTextProgram != null,
      'motionTextRenderTrackIncluded': motionTextRenderTrack != null,
      'preflightSummary': preflightSummary,
      'capabilityMatrix':
          capabilityMatrix.map((entry) => entry.toBridgeMap()).toList(),
      'interpolationRegistry':
          interpolationRegistry.map((entry) => entry.toBridgeMap()).toList(),
      'truthSources':
          truthSources.map((source) => source.toBridgeMap()).toList(),
      'issues': issues
          .map(
            (issue) => <String, Object?>{
              'code': issue.code.name,
              'severity': issue.severity.name,
              'message': issue.message,
              'trackKind': issue.trackKind?.name,
              'clipId': issue.clipId,
              'assetId': issue.assetId,
            },
          )
          .toList(growable: false),
      'firstBaselineBlockingCodes':
          firstBaselineBlockingCodes.map((code) => code.name).toList(),
      'firstBaselineBlockingReasons': firstBaselineBlockingReasons,
      'currentParityLimitationCodes':
          currentParityLimitationCodes.map((code) => code.name).toList(),
      'currentParityLimitations': currentParityLimitations,
    };
  }

  Map<String, Object?> toBridgeMap() {
    return <String, Object?>{
      'contractVersion': contractVersion,
      'graphSchemaVersion': graphSchemaVersion,
      'projectId': projectId,
      'graphMetadata': graphMetadata,
      'visualCompositorGraph': visualCompositorGraph.toBridgeMap(),
      'canonicalEffectsGraph': canonicalEffectsGraph.toBridgeMap(),
      'motionTextRasterContract': motionTextRasterContract?.toBridgeMap(),
      'motionTextRasterProgram': motionTextRasterProgram?.toBridgeMap(),
      'format': <String, Object?>{
        'canvasWidth': format.canvasWidth,
        'canvasHeight': format.canvasHeight,
        'pixelAspectRatio': format.pixelAspectRatio,
        'frameRateNumerator': format.frameRateNumerator,
        'frameRateDenominator': format.frameRateDenominator,
        'durationMs': format.durationTime.inMilliseconds,
      },
      'assets': assets
          .map(
            (asset) => <String, Object?>{
              'assetId': asset.assetId,
              'kind': asset.kind.name,
              'label': asset.label,
              'sourceUri': asset.sourceUri,
              'durationMs': asset.durationTime?.inMilliseconds,
              'width': asset.width,
              'height': asset.height,
              'isImported': asset.isImported,
            },
          )
          .toList(growable: false),
      'tracks': tracks
          .map(
            (track) => <String, Object?>{
              'kind': track.kind.name,
              'clips': track.clips
                  .map(
                    (clip) => <String, Object?>{
                      'clipId': clip.clipId,
                      'assetId': clip.assetId,
                      'timelineStartMs':
                          clip.timelineRange.start.inMilliseconds,
                      'timelineDurationMs':
                          clip.timelineRange.duration.inMilliseconds,
                      'sourceStartMs': clip.sourceRange.start.inMilliseconds,
                      'sourceDurationMs':
                          clip.sourceRange.duration.inMilliseconds,
                      'playbackRate': clip.playbackRate,
                      'speedMode': clip.speedMode.name,
                      'splitGroupId': clip.splitGroupId,
                      'label': clip.label,
                    },
                  )
                  .toList(growable: false),
            },
          )
          .toList(growable: false),
      'preflightSummary': preflightSummary,
      'capabilityMatrix':
          capabilityMatrix.map((entry) => entry.toBridgeMap()).toList(),
      'interpolationRegistry':
          interpolationRegistry.map((entry) => entry.toBridgeMap()).toList(),
      'truthSources':
          truthSources.map((source) => source.toBridgeMap()).toList(),
      'motion': motionComposition == null
          ? null
          : _motionCompositionBridgeMap(motionComposition!),
      'motionTextProgram': motionTextProgram == null
          ? null
          : _motionTextProgramBridgeMap(motionTextProgram!),
      'authoredVisualSurfaceProgram':
          authoredVisualSurfaceProgram?.toBridgeMap(),
      'motionTextRenderTrack': motionTextRenderTrack == null
          ? null
          : _motionTextRenderTrackBridgeMap(motionTextRenderTrack!),
      'issues': issues
          .map(
            (issue) => <String, Object?>{
              'code': issue.code.name,
              'severity': issue.severity.name,
              'message': issue.message,
              'trackKind': issue.trackKind?.name,
              'clipId': issue.clipId,
              'assetId': issue.assetId,
            },
          )
          .toList(growable: false),
    };
  }
}

ExportCanonicalEffectsGraph buildCanonicalEffectsGraphForExportComposition({
  required ExportProjectFormatDescriptor format,
  required List<ExportTrackDescriptor> tracks,
  required MotionNormalizedComposition? motionComposition,
  required ExportMotionTextProgram? motionTextProgram,
  required ExportMotionTextRenderTrack? motionTextRenderTrack,
}) {
  final nodes = <ExportCanonicalEffectsNodeDescriptor>[];
  final operations = <ExportCanonicalEffectOperationDescriptor>[];
  final addedNodeIds = <String>{};

  void addNode(ExportCanonicalEffectsNodeDescriptor node) {
    if (!addedNodeIds.add(node.id)) {
      return;
    }
    nodes.add(node);
  }

  void addOperation(ExportCanonicalEffectOperationDescriptor operation) {
    operations.add(operation);
  }

  for (final track in tracks) {
    for (final clip in track.clips) {
      final targetAddress = 'clip:${clip.clipId}';
      addNode(
        ExportCanonicalEffectsNodeDescriptor(
          id: _canonicalEffectsNodeIdForClip(clip.clipId),
          label: clip.label ?? '${track.kind.name} clip ${clip.clipId}',
          kind: _canonicalEffectsNodeKindForTrack(track.kind),
          sourceTruthKind: ExportTruthSourceKind.canonicalTracks,
          timelineRange: clip.timelineRange,
          backendSupport: _canonicalBackendSupportForNode(
            nodeKind: _canonicalEffectsNodeKindForTrack(track.kind),
            sourceTruthKind: ExportTruthSourceKind.canonicalTracks,
            trackKind: track.kind,
          ),
          targetAddress: targetAddress,
          trackKind: track.kind,
          clipId: clip.clipId,
          detail:
              'Canonical ${track.kind.name} clip `${clip.clipId}` participates in the export graph with trim/source range truth.',
        ),
      );
      if (clip.hasSpeedOverride) {
        addOperation(
          ExportCanonicalEffectOperationDescriptor(
            id: 'op.clip_speed.${clip.clipId}',
            label: 'clip speed ${clip.clipId}',
            kind: ExportCanonicalEffectOperationKind.propertyAssignment,
            sourceTruthKind: ExportTruthSourceKind.canonicalTracks,
            timelineRange: clip.timelineRange,
            backendSupport: _canonicalBackendSupportForOperation(
              kind: ExportCanonicalEffectOperationKind.propertyAssignment,
              sourceTruthKind: ExportTruthSourceKind.canonicalTracks,
              propertyId: 'clip.playbackRate',
            ),
            targetNodeId: _canonicalEffectsNodeIdForClip(clip.clipId),
            targetAddress: targetAddress,
            propertyId: 'clip.playbackRate',
            originId: clip.clipId,
            parameters: <String, Object?>{
              'playbackRate': clip.playbackRate,
              'speedMode': clip.speedMode.name,
              'sourceRange': _timelineTimeRangeBridgeMap(clip.sourceRange),
            },
            detail:
                'Canonical track truth applies clip-local speed without changing authored overlay timing semantics.',
          ),
        );
      }
    }
  }

  if (motionComposition != null) {
    for (final scene in motionComposition.scenes) {
      addNode(
        ExportCanonicalEffectsNodeDescriptor(
          id: _canonicalEffectsNodeIdForAddress('scene:${scene.id}'),
          label: scene.name ?? 'scene ${scene.id}',
          kind: ExportCanonicalEffectsNodeKind.genericElement,
          sourceTruthKind: ExportTruthSourceKind.motionComposition,
          timelineRange: scene.projectRange,
          backendSupport: _canonicalBackendSupportForNode(
            nodeKind: ExportCanonicalEffectsNodeKind.genericElement,
            sourceTruthKind: ExportTruthSourceKind.motionComposition,
          ),
          targetAddress: 'scene:${scene.id}',
          sceneId: scene.id,
          detail:
              'Resolved motion scene container `${scene.id}` contributes authored range and container-level semantics.',
        ),
      );
      for (final assignment in scene.staticProperties) {
        addOperation(
          _buildCanonicalPropertyAssignmentOperation(
            id: 'op.scene.static.${scene.id}.${assignment.definition.id}',
            label: 'scene property ${assignment.definition.path.canonicalKey}',
            sourceTruthKind: ExportTruthSourceKind.motionComposition,
            timelineRange: scene.projectRange,
            targetAddress: assignment.target.canonicalAddress,
            targetNodeId: _canonicalEffectsNodeIdForAddress(
                assignment.target.canonicalAddress),
            assignment: assignment,
            detail:
                'Resolved scene-level static property assignment from motion composition.',
          ),
        );
      }
      for (final channel in scene.propertyChannels) {
        addOperation(
          _buildCanonicalPropertyChannelOperation(
            sourceTruthKind: ExportTruthSourceKind.motionComposition,
            resolvedChannel: channel,
            detail:
                'Resolved scene-level property channel from motion composition.',
          ),
        );
      }
      for (final layer in scene.layers) {
        addNode(
          ExportCanonicalEffectsNodeDescriptor(
            id: _canonicalEffectsNodeIdForAddress('layer:${layer.id}'),
            label: layer.name ?? 'layer ${layer.id}',
            kind: ExportCanonicalEffectsNodeKind.genericElement,
            sourceTruthKind: ExportTruthSourceKind.motionComposition,
            timelineRange: layer.projectRange,
            backendSupport: _canonicalBackendSupportForNode(
              nodeKind: ExportCanonicalEffectsNodeKind.genericElement,
              sourceTruthKind: ExportTruthSourceKind.motionComposition,
            ),
            targetAddress: 'layer:${layer.id}',
            sceneId: layer.sceneId,
            layerId: layer.id,
            zOrder: layer.zIndex,
            detail:
                'Resolved motion layer `${layer.id}` contributes ordering, blend, and container-level property semantics.',
          ),
        );
        if (layer.blendMode != MotionBlendMode.normal) {
          addOperation(
            ExportCanonicalEffectOperationDescriptor(
              id: 'op.layer.blend.${layer.id}',
              label: 'layer blend ${layer.id}',
              kind: ExportCanonicalEffectOperationKind.blendMode,
              sourceTruthKind: ExportTruthSourceKind.motionComposition,
              timelineRange: layer.projectRange,
              backendSupport: _canonicalBackendSupportForOperation(
                kind: ExportCanonicalEffectOperationKind.blendMode,
                sourceTruthKind: ExportTruthSourceKind.motionComposition,
              ),
              targetNodeId: _canonicalEffectsNodeIdForAddress(
                'layer:${layer.id}',
              ),
              targetAddress: 'layer:${layer.id}',
              originId: layer.id,
              parameters: <String, Object?>{
                'blendMode': layer.blendMode.name,
                'zIndex': layer.zIndex,
              },
              detail:
                  'Layer-level blend semantics are authored in the motion composition and require renderer parity.',
            ),
          );
        }
        for (final assignment in layer.staticProperties) {
          addOperation(
            _buildCanonicalPropertyAssignmentOperation(
              id: 'op.layer.static.${layer.id}.${assignment.definition.id}',
              label:
                  'layer property ${assignment.definition.path.canonicalKey}',
              sourceTruthKind: ExportTruthSourceKind.motionComposition,
              timelineRange: layer.projectRange,
              targetAddress: assignment.target.canonicalAddress,
              targetNodeId: _canonicalEffectsNodeIdForAddress(
                assignment.target.canonicalAddress,
              ),
              assignment: assignment,
              detail:
                  'Resolved layer-level static property assignment from motion composition.',
            ),
          );
        }
        for (final channel in layer.propertyChannels) {
          addOperation(
            _buildCanonicalPropertyChannelOperation(
              sourceTruthKind: ExportTruthSourceKind.motionComposition,
              resolvedChannel: channel,
              detail:
                  'Resolved layer-level property channel from motion composition.',
            ),
          );
        }
        for (final element in layer.elements) {
          final elementAddress = 'element:${element.id}';
          final preferProgramTruth = motionTextProgram?.nodes.any(
                (node) => node.targetElementId == element.id,
              ) ??
              false;
          if (!preferProgramTruth) {
            addNode(
              ExportCanonicalEffectsNodeDescriptor(
                id: _canonicalEffectsNodeIdForAddress(elementAddress),
                label: element.name ?? 'element ${element.id}',
                kind: _canonicalEffectsNodeKindForMotionElement(element.kind),
                sourceTruthKind: ExportTruthSourceKind.motionComposition,
                timelineRange: element.projectRange,
                backendSupport: _canonicalBackendSupportForNode(
                  nodeKind: _canonicalEffectsNodeKindForMotionElement(
                    element.kind,
                  ),
                  sourceTruthKind: ExportTruthSourceKind.motionComposition,
                ),
                targetAddress: elementAddress,
                sceneId: element.sceneId,
                layerId: element.layerId,
                elementId: element.id,
                detail:
                    'Resolved motion element `${element.id}` contributes authored visual semantics from motion composition.',
              ),
            );
          }
          for (final assignment in element.staticProperties) {
            addOperation(
              _buildCanonicalPropertyAssignmentOperation(
                id: 'op.element.static.${element.id}.${assignment.definition.id}',
                label:
                    'element property ${assignment.definition.path.canonicalKey}',
                sourceTruthKind: ExportTruthSourceKind.motionComposition,
                timelineRange: element.projectRange,
                targetAddress: assignment.target.canonicalAddress,
                targetNodeId: _canonicalEffectsNodeIdForAddress(
                  assignment.target.canonicalAddress,
                ),
                assignment: assignment,
                detail:
                    'Resolved element-level static property assignment from motion composition.',
              ),
            );
          }
          for (final channel in element.propertyChannels) {
            addOperation(
              _buildCanonicalPropertyChannelOperation(
                sourceTruthKind: ExportTruthSourceKind.motionComposition,
                resolvedChannel: channel,
                detail:
                    'Resolved element-level property channel from motion composition.',
              ),
            );
          }
        }
      }
    }

    for (final channel in motionComposition.globalChannels) {
      addOperation(
        _buildCanonicalPropertyChannelOperation(
          sourceTruthKind: ExportTruthSourceKind.motionComposition,
          resolvedChannel: channel,
          detail:
              'Resolved project-level property channel from motion composition.',
        ),
      );
    }

    for (final effect in motionComposition.effects) {
      addOperation(
        ExportCanonicalEffectOperationDescriptor(
          id: 'op.effect.${effect.id}',
          label: effect.name ?? 'effect ${effect.kind.name}',
          kind: ExportCanonicalEffectOperationKind.motionEffect,
          sourceTruthKind: ExportTruthSourceKind.motionComposition,
          timelineRange: effect.projectRange,
          backendSupport: _canonicalBackendSupportForOperation(
            kind: ExportCanonicalEffectOperationKind.motionEffect,
            sourceTruthKind: ExportTruthSourceKind.motionComposition,
          ),
          targetNodeId: _canonicalEffectsNodeIdForAddress(effect.targetAddress),
          targetAddress: effect.targetAddress,
          originId: effect.id,
          parameters: <String, Object?>{
            'effectKind': effect.kind.name,
            'isEnabled': effect.isEnabled,
            'parameters': _motionPropertyValueMapBridgeValue(effect.parameters),
          },
          detail:
              'Resolved authored effect `${effect.id}` requires a professional effects backend for final parity.',
        ),
      );
    }

    for (final transition in motionComposition.transitions) {
      addOperation(
        ExportCanonicalEffectOperationDescriptor(
          id: 'op.transition.${transition.id}',
          label: transition.name ?? 'transition ${transition.kind.name}',
          kind: ExportCanonicalEffectOperationKind.motionTransition,
          sourceTruthKind: ExportTruthSourceKind.motionComposition,
          timelineRange: transition.projectRange,
          backendSupport: _canonicalBackendSupportForOperation(
            kind: ExportCanonicalEffectOperationKind.motionTransition,
            sourceTruthKind: ExportTruthSourceKind.motionComposition,
          ),
          targetAddress: 'transition:${transition.id}',
          originId: transition.id,
          parameters: <String, Object?>{
            'transitionKind': transition.kind.name,
            'leftTargetId': transition.leftTargetId,
            'rightTargetId': transition.rightTargetId,
            'isEnabled': transition.isEnabled,
            'parameters':
                _motionPropertyValueMapBridgeValue(transition.parameters),
          },
          detail:
              'Resolved authored transition `${transition.id}` remains outside the current baseline export lane.',
        ),
      );
    }

    for (final camera in motionComposition.cameras) {
      addOperation(
        ExportCanonicalEffectOperationDescriptor(
          id: 'op.camera.${camera.id}',
          label: camera.name ?? 'camera ${camera.id}',
          kind: ExportCanonicalEffectOperationKind.camera,
          sourceTruthKind: ExportTruthSourceKind.motionComposition,
          timelineRange: camera.projectRange,
          backendSupport: _canonicalBackendSupportForOperation(
            kind: ExportCanonicalEffectOperationKind.camera,
            sourceTruthKind: ExportTruthSourceKind.motionComposition,
          ),
          targetNodeId: _canonicalEffectsNodeIdForAddress(camera.targetAddress),
          targetAddress: camera.targetAddress,
          originId: camera.id,
          parameters: <String, Object?>{
            'scope': camera.scope.name,
            'isEnabled': camera.isEnabled,
            'staticPropertyCount': camera.staticProperties.length,
            'propertyChannelCount': camera.propertyChannels.length,
          },
          detail:
              'Resolved camera binding `${camera.id}` is modeled canonically but not yet rendered by the baseline export backend.',
        ),
      );
    }

    for (final animation in motionComposition.textAnimations) {
      addOperation(
        ExportCanonicalEffectOperationDescriptor(
          id: 'op.text_animation.${animation.id}',
          label: animation.presetId ?? 'text animation ${animation.id}',
          kind: ExportCanonicalEffectOperationKind.textAnimation,
          sourceTruthKind: ExportTruthSourceKind.motionComposition,
          timelineRange: animation.projectRange,
          backendSupport: _canonicalBackendSupportForOperation(
            kind: ExportCanonicalEffectOperationKind.textAnimation,
            sourceTruthKind: ExportTruthSourceKind.motionComposition,
          ),
          targetNodeId:
              _canonicalEffectsNodeIdForAddress(animation.targetAddress),
          targetAddress: animation.targetAddress,
          originId: animation.id,
          parameters: <String, Object?>{
            'presetId': animation.presetId,
            'animationKinds':
                animation.animationKinds.map((kind) => kind.name).toList(),
            'generatedChannelIds': animation.generatedChannelIds,
            'blockCount': animation.animationBlocks.length,
            'parameterValues':
                _motionPropertyValueMapBridgeValue(animation.parameterValues),
          },
          detail:
              'Resolved text animation `${animation.id}` captures authored motion semantics before export-program lowering.',
        ),
      );
    }
  }

  if (motionTextProgram != null) {
    for (final node in motionTextProgram.nodes) {
      final elementAddress = 'element:${node.targetElementId}';
      addNode(
        ExportCanonicalEffectsNodeDescriptor(
          id: _canonicalEffectsNodeIdForAddress(elementAddress),
          label: node.name ?? node.fullText,
          kind: ExportCanonicalEffectsNodeKind.textElement,
          sourceTruthKind: ExportTruthSourceKind.motionTextProgram,
          timelineRange: node.projectRange,
          backendSupport: _canonicalBackendSupportForNode(
            nodeKind: ExportCanonicalEffectsNodeKind.textElement,
            sourceTruthKind: ExportTruthSourceKind.motionTextProgram,
          ),
          targetAddress: elementAddress,
          sceneId: node.sceneId,
          layerId: node.layerId,
          elementId: node.targetElementId,
          zOrder: node.zIndex,
          detail:
              'Deterministic motion-text export program node `${node.id}` is the current primary export truth for authored text overlays.',
        ),
      );

      addOperation(
        ExportCanonicalEffectOperationDescriptor(
          id: 'op.program.text.${node.id}',
          label: node.presetId ?? 'program node ${node.id}',
          kind: ExportCanonicalEffectOperationKind.textAnimation,
          sourceTruthKind: ExportTruthSourceKind.motionTextProgram,
          timelineRange: node.projectRange,
          backendSupport: _canonicalBackendSupportForOperation(
            kind: ExportCanonicalEffectOperationKind.textAnimation,
            sourceTruthKind: ExportTruthSourceKind.motionTextProgram,
          ),
          targetNodeId: _canonicalEffectsNodeIdForAddress(elementAddress),
          targetAddress: elementAddress,
          originId: node.id,
          parameters: <String, Object?>{
            'presetId': node.presetId,
            'animationKinds': node.animationKinds,
            'blockCount': node.animationBlocks.length,
            'revealUnit': node.revealUnit,
            'baseOpacity': node.baseOpacity,
            'baseBlurAmount': node.baseBlurAmount,
            'baseFontSize': node.baseFontSize,
            'baseLetterSpacing': node.baseLetterSpacing,
            'layerOpacity': node.layerOpacity,
            'blendMode': node.blendMode,
            'zIndex': node.zIndex,
          },
          detail:
              'Deterministic text-program node `${node.id}` lowers authored text motion into an export-oriented program contract.',
        ),
      );

      for (final block in node.animationBlocks) {
        addOperation(
          ExportCanonicalEffectOperationDescriptor(
            id: 'op.program.block.${block.id}',
            label: block.kind,
            kind: ExportCanonicalEffectOperationKind.textAnimation,
            sourceTruthKind: ExportTruthSourceKind.motionTextProgram,
            timelineRange: block.projectRange,
            backendSupport: _canonicalBackendSupportForOperation(
              kind: ExportCanonicalEffectOperationKind.textAnimation,
              sourceTruthKind: ExportTruthSourceKind.motionTextProgram,
            ),
            targetNodeId: _canonicalEffectsNodeIdForAddress(elementAddress),
            targetAddress: elementAddress,
            originId: block.id,
            parameters: <String, Object?>{
              'kind': block.kind,
              'interpolationKind': block.interpolationKind,
              'interpolation':
                  _exportMotionInterpolationBridgeMap(block.interpolation),
              'revealUnit': block.revealUnit,
              'revealStaggerMs': block.revealStagger?.inMilliseconds,
              'parameters':
                  _motionPropertyValueMapBridgeValue(block.parameters),
            },
            detail:
                'Deterministic text-program animation block `${block.id}` captures export-lowered text motion timing.',
          ),
        );
      }

      for (final channel in node.channels) {
        addOperation(
          _buildCanonicalProgramChannelOperation(
            nodeId: _canonicalEffectsNodeIdForAddress(elementAddress),
            targetAddress: elementAddress,
            channel: channel,
            scopeLabel: 'element',
          ),
        );
      }
      for (final channel in node.layerChannels) {
        addOperation(
          _buildCanonicalProgramChannelOperation(
            nodeId: _canonicalEffectsNodeIdForAddress('layer:${node.layerId}'),
            targetAddress: 'layer:${node.layerId}',
            channel: channel,
            scopeLabel: 'layer',
          ),
        );
      }
    }
  }

  if (motionTextRenderTrack != null &&
      motionTextRenderTrack.samples.isNotEmpty) {
    addOperation(
      ExportCanonicalEffectOperationDescriptor(
        id: 'op.motion_text_render_track.summary',
        label: 'motion text render track fallback',
        kind: ExportCanonicalEffectOperationKind.propertyAssignment,
        sourceTruthKind: ExportTruthSourceKind.motionTextRenderTrack,
        timelineRange: TimelineTimeRange(
          start: TimelineTime.zero,
          endExclusive: format.durationTime,
        ),
        backendSupport: _canonicalBackendSupportForOperation(
          kind: ExportCanonicalEffectOperationKind.propertyAssignment,
          sourceTruthKind: ExportTruthSourceKind.motionTextRenderTrack,
          propertyId: 'motionTextRenderTrack.fallback',
        ),
        targetAddress: 'motionTextRenderTrack',
        originId: 'motionTextRenderTrack',
        parameters: <String, Object?>{
          'sampleStepMs': motionTextRenderTrack.sampleStepMs,
          'sampleCount': motionTextRenderTrack.samples.length,
          'totalNodeInstances': motionTextRenderTrack.totalNodeInstances,
        },
        detail:
            'Sampled text render track remains fallback/debug evidence only and is not the canonical export truth.',
      ),
    );
  }

  return ExportCanonicalEffectsGraph(
    schemaVersion: kExportGraphSchemaVersion,
    nodes: nodes,
    operations: operations,
  );
}

MotionTextRasterContract? buildMotionTextRasterContractForExportComposition({
  required MotionNormalizedComposition? motionComposition,
  required ExportMotionTextProgram? motionTextProgram,
  required ExportMotionTextRenderTrack? motionTextRenderTrack,
}) {
  final hasMotionText = (motionComposition?.allElements.any(
            (element) => element.kind == MotionElementKind.text,
          ) ??
          false) ||
      ((motionTextProgram?.nodes.isNotEmpty ?? false) ||
          (motionTextRenderTrack?.samples.isNotEmpty ?? false));
  if (!hasMotionText) {
    return null;
  }
  return const MotionTextRasterContract();
}

ExportCanonicalEffectOperationDescriptor
    _buildCanonicalPropertyAssignmentOperation({
  required String id,
  required String label,
  required ExportTruthSourceKind sourceTruthKind,
  required TimelineTimeRange timelineRange,
  required String targetAddress,
  required String? targetNodeId,
  required MotionPropertyAssignment assignment,
  required String detail,
}) {
  final kind = _canonicalOperationKindForProperty(
    propertyId: assignment.definition.id,
    propertyKey: assignment.definition.path.canonicalKey,
    fallback: ExportCanonicalEffectOperationKind.propertyAssignment,
  );
  return ExportCanonicalEffectOperationDescriptor(
    id: id,
    label: label,
    kind: kind,
    sourceTruthKind: sourceTruthKind,
    timelineRange: timelineRange,
    backendSupport: _canonicalBackendSupportForOperation(
      kind: kind,
      sourceTruthKind: sourceTruthKind,
      propertyId: assignment.definition.id,
    ),
    targetNodeId: targetNodeId,
    targetAddress: targetAddress,
    propertyId: assignment.definition.id,
    originId: assignment.target.targetId,
    parameters: <String, Object?>{
      'propertyKey': assignment.definition.path.canonicalKey,
      'value': _motionPropertyValueBridgeMap(assignment.value),
      'valueKind': assignment.definition.valueKind.name,
    },
    detail: detail,
  );
}

ExportCanonicalEffectOperationDescriptor
    _buildCanonicalPropertyChannelOperation({
  required ExportTruthSourceKind sourceTruthKind,
  required MotionResolvedPropertyChannel resolvedChannel,
  required String detail,
}) {
  final channel = resolvedChannel.channel;
  final kind = _canonicalOperationKindForProperty(
    propertyId: channel.definition.id,
    propertyKey: channel.definition.path.canonicalKey,
    fallback: ExportCanonicalEffectOperationKind.propertyChannel,
  );
  return ExportCanonicalEffectOperationDescriptor(
    id: 'op.channel.${channel.id}',
    label: channel.definition.path.canonicalKey,
    kind: kind,
    sourceTruthKind: sourceTruthKind,
    timelineRange: resolvedChannel.projectRange,
    backendSupport: _canonicalBackendSupportForOperation(
      kind: kind,
      sourceTruthKind: sourceTruthKind,
      propertyId: channel.definition.id,
    ),
    targetNodeId:
        _canonicalEffectsNodeIdForAddress(resolvedChannel.targetAddress),
    targetAddress: resolvedChannel.targetAddress,
    propertyId: channel.definition.id,
    originId: channel.id,
    parameters: <String, Object?>{
      'propertyKey': channel.definition.path.canonicalKey,
      'activeRange': channel.activeRange == null
          ? null
          : _timelineTimeRangeBridgeMap(channel.activeRange!),
      'baseValue': channel.baseValue == null
          ? null
          : _motionPropertyValueBridgeMap(channel.baseValue!),
      'fallbackValue': _motionPropertyValueBridgeMap(channel.fallbackValue),
      'beforeStart': channel.beforeStart.name,
      'afterEnd': channel.afterEnd.name,
      'keyframeCount': channel.keyframes.length,
      'interpolationKinds': channel.keyframes
          .map((keyframe) => keyframe.interpolationToNext.kind.name)
          .toSet()
          .toList(growable: false),
    },
    detail: detail,
  );
}

ExportCanonicalEffectOperationDescriptor
    _buildCanonicalProgramChannelOperation({
  required String nodeId,
  required String targetAddress,
  required ExportMotionScalarChannel channel,
  required String scopeLabel,
}) {
  final kind = _canonicalOperationKindForProperty(
    propertyId: channel.propertyId,
    propertyKey: channel.propertyId,
    fallback: ExportCanonicalEffectOperationKind.propertyChannel,
  );
  return ExportCanonicalEffectOperationDescriptor(
    id: 'op.program.channel.${channel.id}',
    label: '$scopeLabel ${channel.propertyId}',
    kind: kind,
    sourceTruthKind: ExportTruthSourceKind.motionTextProgram,
    timelineRange: channel.projectRange,
    backendSupport: _canonicalBackendSupportForOperation(
      kind: kind,
      sourceTruthKind: ExportTruthSourceKind.motionTextProgram,
      propertyId: channel.propertyId,
    ),
    targetNodeId: nodeId,
    targetAddress: targetAddress,
    propertyId: channel.propertyId,
    originId: channel.id,
    parameters: <String, Object?>{
      'scope': scopeLabel,
      'activeRange': _timelineTimeRangeBridgeMap(channel.activeRange),
      'beforeStart': channel.beforeStart,
      'afterEnd': channel.afterEnd,
      'baseValue': channel.baseValue,
      'fallbackValue': channel.fallbackValue,
      'keyframeCount': channel.keyframes.length,
      'interpolationKinds': channel.keyframes
          .map((keyframe) => keyframe.interpolationKind)
          .toSet()
          .toList(growable: false),
    },
    detail:
        'Deterministic text-program $scopeLabel channel `${channel.id}` feeds the current export text renderer.',
  );
}

ExportCanonicalEffectsNodeKind _canonicalEffectsNodeKindForTrack(
  ExportTrackKind kind,
) {
  switch (kind) {
    case ExportTrackKind.video:
    case ExportTrackKind.image:
      return ExportCanonicalEffectsNodeKind.mediaClip;
    case ExportTrackKind.text:
      return ExportCanonicalEffectsNodeKind.textElement;
    case ExportTrackKind.audio:
    case ExportTrackKind.lipSync:
      return ExportCanonicalEffectsNodeKind.genericElement;
  }
}

ExportCanonicalEffectsNodeKind _canonicalEffectsNodeKindForMotionElement(
  MotionElementKind kind,
) {
  switch (kind) {
    case MotionElementKind.text:
      return ExportCanonicalEffectsNodeKind.textElement;
    case MotionElementKind.image:
      return ExportCanonicalEffectsNodeKind.imageElement;
    case MotionElementKind.shape:
    case MotionElementKind.mask:
      return ExportCanonicalEffectsNodeKind.shapeElement;
    case MotionElementKind.videoClip:
      return ExportCanonicalEffectsNodeKind.mediaClip;
    case MotionElementKind.audioClip:
    case MotionElementKind.camera:
    case MotionElementKind.effectControl:
      return ExportCanonicalEffectsNodeKind.genericElement;
  }
}

String _canonicalEffectsNodeIdForClip(String clipId) => 'clip:$clipId';

String _canonicalEffectsNodeIdForAddress(String address) {
  if (address.startsWith('scene:') ||
      address.startsWith('layer:') ||
      address.startsWith('element:')) {
    return address;
  }
  return 'node:$address';
}

ExportCanonicalEffectOperationKind _canonicalOperationKindForProperty({
  required String propertyId,
  required String propertyKey,
  required ExportCanonicalEffectOperationKind fallback,
}) {
  if (propertyKey.startsWith('transform.')) {
    return ExportCanonicalEffectOperationKind.transform;
  }
  if (propertyId == 'visual.opacity' || propertyKey == 'visual.opacity') {
    return ExportCanonicalEffectOperationKind.opacity;
  }
  if (propertyId.startsWith('visual.blur.') ||
      propertyKey.startsWith('visual.blur.')) {
    return ExportCanonicalEffectOperationKind.blur;
  }
  if (propertyKey.startsWith('crop.')) {
    return ExportCanonicalEffectOperationKind.crop;
  }
  if (propertyId == 'text.revealProgress' ||
      propertyKey == 'text.revealProgress') {
    return ExportCanonicalEffectOperationKind.textReveal;
  }
  if (propertyKey.startsWith('text.') &&
      propertyKey != 'text.content' &&
      propertyKey != 'text.revealProgress') {
    return ExportCanonicalEffectOperationKind.typography;
  }
  return fallback;
}

List<ExportEffectsBackendSupportDescriptor> _canonicalBackendSupportForNode({
  required ExportCanonicalEffectsNodeKind nodeKind,
  required ExportTruthSourceKind sourceTruthKind,
  ExportTrackKind? trackKind,
}) {
  final flutterStatus = switch (nodeKind) {
    ExportCanonicalEffectsNodeKind.mediaClip =>
      ExportCapabilityStatus.supported,
    ExportCanonicalEffectsNodeKind.textElement =>
      ExportCapabilityStatus.supported,
    ExportCanonicalEffectsNodeKind.imageElement =>
      ExportCapabilityStatus.supported,
    ExportCanonicalEffectsNodeKind.shapeElement =>
      ExportCapabilityStatus.supported,
    ExportCanonicalEffectsNodeKind.genericElement =>
      ExportCapabilityStatus.supported,
  };

  final media3CanvasStatus = switch (nodeKind) {
    ExportCanonicalEffectsNodeKind.mediaClip =>
      trackKind == ExportTrackKind.audio
          ? ExportCapabilityStatus.blocked
          : ExportCapabilityStatus.baselineOnly,
    ExportCanonicalEffectsNodeKind.textElement =>
      sourceTruthKind == ExportTruthSourceKind.motionTextProgram
          ? ExportCapabilityStatus.approximation
          : ExportCapabilityStatus.blocked,
    ExportCanonicalEffectsNodeKind.imageElement =>
      ExportCapabilityStatus.blocked,
    ExportCanonicalEffectsNodeKind.shapeElement =>
      ExportCapabilityStatus.blocked,
    ExportCanonicalEffectsNodeKind.genericElement =>
      sourceTruthKind == ExportTruthSourceKind.canonicalTracks
          ? ExportCapabilityStatus.baselineOnly
          : ExportCapabilityStatus.blocked,
  };

  return <ExportEffectsBackendSupportDescriptor>[
    ExportEffectsBackendSupportDescriptor(
      backendId: ExportEffectsBackendId.flutterPreviewRenderer,
      status: flutterStatus,
      detail:
          'Flutter preview can represent this node today and remains the richest current authored-visual renderer.',
    ),
    ExportEffectsBackendSupportDescriptor(
      backendId: ExportEffectsBackendId.media3CanvasOverlayRenderer,
      status: media3CanvasStatus,
      detail: switch (media3CanvasStatus) {
        ExportCapabilityStatus.baselineOnly =>
          'Current Media3 + canvas export path can carry this node only inside the narrow baseline route.',
        ExportCapabilityStatus.approximation =>
          'Current Media3 + canvas export path can render this node but not yet at full renderer parity.',
        ExportCapabilityStatus.blocked =>
          'Current Media3 + canvas export path cannot faithfully own this node.',
        _ =>
          'Current Media3 + canvas export status for this node is not fully defined.',
      },
    ),
    const ExportEffectsBackendSupportDescriptor(
      backendId: ExportEffectsBackendId.media3GlEffectsRenderer,
      status: ExportCapabilityStatus.unknown,
      detail:
          'A Media3 GL effects lane is the planned professional route for texture-backed authored visual parity.',
    ),
    const ExportEffectsBackendSupportDescriptor(
      backendId: ExportEffectsBackendId.bmfRenderGraph,
      status: ExportCapabilityStatus.unknown,
      detail:
          'BMF remains an advanced render-graph candidate for effects/compositor parity beyond the baseline route.',
    ),
  ];
}

List<ExportEffectsBackendSupportDescriptor>
    _canonicalBackendSupportForOperation({
  required ExportCanonicalEffectOperationKind kind,
  required ExportTruthSourceKind sourceTruthKind,
  String? propertyId,
}) {
  final flutterStatus = switch (kind) {
    ExportCanonicalEffectOperationKind.motionEffect ||
    ExportCanonicalEffectOperationKind.motionTransition ||
    ExportCanonicalEffectOperationKind.camera =>
      ExportCapabilityStatus.supported,
    _ => ExportCapabilityStatus.supported,
  };

  ExportCapabilityStatus media3CanvasStatus;
  switch (kind) {
    case ExportCanonicalEffectOperationKind.transform:
    case ExportCanonicalEffectOperationKind.opacity:
    case ExportCanonicalEffectOperationKind.crop:
      media3CanvasStatus =
          sourceTruthKind == ExportTruthSourceKind.motionTextProgram
              ? ExportCapabilityStatus.baselineOnly
              : ExportCapabilityStatus.approximation;
      break;
    case ExportCanonicalEffectOperationKind.typography:
    case ExportCanonicalEffectOperationKind.textReveal:
    case ExportCanonicalEffectOperationKind.textAnimation:
      media3CanvasStatus =
          sourceTruthKind == ExportTruthSourceKind.motionTextProgram
              ? ExportCapabilityStatus.approximation
              : ExportCapabilityStatus.blocked;
      break;
    case ExportCanonicalEffectOperationKind.blur:
      media3CanvasStatus = ExportCapabilityStatus.approximation;
      break;
    case ExportCanonicalEffectOperationKind.blendMode:
    case ExportCanonicalEffectOperationKind.motionEffect:
    case ExportCanonicalEffectOperationKind.motionTransition:
    case ExportCanonicalEffectOperationKind.camera:
      media3CanvasStatus = ExportCapabilityStatus.blocked;
      break;
    case ExportCanonicalEffectOperationKind.propertyAssignment:
    case ExportCanonicalEffectOperationKind.propertyChannel:
      media3CanvasStatus = propertyId == 'clip.playbackRate' ||
              sourceTruthKind == ExportTruthSourceKind.canonicalTracks
          ? ExportCapabilityStatus.supported
          : ExportCapabilityStatus.approximation;
      break;
  }

  return <ExportEffectsBackendSupportDescriptor>[
    ExportEffectsBackendSupportDescriptor(
      backendId: ExportEffectsBackendId.flutterPreviewRenderer,
      status: flutterStatus,
      detail:
          'Flutter preview currently evaluates this semantic path and is the reference authoring runtime.',
    ),
    ExportEffectsBackendSupportDescriptor(
      backendId: ExportEffectsBackendId.media3CanvasOverlayRenderer,
      status: media3CanvasStatus,
      detail: switch (media3CanvasStatus) {
        ExportCapabilityStatus.supported =>
          'Current Media3 export can apply this operation in the existing baseline route.',
        ExportCapabilityStatus.baselineOnly =>
          'Current Media3 export can apply this operation only inside the narrow baseline route.',
        ExportCapabilityStatus.approximation =>
          'Current Media3 + canvas export approximates this operation and still needs renderer parity hardening.',
        ExportCapabilityStatus.blocked =>
          'Current Media3 + canvas export cannot faithfully apply this authored operation.',
        _ =>
          'Current Media3 + canvas export support for this operation is not fully defined.',
      },
    ),
    ExportEffectsBackendSupportDescriptor(
      backendId: ExportEffectsBackendId.media3GlEffectsRenderer,
      status: kind == ExportCanonicalEffectOperationKind.propertyAssignment &&
              propertyId == 'clip.playbackRate'
          ? ExportCapabilityStatus.supported
          : ExportCapabilityStatus.unknown,
      detail:
          'A Media3 GL effects lane is the planned professional route for deterministic texture-backed effect rendering.',
    ),
    const ExportEffectsBackendSupportDescriptor(
      backendId: ExportEffectsBackendId.bmfRenderGraph,
      status: ExportCapabilityStatus.unknown,
      detail:
          'BMF remains the advanced backend candidate when higher-order compositor/effects parity is required.',
    ),
  ];
}

int _computeMaxConcurrentVisualSegments(
  List<ExportVisualSegmentDescriptor> segments,
) {
  if (segments.isEmpty) {
    return 0;
  }
  final events = <({int timeMs, int delta})>[];
  for (final segment in segments) {
    events.add((
      timeMs: segment.timelineRange.start.inMilliseconds,
      delta: 1,
    ));
    events.add((
      timeMs: segment.timelineRange.endExclusive.inMilliseconds,
      delta: -1,
    ));
  }
  events.sort((left, right) {
    final timeCompare = left.timeMs.compareTo(right.timeMs);
    if (timeCompare != 0) {
      return timeCompare;
    }
    return left.delta.compareTo(right.delta);
  });
  var current = 0;
  var maximum = 0;
  for (final event in events) {
    current += event.delta;
    if (current > maximum) {
      maximum = current;
    }
  }
  return maximum;
}

List<ExportVisualAssemblyWindowDescriptor> _buildVisualAssemblyWindows({
  required List<ExportVisualSegmentDescriptor> segments,
  required int durationMs,
}) {
  final boundaries = <int>{0, if (durationMs > 0) durationMs};
  for (final segment in segments) {
    boundaries.add(segment.timelineRange.start.inMilliseconds);
    boundaries.add(segment.timelineRange.endExclusive.inMilliseconds);
  }
  final sortedBoundaries = boundaries.toList()..sort();
  final windows = <ExportVisualAssemblyWindowDescriptor>[];

  for (var index = 0; index < sortedBoundaries.length - 1; index++) {
    final startMs = sortedBoundaries[index];
    final endMs = sortedBoundaries[index + 1];
    if (endMs <= startMs) {
      continue;
    }
    final activeSegments = segments
        .where(
          (segment) =>
              segment.timelineRange.start.inMilliseconds < endMs &&
              segment.timelineRange.endExclusive.inMilliseconds > startMs,
        )
        .toList(growable: false)
      ..sort((left, right) => left.zOrder.compareTo(right.zOrder));
    final activeLayerIds = activeSegments
        .map((segment) => segment.layerId)
        .toSet()
        .toList(growable: false);
    final activeSegmentIds =
        activeSegments.map((segment) => segment.id).toList(growable: false);
    final activeMediaSegments = activeSegments
        .where(
          (segment) =>
              segment.sourceTruthKind == ExportTruthSourceKind.canonicalTracks,
        )
        .length;
    final activeAuthoredSegments = activeSegments.length - activeMediaSegments;
    final hasUnsupportedAuthoredSegment = activeSegments.any(
      (segment) =>
          segment.sourceTruthKind != ExportTruthSourceKind.canonicalTracks &&
          segment.rendererOwnerId != 'app_motion_text_program_renderer',
    );

    late final ExportVisualAssemblyPolicyKind policy;
    if (activeSegments.isEmpty) {
      policy = ExportVisualAssemblyPolicyKind.gap;
    } else if (!hasUnsupportedAuthoredSegment &&
        activeMediaSegments == 1 &&
        activeAuthoredSegments == 0) {
      policy = ExportVisualAssemblyPolicyKind.mediaOnly;
    } else if (!hasUnsupportedAuthoredSegment &&
        activeMediaSegments == 1 &&
        activeAuthoredSegments > 0) {
      policy = ExportVisualAssemblyPolicyKind.mediaWithAuthoredOverlay;
    } else {
      policy = ExportVisualAssemblyPolicyKind.compositorRequired;
    }

    final requiresVisualCompositor =
        policy == ExportVisualAssemblyPolicyKind.compositorRequired;
    final executionOwner = switch (policy) {
      ExportVisualAssemblyPolicyKind.gap => ExportVisualExecutionOwnerKind.none,
      ExportVisualAssemblyPolicyKind.mediaOnly =>
        ExportVisualExecutionOwnerKind.media3BaselineRoute,
      ExportVisualAssemblyPolicyKind.mediaWithAuthoredOverlay =>
        ExportVisualExecutionOwnerKind.media3BaselineRoute,
      ExportVisualAssemblyPolicyKind.compositorRequired =>
        ExportVisualExecutionOwnerKind.nativeVisualCompositor,
    };
    final detail = switch (policy) {
      ExportVisualAssemblyPolicyKind.gap =>
        'No active visual segments in this timeline window.',
      ExportVisualAssemblyPolicyKind.mediaOnly =>
        'A single media visual segment is active in this window.',
      ExportVisualAssemblyPolicyKind.mediaWithAuthoredOverlay =>
        'Media plus authored overlay segments are active in this window and remain on the current baseline path.',
      ExportVisualAssemblyPolicyKind.compositorRequired => activeMediaSegments ==
                  0 &&
              activeAuthoredSegments > 0
          ? 'This window contains authored visual content without an active media base and requires a compositor-capable path.'
          : 'This window contains visual overlap semantics that require a wider compositor path.',
    };

    windows.add(
      ExportVisualAssemblyWindowDescriptor(
        id: 'visual.window.$index',
        timelineRange: TimelineTimeRange(
          start: TimelineTime.fromMilliseconds(startMs),
          endExclusive: TimelineTime.fromMilliseconds(endMs),
        ),
        policy: policy,
        executionOwner: executionOwner,
        requiresVisualCompositor: requiresVisualCompositor,
        supportsCurrentBackend: !requiresVisualCompositor,
        activeLayerIds: activeLayerIds,
        activeSegmentIds: activeSegmentIds,
        detail: detail,
      ),
    );
  }

  return windows;
}

List<ExportCompositorWindowExecutionPlanDescriptor>
    _buildCompositorWindowExecutionPlans({
  required List<ExportVisualAssemblyWindowDescriptor> windows,
  required List<ExportVisualSegmentDescriptor> segments,
}) {
  if (windows.isEmpty || segments.isEmpty) {
    return const <ExportCompositorWindowExecutionPlanDescriptor>[];
  }
  final segmentsById = <String, ExportVisualSegmentDescriptor>{
    for (final segment in segments) segment.id: segment,
  };
  return windows
      .where(
    (window) =>
        window.policy == ExportVisualAssemblyPolicyKind.compositorRequired,
  )
      .map((window) {
    final orderedSegments = window.activeSegmentIds
        .map((segmentId) => segmentsById[segmentId])
        .whereType<ExportVisualSegmentDescriptor>()
        .toList(growable: false)
      ..sort((left, right) => left.zOrder.compareTo(right.zOrder));
    final orderedLayerIds = <String>[];
    for (final segment in orderedSegments) {
      if (!orderedLayerIds.contains(segment.layerId)) {
        orderedLayerIds.add(segment.layerId);
      }
    }
    final mediaSegmentIds = orderedSegments
        .where(
          (segment) =>
              segment.sourceTruthKind == ExportTruthSourceKind.canonicalTracks,
        )
        .map((segment) => segment.id)
        .toList(growable: false);
    final authoredSegmentIds = orderedSegments
        .where(
          (segment) =>
              segment.sourceTruthKind != ExportTruthSourceKind.canonicalTracks,
        )
        .map((segment) => segment.id)
        .toList(growable: false);
    var mediaInputIndex = 0;
    final executionInputs = orderedSegments.map((segment) {
      final isMedia =
          segment.sourceTruthKind == ExportTruthSourceKind.canonicalTracks;
      final role = isMedia
          ? (mediaInputIndex++ == 0
              ? ExportCompositorExecutionInputRoleKind.baseMedia
              : ExportCompositorExecutionInputRoleKind.overlayMedia)
          : ExportCompositorExecutionInputRoleKind.authoredOverlay;
      return ExportCompositorExecutionInputDescriptor(
        segmentId: segment.id,
        layerId: segment.layerId,
        role: role,
        sourceTruthKind: segment.sourceTruthKind,
        rendererOwnerId: segment.rendererOwnerId,
        zOrder: segment.zOrder,
        trackKind: segment.trackKind,
        clipId: segment.clipId,
        nodeId: segment.nodeId,
      );
    }).toList(growable: false);
    return ExportCompositorWindowExecutionPlanDescriptor(
      windowId: window.id,
      timelineRange: window.timelineRange,
      executionOwner: ExportVisualExecutionOwnerKind.nativeVisualCompositor,
      orderedLayerIds: orderedLayerIds,
      orderedSegmentIds:
          orderedSegments.map((segment) => segment.id).toList(growable: false),
      mediaSegmentIds: mediaSegmentIds,
      authoredSegmentIds: authoredSegmentIds,
      executionInputs: executionInputs,
      detail:
          'Window `${window.id}` requires the native visual compositor with ordered graph inputs from canonical visual truth.',
    );
  }).toList(growable: false);
}

Set<String> _resolveSupportedBackendCompositorWindowIds({
  required List<ExportCompositorWindowExecutionPlanDescriptor>
      compositorWindowExecutionPlans,
  required List<ExportVisualSegmentDescriptor> segments,
}) {
  if (compositorWindowExecutionPlans.isEmpty || segments.isEmpty) {
    return const <String>{};
  }
  final segmentsById = <String, ExportVisualSegmentDescriptor>{
    for (final segment in segments) segment.id: segment,
  };
  return compositorWindowExecutionPlans
      .where(
        (plan) => _isSupportedCurrentBackendCompositorPlan(
          plan: plan,
          segmentsById: segmentsById,
        ),
      )
      .map((plan) => plan.windowId)
      .toSet();
}

bool _isSupportedCurrentBackendCompositorPlan({
  required ExportCompositorWindowExecutionPlanDescriptor plan,
  required Map<String, ExportVisualSegmentDescriptor> segmentsById,
}) {
  if (plan.executionOwner !=
      ExportVisualExecutionOwnerKind.nativeVisualCompositor) {
    return false;
  }
  if (!listEquals(
    plan.executionInputs
        .map((input) => input.segmentId)
        .toList(growable: false),
    plan.orderedSegmentIds,
  )) {
    return false;
  }
  final baseMediaInputs = plan.executionInputs
      .where(
        (input) =>
            input.role == ExportCompositorExecutionInputRoleKind.baseMedia,
      )
      .toList(growable: false);
  final overlayMediaInputs = plan.executionInputs
      .where(
        (input) =>
            input.role == ExportCompositorExecutionInputRoleKind.overlayMedia,
      )
      .toList(growable: false);
  final authoredInputs = plan.executionInputs
      .where(
        (input) =>
            input.role ==
            ExportCompositorExecutionInputRoleKind.authoredOverlay,
      )
      .toList(growable: false);
  if (baseMediaInputs.length != 1) {
    return false;
  }
  if (baseMediaInputs.any(
        (input) =>
            input.sourceTruthKind != ExportTruthSourceKind.canonicalTracks,
      ) ||
      overlayMediaInputs.any(
        (input) =>
            input.sourceTruthKind != ExportTruthSourceKind.canonicalTracks ||
            input.trackKind != ExportTrackKind.image,
      )) {
    return false;
  }
  final firstAuthoredIndex = plan.executionInputs.indexWhere(
    (input) =>
        input.role == ExportCompositorExecutionInputRoleKind.authoredOverlay,
  );
  final lastMediaIndex = plan.executionInputs.lastIndexWhere(
    (input) =>
        input.role == ExportCompositorExecutionInputRoleKind.baseMedia ||
        input.role == ExportCompositorExecutionInputRoleKind.overlayMedia,
  );
  if (firstAuthoredIndex != -1 &&
      lastMediaIndex != -1 &&
      firstAuthoredIndex <= lastMediaIndex) {
    return false;
  }
  return authoredInputs.every(
    (input) =>
        _isSupportedCurrentBackendAuthoredRendererOwner(
            input.rendererOwnerId) &&
        input.nodeId != null &&
        input.sourceTruthKind != ExportTruthSourceKind.canonicalTracks &&
        segmentsById[input.segmentId]?.nodeId != null,
  );
}

bool _isSupportedCurrentBackendAuthoredRendererOwner(String ownerId) {
  return ownerId == 'app_motion_text_program_renderer' ||
      ownerId == 'app_authored_visual_surface_renderer';
}

bool _isGraphOwnedAuthoredVisualElement(MotionElementKind kind) {
  switch (kind) {
    case MotionElementKind.image:
    case MotionElementKind.shape:
    case MotionElementKind.mask:
    case MotionElementKind.videoClip:
      return true;
    case MotionElementKind.text:
    case MotionElementKind.audioClip:
    case MotionElementKind.camera:
    case MotionElementKind.effectControl:
      return false;
  }
}

String _baselineBlockerMessage(ExportBaselineBlockerCode code) {
  switch (code) {
    case ExportBaselineBlockerCode.unresolvedCompositionErrors:
      return 'composition contains unresolved export errors';
    case ExportBaselineBlockerCode.missingMotionTextProgram:
      return 'canonical motion/text export program is required; sampled fallback alone is not baseline-eligible';
    case ExportBaselineBlockerCode.compositorRequiredVisualWindow:
      return 'visual assembly contains compositor-required windows outside the current backend baseline';
    case ExportBaselineBlockerCode.unsupportedNonTextMotion:
      return 'non-text motion elements are not in the first export baseline';
    case ExportBaselineBlockerCode.unsupportedMotionCamera:
      return 'motion camera bindings are not in the first export baseline';
    case ExportBaselineBlockerCode.unsupportedMotionEffect:
      return 'motion effects are not in the first export baseline';
    case ExportBaselineBlockerCode.unsupportedMotionTransition:
      return 'motion transitions are not in the first export baseline';
    case ExportBaselineBlockerCode.noMediaClips:
      return 'export composition contains no media clips';
    case ExportBaselineBlockerCode.noVisualBaselineTrack:
      return 'export composition contains no visual baseline track';
    case ExportBaselineBlockerCode.multipleVisualTracks:
      return 'multiple visual tracks are not in the first export baseline';
    case ExportBaselineBlockerCode.multipleAudioTracks:
      return 'multiple audio tracks are not in the first export baseline';
    case ExportBaselineBlockerCode.unsupportedTrackKind:
      return 'non-baseline track content exists in the export composition';
    case ExportBaselineBlockerCode.curveSpeed:
      return 'curve speed is not in the first export baseline';
    case ExportBaselineBlockerCode.unsupportedInterpolationKind:
      return 'encountered interpolation kinds are not registered for export';
  }
}

String _parityLimitationMessage(ExportParityLimitationCode code) {
  switch (code) {
    case ExportParityLimitationCode.textMotionRendererParity:
      return 'text motion export requires deterministic motion-text program ownership before parity can be asserted';
    case ExportParityLimitationCode.typographyParity:
      return 'text typography export parity is not fully implemented';
    case ExportParityLimitationCode.interpolationParity:
      return 'interpolation export parity is not fully implemented';
    case ExportParityLimitationCode.nonTextMotionParity:
      return 'non-text motion export parity is blocked by compositor windows without production proof';
    case ExportParityLimitationCode.motionCameraParity:
      return 'motion camera export parity is not implemented';
    case ExportParityLimitationCode.motionEffectParity:
      return 'motion effect export parity is blocked by compositor/effect windows without production proof';
    case ExportParityLimitationCode.motionTransitionParity:
      return 'motion transition export parity is blocked by transition windows without production proof';
    case ExportParityLimitationCode.multiVisualCompositingParity:
      return 'multi-visual compositing parity is blocked by unsupported compositor windows';
    case ExportParityLimitationCode.multiAudioParity:
      return 'multi-audio export parity is not implemented';
    case ExportParityLimitationCode.textTrackParity:
      return 'text track parity is not implemented';
    case ExportParityLimitationCode.lipSyncTrackParity:
      return 'lipSync track parity is not implemented';
    case ExportParityLimitationCode.curveSpeedParity:
      return 'curve speed export parity is not implemented';
  }
}

Map<String, Object?> _motionCompositionBridgeMap(
  MotionNormalizedComposition composition,
) {
  return <String, Object?>{
    'contractVersion': 'motion.v1alpha1',
    'projectId': composition.projectId,
    'projectRange': _timelineTimeRangeBridgeMap(composition.projectRange),
    'format': _motionProjectFormatBridgeMap(composition.format),
    'frameRate': _motionFrameRateBridgeMap(composition.frameRate),
    'sceneCount': composition.scenes.length,
    'textAnimationCount': composition.textAnimations.length,
    'effectCount': composition.effects.length,
    'transitionCount': composition.transitions.length,
    'cameraCount': composition.cameras.length,
    'globalChannelCount': composition.globalChannels.length,
    'durationMs': composition.projectRange.duration.inMilliseconds,
    'metadata': composition.metadata,
    'authoringOrigins': composition.authoringOrigins
        .map(_motionAuthoringOriginBridgeMap)
        .toList(growable: false),
    'elements': composition.allElements
        .map(_motionElementSummaryBridgeMap)
        .toList(growable: false),
    'globalChannels': composition.globalChannels
        .map(_motionResolvedPropertyChannelBridgeMap)
        .toList(growable: false),
    'scenes': composition.scenes
        .map(_motionResolvedSceneBridgeMap)
        .toList(growable: false),
    'cameras': composition.cameras
        .map(_motionResolvedCameraBridgeMap)
        .toList(growable: false),
    'textAnimations': composition.textAnimations
        .map(_motionResolvedTextAnimationBridgeMap)
        .toList(growable: false),
    'effects': composition.effects
        .map(_motionResolvedEffectBridgeMap)
        .toList(growable: false),
    'transitions': composition.transitions
        .map(_motionResolvedTransitionBridgeMap)
        .toList(growable: false),
  };
}

Map<String, Object?> _motionProjectFormatBridgeMap(MotionProjectFormat format) {
  return <String, Object?>{
    'canvasSize': _motionSize2DBridgeValue(format.canvasSize),
    'pixelAspectRatio': format.pixelAspectRatio,
  };
}

Map<String, Object?> _motionFrameRateBridgeMap(MotionFrameRate frameRate) {
  return <String, Object?>{
    'numerator': frameRate.numerator,
    'denominator': frameRate.denominator,
    'framesPerSecond': frameRate.framesPerSecond,
  };
}

Map<String, Object?> _motionAuthoringOriginBridgeMap(
  MotionAuthoringOrigin origin,
) {
  return <String, Object?>{
    'kind': origin.kind.name,
    'id': origin.id,
    'label': origin.label,
    'metadata': origin.metadata,
  };
}

Map<String, Object?> _motionElementSummaryBridgeMap(
  MotionResolvedElementModel element,
) {
  return <String, Object?>{
    'id': element.id,
    'sourceElementId': element.sourceElementId,
    'sceneId': element.sceneId,
    'layerId': element.layerId,
    'kind': element.kind.name,
    'shapeKind': element.shapeKind?.name,
    'isEnabled': element.isEnabled,
    'name': element.name,
    'projectRange': _timelineTimeRangeBridgeMap(element.projectRange),
    'localRange': _timelineTimeRangeBridgeMap(element.localRange),
    'sourceBinding': element.sourceBinding == null
        ? null
        : _motionElementSourceBindingBridgeMap(element.sourceBinding!),
  };
}

Map<String, Object?> _motionResolvedSceneBridgeMap(
  MotionResolvedSceneModel scene,
) {
  return <String, Object?>{
    'id': scene.id,
    'sourceSceneId': scene.sourceSceneId,
    'projectRange': _timelineTimeRangeBridgeMap(scene.projectRange),
    'name': scene.name,
    'cameraLayerId': scene.cameraLayerId,
    'isEnabled': scene.isEnabled,
    'metadata': scene.metadata,
    'staticProperties': scene.staticProperties
        .map(_motionPropertyAssignmentBridgeMap)
        .toList(growable: false),
    'propertyChannels': scene.propertyChannels
        .map(_motionResolvedPropertyChannelBridgeMap)
        .toList(growable: false),
    'layers':
        scene.layers.map(_motionResolvedLayerBridgeMap).toList(growable: false),
  };
}

Map<String, Object?> _motionResolvedLayerBridgeMap(
  MotionResolvedLayerModel layer,
) {
  return <String, Object?>{
    'id': layer.id,
    'sourceLayerId': layer.sourceLayerId,
    'sceneId': layer.sceneId,
    'kind': layer.kind.name,
    'projectRange': _timelineTimeRangeBridgeMap(layer.projectRange),
    'name': layer.name,
    'zIndex': layer.zIndex,
    'isEnabled': layer.isEnabled,
    'blendMode': layer.blendMode.name,
    'staticProperties': layer.staticProperties
        .map(_motionPropertyAssignmentBridgeMap)
        .toList(growable: false),
    'propertyChannels': layer.propertyChannels
        .map(_motionResolvedPropertyChannelBridgeMap)
        .toList(growable: false),
    'elements': layer.elements
        .map(_motionResolvedElementBridgeMap)
        .toList(growable: false),
  };
}

Map<String, Object?> _motionResolvedElementBridgeMap(
  MotionResolvedElementModel element,
) {
  return <String, Object?>{
    'id': element.id,
    'sourceElementId': element.sourceElementId,
    'sceneId': element.sceneId,
    'layerId': element.layerId,
    'kind': element.kind.name,
    'shapeKind': element.shapeKind?.name,
    'projectRange': _timelineTimeRangeBridgeMap(element.projectRange),
    'localRange': _timelineTimeRangeBridgeMap(element.localRange),
    'name': element.name,
    'isEnabled': element.isEnabled,
    'sourceBinding': element.sourceBinding == null
        ? null
        : _motionElementSourceBindingBridgeMap(element.sourceBinding!),
    'staticProperties': element.staticProperties
        .map(_motionPropertyAssignmentBridgeMap)
        .toList(growable: false),
    'propertyChannels': element.propertyChannels
        .map(_motionResolvedPropertyChannelBridgeMap)
        .toList(growable: false),
  };
}

Map<String, Object?> _motionResolvedCameraBridgeMap(
  MotionResolvedCameraModel camera,
) {
  return <String, Object?>{
    'id': camera.id,
    'scope': camera.scope.name,
    'targetAddress': camera.targetAddress,
    'projectRange': _timelineTimeRangeBridgeMap(camera.projectRange),
    'name': camera.name,
    'isEnabled': camera.isEnabled,
    'staticProperties': camera.staticProperties
        .map(_motionPropertyAssignmentBridgeMap)
        .toList(growable: false),
    'propertyChannels': camera.propertyChannels
        .map(_motionResolvedPropertyChannelBridgeMap)
        .toList(growable: false),
  };
}

Map<String, Object?> _motionResolvedTextAnimationBridgeMap(
  MotionResolvedTextAnimationModel animation,
) {
  return <String, Object?>{
    'id': animation.id,
    'targetElementId': animation.targetElementId,
    'targetAddress': animation.targetAddress,
    'projectRange': _timelineTimeRangeBridgeMap(animation.projectRange),
    'presetId': animation.presetId,
    'animationKinds': animation.animationKinds
        .map((kind) => kind.name)
        .toList(growable: false),
    'generatedChannelIds': animation.generatedChannelIds,
    'parameterValues':
        _motionPropertyValueMapBridgeValue(animation.parameterValues),
  };
}

Map<String, Object?> _motionResolvedEffectBridgeMap(
    MotionResolvedEffectModel effect) {
  return <String, Object?>{
    'id': effect.id,
    'kind': effect.kind.name,
    'targetAddress': effect.targetAddress,
    'projectRange': _timelineTimeRangeBridgeMap(effect.projectRange),
    'name': effect.name,
    'isEnabled': effect.isEnabled,
    'parameterCount': effect.parameters.length,
    'parameters': _motionPropertyValueMapBridgeValue(effect.parameters),
  };
}

Map<String, Object?> _motionResolvedTransitionBridgeMap(
  MotionResolvedTransitionModel transition,
) {
  return <String, Object?>{
    'id': transition.id,
    'kind': transition.kind.name,
    'leftTargetId': transition.leftTargetId,
    'rightTargetId': transition.rightTargetId,
    'projectRange': _timelineTimeRangeBridgeMap(transition.projectRange),
    'name': transition.name,
    'isEnabled': transition.isEnabled,
    'parameterCount': transition.parameters.length,
    'parameters': _motionPropertyValueMapBridgeValue(transition.parameters),
  };
}

Map<String, Object?> _motionResolvedPropertyChannelBridgeMap(
  MotionResolvedPropertyChannel resolvedChannel,
) {
  final channel = resolvedChannel.channel;
  return <String, Object?>{
    'id': channel.id,
    'targetAddress': resolvedChannel.targetAddress,
    'projectRange': _timelineTimeRangeBridgeMap(resolvedChannel.projectRange),
    'target': _motionPropertyTargetBridgeMap(channel.target),
    'definition': _motionPropertyDefinitionBridgeMap(channel.definition),
    'activeRange': channel.activeRange == null
        ? null
        : _timelineTimeRangeBridgeMap(channel.activeRange!),
    'baseValue': channel.baseValue == null
        ? null
        : _motionPropertyValueBridgeMap(channel.baseValue!),
    'fallbackValue': _motionPropertyValueBridgeMap(channel.fallbackValue),
    'beforeStart': channel.beforeStart.name,
    'afterEnd': channel.afterEnd.name,
    'isAnimated': channel.isAnimated,
    'keyframes':
        channel.keyframes.map(_motionKeyframeBridgeMap).toList(growable: false),
  };
}

Map<String, Object?> _motionKeyframeBridgeMap(MotionKeyframeModel keyframe) {
  return <String, Object?>{
    'id': keyframe.id,
    'channelId': keyframe.channelId,
    'timeMs': keyframe.time.inMilliseconds,
    'value': _motionPropertyValueBridgeMap(keyframe.value),
    'interpolation': _motionInterpolationBridgeMap(
      keyframe.interpolationToNext,
    ),
  };
}

Map<String, Object?> _motionInterpolationBridgeMap(
  MotionInterpolationSpec interpolation,
) {
  return <String, Object?>{
    'kind': interpolation.kind.name,
    'bezier': interpolation.bezier == null
        ? null
        : <String, Object?>{
            'x1': interpolation.bezier!.x1,
            'y1': interpolation.bezier!.y1,
            'x2': interpolation.bezier!.x2,
            'y2': interpolation.bezier!.y2,
          },
    'spring': interpolation.spring == null
        ? null
        : <String, Object?>{
            'stiffness': interpolation.spring!.stiffness,
            'damping': interpolation.spring!.damping,
            'mass': interpolation.spring!.mass,
            'initialVelocity': interpolation.spring!.initialVelocity,
          },
    'bounce': interpolation.bounce == null
        ? null
        : <String, Object?>{
            'amplitude': interpolation.bounce!.amplitude,
            'bounces': interpolation.bounce!.bounces,
            'decay': interpolation.bounce!.decay,
          },
    'elastic': interpolation.elastic == null
        ? null
        : <String, Object?>{
            'amplitude': interpolation.elastic!.amplitude,
            'period': interpolation.elastic!.period,
            'decay': interpolation.elastic!.decay,
          },
  };
}

Map<String, Object?> _motionPropertyAssignmentBridgeMap(
  MotionPropertyAssignment assignment,
) {
  return <String, Object?>{
    'target': _motionPropertyTargetBridgeMap(assignment.target),
    'definition': _motionPropertyDefinitionBridgeMap(assignment.definition),
    'value': _motionPropertyValueBridgeMap(assignment.value),
  };
}

Map<String, Object?> _motionPropertyTargetBridgeMap(
    MotionPropertyTarget target) {
  return <String, Object?>{
    'kind': target.kind.name,
    'targetId': target.targetId,
    'projectId': target.projectId,
    'sceneId': target.sceneId,
    'layerId': target.layerId,
    'elementId': target.elementId,
    'canonicalAddress': target.canonicalAddress,
  };
}

Map<String, Object?> _motionPropertyDefinitionBridgeMap(
  MotionPropertyDefinition definition,
) {
  return <String, Object?>{
    'id': definition.id,
    'path': <String, Object?>{
      'group': definition.path.group.name,
      'name': definition.path.name,
      'component': definition.path.component,
      'canonicalKey': definition.path.canonicalKey,
    },
    'valueKind': definition.valueKind.name,
    'supportedTargets': definition.supportedTargets
        .map((target) => target.name)
        .toList(growable: false),
    'defaultValue': _motionPropertyValueBridgeMap(definition.defaultValue),
    'isAnimatable': definition.isAnimatable,
  };
}

Map<String, Object?> _motionElementSourceBindingBridgeMap(
  MotionElementSourceBinding binding,
) {
  return <String, Object?>{
    'kind': binding.kind.name,
    'sourceId': binding.sourceId,
    'assetId': binding.assetId,
    'label': binding.label,
    'sourceRange': binding.sourceRange == null
        ? null
        : _timelineTimeRangeBridgeMap(binding.sourceRange!),
    'metadata': binding.metadata,
  };
}

Map<String, Object?> _motionPropertyValueBridgeMap(MotionPropertyValue value) {
  return <String, Object?>{
    'kind': value.kind.name,
    'raw': _motionPropertyRawBridgeValue(value),
  };
}

Map<String, Object?> _motionPropertyValueMapBridgeValue(
  Map<String, MotionPropertyValue> values,
) {
  return Map<String, Object?>.unmodifiable(
    values.map(
      (key, value) => MapEntry<String, Object?>(
        key,
        _motionPropertyValueBridgeMap(value),
      ),
    ),
  );
}

Object? _motionPropertyRawBridgeValue(MotionPropertyValue value) {
  switch (value.kind) {
    case MotionPropertyValueKind.scalar:
    case MotionPropertyValueKind.integer:
    case MotionPropertyValueKind.boolean:
    case MotionPropertyValueKind.stringValue:
    case MotionPropertyValueKind.enumValue:
      return value.rawValue;
    case MotionPropertyValueKind.colorArgb:
      final argb = value.rawValue as int;
      return <String, Object?>{
        'argb': argb,
        'hex': '0x${argb.toRadixString(16).padLeft(8, '0').toUpperCase()}',
      };
    case MotionPropertyValueKind.point2D:
      return _motionPoint2DBridgeValue(value.rawValue as MotionPoint2D);
    case MotionPropertyValueKind.size2D:
      return _motionSize2DBridgeValue(value.rawValue as MotionSize2D);
    case MotionPropertyValueKind.rect:
      return _motionRectBridgeValue(value.rawValue as MotionRect);
  }
}

Map<String, Object?> _motionPoint2DBridgeValue(MotionPoint2D value) {
  return <String, Object?>{
    'x': value.x,
    'y': value.y,
  };
}

Map<String, Object?> _motionSize2DBridgeValue(MotionSize2D value) {
  return <String, Object?>{
    'width': value.width,
    'height': value.height,
  };
}

Map<String, Object?> _motionRectBridgeValue(MotionRect value) {
  return <String, Object?>{
    'left': value.left,
    'top': value.top,
    'width': value.width,
    'height': value.height,
  };
}

Map<String, Object?> _timelineTimeRangeBridgeMap(TimelineTimeRange range) {
  return <String, Object?>{
    'startMs': range.start.inMilliseconds,
    'durationMs': range.duration.inMilliseconds,
    'endExclusiveMs': range.endExclusive.inMilliseconds,
  };
}

Map<String, Object?> _motionTextRenderTrackBridgeMap(
  ExportMotionTextRenderTrack track,
) {
  return <String, Object?>{
    'canvasSize': _motionSize2DBridgeValue(track.canvasSize),
    'sampleStepMs': track.sampleStepMs,
    'sampleCount': track.samples.length,
    'totalNodeInstances': track.totalNodeInstances,
    'samples': track.samples
        .map(
          (sample) => <String, Object?>{
            'timeMs': sample.time.inMilliseconds,
            'nodes': sample.nodes
                .map(
                  (node) => <String, Object?>{
                    'id': node.id,
                    'targetElementId': node.targetElementId,
                    'sceneId': node.sceneId,
                    'layerId': node.layerId,
                    'projectRange':
                        _timelineTimeRangeBridgeMap(node.projectRange),
                    'text': node.text,
                    'fullText': node.fullText,
                    'revealUnit': node.revealUnit,
                    'revealProgress': node.revealProgress,
                    'hasRevealAnimation': node.hasRevealAnimation,
                    'animationKinds': node.animationKinds,
                    'animationProgressByKind': node.animationProgressByKind,
                    'canvasOffset':
                        _motionPoint2DBridgeValue(node.canvasOffset),
                    'scaleX': node.scaleX,
                    'scaleY': node.scaleY,
                    'rotationDegrees': node.rotationDegrees,
                    'opacity': node.opacity,
                    'blurAmount': node.blurAmount,
                    'fontSize': node.fontSize,
                    'letterSpacing': node.letterSpacing,
                    'colorArgb': node.colorArgb,
                    'fontFamily': node.fontFamily,
                    'fontWeight': node.fontWeight,
                    'fontStyle': node.fontStyle,
                    'lineHeight': node.lineHeight,
                    'textAlignment': node.textAlignment,
                    'anchor': node.anchor,
                    'blendMode': node.blendMode,
                    'zIndex': node.zIndex,
                    'name': node.name,
                    'presetId': node.presetId,
                  },
                )
                .toList(growable: false),
          },
        )
        .toList(growable: false),
  };
}

@immutable
class ExportCompositionBuildInput {
  ExportCompositionBuildInput({
    required this.contractVersion,
    required this.projectId,
    required this.projectFormat,
    required List<ExportAssetDescriptor> assets,
    required List<ExportTrackSeed> timelineTracks,
    this.motionComposition,
    this.motionTextProgram,
    this.motionTextRenderTrack,
  })  : assets = List.unmodifiable(assets),
        timelineTracks = List.unmodifiable(timelineTracks);

  final String contractVersion;
  final String projectId;
  final ExportProjectFormatDescriptor projectFormat;
  final List<ExportAssetDescriptor> assets;
  final List<ExportTrackSeed> timelineTracks;
  final MotionNormalizedComposition? motionComposition;
  final ExportMotionTextProgram? motionTextProgram;
  final ExportMotionTextRenderTrack? motionTextRenderTrack;
}

Map<String, Object?> _motionTextProgramBridgeMap(
    ExportMotionTextProgram program) {
  return <String, Object?>{
    'canvasSize': _motionSize2DBridgeValue(program.canvasSize),
    'nodeCount': program.nodes.length,
    'nodes': program.nodes
        .map(
          (node) => <String, Object?>{
            'id': node.id,
            'targetElementId': node.targetElementId,
            'sceneId': node.sceneId,
            'layerId': node.layerId,
            'projectRange': _timelineTimeRangeBridgeMap(node.projectRange),
            'fullText': node.fullText,
            'revealUnit': node.revealUnit,
            'basePositionX': node.basePositionX,
            'basePositionY': node.basePositionY,
            'baseScaleX': node.baseScaleX,
            'baseScaleY': node.baseScaleY,
            'baseRotationDegrees': node.baseRotationDegrees,
            'baseOpacity': node.baseOpacity,
            'baseBlurAmount': node.baseBlurAmount,
            'baseFontSize': node.baseFontSize,
            'baseLetterSpacing': node.baseLetterSpacing,
            'layerOpacity': node.layerOpacity,
            'colorArgb': node.colorArgb,
            'fontFamily': node.fontFamily,
            'fontWeight': node.fontWeight,
            'fontStyle': node.fontStyle,
            'lineHeight': node.lineHeight,
            'textAlignment': node.textAlignment,
            'anchor': node.anchor,
            'blendMode': node.blendMode,
            'zIndex': node.zIndex,
            'animationKinds': node.animationKinds,
            'animationBlocks': node.animationBlocks
                .map(
                  (block) => <String, Object?>{
                    'id': block.id,
                    'kind': block.kind,
                    'projectRange':
                        _timelineTimeRangeBridgeMap(block.projectRange),
                    'interpolationKind': block.interpolationKind,
                    'interpolation': _exportMotionInterpolationBridgeMap(
                      block.interpolation,
                    ),
                    'parameters':
                        _motionPropertyValueMapBridgeValue(block.parameters),
                    'revealUnit': block.revealUnit,
                    'revealStaggerMs': block.revealStagger?.inMilliseconds,
                  },
                )
                .toList(growable: false),
            'channels': node.channels
                .map(_motionTextProgramChannelBridgeMap)
                .toList(growable: false),
            'layerChannels': node.layerChannels
                .map(_motionTextProgramChannelBridgeMap)
                .toList(growable: false),
            'name': node.name,
            'presetId': node.presetId,
          },
        )
        .toList(growable: false),
  };
}

Map<String, Object?> _motionTextProgramChannelBridgeMap(
  ExportMotionScalarChannel channel,
) {
  return <String, Object?>{
    'id': channel.id,
    'propertyId': channel.propertyId,
    'projectRange': _timelineTimeRangeBridgeMap(channel.projectRange),
    'activeRange': _timelineTimeRangeBridgeMap(channel.activeRange),
    'beforeStart': channel.beforeStart,
    'afterEnd': channel.afterEnd,
    'baseValue': channel.baseValue,
    'fallbackValue': channel.fallbackValue,
    'keyframes': channel.keyframes
        .map(
          (keyframe) => <String, Object?>{
            'timeMs': keyframe.time.inMilliseconds,
            'value': keyframe.value,
            'interpolationKind': keyframe.interpolationKind,
            'interpolation': _exportMotionInterpolationBridgeMap(
              keyframe.interpolation,
            ),
          },
        )
        .toList(growable: false),
  };
}

Map<String, Object?> _exportMotionInterpolationBridgeMap(
  ExportMotionInterpolationSpec interpolation,
) {
  return <String, Object?>{
    'kind': interpolation.kind,
    'bezier': interpolation.bezier == null
        ? null
        : <String, Object?>{
            'x1': interpolation.bezier!.x1,
            'y1': interpolation.bezier!.y1,
            'x2': interpolation.bezier!.x2,
            'y2': interpolation.bezier!.y2,
          },
    'spring': interpolation.spring == null
        ? null
        : <String, Object?>{
            'stiffness': interpolation.spring!.stiffness,
            'damping': interpolation.spring!.damping,
            'mass': interpolation.spring!.mass,
            'initialVelocity': interpolation.spring!.initialVelocity,
          },
    'bounce': interpolation.bounce == null
        ? null
        : <String, Object?>{
            'amplitude': interpolation.bounce!.amplitude,
            'bounces': interpolation.bounce!.bounces,
            'decay': interpolation.bounce!.decay,
          },
    'elastic': interpolation.elastic == null
        ? null
        : <String, Object?>{
            'amplitude': interpolation.elastic!.amplitude,
            'period': interpolation.elastic!.period,
            'decay': interpolation.elastic!.decay,
          },
  };
}

@immutable
class ExportTrackSeed {
  ExportTrackSeed({
    required this.kind,
    required List<ExportClipSeed> clips,
  }) : clips = List.unmodifiable(clips);

  final ExportTrackKind kind;
  final List<ExportClipSeed> clips;
}

@immutable
class ExportClipSeed {
  const ExportClipSeed({
    required this.clipId,
    required this.assetId,
    required this.timelineStartTime,
    required this.timelineDurationTime,
    required this.sourceStartTime,
    required this.sourceDurationTime,
    required this.playbackRate,
    required this.speedMode,
    this.splitGroupId,
    this.label,
    this.isPlaceholder = false,
  });

  final String clipId;
  final String? assetId;
  final TimelineTime timelineStartTime;
  final TimelineTime timelineDurationTime;
  final TimelineTime sourceStartTime;
  final TimelineTime sourceDurationTime;
  final double playbackRate;
  final ExportClipSpeedMode speedMode;
  final String? splitGroupId;
  final String? label;
  final bool isPlaceholder;
}

@immutable
class ExportMotionTextRenderNode {
  ExportMotionTextRenderNode({
    required this.id,
    required this.targetElementId,
    required this.sceneId,
    required this.layerId,
    required this.projectRange,
    required this.text,
    required this.fullText,
    required this.revealUnit,
    required this.revealProgress,
    required this.hasRevealAnimation,
    required List<String> animationKinds,
    required Map<String, double> animationProgressByKind,
    required this.canvasOffset,
    required this.scaleX,
    required this.scaleY,
    required this.rotationDegrees,
    required this.opacity,
    required this.blurAmount,
    required this.fontSize,
    required this.letterSpacing,
    required this.colorArgb,
    required this.fontFamily,
    required this.fontWeight,
    required this.fontStyle,
    required this.lineHeight,
    required this.textAlignment,
    required this.anchor,
    required this.blendMode,
    required this.zIndex,
    this.name,
    this.presetId,
  })  : animationKinds = List.unmodifiable(animationKinds),
        animationProgressByKind = Map.unmodifiable(animationProgressByKind);

  final String id;
  final String targetElementId;
  final String sceneId;
  final String layerId;
  final TimelineTimeRange projectRange;
  final String text;
  final String fullText;
  final String revealUnit;
  final double? revealProgress;
  final bool hasRevealAnimation;
  final List<String> animationKinds;
  final Map<String, double> animationProgressByKind;
  final MotionPoint2D canvasOffset;
  final double scaleX;
  final double scaleY;
  final double rotationDegrees;
  final double opacity;
  final double blurAmount;
  final double fontSize;
  final double letterSpacing;
  final int colorArgb;
  final String? fontFamily;
  final int fontWeight;
  final String fontStyle;
  final double lineHeight;
  final String textAlignment;
  final String anchor;
  final String blendMode;
  final int zIndex;
  final String? name;
  final String? presetId;

  factory ExportMotionTextRenderNode.fromSnapshotNode(
      MotionTextRenderNode node) {
    return ExportMotionTextRenderNode(
      id: buildExportMotionTextNodeId(node.targetElementId),
      targetElementId: node.targetElementId,
      sceneId: node.sceneId,
      layerId: node.layerId,
      projectRange: node.projectRange,
      text: node.text,
      fullText: node.fullText,
      revealUnit: node.revealUnit.name,
      revealProgress: node.revealProgress,
      hasRevealAnimation: node.hasRevealAnimation,
      animationKinds:
          node.animationKinds.map((kind) => kind.name).toList(growable: false),
      animationProgressByKind: node.animationProgressByKind.map(
        (kind, progress) => MapEntry(kind.name, progress),
      ),
      canvasOffset: node.canvasOffset,
      scaleX: node.scaleX,
      scaleY: node.scaleY,
      rotationDegrees: node.rotationDegrees,
      opacity: node.opacity,
      blurAmount: node.blurAmount,
      fontSize: node.fontSize,
      letterSpacing: node.letterSpacing,
      colorArgb: node.colorArgb,
      fontFamily: node.fontFamily,
      fontWeight: node.fontWeight,
      fontStyle: node.fontStyle,
      lineHeight: node.lineHeight,
      textAlignment: node.textAlignment,
      anchor: node.anchor,
      blendMode: node.blendMode.name,
      zIndex: node.zIndex,
      name: node.name,
      presetId: node.presetId,
    );
  }
}

@immutable
class ExportMotionTextRenderSample {
  ExportMotionTextRenderSample({
    required this.time,
    required List<ExportMotionTextRenderNode> nodes,
  }) : nodes = List.unmodifiable(nodes);

  final TimelineTime time;
  final List<ExportMotionTextRenderNode> nodes;
}

@immutable
class ExportMotionTextRenderTrack {
  ExportMotionTextRenderTrack({
    required this.canvasSize,
    required this.sampleStepMs,
    required List<ExportMotionTextRenderSample> samples,
  }) : samples = List.unmodifiable(samples);

  final MotionSize2D canvasSize;
  final int sampleStepMs;
  final List<ExportMotionTextRenderSample> samples;

  int get totalNodeInstances => samples.fold<int>(
        0,
        (count, sample) => count + sample.nodes.length,
      );
}
