import 'package:flutter/foundation.dart';

import '../../presentation/models/timeline_time.dart';
import 'composition_scene_clip_models.dart';
import 'professional_motion_models.dart';

enum CompositionWorkspaceIssueCode {
  missingRootScene,
  missingSourceScene,
  invalidSceneClip,
  invalidRootBackgroundLayer,
}

@immutable
class CompositionWorkspaceIssue {
  const CompositionWorkspaceIssue({
    required this.code,
    required this.message,
    this.sceneId,
    this.sceneClipId,
  });

  final CompositionWorkspaceIssueCode code;
  final String message;
  final String? sceneId;
  final String? sceneClipId;
}

enum CompositionWorkspaceScopeKind {
  rootComposition,
  sceneComposition,
  layerScope,
}

enum CompositionRootBackgroundLayerKind {
  color,
  image,
  video,
  generated,
}

@immutable
class CompositionRootBackgroundLayerModel {
  CompositionRootBackgroundLayerModel({
    required this.id,
    this.kind = CompositionRootBackgroundLayerKind.color,
    this.name,
    this.visibleRange,
    this.colorArgb,
    this.assetId,
    this.opacity = 1,
    this.zIndex = -1000,
    this.isEnabled = true,
    this.isLocked = false,
    Map<String, String> metadata = const <String, String>{},
  }) : metadata = Map.unmodifiable(metadata);

  final String id;
  final CompositionRootBackgroundLayerKind kind;
  final String? name;
  final TimelineTimeRange? visibleRange;
  final int? colorArgb;
  final String? assetId;
  final double opacity;
  final int zIndex;
  final bool isEnabled;
  final bool isLocked;
  final Map<String, String> metadata;

  bool isVisibleAt(TimelineTime rootTime) {
    if (!isEnabled) {
      return false;
    }
    final range = visibleRange;
    return range == null || range.contains(rootTime);
  }

  bool get hasValidOpacity => opacity.isFinite && opacity >= 0 && opacity <= 1;

  bool get hasValidVisibleRange {
    final range = visibleRange;
    return range == null || range.endExclusive > range.start;
  }

  CompositionRootBackgroundLayerModel copyWith({
    String? id,
    CompositionRootBackgroundLayerKind? kind,
    String? name,
    TimelineTimeRange? visibleRange,
    bool clearVisibleRange = false,
    int? colorArgb,
    String? assetId,
    double? opacity,
    int? zIndex,
    bool? isEnabled,
    bool? isLocked,
    Map<String, String>? metadata,
  }) {
    return CompositionRootBackgroundLayerModel(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      name: name ?? this.name,
      visibleRange:
          clearVisibleRange ? null : visibleRange ?? this.visibleRange,
      colorArgb: colorArgb ?? this.colorArgb,
      assetId: assetId ?? this.assetId,
      opacity: opacity ?? this.opacity,
      zIndex: zIndex ?? this.zIndex,
      isEnabled: isEnabled ?? this.isEnabled,
      isLocked: isLocked ?? this.isLocked,
      metadata: metadata ?? this.metadata,
    );
  }
}

@immutable
class CompositionWorkspaceScope {
  const CompositionWorkspaceScope._({
    required this.kind,
    required this.rootSceneId,
    this.sceneClipId,
    this.sourceSceneId,
    this.layerId,
  });

  const CompositionWorkspaceScope.root({
    required String rootSceneId,
  }) : this._(
          kind: CompositionWorkspaceScopeKind.rootComposition,
          rootSceneId: rootSceneId,
        );

  const CompositionWorkspaceScope.scene({
    required String rootSceneId,
    required String sceneClipId,
    required String sourceSceneId,
  }) : this._(
          kind: CompositionWorkspaceScopeKind.sceneComposition,
          rootSceneId: rootSceneId,
          sceneClipId: sceneClipId,
          sourceSceneId: sourceSceneId,
        );

  const CompositionWorkspaceScope.layer({
    required String rootSceneId,
    required String sceneClipId,
    required String sourceSceneId,
    required String layerId,
  }) : this._(
          kind: CompositionWorkspaceScopeKind.layerScope,
          rootSceneId: rootSceneId,
          sceneClipId: sceneClipId,
          sourceSceneId: sourceSceneId,
          layerId: layerId,
        );

  final CompositionWorkspaceScopeKind kind;
  final String rootSceneId;
  final String? sceneClipId;
  final String? sourceSceneId;
  final String? layerId;
}

enum CompositionWorkspaceSelectionKind {
  none,
  sceneClip,
  sourceScene,
  layer,
  element,
  keyframe,
}

@immutable
class CompositionWorkspaceSelection {
  const CompositionWorkspaceSelection._({
    required this.kind,
    this.sceneClipId,
    this.sourceSceneId,
    this.layerId,
    this.elementId,
    this.channelId,
    this.keyframeId,
  });

  const CompositionWorkspaceSelection.none()
      : this._(kind: CompositionWorkspaceSelectionKind.none);

  const CompositionWorkspaceSelection.sceneClip({
    required String sceneClipId,
  }) : this._(
          kind: CompositionWorkspaceSelectionKind.sceneClip,
          sceneClipId: sceneClipId,
        );

  const CompositionWorkspaceSelection.sourceScene({
    required String sourceSceneId,
  }) : this._(
          kind: CompositionWorkspaceSelectionKind.sourceScene,
          sourceSceneId: sourceSceneId,
        );

  const CompositionWorkspaceSelection.layer({
    required String sourceSceneId,
    required String layerId,
    String? sceneClipId,
  }) : this._(
          kind: CompositionWorkspaceSelectionKind.layer,
          sceneClipId: sceneClipId,
          sourceSceneId: sourceSceneId,
          layerId: layerId,
        );

  const CompositionWorkspaceSelection.element({
    required String sourceSceneId,
    required String layerId,
    required String elementId,
    String? sceneClipId,
  }) : this._(
          kind: CompositionWorkspaceSelectionKind.element,
          sceneClipId: sceneClipId,
          sourceSceneId: sourceSceneId,
          layerId: layerId,
          elementId: elementId,
        );

  const CompositionWorkspaceSelection.keyframe({
    required String sourceSceneId,
    required String layerId,
    required String elementId,
    required String channelId,
    required String keyframeId,
    String? sceneClipId,
  }) : this._(
          kind: CompositionWorkspaceSelectionKind.keyframe,
          sceneClipId: sceneClipId,
          sourceSceneId: sourceSceneId,
          layerId: layerId,
          elementId: elementId,
          channelId: channelId,
          keyframeId: keyframeId,
        );

  final CompositionWorkspaceSelectionKind kind;
  final String? sceneClipId;
  final String? sourceSceneId;
  final String? layerId;
  final String? elementId;
  final String? channelId;
  final String? keyframeId;

  bool get isEmpty => kind == CompositionWorkspaceSelectionKind.none;
}

enum CompositionWorkspaceInsertableLayerKind {
  video,
  image,
  text,
  shape,
  audio,
  camera,
  nullObject,
  adjustmentLayer,
}

extension CompositionWorkspaceInsertableLayerKindX
    on CompositionWorkspaceInsertableLayerKind {
  MotionLayerKind get motionLayerKind {
    switch (this) {
      case CompositionWorkspaceInsertableLayerKind.video:
        return MotionLayerKind.video;
      case CompositionWorkspaceInsertableLayerKind.image:
        return MotionLayerKind.image;
      case CompositionWorkspaceInsertableLayerKind.text:
        return MotionLayerKind.text;
      case CompositionWorkspaceInsertableLayerKind.shape:
        return MotionLayerKind.shape;
      case CompositionWorkspaceInsertableLayerKind.audio:
        return MotionLayerKind.audio;
      case CompositionWorkspaceInsertableLayerKind.camera:
        return MotionLayerKind.camera;
      case CompositionWorkspaceInsertableLayerKind.nullObject:
      case CompositionWorkspaceInsertableLayerKind.adjustmentLayer:
        return MotionLayerKind.effectControl;
    }
  }
}

enum CompositionWorkspaceInsertionAction {
  createSceneClip,
  modifySceneClip,
  addLayerToScene,
  editLayerScope,
  editKeyframe,
}

@immutable
class CompositionWorkspaceInsertionTarget {
  const CompositionWorkspaceInsertionTarget({
    required this.action,
    required this.rootSceneId,
    required this.rootTime,
    this.sourceSceneId,
    this.sceneClipId,
    this.layerId,
    this.elementId,
    this.channelId,
    this.keyframeId,
    this.localTime,
    this.layerKind,
  });

  final CompositionWorkspaceInsertionAction action;
  final String rootSceneId;
  final TimelineTime rootTime;
  final String? sourceSceneId;
  final String? sceneClipId;
  final String? layerId;
  final String? elementId;
  final String? channelId;
  final String? keyframeId;
  final TimelineTime? localTime;
  final CompositionWorkspaceInsertableLayerKind? layerKind;
}

@immutable
class CompositionWorkspaceTimeContext {
  const CompositionWorkspaceTimeContext({
    required this.rootTime,
    required this.sourceTime,
    required this.localTime,
    required this.scope,
    this.sceneClip,
  });

  final TimelineTime rootTime;
  final TimelineTime sourceTime;
  final TimelineTime localTime;
  final CompositionWorkspaceScope scope;
  final CompositionSceneClipModel? sceneClip;
}

@immutable
class CompositionWorkspaceModel {
  CompositionWorkspaceModel({
    required this.project,
    required this.rootSceneId,
    required this.currentRootTime,
    List<CompositionRootBackgroundLayerModel> rootBackgroundLayers =
        const <CompositionRootBackgroundLayerModel>[],
    List<CompositionSceneClipModel> sceneClips =
        const <CompositionSceneClipModel>[],
    CompositionWorkspaceScope? activeScope,
    this.selection = const CompositionWorkspaceSelection.none(),
  })  : rootBackgroundLayers = List.unmodifiable(rootBackgroundLayers),
        sceneClips = List.unmodifiable(sceneClips),
        activeScope = activeScope ??
            CompositionWorkspaceScope.root(rootSceneId: rootSceneId);

  final MotionProjectModel project;
  final String rootSceneId;
  final TimelineTime currentRootTime;
  final List<CompositionRootBackgroundLayerModel> rootBackgroundLayers;
  final List<CompositionSceneClipModel> sceneClips;
  final CompositionWorkspaceScope activeScope;
  final CompositionWorkspaceSelection selection;

  MotionSceneModel? get rootScene => sceneById(rootSceneId);

  List<MotionSceneModel> get sourceScenes {
    return project.scenes
        .where((scene) => scene.id != rootSceneId)
        .toList(growable: false);
  }

  TimelineTime get rootDurationTime {
    final scene = rootScene;
    if (scene != null) {
      return scene.durationTime;
    }
    return project.durationTime;
  }

  CompositionSceneClipCollection get sceneClipCollection {
    return CompositionSceneClipCollection(clips: sceneClips);
  }

  MotionSceneModel? sceneById(String id) {
    for (final scene in project.scenes) {
      if (scene.id == id) {
        return scene;
      }
    }
    return null;
  }

  CompositionSceneClipModel? sceneClipById(String id) {
    for (final clip in sceneClips) {
      if (clip.id == id) {
        return clip;
      }
    }
    return null;
  }

  MotionSceneModel? sourceSceneForClip(CompositionSceneClipModel clip) {
    return sceneById(clip.sourceSceneId);
  }

  CompositionSceneClipModel? get sceneClipAtCurrentRootTime {
    return sceneClipCollection.clipAtRootTime(currentRootTime);
  }

  List<CompositionRootBackgroundLayerModel>
      get rootBackgroundLayersAtCurrentRootTime {
    final visibleLayers = rootBackgroundLayers
        .where((layer) => layer.isVisibleAt(currentRootTime))
        .toList(growable: false);
    visibleLayers.sort((left, right) {
      final zCompare = left.zIndex.compareTo(right.zIndex);
      if (zCompare != 0) {
        return zCompare;
      }
      return left.id.compareTo(right.id);
    });
    return List<CompositionRootBackgroundLayerModel>.unmodifiable(
      visibleLayers,
    );
  }

  CompositionWorkspaceTimeContext timeContext() {
    final sceneClipId = activeScope.sceneClipId ?? selection.sceneClipId;
    final sceneClip = sceneClipId == null ? null : sceneClipById(sceneClipId);
    if (sceneClip == null) {
      return CompositionWorkspaceTimeContext(
        rootTime: currentRootTime,
        sourceTime: currentRootTime,
        localTime: currentRootTime,
        scope: CompositionWorkspaceScope.root(rootSceneId: rootSceneId),
      );
    }

    return CompositionWorkspaceTimeContext(
      rootTime: currentRootTime.clamp(
        sceneClip.rootRange.start,
        sceneClip.rootRange.endExclusive,
      ),
      sourceTime: sceneClip.rootToSourceTime(currentRootTime),
      localTime: sceneClip.rootToLocalTime(currentRootTime),
      scope: activeScope,
      sceneClip: sceneClip,
    );
  }

  List<CompositionWorkspaceIssue> validate() {
    final issues = <CompositionWorkspaceIssue>[];
    if (rootScene == null) {
      issues.add(
        CompositionWorkspaceIssue(
          code: CompositionWorkspaceIssueCode.missingRootScene,
          message: 'Root composition scene `$rootSceneId` was not found.',
          sceneId: rootSceneId,
        ),
      );
    }

    for (final layer in rootBackgroundLayers) {
      if (!layer.hasValidOpacity || !layer.hasValidVisibleRange) {
        issues.add(
          CompositionWorkspaceIssue(
            code: CompositionWorkspaceIssueCode.invalidRootBackgroundLayer,
            message:
                'Root background layer `${layer.id}` has invalid opacity or timing.',
            sceneId: rootSceneId,
          ),
        );
      }
    }

    for (final clip in sceneClips) {
      for (final clipIssue in clip.validate()) {
        issues.add(
          CompositionWorkspaceIssue(
            code: CompositionWorkspaceIssueCode.invalidSceneClip,
            message: clipIssue.message,
            sceneId: clip.sourceSceneId,
            sceneClipId: clip.id,
          ),
        );
      }
      if (sceneById(clip.sourceSceneId) == null) {
        issues.add(
          CompositionWorkspaceIssue(
            code: CompositionWorkspaceIssueCode.missingSourceScene,
            message:
                'Scene clip `${clip.id}` points to missing source composition `${clip.sourceSceneId}`.',
            sceneId: clip.sourceSceneId,
            sceneClipId: clip.id,
          ),
        );
      }
    }

    return issues;
  }
}

class CompositionWorkspaceInsertionTargetResolver {
  const CompositionWorkspaceInsertionTargetResolver();

  CompositionWorkspaceInsertionTarget resolveSceneAction(
    CompositionWorkspaceModel workspace,
  ) {
    final selectedClipId = workspace.selection.sceneClipId;
    final selectedClip =
        selectedClipId == null ? null : workspace.sceneClipById(selectedClipId);
    if (selectedClip != null) {
      return CompositionWorkspaceInsertionTarget(
        action: CompositionWorkspaceInsertionAction.modifySceneClip,
        rootSceneId: workspace.rootSceneId,
        rootTime: workspace.currentRootTime,
        sourceSceneId: selectedClip.sourceSceneId,
        sceneClipId: selectedClip.id,
        localTime: selectedClip.rootToLocalTime(workspace.currentRootTime),
      );
    }

    return CompositionWorkspaceInsertionTarget(
      action: CompositionWorkspaceInsertionAction.createSceneClip,
      rootSceneId: workspace.rootSceneId,
      rootTime: workspace.currentRootTime,
    );
  }

  CompositionWorkspaceInsertionTarget resolveLayerInsert(
    CompositionWorkspaceModel workspace, {
    required CompositionWorkspaceInsertableLayerKind layerKind,
  }) {
    final context = workspace.timeContext();
    final sourceSceneId =
        context.sceneClip?.sourceSceneId ?? workspace.rootSceneId;
    return CompositionWorkspaceInsertionTarget(
      action: CompositionWorkspaceInsertionAction.addLayerToScene,
      rootSceneId: workspace.rootSceneId,
      rootTime: workspace.currentRootTime,
      sourceSceneId: sourceSceneId,
      sceneClipId: context.sceneClip?.id,
      localTime: context.localTime,
      layerKind: layerKind,
    );
  }

  CompositionWorkspaceInsertionTarget resolveSelectionEdit(
    CompositionWorkspaceModel workspace,
  ) {
    final selection = workspace.selection;
    final context = workspace.timeContext();
    if (selection.kind == CompositionWorkspaceSelectionKind.keyframe) {
      return CompositionWorkspaceInsertionTarget(
        action: CompositionWorkspaceInsertionAction.editKeyframe,
        rootSceneId: workspace.rootSceneId,
        rootTime: workspace.currentRootTime,
        sourceSceneId:
            selection.sourceSceneId ?? context.sceneClip?.sourceSceneId,
        sceneClipId: selection.sceneClipId ?? context.sceneClip?.id,
        layerId: selection.layerId,
        elementId: selection.elementId,
        channelId: selection.channelId,
        keyframeId: selection.keyframeId,
        localTime: context.localTime,
      );
    }

    return CompositionWorkspaceInsertionTarget(
      action: CompositionWorkspaceInsertionAction.editLayerScope,
      rootSceneId: workspace.rootSceneId,
      rootTime: workspace.currentRootTime,
      sourceSceneId:
          selection.sourceSceneId ?? context.sceneClip?.sourceSceneId,
      sceneClipId: selection.sceneClipId ?? context.sceneClip?.id,
      layerId: selection.layerId ?? workspace.activeScope.layerId,
      elementId: selection.elementId,
      localTime: context.localTime,
    );
  }
}
