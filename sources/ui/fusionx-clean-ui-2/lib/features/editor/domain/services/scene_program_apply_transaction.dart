import 'package:flutter/foundation.dart';

import '../../presentation/models/timeline_time.dart';
import '../models/composition_scene_clip_models.dart';
import '../models/professional_motion_animation_models.dart';
import '../models/professional_motion_models.dart';
import '../models/professional_motion_text_models.dart';
import '../models/refusion_scene_program_models.dart';
import 'refusion_scene_program_authoring_service.dart';
import 'scene_pre_render_sanity_gate.dart';

enum SceneProgramApplyIssueCode {
  invalidAuthoringResult,
  missingSourceScene,
}

@immutable
class SceneProgramApplyIssue {
  const SceneProgramApplyIssue({
    required this.code,
    required this.message,
  });

  final SceneProgramApplyIssueCode code;
  final String message;
}

@immutable
class SceneProgramApplyTransactionRequest {
  SceneProgramApplyTransactionRequest({
    required this.baseProject,
    required this.authoringResult,
    required this.rootSceneId,
    this.startTime = TimelineTime.zero,
    this.clipId,
    this.sourceSceneId,
    this.clipName,
    List<CompositionSceneClipModel> existingSceneClips =
        const <CompositionSceneClipModel>[],
    List<MotionPropertyChannelModel> existingChannels =
        const <MotionPropertyChannelModel>[],
    List<MotionTextAnimationBindingModel> existingTextAnimationBindings =
        const <MotionTextAnimationBindingModel>[],
  })  : existingSceneClips = List.unmodifiable(existingSceneClips),
        existingChannels = List.unmodifiable(existingChannels),
        existingTextAnimationBindings =
            List.unmodifiable(existingTextAnimationBindings);

  final MotionProjectModel baseProject;
  final ReFusionSceneProgramAuthoringResult authoringResult;
  final String rootSceneId;
  final TimelineTime startTime;
  final String? clipId;
  final String? sourceSceneId;
  final String? clipName;
  final List<CompositionSceneClipModel> existingSceneClips;
  final List<MotionPropertyChannelModel> existingChannels;
  final List<MotionTextAnimationBindingModel> existingTextAnimationBindings;
}

@immutable
class SceneProgramApplyTransactionResult {
  SceneProgramApplyTransactionResult({
    required this.project,
    required this.rootScene,
    required this.sourceScene,
    required this.sceneClip,
    required List<CompositionSceneClipModel> sceneClips,
    required List<MotionPropertyChannelModel> channels,
    required List<MotionTextAnimationBindingModel> textAnimationBindings,
    List<SceneProgramApplyIssue> issues = const <SceneProgramApplyIssue>[],
  })  : sceneClips = List.unmodifiable(sceneClips),
        channels = List.unmodifiable(channels),
        textAnimationBindings = List.unmodifiable(textAnimationBindings),
        issues = List.unmodifiable(issues);

  final MotionProjectModel project;
  final MotionSceneModel rootScene;
  final MotionSceneModel sourceScene;
  final CompositionSceneClipModel sceneClip;
  final List<CompositionSceneClipModel> sceneClips;
  final List<MotionPropertyChannelModel> channels;
  final List<MotionTextAnimationBindingModel> textAnimationBindings;
  final List<SceneProgramApplyIssue> issues;

  bool get hasIssues => issues.isNotEmpty;
}

class SceneProgramApplyTransaction {
  const SceneProgramApplyTransaction({
    ScenePreRenderSanityGate preRenderSanityGate =
        const ScenePreRenderSanityGate(),
  }) : _preRenderSanityGate = preRenderSanityGate;

  final ScenePreRenderSanityGate _preRenderSanityGate;

  SceneProgramApplyTransactionResult? apply(
    SceneProgramApplyTransactionRequest request,
  ) {
    final authoring = request.authoringResult;
    if (!authoring.isValid || authoring.project == null) {
      return null;
    }
    final preRenderGate = _preRenderSanityGate.validate(
      authoringResult: authoring,
      sceneId: request.rootSceneId,
    );
    final bypassAlignmentOnlyBlock =
        preRenderGate.blocked && _canBypassAlignmentOnlyBlock(preRenderGate);
    if (preRenderGate.blocked && !bypassAlignmentOnlyBlock) {
      if (kDebugMode) {
        debugPrint(
          'SceneProgramApplyTransaction blocked by pre-render gate: '
          '${preRenderGate.fallbackReason}',
        );
        for (final issue in preRenderGate.issues.take(6)) {
          debugPrint(' - ${issue.message}');
        }
      }
      return null;
    }
    if (bypassAlignmentOnlyBlock && kDebugMode) {
      debugPrint(
        'SceneProgramApplyTransaction bypassed alignment-only pre-render gate '
        'for sceneId=${request.rootSceneId}',
      );
    }
    final importedProject = authoring.project!;
    if (importedProject.scenes.isEmpty) {
      return null;
    }

    final importedScene = importedProject.scenes.first;
    final sourceSceneId = _uniqueSceneId(
      request.sourceSceneId ?? '${_sanitizeId(importedScene.id)}_source',
      request.baseProject.scenes.map((scene) => scene.id),
    );
    final clipId = _uniqueSceneClipId(
      request.clipId ?? '${sourceSceneId}_clip',
      request.existingSceneClips.map((clip) => clip.id),
    );
    final namespace = _sanitizeId(sourceSceneId);
    final remap = _SceneProgramApplyIdRemap.fromScene(
      sourceSceneId: sourceSceneId,
      namespace: namespace,
      scene: importedScene,
    );
    final sourceScene = _remapScene(
      scene: importedScene,
      sourceSceneId: sourceSceneId,
      remap: remap,
      clipName: request.clipName ?? authoring.program?.name,
    );
    final sourceDuration = sourceScene.projectRange.duration;
    final sceneClip = CompositionSceneClipModel(
      id: clipId,
      sourceSceneId: sourceScene.id,
      name: request.clipName ?? sourceScene.name ?? authoring.program?.name,
      startTime: request.startTime,
      durationTime: sourceDuration,
      sourceInTime: sourceScene.projectRange.start,
      sourceOutTime: sourceScene.projectRange.endExclusive,
      metadata: <String, String>{
        'source': 'refusion.scene-program',
        if (authoring.program != null)
          'schemaVersion': authoring.program!.schemaVersion,
        'sourceSceneId': sourceScene.id,
      },
    );
    final rootScene = _rootSceneFor(
      project: request.baseProject,
      rootSceneId: request.rootSceneId,
      sceneClip: sceneClip,
    );
    final nextProject = _projectWithScenes(
      baseProject: request.baseProject,
      rootScene: rootScene,
      sourceScene: sourceScene,
      sceneClip: sceneClip,
    );
    final remappedChannels = authoring.channels
        .map((channel) => _remapChannel(channel, remap))
        .toList(growable: false);
    final remappedBindings = authoring.textAnimationBindings
        .map((binding) => _remapTextBinding(binding, remap))
        .toList(growable: false);
    final incomingChannelIds =
        remappedChannels.map((channel) => channel.id).toSet();
    final incomingBindingIds =
        remappedBindings.map((binding) => binding.id).toSet();

    return SceneProgramApplyTransactionResult(
      project: nextProject,
      rootScene: rootScene,
      sourceScene: sourceScene,
      sceneClip: sceneClip,
      sceneClips: <CompositionSceneClipModel>[
        for (final clip in request.existingSceneClips)
          if (clip.id != sceneClip.id) clip,
        sceneClip,
      ],
      channels: <MotionPropertyChannelModel>[
        for (final channel in request.existingChannels)
          if (!incomingChannelIds.contains(channel.id)) channel,
        ...remappedChannels,
      ],
      textAnimationBindings: <MotionTextAnimationBindingModel>[
        for (final binding in request.existingTextAnimationBindings)
          if (!incomingBindingIds.contains(binding.id)) binding,
        ...remappedBindings,
      ],
    );
  }

  bool _canBypassAlignmentOnlyBlock(ScenePreRenderSanityGateResult gate) {
    final errors = gate.issues
        .where(
          (issue) => issue.severity == ReFusionSceneProgramIssueSeverity.error,
        )
        .toList(growable: false);
    if (errors.isEmpty) {
      return false;
    }
    const alignmentProofTag = 'TF_SCENE_RENDER_TRUTH_ALIGNMENT_PROOF';
    return errors.every(
      (issue) => issue.message.contains(alignmentProofTag),
    );
  }

  MotionSceneModel _rootSceneFor({
    required MotionProjectModel project,
    required String rootSceneId,
    required CompositionSceneClipModel sceneClip,
  }) {
    final existing = project.scenes
        .where((scene) => scene.id == rootSceneId)
        .cast<MotionSceneModel?>()
        .firstOrNull;
    final nextEnd = _maxTime(<TimelineTime>[
      sceneClip.endTime,
      if (existing != null) existing.projectRange.endExclusive,
    ]);
    final metadata = <String, String>{
      if (existing != null) ...existing.metadata,
      'sceneClip.${sceneClip.id}.sourceSceneId': sceneClip.sourceSceneId,
      'sceneClip.${sceneClip.id}.startMs':
          '${sceneClip.startTime.inMilliseconds}',
      'sceneClip.${sceneClip.id}.durationMs':
          '${sceneClip.durationTime.inMilliseconds}',
    };
    if (existing != null) {
      return existing.copyWith(
        projectRange: TimelineTimeRange(
          start: existing.projectRange.start,
          endExclusive: nextEnd,
        ),
        metadata: metadata,
      );
    }
    return MotionSceneModel(
      id: rootSceneId,
      name: 'Root Composition',
      projectRange: TimelineTimeRange(
        start: TimelineTime.zero,
        endExclusive: nextEnd,
      ),
      layers: const <MotionLayerModel>[],
      metadata: metadata,
    );
  }

  MotionProjectModel _projectWithScenes({
    required MotionProjectModel baseProject,
    required MotionSceneModel rootScene,
    required MotionSceneModel sourceScene,
    required CompositionSceneClipModel sceneClip,
  }) {
    final scenes = <MotionSceneModel>[];
    var wroteRoot = false;
    var wroteSource = false;
    for (final scene in baseProject.scenes) {
      if (scene.id == rootScene.id) {
        scenes.add(rootScene);
        wroteRoot = true;
        continue;
      }
      if (scene.id == sourceScene.id) {
        scenes.add(sourceScene);
        wroteSource = true;
        continue;
      }
      scenes.add(scene);
    }
    if (!wroteRoot) {
      scenes.insert(0, rootScene);
    }
    if (!wroteSource) {
      scenes.add(sourceScene);
    }
    return baseProject.copyWith(
      scenes: List<MotionSceneModel>.unmodifiable(scenes),
      metadata: <String, String>{
        ...baseProject.metadata,
        'sceneClip.${sceneClip.id}.sourceSceneId': sceneClip.sourceSceneId,
      },
    );
  }
}

extension _FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) {
      return null;
    }
    return iterator.current;
  }
}

@immutable
class _SceneProgramApplyIdRemap {
  _SceneProgramApplyIdRemap({
    required this.sourceSceneId,
    required Map<String, String> layerIds,
    required Map<String, String> elementIds,
  })  : layerIds = Map.unmodifiable(layerIds),
        elementIds = Map.unmodifiable(elementIds);

  factory _SceneProgramApplyIdRemap.fromScene({
    required String sourceSceneId,
    required String namespace,
    required MotionSceneModel scene,
  }) {
    final layerIds = <String, String>{};
    final elementIds = <String, String>{};
    for (final layer in scene.layers) {
      layerIds[layer.id] = _namespacedId(namespace, layer.id);
      for (final element in layer.elements) {
        elementIds[element.id] = _namespacedId(namespace, element.id);
      }
    }
    return _SceneProgramApplyIdRemap(
      sourceSceneId: sourceSceneId,
      layerIds: layerIds,
      elementIds: elementIds,
    );
  }

  final String sourceSceneId;
  final Map<String, String> layerIds;
  final Map<String, String> elementIds;

  String layerId(String id) => layerIds[id] ?? id;

  String elementId(String id) => elementIds[id] ?? id;
}

MotionSceneModel _remapScene({
  required MotionSceneModel scene,
  required String sourceSceneId,
  required _SceneProgramApplyIdRemap remap,
  String? clipName,
}) {
  return scene.copyWith(
    id: sourceSceneId,
    name: clipName ?? scene.name,
    layers: scene.layers
        .map((layer) => _remapLayer(layer, sourceSceneId, remap))
        .toList(growable: false),
    metadata: <String, String>{
      ...scene.metadata,
      'sourceSceneId': sourceSceneId,
      'source': scene.metadata['source'] ?? 'refusion.scene-program',
    },
  );
}

MotionLayerModel _remapLayer(
  MotionLayerModel layer,
  String sourceSceneId,
  _SceneProgramApplyIdRemap remap,
) {
  final nextLayerId = remap.layerId(layer.id);
  return layer.copyWith(
    id: nextLayerId,
    sceneId: sourceSceneId,
    elements: layer.elements
        .map((element) => _remapElement(element, nextLayerId, remap))
        .toList(growable: false),
  );
}

MotionElementModel _remapElement(
  MotionElementModel element,
  String nextLayerId,
  _SceneProgramApplyIdRemap remap,
) {
  final nextElementId = remap.elementId(element.id);
  return element.copyWith(
    id: nextElementId,
    layerId: nextLayerId,
    sourceBinding: _remapSourceBinding(
      binding: element.sourceBinding,
      oldElementId: element.id,
      nextElementId: nextElementId,
    ),
  );
}

MotionElementSourceBinding? _remapSourceBinding({
  required MotionElementSourceBinding? binding,
  required String oldElementId,
  required String nextElementId,
}) {
  if (binding == null) {
    return null;
  }
  return MotionElementSourceBinding(
    kind: binding.kind,
    sourceId:
        binding.sourceId == oldElementId ? nextElementId : binding.sourceId,
    assetId: binding.assetId,
    label: binding.label,
    sourceRange: binding.sourceRange,
    metadata: binding.metadata,
  );
}

MotionPropertyChannelModel _remapChannel(
  MotionPropertyChannelModel channel,
  _SceneProgramApplyIdRemap remap,
) {
  final nextChannelId = _namespacedId(remap.sourceSceneId, channel.id);
  return channel.copyWith(
    id: nextChannelId,
    target: _remapTarget(channel.target, remap),
    keyframes: channel.keyframes
        .map(
          (keyframe) => keyframe.copyWith(
            id: _namespacedId(remap.sourceSceneId, keyframe.id),
            channelId: nextChannelId,
          ),
        )
        .toList(growable: false),
  );
}

MotionTextAnimationBindingModel _remapTextBinding(
  MotionTextAnimationBindingModel binding,
  _SceneProgramApplyIdRemap remap,
) {
  return MotionTextAnimationBindingModel(
    id: _namespacedId(remap.sourceSceneId, binding.id),
    elementTarget: _remapTarget(binding.elementTarget, remap),
    activeRange: binding.activeRange,
    presetId: binding.presetId,
    animationBlocks: binding.animationBlocks,
    parameterValues: binding.parameterValues,
  );
}

MotionPropertyTarget _remapTarget(
  MotionPropertyTarget target,
  _SceneProgramApplyIdRemap remap,
) {
  final targetId = switch (target.kind) {
    MotionTargetKind.layer => remap.layerId(target.targetId),
    MotionTargetKind.element => remap.elementId(target.targetId),
    MotionTargetKind.scene => remap.sourceSceneId,
    MotionTargetKind.project => target.targetId,
  };
  return MotionPropertyTarget(
    kind: target.kind,
    targetId: targetId,
    projectId: target.projectId,
    sceneId: target.sceneId == null ? null : remap.sourceSceneId,
    layerId: target.layerId == null ? null : remap.layerId(target.layerId!),
    elementId:
        target.elementId == null ? null : remap.elementId(target.elementId!),
  );
}

String _uniqueSceneId(String preferredId, Iterable<String> existingIds) {
  final existing = existingIds.toSet();
  var candidate = _sanitizeId(preferredId);
  if (!existing.contains(candidate)) {
    return candidate;
  }
  var suffix = 2;
  while (existing.contains('${candidate}_$suffix')) {
    suffix += 1;
  }
  return '${candidate}_$suffix';
}

String _uniqueSceneClipId(String preferredId, Iterable<String> existingIds) {
  final existing = existingIds.toSet();
  var candidate = _sanitizeId(preferredId);
  if (!existing.contains(candidate)) {
    return candidate;
  }
  var suffix = 2;
  while (existing.contains('${candidate}_$suffix')) {
    suffix += 1;
  }
  return '${candidate}_$suffix';
}

String _namespacedId(String namespace, String id) {
  final safeNamespace = _sanitizeId(namespace);
  final safeId = _sanitizeId(id);
  if (safeId.startsWith('${safeNamespace}__')) {
    return safeId;
  }
  return '${safeNamespace}__$safeId';
}

String _sanitizeId(String raw) {
  final normalized = raw
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9_-]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  return normalized.isEmpty ? 'scene' : normalized;
}

TimelineTime _maxTime(Iterable<TimelineTime> values) {
  var max = TimelineTime.zero;
  for (final value in values) {
    if (value > max) {
      max = value;
    }
  }
  return max;
}
