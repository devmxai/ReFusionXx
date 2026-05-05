import '../models/composition_scene_clip_models.dart';
import '../models/professional_motion_models.dart';

enum TrueFrameResolvedTargetKind {
  project,
  scene,
  layer,
  element,
  sceneClipInstance,
  transitionRole,
  group,
}

class TrueFrameUniversalTargetResolutionContext {
  TrueFrameUniversalTargetResolutionContext({
    required this.projectId,
    required this.knownSceneIds,
    required this.knownLayerIds,
    required this.knownElementIds,
    required this.knownSceneClipIds,
    required this.transitionRoleClipIdByRole,
    required this.knownGroupIds,
  });

  final String projectId;
  final Set<String> knownSceneIds;
  final Set<String> knownLayerIds;
  final Set<String> knownElementIds;
  final Set<String> knownSceneClipIds;
  final Map<String, String> transitionRoleClipIdByRole;
  final Set<String> knownGroupIds;
}

class TrueFrameResolvedTarget {
  const TrueFrameResolvedTarget({
    required this.kind,
    required this.nodeId,
    required this.canonicalTargetId,
    this.projectId,
    this.sceneId,
    this.layerId,
    this.elementId,
    this.sceneClipId,
    this.transitionRole,
    this.groupId,
  });

  final TrueFrameResolvedTargetKind kind;
  final String nodeId;
  final String canonicalTargetId;
  final String? projectId;
  final String? sceneId;
  final String? layerId;
  final String? elementId;
  final String? sceneClipId;
  final String? transitionRole;
  final String? groupId;
}

class TrueFrameTargetResolution {
  TrueFrameTargetResolution({
    required this.resolvedTarget,
    this.blocker,
    List<String> diagnostics = const <String>[],
  }) : diagnostics = List.unmodifiable(diagnostics);

  final TrueFrameResolvedTarget? resolvedTarget;
  final String? blocker;
  final List<String> diagnostics;

  bool get isResolved => resolvedTarget != null && blocker == null;
}

class TrueFrameUniversalTargetResolver {
  const TrueFrameUniversalTargetResolver();

  TrueFrameUniversalTargetResolutionContext buildContext({
    required MotionProjectModel project,
    required List<CompositionSceneClipModel> sceneClips,
    Map<String, String> transitionRoleClipIdByRole = const <String, String>{},
    Set<String> knownGroupIds = const <String>{},
  }) {
    final knownSceneIds = <String>{...project.scenes.map((scene) => scene.id)};
    final knownLayerIds = <String>{};
    final knownElementIds = <String>{};
    for (final scene in project.scenes) {
      for (final layer in scene.layers) {
        knownLayerIds.add(layer.id);
        for (final element in layer.elements) {
          knownElementIds.add(element.id);
        }
      }
    }
    final knownSceneClipIds = <String>{...sceneClips.map((clip) => clip.id)};
    return TrueFrameUniversalTargetResolutionContext(
      projectId: project.id,
      knownSceneIds: knownSceneIds,
      knownLayerIds: knownLayerIds,
      knownElementIds: knownElementIds,
      knownSceneClipIds: knownSceneClipIds,
      transitionRoleClipIdByRole: Map<String, String>.unmodifiable(
        transitionRoleClipIdByRole.map(
          (key, value) => MapEntry(key.trim().toLowerCase(), value.trim()),
        ),
      ),
      knownGroupIds: Set<String>.unmodifiable(knownGroupIds),
    );
  }

  TrueFrameTargetResolution resolveMotionTarget({
    required MotionPropertyTarget target,
    required TrueFrameUniversalTargetResolutionContext context,
    String? channelId,
  }) {
    final diagnostics = <String>[];
    final id = (channelId == null || channelId.trim().isEmpty)
        ? 'unknown'
        : channelId.trim();
    final rawTargetId = target.targetId.trim();
    if (rawTargetId.isEmpty) {
      return TrueFrameTargetResolution(
        resolvedTarget: null,
        blocker: 'missing_target_id',
        diagnostics: diagnostics,
      );
    }

    final explicitProjectId = target.projectId?.trim();
    final projectId = (explicitProjectId == null || explicitProjectId.isEmpty)
        ? context.projectId
        : explicitProjectId;
    if (target.projectId == null || target.projectId!.trim().isEmpty) {
      diagnostics.add('inferred_project_id:$id:$projectId');
    }

    switch (target.kind) {
      case MotionTargetKind.project:
        return TrueFrameTargetResolution(
          resolvedTarget: TrueFrameResolvedTarget(
            kind: TrueFrameResolvedTargetKind.project,
            nodeId: 'project:$projectId',
            canonicalTargetId: projectId,
            projectId: projectId,
          ),
          diagnostics: diagnostics,
        );
      case MotionTargetKind.scene:
        final sceneId =
            (target.sceneId == null || target.sceneId!.trim().isEmpty)
                ? rawTargetId
                : target.sceneId!.trim();
        if (!context.knownSceneIds.contains(sceneId)) {
          return TrueFrameTargetResolution(
            resolvedTarget: null,
            blocker: 'unknown_scene_id',
            diagnostics: diagnostics,
          );
        }
        if (target.sceneId == null || target.sceneId!.trim().isEmpty) {
          diagnostics.add('inferred_scene_id:$id:$sceneId');
        }
        return TrueFrameTargetResolution(
          resolvedTarget: TrueFrameResolvedTarget(
            kind: TrueFrameResolvedTargetKind.scene,
            nodeId: 'scene:$sceneId',
            canonicalTargetId: sceneId,
            projectId: projectId,
            sceneId: sceneId,
          ),
          diagnostics: diagnostics,
        );
      case MotionTargetKind.layer:
        final layerId =
            (target.layerId == null || target.layerId!.trim().isEmpty)
                ? rawTargetId
                : target.layerId!.trim();
        if (layerId.startsWith('group:') ||
            context.knownGroupIds.contains(layerId)) {
          return TrueFrameTargetResolution(
            resolvedTarget: TrueFrameResolvedTarget(
              kind: TrueFrameResolvedTargetKind.group,
              nodeId: 'group:$layerId',
              canonicalTargetId: layerId,
              projectId: projectId,
              groupId: layerId,
            ),
            diagnostics: diagnostics,
          );
        }
        if (!context.knownLayerIds.contains(layerId)) {
          return TrueFrameTargetResolution(
            resolvedTarget: null,
            blocker: 'unknown_layer_id',
            diagnostics: diagnostics,
          );
        }
        if (target.layerId == null || target.layerId!.trim().isEmpty) {
          diagnostics.add('inferred_layer_id:$id:$layerId');
        }
        return TrueFrameTargetResolution(
          resolvedTarget: TrueFrameResolvedTarget(
            kind: TrueFrameResolvedTargetKind.layer,
            nodeId: 'layer:$layerId',
            canonicalTargetId: layerId,
            projectId: projectId,
            layerId: layerId,
            sceneId: target.sceneId?.trim(),
          ),
          diagnostics: diagnostics,
        );
      case MotionTargetKind.element:
        final role = rawTargetId.toLowerCase();
        final roleClipId = context.transitionRoleClipIdByRole[role];
        if (roleClipId != null && roleClipId.isNotEmpty) {
          diagnostics.add('resolved_transition_role:$id:$role->$roleClipId');
          return TrueFrameTargetResolution(
            resolvedTarget: TrueFrameResolvedTarget(
              kind: TrueFrameResolvedTargetKind.transitionRole,
              nodeId: 'transition-role:$role:$roleClipId',
              canonicalTargetId: roleClipId,
              projectId: projectId,
              sceneClipId: roleClipId,
              transitionRole: role,
            ),
            diagnostics: diagnostics,
          );
        }
        if (context.knownSceneClipIds.contains(rawTargetId)) {
          diagnostics.add('resolved_scene_clip_instance:$id:$rawTargetId');
          return TrueFrameTargetResolution(
            resolvedTarget: TrueFrameResolvedTarget(
              kind: TrueFrameResolvedTargetKind.sceneClipInstance,
              nodeId: 'scene-clip:$rawTargetId',
              canonicalTargetId: rawTargetId,
              projectId: projectId,
              sceneClipId: rawTargetId,
            ),
            diagnostics: diagnostics,
          );
        }
        final elementId =
            (target.elementId == null || target.elementId!.trim().isEmpty)
                ? rawTargetId
                : target.elementId!.trim();
        if (!context.knownElementIds.contains(elementId)) {
          return TrueFrameTargetResolution(
            resolvedTarget: null,
            blocker: 'unknown_element_id',
            diagnostics: diagnostics,
          );
        }
        if (target.elementId == null || target.elementId!.trim().isEmpty) {
          diagnostics.add('inferred_element_id:$id:$elementId');
        }
        return TrueFrameTargetResolution(
          resolvedTarget: TrueFrameResolvedTarget(
            kind: TrueFrameResolvedTargetKind.element,
            nodeId: 'element:$elementId',
            canonicalTargetId: elementId,
            projectId: projectId,
            sceneId: target.sceneId?.trim(),
            layerId: target.layerId?.trim(),
            elementId: elementId,
          ),
          diagnostics: diagnostics,
        );
    }
  }
}
