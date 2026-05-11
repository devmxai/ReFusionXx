import '../../presentation/models/timeline_time.dart';
import '../models/professional_motion_models.dart';
import 'refusion_mcp_command.dart';
import 'refusion_mcp_command_bus.dart';
import 'refusion_mcp_transaction.dart';

class RefusionMcpTimelineProjectCommitRequest {
  const RefusionMcpTimelineProjectCommitRequest({
    required this.command,
    required this.project,
    required this.summary,
    this.diagnostics = const <String>[],
    this.affectedLayerIds = const <String>[],
    this.changedProperties = const <String>[],
  });

  final RefusionMcpCommandEnvelope command;
  final MotionProjectModel project;
  final String summary;
  final List<String> diagnostics;
  final List<String> affectedLayerIds;
  final List<String> changedProperties;
}

class RefusionMcpTimelineProjectCommitResult {
  const RefusionMcpTimelineProjectCommitResult({
    required this.revisionAfter,
    this.summary,
    this.diagnostics = const <String>[],
  });

  final int revisionAfter;
  final String? summary;
  final List<String> diagnostics;
}

typedef RefusionMcpTimelineProjectCommit
    = RefusionMcpTimelineProjectCommitResult Function(
        RefusionMcpTimelineProjectCommitRequest request);

typedef RefusionMcpTimelinePlayheadReader = TimelineTime Function();

class RefusionMcpTimelineTools {
  const RefusionMcpTimelineTools();

  RefusionMcpCommandHandlingOutcome handle({
    required RefusionMcpCommandEnvelope command,
    required MotionProjectModel project,
    required String rootSceneId,
    required RefusionMcpTimelinePlayheadReader playheadReader,
    required RefusionMcpTimelineProjectCommit commitProject,
  }) {
    switch (command.type) {
      case 'refusion.insert_layer':
        return _insertLayer(
          command: command,
          project: project,
          rootSceneId: rootSceneId,
          commitProject: commitProject,
        );
      case 'refusion.split_at_playhead':
        return _splitAtPlayhead(
          command: command,
          project: project,
          rootSceneId: rootSceneId,
          playheadReader: playheadReader,
          commitProject: commitProject,
        );
      case 'refusion.trim_layer':
        return _trimLayer(
          command: command,
          project: project,
          rootSceneId: rootSceneId,
          commitProject: commitProject,
        );
      case 'refusion.move_layer':
        return _moveLayer(
          command: command,
          project: project,
          rootSceneId: rootSceneId,
          commitProject: commitProject,
        );
      case 'refusion.delete_layer':
        return _deleteLayer(
          command: command,
          project: project,
          rootSceneId: rootSceneId,
          commitProject: commitProject,
        );
      default:
        return RefusionMcpCommandHandlingOutcome(
          summary: 'Unsupported timeline command `${command.type}`.',
          requiresConfirmation: true,
        );
    }
  }

  RefusionMcpCommandHandlingOutcome _insertLayer({
    required RefusionMcpCommandEnvelope command,
    required MotionProjectModel project,
    required String rootSceneId,
    required RefusionMcpTimelineProjectCommit commitProject,
  }) {
    final scene = _resolveScene(project, rootSceneId, command.payload);
    if (scene == null) {
      return RefusionMcpCommandHandlingOutcome(
        summary: 'Scene was not found for insert layer.',
        requiresConfirmation: true,
      );
    }
    final kind = _parseLayerKind(command.payload['layerKind'] as String?);
    if (kind == null) {
      return RefusionMcpCommandHandlingOutcome(
        summary: 'insert_layer requires a valid layerKind.',
        requiresConfirmation: true,
      );
    }

    final startMs = _readInt(command.payload['startMs']) ?? 0;
    final durationMs = _readInt(command.payload['durationMs']) ?? 3000;
    if (durationMs <= 0) {
      return RefusionMcpCommandHandlingOutcome(
        summary: 'insert_layer requires durationMs > 0.',
        requiresConfirmation: true,
      );
    }
    final start = TimelineTime.fromMilliseconds(startMs);
    final endExclusive = TimelineTime.fromMilliseconds(startMs + durationMs);

    final requestedIndex =
        _readInt(command.payload['index']) ?? scene.layers.length;
    final insertIndex = requestedIndex.clamp(0, scene.layers.length);
    final layerId =
        (command.payload['layerId'] as String?)?.trim().isNotEmpty == true
            ? (command.payload['layerId'] as String).trim()
            : 'mcp_layer_${DateTime.now().microsecondsSinceEpoch}';
    final name = (command.payload['name'] as String?)?.trim();

    final nextLayer = MotionLayerModel(
      id: layerId,
      sceneId: scene.id,
      kind: kind,
      visibleRange: TimelineTimeRange(
        start: start,
        endExclusive: endExclusive,
      ),
      name: name == null || name.isEmpty ? 'Layer' : name,
      elements: const <MotionElementModel>[],
      zIndex: insertIndex,
    );
    final nextLayers = scene.layers.toList(growable: true)
      ..insert(insertIndex, nextLayer);
    final nextScene = scene.copyWith(layers: _normalizeLayerOrder(nextLayers));
    final nextProject = _replaceScene(project, nextScene);

    return _timelineCommitOutcome(
      command: command,
      summary: 'Insert layer is ready to commit.',
      previousProject: project,
      project: nextProject,
      commitProject: commitProject,
      affectedLayerIds: <String>[layerId],
      changedProperties: const <String>['layers'],
      payload: <String, Object?>{
        'sceneId': scene.id,
        'layerId': layerId,
        'insertIndex': insertIndex,
      },
    );
  }

  RefusionMcpCommandHandlingOutcome _splitAtPlayhead({
    required RefusionMcpCommandEnvelope command,
    required MotionProjectModel project,
    required String rootSceneId,
    required RefusionMcpTimelinePlayheadReader playheadReader,
    required RefusionMcpTimelineProjectCommit commitProject,
  }) {
    final scene = _resolveScene(project, rootSceneId, command.payload);
    if (scene == null) {
      return RefusionMcpCommandHandlingOutcome(
        summary: 'Scene was not found for split.',
        requiresConfirmation: true,
      );
    }
    final layerId = command.payload['layerId'] as String?;
    if (layerId == null || layerId.trim().isEmpty) {
      return RefusionMcpCommandHandlingOutcome(
        summary: 'split_at_playhead requires layerId.',
        requiresConfirmation: true,
      );
    }
    final layerIndex = scene.layers.indexWhere((entry) => entry.id == layerId);
    if (layerIndex < 0) {
      return RefusionMcpCommandHandlingOutcome(
        summary: 'Layer `$layerId` was not found.',
        requiresConfirmation: true,
      );
    }
    final layer = scene.layers[layerIndex];
    final splitTime = _readInt(command.payload['splitTimeMs']) != null
        ? TimelineTime.fromMilliseconds(
            _readInt(command.payload['splitTimeMs'])!)
        : playheadReader();
    if (splitTime <= layer.visibleRange.start ||
        splitTime >= layer.visibleRange.endExclusive) {
      return RefusionMcpCommandHandlingOutcome(
        summary:
            'split_at_playhead requires split time inside layer visible range.',
        requiresConfirmation: true,
      );
    }

    final leftRange = TimelineTimeRange(
      start: layer.visibleRange.start,
      endExclusive: splitTime,
    );
    final rightRange = TimelineTimeRange(
      start: splitTime,
      endExclusive: layer.visibleRange.endExclusive,
    );
    final rightLayerId =
        '${layer.id}_split_${splitTime.inMilliseconds.toString()}';
    final leftLayer = layer.copyWith(
      visibleRange: leftRange,
      elements: _trimElementsForRange(
        elements: layer.elements,
        nextLayerId: layer.id,
        range: leftRange,
      ),
    );
    final rightLayer = layer.copyWith(
      id: rightLayerId,
      visibleRange: rightRange,
      elements: _trimElementsForRange(
        elements: layer.elements,
        nextLayerId: rightLayerId,
        range: rightRange,
      ),
      zIndex: layer.zIndex + 1,
      name: layer.name == null ? null : '${layer.name} (Split)',
    );
    final nextLayers = scene.layers.toList(growable: true)
      ..removeAt(layerIndex)
      ..insert(layerIndex, leftLayer)
      ..insert(layerIndex + 1, rightLayer);
    final nextScene = scene.copyWith(layers: _normalizeLayerOrder(nextLayers));
    final nextProject = _replaceScene(project, nextScene);

    return _timelineCommitOutcome(
      command: command,
      summary: 'Split layer is ready to commit.',
      previousProject: project,
      project: nextProject,
      commitProject: commitProject,
      affectedLayerIds: <String>[layer.id, rightLayerId],
      changedProperties: const <String>['layers', 'elements'],
      payload: <String, Object?>{
        'sceneId': scene.id,
        'leftLayerId': layer.id,
        'rightLayerId': rightLayerId,
      },
    );
  }

  RefusionMcpCommandHandlingOutcome _trimLayer({
    required RefusionMcpCommandEnvelope command,
    required MotionProjectModel project,
    required String rootSceneId,
    required RefusionMcpTimelineProjectCommit commitProject,
  }) {
    final scene = _resolveScene(project, rootSceneId, command.payload);
    if (scene == null) {
      return RefusionMcpCommandHandlingOutcome(
        summary: 'Scene was not found for trim.',
        requiresConfirmation: true,
      );
    }
    final layerId = command.payload['layerId'] as String?;
    if (layerId == null || layerId.trim().isEmpty) {
      return RefusionMcpCommandHandlingOutcome(
        summary: 'trim_layer requires layerId.',
        requiresConfirmation: true,
      );
    }
    final layerIndex = scene.layers.indexWhere((entry) => entry.id == layerId);
    if (layerIndex < 0) {
      return RefusionMcpCommandHandlingOutcome(
        summary: 'Layer `$layerId` was not found.',
        requiresConfirmation: true,
      );
    }
    final layer = scene.layers[layerIndex];
    final nextStartMs = _readInt(command.payload['startMs']) ??
        layer.visibleRange.start.inMilliseconds;
    final nextEndMs = _readInt(command.payload['endMs']) ??
        layer.visibleRange.endExclusive.inMilliseconds;
    if (nextEndMs <= nextStartMs) {
      return RefusionMcpCommandHandlingOutcome(
        summary: 'trim_layer requires endMs > startMs.',
        requiresConfirmation: true,
      );
    }
    final nextRange = TimelineTimeRange(
      start: TimelineTime.fromMilliseconds(nextStartMs),
      endExclusive: TimelineTime.fromMilliseconds(nextEndMs),
    );
    final nextLayer = layer.copyWith(
      visibleRange: nextRange,
      elements: _trimElementsForRange(
        elements: layer.elements,
        nextLayerId: layer.id,
        range: nextRange,
      ),
    );
    final nextLayers = scene.layers.toList(growable: true)
      ..removeAt(layerIndex)
      ..insert(layerIndex, nextLayer);
    final nextScene = scene.copyWith(layers: _normalizeLayerOrder(nextLayers));
    final nextProject = _replaceScene(project, nextScene);

    return _timelineCommitOutcome(
      command: command,
      summary: 'Trim layer is ready to commit.',
      previousProject: project,
      project: nextProject,
      commitProject: commitProject,
      affectedLayerIds: <String>[layer.id],
      changedProperties: const <String>['layers', 'elements'],
      payload: <String, Object?>{
        'sceneId': scene.id,
        'layerId': layer.id,
        'startMs': nextStartMs,
        'endMs': nextEndMs,
      },
    );
  }

  RefusionMcpCommandHandlingOutcome _moveLayer({
    required RefusionMcpCommandEnvelope command,
    required MotionProjectModel project,
    required String rootSceneId,
    required RefusionMcpTimelineProjectCommit commitProject,
  }) {
    final scene = _resolveScene(project, rootSceneId, command.payload);
    if (scene == null) {
      return RefusionMcpCommandHandlingOutcome(
        summary: 'Scene was not found for move.',
        requiresConfirmation: true,
      );
    }
    final layerId = command.payload['layerId'] as String?;
    if (layerId == null || layerId.trim().isEmpty) {
      return RefusionMcpCommandHandlingOutcome(
        summary: 'move_layer requires layerId.',
        requiresConfirmation: true,
      );
    }
    final currentIndex =
        scene.layers.indexWhere((entry) => entry.id == layerId);
    if (currentIndex < 0) {
      return RefusionMcpCommandHandlingOutcome(
        summary: 'Layer `$layerId` was not found.',
        requiresConfirmation: true,
      );
    }
    final layers = scene.layers.toList(growable: true);
    final layer = layers[currentIndex];
    var changed = false;

    final toIndexRaw = _readInt(command.payload['toIndex']);
    if (toIndexRaw != null) {
      final toIndex = toIndexRaw.clamp(0, layers.length - 1);
      if (toIndex != currentIndex) {
        final removed = layers.removeAt(currentIndex);
        layers.insert(toIndex, removed);
        changed = true;
      }
    }

    final startMs = _readInt(command.payload['startMs']);
    if (startMs != null) {
      final duration = layer.visibleRange.duration;
      final nextStart = TimelineTime.fromMilliseconds(startMs);
      final nextLayer = layer.copyWith(
        visibleRange: TimelineTimeRange(
          start: nextStart,
          endExclusive: nextStart + duration,
        ),
      );
      final nextIndex = layers.indexWhere((entry) => entry.id == layer.id);
      if (nextIndex >= 0) {
        layers[nextIndex] = nextLayer;
        changed = true;
      }
    }

    if (!changed) {
      return RefusionMcpCommandHandlingOutcome(
        summary: 'move_layer requires toIndex and/or startMs.',
        requiresConfirmation: true,
      );
    }

    final nextScene = scene.copyWith(layers: _normalizeLayerOrder(layers));
    final nextProject = _replaceScene(project, nextScene);
    return _timelineCommitOutcome(
      command: command,
      summary: 'Move layer is ready to commit.',
      previousProject: project,
      project: nextProject,
      commitProject: commitProject,
      affectedLayerIds: <String>[layer.id],
      changedProperties: const <String>['layers'],
      payload: <String, Object?>{
        'sceneId': scene.id,
        'layerId': layer.id,
      },
    );
  }

  RefusionMcpCommandHandlingOutcome _deleteLayer({
    required RefusionMcpCommandEnvelope command,
    required MotionProjectModel project,
    required String rootSceneId,
    required RefusionMcpTimelineProjectCommit commitProject,
  }) {
    final confirmed = command.payload['confirmed'] == true;
    if (!confirmed) {
      return RefusionMcpCommandHandlingOutcome(
        summary: 'delete_layer requires explicit confirmation.',
        requiresConfirmation: true,
      );
    }
    final scene = _resolveScene(project, rootSceneId, command.payload);
    if (scene == null) {
      return RefusionMcpCommandHandlingOutcome(
        summary: 'Scene was not found for delete.',
        requiresConfirmation: true,
      );
    }
    final layerId = command.payload['layerId'] as String?;
    if (layerId == null || layerId.trim().isEmpty) {
      return RefusionMcpCommandHandlingOutcome(
        summary: 'delete_layer requires layerId.',
        requiresConfirmation: true,
      );
    }
    final nextLayers = scene.layers
        .where((entry) => entry.id != layerId)
        .toList(growable: false);
    if (nextLayers.length == scene.layers.length) {
      return RefusionMcpCommandHandlingOutcome(
        summary: 'Layer `$layerId` was not found.',
        requiresConfirmation: true,
      );
    }
    final nextScene = scene.copyWith(layers: _normalizeLayerOrder(nextLayers));
    final nextProject = _replaceScene(project, nextScene);
    return _timelineCommitOutcome(
      command: command,
      summary: 'Delete layer is ready to commit.',
      previousProject: project,
      project: nextProject,
      commitProject: commitProject,
      affectedLayerIds: <String>[layerId],
      changedProperties: const <String>['layers'],
      payload: <String, Object?>{
        'sceneId': scene.id,
        'layerId': layerId,
      },
    );
  }

  RefusionMcpCommandHandlingOutcome _timelineCommitOutcome({
    required RefusionMcpCommandEnvelope command,
    required String summary,
    required MotionProjectModel previousProject,
    required MotionProjectModel project,
    required RefusionMcpTimelineProjectCommit commitProject,
    required List<String> affectedLayerIds,
    required List<String> changedProperties,
    Map<String, Object?> payload = const <String, Object?>{},
    List<String> diagnostics = const <String>[],
  }) {
    return RefusionMcpCommandHandlingOutcome(
      summary: summary,
      diagnostics: diagnostics,
      patchPreview: RefusionMcpPatchPreview(
        affectedObjects: affectedLayerIds,
        changedProperties: changedProperties,
      ),
      payload: payload,
      commitOperation: () {
        final commit = commitProject(
          RefusionMcpTimelineProjectCommitRequest(
            command: command,
            project: project,
            summary: summary,
            diagnostics: diagnostics,
            affectedLayerIds: affectedLayerIds,
            changedProperties: changedProperties,
          ),
        );
        return RefusionMcpCommitExecution(
          revisionAfter: commit.revisionAfter,
          summary: commit.summary,
          undo: () {
            final undoCommit = commitProject(
              RefusionMcpTimelineProjectCommitRequest(
                command: command,
                project: previousProject,
                summary: 'Undo ${commit.summary ?? summary}',
              ),
            );
            return undoCommit.revisionAfter;
          },
          redo: () {
            final redoCommit = commitProject(
              RefusionMcpTimelineProjectCommitRequest(
                command: command,
                project: project,
                summary: 'Redo ${commit.summary ?? summary}',
              ),
            );
            return redoCommit.revisionAfter;
          },
        );
      },
    );
  }

  MotionSceneModel? _resolveScene(
    MotionProjectModel project,
    String rootSceneId,
    Map<String, Object?> payload,
  ) {
    final requestedId =
        (payload['sceneId'] as String?)?.trim().isNotEmpty == true
            ? (payload['sceneId'] as String).trim()
            : rootSceneId;
    for (final scene in project.scenes) {
      if (scene.id == requestedId) {
        return scene;
      }
    }
    return null;
  }

  MotionProjectModel _replaceScene(
    MotionProjectModel project,
    MotionSceneModel nextScene,
  ) {
    final scenes = project.scenes
        .map((scene) => scene.id == nextScene.id ? nextScene : scene)
        .toList(growable: false);
    return project.copyWith(scenes: scenes);
  }

  List<MotionLayerModel> _normalizeLayerOrder(List<MotionLayerModel> layers) {
    return layers
        .asMap()
        .entries
        .map((entry) => entry.value.copyWith(zIndex: entry.key))
        .toList(growable: false);
  }

  List<MotionElementModel> _trimElementsForRange({
    required List<MotionElementModel> elements,
    required String nextLayerId,
    required TimelineTimeRange range,
  }) {
    final trimmed = <MotionElementModel>[];
    for (final element in elements) {
      final overlapStart = element.localRange.start > range.start
          ? element.localRange.start
          : range.start;
      final overlapEnd = element.localRange.endExclusive < range.endExclusive
          ? element.localRange.endExclusive
          : range.endExclusive;
      if (overlapEnd <= overlapStart) {
        continue;
      }
      trimmed.add(
        element.copyWith(
          layerId: nextLayerId,
          localRange: TimelineTimeRange(
            start: overlapStart,
            endExclusive: overlapEnd,
          ),
        ),
      );
    }
    return trimmed;
  }

  MotionLayerKind? _parseLayerKind(String? value) {
    if (value == null) {
      return null;
    }
    for (final entry in MotionLayerKind.values) {
      if (entry.name == value) {
        return entry;
      }
    }
    return null;
  }

  int? _readInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    return null;
  }
}
