import '../models/refusion_scene_program_models.dart';

class SceneGlobalParentGraphIssue {
  const SceneGlobalParentGraphIssue({
    required this.code,
    required this.message,
    this.path,
  });

  final String code;
  final String message;
  final String? path;
}

class SceneGlobalParentGraphResult {
  const SceneGlobalParentGraphResult({
    required this.parentByRuntimeNodeId,
    required this.issues,
  });

  final Map<String, String?> parentByRuntimeNodeId;
  final List<SceneGlobalParentGraphIssue> issues;
}

class SceneGlobalParentGraph {
  const SceneGlobalParentGraph();

  static const String sceneRootNodeId = '__scene__root';

  SceneGlobalParentGraphResult build(ReFusionSceneProgram program) {
    final issues = <SceneGlobalParentGraphIssue>[];
    final parentByRuntimeNodeId = <String, String?>{};

    final occurrencesByElementId = <String, List<(int, int)>>{};
    for (var layerIndex = 0;
        layerIndex < program.layers.length;
        layerIndex += 1) {
      final layer = program.layers[layerIndex];
      for (var elementIndex = 0;
          elementIndex < layer.elements.length;
          elementIndex += 1) {
        final element = layer.elements[elementIndex];
        occurrencesByElementId
            .putIfAbsent(element.id, () => <(int, int)>[])
            .add((layerIndex, elementIndex));
      }
    }

    for (var layerIndex = 0;
        layerIndex < program.layers.length;
        layerIndex += 1) {
      final layer = program.layers[layerIndex];
      for (var elementIndex = 0;
          elementIndex < layer.elements.length;
          elementIndex += 1) {
        final element = layer.elements[elementIndex];
        final runtimeNodeId = _runtimeNodeId(
          layerId: layer.id,
          elementId: element.id,
        );
        final parentValue = element.properties['parentId'];
        if (parentValue is! String || parentValue.trim().isEmpty) {
          parentByRuntimeNodeId[runtimeNodeId] = sceneRootNodeId;
          continue;
        }

        final parentId = parentValue.trim();
        final sameLayerParent = layer.elements
            .where((candidate) => candidate.id == parentId)
            .toList(growable: false);
        if (sameLayerParent.length == 1) {
          parentByRuntimeNodeId[runtimeNodeId] = _runtimeNodeId(
            layerId: layer.id,
            elementId: parentId,
          );
          continue;
        }

        final occurrences =
            occurrencesByElementId[parentId] ?? const <(int, int)>[];
        if (occurrences.isEmpty) {
          parentByRuntimeNodeId[runtimeNodeId] = sceneRootNodeId;
          issues.add(
            SceneGlobalParentGraphIssue(
              code: 'missing_parent',
              message:
                  'Element `${element.id}` references missing parent `$parentId`.',
              path:
                  'layers[$layerIndex].elements[$elementIndex].properties.parentId',
            ),
          );
          continue;
        }
        if (occurrences.length > 1) {
          parentByRuntimeNodeId[runtimeNodeId] = sceneRootNodeId;
          issues.add(
            SceneGlobalParentGraphIssue(
              code: 'ambiguous_parent',
              message:
                  'Element `${element.id}` references ambiguous parent `$parentId` across multiple layers.',
              path:
                  'layers[$layerIndex].elements[$elementIndex].properties.parentId',
            ),
          );
          continue;
        }

        final parentOccurrence = occurrences.single;
        final parentLayer = program.layers[parentOccurrence.$1];
        final parentElement = parentLayer.elements[parentOccurrence.$2];
        parentByRuntimeNodeId[runtimeNodeId] = _runtimeNodeId(
          layerId: parentLayer.id,
          elementId: parentElement.id,
        );
      }
    }

    return SceneGlobalParentGraphResult(
      parentByRuntimeNodeId: parentByRuntimeNodeId,
      issues: List.unmodifiable(issues),
    );
  }

  String _runtimeNodeId({
    required String layerId,
    required String elementId,
  }) {
    return '__layer__${layerId}__element__${elementId}';
  }
}
