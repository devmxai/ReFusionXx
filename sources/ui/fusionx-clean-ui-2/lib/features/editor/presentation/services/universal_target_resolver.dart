import '../../domain/models/composition_scene_clip_models.dart';
import '../../domain/models/professional_motion_animation_models.dart';
import '../../domain/models/professional_motion_models.dart';

class UniversalTargetResolutionContext {
  UniversalTargetResolutionContext({
    required this.projectId,
    required this.knownSceneIds,
    required this.sceneIdByLayerId,
    required this.sceneIdByElementId,
    required this.layerIdByElementId,
  });

  final String projectId;
  final Set<String> knownSceneIds;
  final Map<String, String> sceneIdByLayerId;
  final Map<String, String> sceneIdByElementId;
  final Map<String, String> layerIdByElementId;
}

class UniversalTargetResolution {
  UniversalTargetResolution({
    required this.channel,
    this.blocker,
    List<String> diagnostics = const <String>[],
  }) : diagnostics = List.unmodifiable(diagnostics);

  final MotionPropertyChannelModel? channel;
  final String? blocker;
  final List<String> diagnostics;

  bool get isResolved => channel != null && blocker == null;
}

class UniversalTargetResolver {
  const UniversalTargetResolver();

  UniversalTargetResolutionContext buildContext({
    required MotionProjectModel project,
    required List<CompositionSceneClipModel> sceneClips,
  }) {
    final knownSceneIds = <String>{
      ...project.scenes.map((scene) => scene.id),
      ...sceneClips.map((clip) => clip.sourceSceneId),
    };
    final sceneIdByLayerId = <String, String>{};
    final sceneIdByElementId = <String, String>{};
    final layerIdByElementId = <String, String>{};
    for (final scene in project.scenes) {
      for (final layer in scene.layers) {
        sceneIdByLayerId.putIfAbsent(layer.id, () => scene.id);
        for (final element in layer.elements) {
          sceneIdByElementId.putIfAbsent(element.id, () => scene.id);
          layerIdByElementId.putIfAbsent(element.id, () => layer.id);
        }
      }
    }
    return UniversalTargetResolutionContext(
      projectId: project.id,
      knownSceneIds: knownSceneIds,
      sceneIdByLayerId: sceneIdByLayerId,
      sceneIdByElementId: sceneIdByElementId,
      layerIdByElementId: layerIdByElementId,
    );
  }

  UniversalTargetResolution resolveChannel({
    required MotionPropertyChannelModel channel,
    required UniversalTargetResolutionContext context,
  }) {
    final diagnostics = <String>[];
    final source = channel.target;
    var targetId = source.targetId.trim();
    var projectId = source.projectId?.trim();
    var sceneId = source.sceneId?.trim();
    var layerId = source.layerId?.trim();
    var elementId = source.elementId?.trim();

    if (projectId == null || projectId.isEmpty) {
      projectId = context.projectId;
      diagnostics.add('inferred_project_id:${channel.id}:$projectId');
    }
    if (targetId.isEmpty) {
      targetId = switch (source.kind) {
        MotionTargetKind.project => projectId,
        MotionTargetKind.scene => sceneId ?? '',
        MotionTargetKind.layer => layerId ?? '',
        MotionTargetKind.element => elementId ?? '',
      };
      if (targetId.isNotEmpty) {
        diagnostics.add('inferred_target_id:${channel.id}:$targetId');
      }
    }
    if ((sceneId == null || sceneId.isEmpty) &&
        source.kind == MotionTargetKind.scene &&
        targetId.isNotEmpty &&
        context.knownSceneIds.contains(targetId)) {
      sceneId = targetId;
      diagnostics.add('inferred_scene_id:${channel.id}:$sceneId');
    }
    if ((layerId == null || layerId.isEmpty) &&
        source.kind == MotionTargetKind.layer &&
        targetId.isNotEmpty) {
      layerId = targetId;
      diagnostics.add('inferred_layer_id:${channel.id}:$layerId');
    }
    if ((elementId == null || elementId.isEmpty) &&
        source.kind == MotionTargetKind.element &&
        targetId.isNotEmpty) {
      elementId = targetId;
      diagnostics.add('inferred_element_id:${channel.id}:$elementId');
    }

    if ((sceneId == null || sceneId.isEmpty) &&
        source.kind != MotionTargetKind.project) {
      if (source.kind == MotionTargetKind.scene &&
          targetId.isNotEmpty &&
          context.knownSceneIds.contains(targetId)) {
        sceneId = targetId;
      }
      if (layerId != null && layerId.isNotEmpty) {
        sceneId = context.sceneIdByLayerId[layerId];
      }
      if ((sceneId == null || sceneId.isEmpty) &&
          elementId != null &&
          elementId.isNotEmpty) {
        sceneId = context.sceneIdByElementId[elementId];
      }
      if ((sceneId == null || sceneId.isEmpty) &&
          source.kind == MotionTargetKind.scene &&
          targetId.isNotEmpty &&
          context.knownSceneIds.contains(targetId)) {
        sceneId = targetId;
      }
      if (sceneId != null && sceneId.isNotEmpty) {
        diagnostics.add('inferred_scene_id:${channel.id}:$sceneId');
      }
    }

    if ((sceneId == null || sceneId.isEmpty) &&
        layerId != null &&
        layerId.isNotEmpty) {
      final inferredSceneId = context.sceneIdByLayerId[layerId];
      if (inferredSceneId != null && inferredSceneId.isNotEmpty) {
        sceneId = inferredSceneId;
        diagnostics.add('inferred_scene_id:${channel.id}:$sceneId');
      }
    }

    if ((layerId == null || layerId.isEmpty) &&
        source.kind == MotionTargetKind.element &&
        elementId != null &&
        elementId.isNotEmpty) {
      layerId = context.layerIdByElementId[elementId];
      if (layerId != null && layerId.isNotEmpty) {
        diagnostics.add('inferred_layer_id:${channel.id}:$layerId');
      }
    }
    if ((sceneId == null || sceneId.isEmpty) &&
        elementId != null &&
        elementId.isNotEmpty) {
      final inferredSceneId = context.sceneIdByElementId[elementId];
      if (inferredSceneId != null && inferredSceneId.isNotEmpty) {
        sceneId = inferredSceneId;
        diagnostics.add('inferred_scene_id:${channel.id}:$sceneId');
      }
    }

    final blocker = _validateResolvedTarget(
      kind: source.kind,
      targetId: targetId,
      sceneId: sceneId,
      layerId: layerId,
      elementId: elementId,
    );
    if (blocker != null) {
      return UniversalTargetResolution(
        channel: null,
        blocker: blocker,
        diagnostics: diagnostics,
      );
    }

    final resolvedTarget = MotionPropertyTarget(
      kind: source.kind,
      targetId: targetId,
      projectId: projectId,
      sceneId: _emptyToNull(sceneId),
      layerId: _emptyToNull(layerId),
      elementId: _emptyToNull(elementId),
    );
    return UniversalTargetResolution(
      channel: channel.copyWith(target: resolvedTarget),
      diagnostics: diagnostics,
    );
  }

  static String? _validateResolvedTarget({
    required MotionTargetKind kind,
    required String targetId,
    required String? sceneId,
    required String? layerId,
    required String? elementId,
  }) {
    if (targetId.isEmpty) {
      return 'missing_target_id';
    }
    switch (kind) {
      case MotionTargetKind.project:
        return null;
      case MotionTargetKind.scene:
        return (sceneId == null || sceneId.isEmpty) ? 'missing_scene_id' : null;
      case MotionTargetKind.layer:
        if (layerId == null || layerId.isEmpty) {
          return 'missing_layer_id';
        }
        return (sceneId == null || sceneId.isEmpty) ? 'missing_scene_id' : null;
      case MotionTargetKind.element:
        if (elementId == null || elementId.isEmpty) {
          return 'missing_element_id';
        }
        if (layerId == null || layerId.isEmpty) {
          return 'missing_layer_id';
        }
        return (sceneId == null || sceneId.isEmpty) ? 'missing_scene_id' : null;
    }
  }

  static String? _emptyToNull(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }
}
