import '../../domain/models/composition_workspace_models.dart';
import '../../domain/models/professional_motion_animation_models.dart';
import '../../domain/models/professional_motion_models.dart';
import '../models/timeline_time.dart';
import 'root_composition_layer_projection_adapter.dart';

enum CompositionWorkspaceOutlinerNodeKind {
  project,
  assetsGroup,
  rootComposition,
  backgroundLayersGroup,
  rootBackgroundLayer,
  sceneClipsGroup,
  sceneClipInstance,
  sourceCompositionsGroup,
  sourceComposition,
  layer,
  element,
  channel,
}

enum CompositionWorkspaceOutlinerIssueCode {
  rootLayerProjection,
}

class CompositionWorkspaceOutlinerIssue {
  const CompositionWorkspaceOutlinerIssue({
    required this.code,
    required this.message,
    this.nodeId,
  });

  final CompositionWorkspaceOutlinerIssueCode code;
  final String message;
  final String? nodeId;
}

class CompositionWorkspaceOutlinerNode {
  CompositionWorkspaceOutlinerNode({
    required this.id,
    required this.kind,
    required this.label,
    List<CompositionWorkspaceOutlinerNode> children =
        const <CompositionWorkspaceOutlinerNode>[],
    this.isSelected = false,
    this.isEnabled = true,
    this.isLocked = false,
    this.zIndex,
    this.rootRange,
    this.sourceSceneId,
    this.sceneClipId,
    this.layerId,
    this.elementId,
    this.channelId,
    this.workspaceSelection,
  }) : children = List.unmodifiable(children);

  final String id;
  final CompositionWorkspaceOutlinerNodeKind kind;
  final String label;
  final List<CompositionWorkspaceOutlinerNode> children;
  final bool isSelected;
  final bool isEnabled;
  final bool isLocked;
  final int? zIndex;
  final TimelineTimeRange? rootRange;
  final String? sourceSceneId;
  final String? sceneClipId;
  final String? layerId;
  final String? elementId;
  final String? channelId;
  final CompositionWorkspaceSelection? workspaceSelection;

  bool get hasChildren => children.isNotEmpty;

  Iterable<CompositionWorkspaceOutlinerNode> get flattened sync* {
    yield this;
    for (final child in children) {
      yield* child.flattened;
    }
  }

  CompositionWorkspaceOutlinerNode? findById(String targetId) {
    if (id == targetId) {
      return this;
    }
    for (final child in children) {
      final match = child.findById(targetId);
      if (match != null) {
        return match;
      }
    }
    return null;
  }
}

class CompositionWorkspaceOutlinerResult {
  CompositionWorkspaceOutlinerResult({
    required this.root,
    List<CompositionWorkspaceOutlinerIssue> issues =
        const <CompositionWorkspaceOutlinerIssue>[],
  }) : issues = List.unmodifiable(issues);

  final CompositionWorkspaceOutlinerNode root;
  final List<CompositionWorkspaceOutlinerIssue> issues;

  bool get hasIssues => issues.isNotEmpty;

  List<CompositionWorkspaceOutlinerNode> get flattened {
    return List<CompositionWorkspaceOutlinerNode>.unmodifiable(root.flattened);
  }

  CompositionWorkspaceOutlinerNode? findById(String id) => root.findById(id);

  CompositionWorkspaceOutlinerNode? get selectedNode {
    for (final node in root.flattened) {
      if (node.isSelected) {
        return node;
      }
    }
    return null;
  }
}

class CompositionWorkspaceOutlinerAdapter {
  const CompositionWorkspaceOutlinerAdapter({
    RootCompositionLayerProjectionAdapter rootLayerProjectionAdapter =
        const RootCompositionLayerProjectionAdapter(),
  }) : _rootLayerProjectionAdapter = rootLayerProjectionAdapter;

  final RootCompositionLayerProjectionAdapter _rootLayerProjectionAdapter;

  CompositionWorkspaceOutlinerResult build({
    required CompositionWorkspaceModel workspace,
    List<MotionPropertyChannelModel> channels =
        const <MotionPropertyChannelModel>[],
  }) {
    final rootLayerProjection =
        _rootLayerProjectionAdapter.projectWorkspace(workspace);
    final issues = <CompositionWorkspaceOutlinerIssue>[
      for (final issue in rootLayerProjection.issues)
        CompositionWorkspaceOutlinerIssue(
          code: CompositionWorkspaceOutlinerIssueCode.rootLayerProjection,
          message: issue.message,
          nodeId: issue.layerId ?? issue.sceneClipId,
        ),
    ];

    final channelsByTargetId = _channelsByTargetId(channels);
    final projectNode = CompositionWorkspaceOutlinerNode(
      id: 'project:${workspace.project.id}',
      kind: CompositionWorkspaceOutlinerNodeKind.project,
      label: _labelOrFallback(workspace.project.name, 'Project'),
      children: <CompositionWorkspaceOutlinerNode>[
        CompositionWorkspaceOutlinerNode(
          id: 'assets:${workspace.project.id}',
          kind: CompositionWorkspaceOutlinerNodeKind.assetsGroup,
          label: 'Assets',
        ),
        _rootCompositionNode(
          workspace: workspace,
          rootLayerProjection: rootLayerProjection,
        ),
        _sourceCompositionsNode(
          workspace: workspace,
          channelsByTargetId: channelsByTargetId,
        ),
      ],
    );

    return CompositionWorkspaceOutlinerResult(
      root: projectNode,
      issues: issues,
    );
  }

  CompositionWorkspaceOutlinerNode _rootCompositionNode({
    required CompositionWorkspaceModel workspace,
    required RootCompositionLayerProjectionResult rootLayerProjection,
  }) {
    final backgroundNodes = <CompositionWorkspaceOutlinerNode>[];
    final sceneClipNodes = <CompositionWorkspaceOutlinerNode>[];

    for (final projection in rootLayerProjection.layers) {
      if (projection.isBackground) {
        final background = projection.backgroundLayer!;
        backgroundNodes.add(
          CompositionWorkspaceOutlinerNode(
            id: 'rootBackground:${background.id}',
            kind: CompositionWorkspaceOutlinerNodeKind.rootBackgroundLayer,
            label: projection.label,
            isEnabled: background.isEnabled,
            isLocked: background.isLocked,
            zIndex: projection.zIndex,
            rootRange: projection.rootRange,
          ),
        );
      } else if (projection.isSceneClip) {
        final clip = projection.sceneClip!;
        sceneClipNodes.add(
          CompositionWorkspaceOutlinerNode(
            id: 'sceneClip:${clip.id}',
            kind: CompositionWorkspaceOutlinerNodeKind.sceneClipInstance,
            label: projection.label,
            isSelected: _isSceneClipSelected(workspace.selection, clip.id),
            isEnabled: clip.isEnabled,
            isLocked: clip.isLocked,
            zIndex: projection.zIndex,
            rootRange: projection.rootRange,
            sourceSceneId: clip.sourceSceneId,
            sceneClipId: clip.id,
            workspaceSelection: CompositionWorkspaceSelection.sceneClip(
              sceneClipId: clip.id,
            ),
          ),
        );
      }
    }

    return CompositionWorkspaceOutlinerNode(
      id: 'rootComposition:${workspace.rootSceneId}',
      kind: CompositionWorkspaceOutlinerNodeKind.rootComposition,
      label: _labelOrFallback(workspace.rootScene?.name, 'Root Composition'),
      sourceSceneId: workspace.rootSceneId,
      children: <CompositionWorkspaceOutlinerNode>[
        CompositionWorkspaceOutlinerNode(
          id: 'rootBackgrounds:${workspace.rootSceneId}',
          kind: CompositionWorkspaceOutlinerNodeKind.backgroundLayersGroup,
          label: 'Background Layers',
          children: backgroundNodes,
        ),
        CompositionWorkspaceOutlinerNode(
          id: 'sceneClips:${workspace.rootSceneId}',
          kind: CompositionWorkspaceOutlinerNodeKind.sceneClipsGroup,
          label: 'Scene Clips',
          children: sceneClipNodes,
        ),
      ],
    );
  }

  CompositionWorkspaceOutlinerNode _sourceCompositionsNode({
    required CompositionWorkspaceModel workspace,
    required Map<String, List<MotionPropertyChannelModel>> channelsByTargetId,
  }) {
    final sourceScenes = workspace.sourceScenes.toList(growable: false)
      ..sort((left, right) {
        final startCompare = left.projectRange.start.compareTo(
          right.projectRange.start,
        );
        if (startCompare != 0) {
          return startCompare;
        }
        return left.id.compareTo(right.id);
      });

    return CompositionWorkspaceOutlinerNode(
      id: 'sourceCompositions:${workspace.project.id}',
      kind: CompositionWorkspaceOutlinerNodeKind.sourceCompositionsGroup,
      label: 'Source Compositions',
      children: <CompositionWorkspaceOutlinerNode>[
        for (final scene in sourceScenes)
          _sourceCompositionNode(
            workspace: workspace,
            scene: scene,
            channelsByTargetId: channelsByTargetId,
          ),
      ],
    );
  }

  CompositionWorkspaceOutlinerNode _sourceCompositionNode({
    required CompositionWorkspaceModel workspace,
    required MotionSceneModel scene,
    required Map<String, List<MotionPropertyChannelModel>> channelsByTargetId,
  }) {
    final layers = scene.layers.toList(growable: false)
      ..sort((left, right) {
        final zCompare = left.zIndex.compareTo(right.zIndex);
        if (zCompare != 0) {
          return zCompare;
        }
        return left.id.compareTo(right.id);
      });

    return CompositionWorkspaceOutlinerNode(
      id: 'sourceComposition:${scene.id}',
      kind: CompositionWorkspaceOutlinerNodeKind.sourceComposition,
      label: _labelOrFallback(scene.name, scene.id),
      sourceSceneId: scene.id,
      isSelected: _isSourceSceneSelected(workspace.selection, scene.id),
      workspaceSelection: CompositionWorkspaceSelection.sourceScene(
        sourceSceneId: scene.id,
      ),
      children: <CompositionWorkspaceOutlinerNode>[
        for (final layer in layers)
          _layerNode(
            workspace: workspace,
            scene: scene,
            layer: layer,
            channelsByTargetId: channelsByTargetId,
          ),
      ],
    );
  }

  CompositionWorkspaceOutlinerNode _layerNode({
    required CompositionWorkspaceModel workspace,
    required MotionSceneModel scene,
    required MotionLayerModel layer,
    required Map<String, List<MotionPropertyChannelModel>> channelsByTargetId,
  }) {
    return CompositionWorkspaceOutlinerNode(
      id: 'layer:${layer.id}',
      kind: CompositionWorkspaceOutlinerNodeKind.layer,
      label: _labelOrFallback(layer.name, _layerFallbackLabel(layer)),
      sourceSceneId: scene.id,
      layerId: layer.id,
      isSelected: _isLayerSelected(workspace.selection, scene.id, layer.id),
      isEnabled: layer.isEnabled,
      zIndex: layer.zIndex,
      workspaceSelection: CompositionWorkspaceSelection.layer(
        sourceSceneId: scene.id,
        layerId: layer.id,
        sceneClipId: workspace.selection.sceneClipId,
      ),
      children: <CompositionWorkspaceOutlinerNode>[
        for (final element in layer.elements)
          _elementNode(
            workspace: workspace,
            scene: scene,
            layer: layer,
            element: element,
            channelsByTargetId: channelsByTargetId,
          ),
        for (final channel in channelsByTargetId[layer.id] ??
            const <MotionPropertyChannelModel>[])
          _channelNode(
            workspace: workspace,
            sceneId: scene.id,
            layerId: layer.id,
            channel: channel,
          ),
      ],
    );
  }

  CompositionWorkspaceOutlinerNode _elementNode({
    required CompositionWorkspaceModel workspace,
    required MotionSceneModel scene,
    required MotionLayerModel layer,
    required MotionElementModel element,
    required Map<String, List<MotionPropertyChannelModel>> channelsByTargetId,
  }) {
    return CompositionWorkspaceOutlinerNode(
      id: 'element:${element.id}',
      kind: CompositionWorkspaceOutlinerNodeKind.element,
      label: _labelOrFallback(element.name, _elementFallbackLabel(element)),
      sourceSceneId: scene.id,
      layerId: layer.id,
      elementId: element.id,
      isSelected: _isElementSelected(workspace.selection, scene.id, element.id),
      isEnabled: element.isEnabled,
      workspaceSelection: CompositionWorkspaceSelection.element(
        sourceSceneId: scene.id,
        layerId: layer.id,
        elementId: element.id,
        sceneClipId: workspace.selection.sceneClipId,
      ),
      children: <CompositionWorkspaceOutlinerNode>[
        for (final channel in channelsByTargetId[element.id] ??
            const <MotionPropertyChannelModel>[])
          _channelNode(
            workspace: workspace,
            sceneId: scene.id,
            layerId: layer.id,
            elementId: element.id,
            channel: channel,
          ),
      ],
    );
  }

  CompositionWorkspaceOutlinerNode _channelNode({
    required CompositionWorkspaceModel workspace,
    required String sceneId,
    required String layerId,
    String? elementId,
    required MotionPropertyChannelModel channel,
  }) {
    return CompositionWorkspaceOutlinerNode(
      id: 'channel:${channel.id}',
      kind: CompositionWorkspaceOutlinerNodeKind.channel,
      label: _channelLabelFor(channel),
      sourceSceneId: sceneId,
      layerId: layerId,
      elementId: elementId,
      channelId: channel.id,
      isSelected: _isChannelSelected(workspace.selection, channel.id),
    );
  }

  Map<String, List<MotionPropertyChannelModel>> _channelsByTargetId(
    List<MotionPropertyChannelModel> channels,
  ) {
    final grouped = <String, List<MotionPropertyChannelModel>>{};
    for (final channel in channels) {
      (grouped[channel.target.targetId] ??= <MotionPropertyChannelModel>[])
          .add(channel);
    }
    for (final entry in grouped.entries) {
      entry.value.sort((left, right) {
        final propertyCompare = left.definition.id.compareTo(
          right.definition.id,
        );
        if (propertyCompare != 0) {
          return propertyCompare;
        }
        return left.id.compareTo(right.id);
      });
    }
    return grouped;
  }

  String _labelOrFallback(String? label, String fallback) {
    final trimmed = label?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }
    return fallback;
  }

  String _layerFallbackLabel(MotionLayerModel layer) {
    return switch (layer.kind) {
      MotionLayerKind.video => 'Video Layer',
      MotionLayerKind.image => 'Image Layer',
      MotionLayerKind.text => 'Text Layer',
      MotionLayerKind.shape => 'Shape Layer',
      MotionLayerKind.audio => 'Audio Layer',
      MotionLayerKind.camera => 'Camera Layer',
      MotionLayerKind.effectControl => 'Control Layer',
    };
  }

  String _elementFallbackLabel(MotionElementModel element) {
    return switch (element.kind) {
      MotionElementKind.videoClip => 'Video',
      MotionElementKind.image => 'Image',
      MotionElementKind.text => 'Text',
      MotionElementKind.shape => element.shapeKind?.name ?? 'Shape',
      MotionElementKind.audioClip => 'Audio',
      MotionElementKind.camera => 'Camera',
      MotionElementKind.mask => 'Mask',
      MotionElementKind.effectControl => 'Control',
    };
  }

  String _channelLabelFor(MotionPropertyChannelModel channel) {
    return channel.definition.path.canonicalKey;
  }

  bool _isSceneClipSelected(
    CompositionWorkspaceSelection selection,
    String sceneClipId,
  ) {
    return selection.kind == CompositionWorkspaceSelectionKind.sceneClip &&
        selection.sceneClipId == sceneClipId;
  }

  bool _isSourceSceneSelected(
    CompositionWorkspaceSelection selection,
    String sourceSceneId,
  ) {
    return selection.kind == CompositionWorkspaceSelectionKind.sourceScene &&
        selection.sourceSceneId == sourceSceneId;
  }

  bool _isLayerSelected(
    CompositionWorkspaceSelection selection,
    String sourceSceneId,
    String layerId,
  ) {
    return selection.kind == CompositionWorkspaceSelectionKind.layer &&
        selection.sourceSceneId == sourceSceneId &&
        selection.layerId == layerId;
  }

  bool _isElementSelected(
    CompositionWorkspaceSelection selection,
    String sourceSceneId,
    String elementId,
  ) {
    return selection.kind == CompositionWorkspaceSelectionKind.element &&
        selection.sourceSceneId == sourceSceneId &&
        selection.elementId == elementId;
  }

  bool _isChannelSelected(
    CompositionWorkspaceSelection selection,
    String channelId,
  ) {
    return selection.channelId == channelId;
  }
}
