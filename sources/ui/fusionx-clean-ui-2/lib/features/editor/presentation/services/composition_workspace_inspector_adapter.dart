import '../../domain/models/composition_workspace_models.dart';
import '../../domain/models/professional_motion_animation_models.dart';
import '../../domain/models/professional_motion_models.dart';

enum CompositionWorkspaceInspectorTargetKind {
  rootComposition,
  sceneClipInstance,
  sourceComposition,
  layer,
  element,
  keyframe,
}

enum CompositionWorkspaceInspectorSectionKind {
  format,
  timing,
  source,
  transform,
  style,
  effects,
  drawOrder,
  metadata,
  graph,
}

enum CompositionWorkspaceInspectorPropertyKind {
  stringValue,
  number,
  integer,
  boolean,
  colorArgb,
  timeMs,
  enumValue,
}

enum CompositionWorkspaceInspectorIssueCode {
  missingSceneClip,
  missingSourceScene,
  missingLayer,
  missingElement,
  missingChannel,
  missingKeyframe,
}

class CompositionWorkspaceInspectorProperty {
  const CompositionWorkspaceInspectorProperty({
    required this.id,
    required this.label,
    required this.kind,
    required this.value,
    this.isEditable = false,
    this.unit,
  });

  final String id;
  final String label;
  final CompositionWorkspaceInspectorPropertyKind kind;
  final Object? value;
  final bool isEditable;
  final String? unit;
}

class CompositionWorkspaceInspectorSection {
  CompositionWorkspaceInspectorSection({
    required this.id,
    required this.label,
    required this.kind,
    List<CompositionWorkspaceInspectorProperty> properties =
        const <CompositionWorkspaceInspectorProperty>[],
  }) : properties = List.unmodifiable(properties);

  final String id;
  final String label;
  final CompositionWorkspaceInspectorSectionKind kind;
  final List<CompositionWorkspaceInspectorProperty> properties;

  CompositionWorkspaceInspectorProperty? propertyById(String propertyId) {
    for (final property in properties) {
      if (property.id == propertyId) {
        return property;
      }
    }
    return null;
  }
}

class CompositionWorkspaceInspectorModel {
  CompositionWorkspaceInspectorModel({
    required this.targetKind,
    required this.targetId,
    required this.title,
    required this.subtitle,
    List<CompositionWorkspaceInspectorSection> sections =
        const <CompositionWorkspaceInspectorSection>[],
  }) : sections = List.unmodifiable(sections);

  final CompositionWorkspaceInspectorTargetKind targetKind;
  final String targetId;
  final String title;
  final String subtitle;
  final List<CompositionWorkspaceInspectorSection> sections;

  bool get hasEditableProperties {
    return sections.any(
      (section) => section.properties.any((property) => property.isEditable),
    );
  }

  CompositionWorkspaceInspectorSection? sectionById(String sectionId) {
    for (final section in sections) {
      if (section.id == sectionId) {
        return section;
      }
    }
    return null;
  }

  CompositionWorkspaceInspectorProperty? propertyById(String propertyId) {
    for (final section in sections) {
      final property = section.propertyById(propertyId);
      if (property != null) {
        return property;
      }
    }
    return null;
  }
}

class CompositionWorkspaceInspectorIssue {
  const CompositionWorkspaceInspectorIssue({
    required this.code,
    required this.message,
    this.targetId,
  });

  final CompositionWorkspaceInspectorIssueCode code;
  final String message;
  final String? targetId;
}

class CompositionWorkspaceInspectorResult {
  CompositionWorkspaceInspectorResult({
    this.model,
    List<CompositionWorkspaceInspectorIssue> issues =
        const <CompositionWorkspaceInspectorIssue>[],
  }) : issues = List.unmodifiable(issues);

  final CompositionWorkspaceInspectorModel? model;
  final List<CompositionWorkspaceInspectorIssue> issues;

  bool get hasModel => model != null;

  bool get hasIssues => issues.isNotEmpty;
}

class CompositionWorkspaceInspectorAdapter {
  const CompositionWorkspaceInspectorAdapter();

  CompositionWorkspaceInspectorResult inspect({
    required CompositionWorkspaceModel workspace,
    List<MotionPropertyChannelModel> channels =
        const <MotionPropertyChannelModel>[],
  }) {
    final selection = workspace.selection;
    switch (selection.kind) {
      case CompositionWorkspaceSelectionKind.none:
        return CompositionWorkspaceInspectorResult(
          model: _rootCompositionModel(workspace),
        );
      case CompositionWorkspaceSelectionKind.sceneClip:
        return _sceneClipModel(workspace, selection);
      case CompositionWorkspaceSelectionKind.sourceScene:
        return _sourceSceneModel(workspace, selection, channels);
      case CompositionWorkspaceSelectionKind.layer:
        return _layerModel(workspace, selection, channels);
      case CompositionWorkspaceSelectionKind.element:
        return _elementModel(workspace, selection, channels);
      case CompositionWorkspaceSelectionKind.keyframe:
        return _keyframeModel(workspace, selection, channels);
    }
  }

  CompositionWorkspaceInspectorModel _rootCompositionModel(
    CompositionWorkspaceModel workspace,
  ) {
    final project = workspace.project;
    final canvasSize = project.format.canvasSize;
    return CompositionWorkspaceInspectorModel(
      targetKind: CompositionWorkspaceInspectorTargetKind.rootComposition,
      targetId: workspace.rootSceneId,
      title: _labelOrFallback(workspace.rootScene?.name, 'Root Composition'),
      subtitle: 'Project composition',
      sections: <CompositionWorkspaceInspectorSection>[
        CompositionWorkspaceInspectorSection(
          id: 'format',
          label: 'Format',
          kind: CompositionWorkspaceInspectorSectionKind.format,
          properties: <CompositionWorkspaceInspectorProperty>[
            _number(
              id: 'format.width',
              label: 'Width',
              value: canvasSize.width,
              unit: 'px',
              isEditable: true,
            ),
            _number(
              id: 'format.height',
              label: 'Height',
              value: canvasSize.height,
              unit: 'px',
              isEditable: true,
            ),
            _number(
              id: 'format.fps',
              label: 'Frame Rate',
              value: project.frameRate.framesPerSecond,
              unit: 'fps',
              isEditable: true,
            ),
            _time(
              id: 'timing.durationMs',
              label: 'Duration',
              valueMs: workspace.rootDurationTime.inMilliseconds,
              isEditable: true,
            ),
            _time(
              id: 'timing.currentRootMs',
              label: 'Current Time',
              valueMs: workspace.currentRootTime.inMilliseconds,
            ),
          ],
        ),
        CompositionWorkspaceInspectorSection(
          id: 'structure',
          label: 'Structure',
          kind: CompositionWorkspaceInspectorSectionKind.source,
          properties: <CompositionWorkspaceInspectorProperty>[
            _integer(
              id: 'structure.sceneClips',
              label: 'Scene Clips',
              value: workspace.sceneClips.length,
            ),
            _integer(
              id: 'structure.backgroundLayers',
              label: 'Background Layers',
              value: workspace.rootBackgroundLayers.length,
            ),
            _integer(
              id: 'structure.sourceCompositions',
              label: 'Source Compositions',
              value: workspace.sourceScenes.length,
            ),
          ],
        ),
      ],
    );
  }

  CompositionWorkspaceInspectorResult _sceneClipModel(
    CompositionWorkspaceModel workspace,
    CompositionWorkspaceSelection selection,
  ) {
    final sceneClipId = selection.sceneClipId;
    final clip =
        sceneClipId == null ? null : workspace.sceneClipById(sceneClipId);
    if (clip == null) {
      return _issueResult(
        code: CompositionWorkspaceInspectorIssueCode.missingSceneClip,
        message: 'Selected Scene Clip `$sceneClipId` was not found.',
        targetId: sceneClipId,
      );
    }

    final sourceScene = workspace.sourceSceneForClip(clip);
    final style = clip.instanceVisualStyle;
    final transform = style.transform;
    return CompositionWorkspaceInspectorResult(
      model: CompositionWorkspaceInspectorModel(
        targetKind: CompositionWorkspaceInspectorTargetKind.sceneClipInstance,
        targetId: clip.id,
        title: _labelOrFallback(clip.name, 'Scene Clip'),
        subtitle:
            'Instance of ${_labelOrFallback(sourceScene?.name, clip.sourceSceneId)}',
        sections: <CompositionWorkspaceInspectorSection>[
          CompositionWorkspaceInspectorSection(
            id: 'timing',
            label: 'Timing',
            kind: CompositionWorkspaceInspectorSectionKind.timing,
            properties: <CompositionWorkspaceInspectorProperty>[
              _time(
                id: 'timing.startMs',
                label: 'Start',
                valueMs: clip.startTime.inMilliseconds,
                isEditable: true,
              ),
              _time(
                id: 'timing.durationMs',
                label: 'Duration',
                valueMs: clip.durationTime.inMilliseconds,
                isEditable: true,
              ),
              _time(
                id: 'timing.sourceInMs',
                label: 'Source In',
                valueMs: clip.sourceInTime.inMilliseconds,
                isEditable: true,
              ),
              _time(
                id: 'timing.sourceOutMs',
                label: 'Source Out',
                valueMs: clip.sourceOutTime.inMilliseconds,
                isEditable: true,
              ),
              _number(
                id: 'timing.timeScale',
                label: 'Time Scale',
                value: clip.timeScale,
                isEditable: true,
              ),
            ],
          ),
          CompositionWorkspaceInspectorSection(
            id: 'source',
            label: 'Source',
            kind: CompositionWorkspaceInspectorSectionKind.source,
            properties: <CompositionWorkspaceInspectorProperty>[
              _string(
                id: 'source.sceneId',
                label: 'Source Composition',
                value: clip.sourceSceneId,
              ),
              _integer(
                id: 'source.layerCount',
                label: 'Source Layers',
                value: sourceScene?.layers.length ?? 0,
              ),
            ],
          ),
          CompositionWorkspaceInspectorSection(
            id: 'transform',
            label: 'Transform',
            kind: CompositionWorkspaceInspectorSectionKind.transform,
            properties: <CompositionWorkspaceInspectorProperty>[
              _number(
                id: 'transform.positionX',
                label: 'Position X',
                value: transform.positionX,
                unit: 'px',
                isEditable: true,
              ),
              _number(
                id: 'transform.positionY',
                label: 'Position Y',
                value: transform.positionY,
                unit: 'px',
                isEditable: true,
              ),
              _number(
                id: 'transform.scaleX',
                label: 'Scale X',
                value: transform.scaleX,
                isEditable: true,
              ),
              _number(
                id: 'transform.scaleY',
                label: 'Scale Y',
                value: transform.scaleY,
                isEditable: true,
              ),
              _number(
                id: 'transform.rotation',
                label: 'Rotation',
                value: transform.rotationDegrees,
                unit: 'deg',
                isEditable: true,
              ),
            ],
          ),
          _styleSection(
            opacity: style.opacity,
            isEnabled: clip.isEnabled,
            isLocked: clip.isLocked,
          ),
          CompositionWorkspaceInspectorSection(
            id: 'drawOrder',
            label: 'Draw Order',
            kind: CompositionWorkspaceInspectorSectionKind.drawOrder,
            properties: <CompositionWorkspaceInspectorProperty>[
              _integer(
                id: 'drawOrder.zIndex',
                label: 'Z Index',
                value: style.zIndex,
                isEditable: true,
              ),
            ],
          ),
          CompositionWorkspaceInspectorSection(
            id: 'effects',
            label: 'Effects',
            kind: CompositionWorkspaceInspectorSectionKind.effects,
            properties: <CompositionWorkspaceInspectorProperty>[
              _integer(
                id: 'effects.count',
                label: 'Effect Count',
                value: style.effectIds.length,
              ),
            ],
          ),
        ],
      ),
    );
  }

  CompositionWorkspaceInspectorResult _sourceSceneModel(
    CompositionWorkspaceModel workspace,
    CompositionWorkspaceSelection selection,
    List<MotionPropertyChannelModel> channels,
  ) {
    final sourceSceneId = selection.sourceSceneId;
    final scene =
        sourceSceneId == null ? null : workspace.sceneById(sourceSceneId);
    if (scene == null) {
      return _issueResult(
        code: CompositionWorkspaceInspectorIssueCode.missingSourceScene,
        message: 'Selected source composition `$sourceSceneId` was not found.',
        targetId: sourceSceneId,
      );
    }

    final sceneChannelCount =
        channels.where((channel) => channel.target.sceneId == scene.id).length;
    return CompositionWorkspaceInspectorResult(
      model: CompositionWorkspaceInspectorModel(
        targetKind: CompositionWorkspaceInspectorTargetKind.sourceComposition,
        targetId: scene.id,
        title: _labelOrFallback(scene.name, scene.id),
        subtitle: 'Source composition',
        sections: <CompositionWorkspaceInspectorSection>[
          CompositionWorkspaceInspectorSection(
            id: 'timing',
            label: 'Timing',
            kind: CompositionWorkspaceInspectorSectionKind.timing,
            properties: <CompositionWorkspaceInspectorProperty>[
              _time(
                id: 'timing.startMs',
                label: 'Start',
                valueMs: scene.projectRange.start.inMilliseconds,
                isEditable: true,
              ),
              _time(
                id: 'timing.durationMs',
                label: 'Duration',
                valueMs: scene.durationTime.inMilliseconds,
                isEditable: true,
              ),
            ],
          ),
          CompositionWorkspaceInspectorSection(
            id: 'structure',
            label: 'Structure',
            kind: CompositionWorkspaceInspectorSectionKind.source,
            properties: <CompositionWorkspaceInspectorProperty>[
              _integer(
                id: 'structure.layers',
                label: 'Layers',
                value: scene.layers.length,
              ),
              _integer(
                id: 'structure.channels',
                label: 'Channels',
                value: sceneChannelCount,
              ),
            ],
          ),
        ],
      ),
    );
  }

  CompositionWorkspaceInspectorResult _layerModel(
    CompositionWorkspaceModel workspace,
    CompositionWorkspaceSelection selection,
    List<MotionPropertyChannelModel> channels,
  ) {
    final sceneResult = _sceneAndLayerFor(workspace, selection);
    if (sceneResult.issue != null) {
      return CompositionWorkspaceInspectorResult(
          issues: <CompositionWorkspaceInspectorIssue>[
            sceneResult.issue!,
          ]);
    }
    final layer = sceneResult.layer!;
    final layerChannels = _channelsForTarget(channels, layer.id);
    return CompositionWorkspaceInspectorResult(
      model: CompositionWorkspaceInspectorModel(
        targetKind: CompositionWorkspaceInspectorTargetKind.layer,
        targetId: layer.id,
        title: _labelOrFallback(layer.name, _layerFallbackLabel(layer)),
        subtitle: '${layer.kind.name} layer',
        sections: <CompositionWorkspaceInspectorSection>[
          CompositionWorkspaceInspectorSection(
            id: 'timing',
            label: 'Timing',
            kind: CompositionWorkspaceInspectorSectionKind.timing,
            properties: <CompositionWorkspaceInspectorProperty>[
              _time(
                id: 'timing.startMs',
                label: 'Start',
                valueMs: layer.visibleRange.start.inMilliseconds,
                isEditable: true,
              ),
              _time(
                id: 'timing.durationMs',
                label: 'Duration',
                valueMs: layer.visibleRange.duration.inMilliseconds,
                isEditable: true,
              ),
            ],
          ),
          _styleSection(
            opacity: _opacityFromAssignments(layer.properties),
            isEnabled: layer.isEnabled,
            blendMode: layer.blendMode.name,
          ),
          CompositionWorkspaceInspectorSection(
            id: 'drawOrder',
            label: 'Draw Order',
            kind: CompositionWorkspaceInspectorSectionKind.drawOrder,
            properties: <CompositionWorkspaceInspectorProperty>[
              _integer(
                id: 'drawOrder.zIndex',
                label: 'Z Index',
                value: layer.zIndex,
                isEditable: true,
              ),
            ],
          ),
          CompositionWorkspaceInspectorSection(
            id: 'graph',
            label: 'Graph',
            kind: CompositionWorkspaceInspectorSectionKind.graph,
            properties: <CompositionWorkspaceInspectorProperty>[
              _integer(
                id: 'graph.elements',
                label: 'Elements',
                value: layer.elements.length,
              ),
              _integer(
                id: 'graph.channels',
                label: 'Channels',
                value: layerChannels.length,
              ),
            ],
          ),
        ],
      ),
    );
  }

  CompositionWorkspaceInspectorResult _elementModel(
    CompositionWorkspaceModel workspace,
    CompositionWorkspaceSelection selection,
    List<MotionPropertyChannelModel> channels,
  ) {
    final elementResult = _sceneLayerAndElementFor(workspace, selection);
    if (elementResult.issue != null) {
      return CompositionWorkspaceInspectorResult(
          issues: <CompositionWorkspaceInspectorIssue>[
            elementResult.issue!,
          ]);
    }
    final element = elementResult.element!;
    final elementChannels = _channelsForTarget(channels, element.id);
    return CompositionWorkspaceInspectorResult(
      model: CompositionWorkspaceInspectorModel(
        targetKind: CompositionWorkspaceInspectorTargetKind.element,
        targetId: element.id,
        title: _labelOrFallback(element.name, _elementFallbackLabel(element)),
        subtitle: '${element.kind.name} element',
        sections: <CompositionWorkspaceInspectorSection>[
          CompositionWorkspaceInspectorSection(
            id: 'timing',
            label: 'Timing',
            kind: CompositionWorkspaceInspectorSectionKind.timing,
            properties: <CompositionWorkspaceInspectorProperty>[
              _time(
                id: 'timing.startMs',
                label: 'Start',
                valueMs: element.localRange.start.inMilliseconds,
                isEditable: true,
              ),
              _time(
                id: 'timing.durationMs',
                label: 'Duration',
                valueMs: element.localRange.duration.inMilliseconds,
                isEditable: true,
              ),
            ],
          ),
          CompositionWorkspaceInspectorSection(
            id: 'source',
            label: 'Source',
            kind: CompositionWorkspaceInspectorSectionKind.source,
            properties: <CompositionWorkspaceInspectorProperty>[
              _enum(
                id: 'source.kind',
                label: 'Kind',
                value: element.kind.name,
              ),
              _enum(
                id: 'source.shapeKind',
                label: 'Shape',
                value: element.shapeKind?.name,
              ),
              _string(
                id: 'source.assetId',
                label: 'Asset',
                value: element.sourceBinding?.assetId,
              ),
            ],
          ),
          _styleSection(
            opacity: _opacityFromAssignments(element.properties),
            isEnabled: element.isEnabled,
          ),
          CompositionWorkspaceInspectorSection(
            id: 'graph',
            label: 'Graph',
            kind: CompositionWorkspaceInspectorSectionKind.graph,
            properties: <CompositionWorkspaceInspectorProperty>[
              _integer(
                id: 'graph.channels',
                label: 'Channels',
                value: elementChannels.length,
              ),
              _integer(
                id: 'graph.properties',
                label: 'Static Properties',
                value: element.properties.length,
              ),
            ],
          ),
        ],
      ),
    );
  }

  CompositionWorkspaceInspectorResult _keyframeModel(
    CompositionWorkspaceModel workspace,
    CompositionWorkspaceSelection selection,
    List<MotionPropertyChannelModel> channels,
  ) {
    final elementResult = _sceneLayerAndElementFor(workspace, selection);
    if (elementResult.issue != null) {
      return CompositionWorkspaceInspectorResult(
          issues: <CompositionWorkspaceInspectorIssue>[
            elementResult.issue!,
          ]);
    }
    final channel = _channelById(channels, selection.channelId);
    if (channel == null) {
      return _issueResult(
        code: CompositionWorkspaceInspectorIssueCode.missingChannel,
        message: 'Selected channel `${selection.channelId}` was not found.',
        targetId: selection.channelId,
      );
    }
    final keyframe = _keyframeById(channel, selection.keyframeId);
    if (keyframe == null) {
      return _issueResult(
        code: CompositionWorkspaceInspectorIssueCode.missingKeyframe,
        message:
            'Selected keyframe `${selection.keyframeId}` was not found in channel `${channel.id}`.',
        targetId: selection.keyframeId,
      );
    }

    return CompositionWorkspaceInspectorResult(
      model: CompositionWorkspaceInspectorModel(
        targetKind: CompositionWorkspaceInspectorTargetKind.keyframe,
        targetId: keyframe.id,
        title: 'Keyframe',
        subtitle: channel.definition.path.canonicalKey,
        sections: <CompositionWorkspaceInspectorSection>[
          CompositionWorkspaceInspectorSection(
            id: 'timing',
            label: 'Timing',
            kind: CompositionWorkspaceInspectorSectionKind.timing,
            properties: <CompositionWorkspaceInspectorProperty>[
              _time(
                id: 'timing.timeMs',
                label: 'Time',
                valueMs: keyframe.time.inMilliseconds,
                isEditable: true,
              ),
            ],
          ),
          CompositionWorkspaceInspectorSection(
            id: 'graph',
            label: 'Graph',
            kind: CompositionWorkspaceInspectorSectionKind.graph,
            properties: <CompositionWorkspaceInspectorProperty>[
              _string(
                id: 'graph.channelId',
                label: 'Channel',
                value: channel.id,
              ),
              _string(
                id: 'graph.property',
                label: 'Property',
                value: channel.definition.path.canonicalKey,
              ),
              CompositionWorkspaceInspectorProperty(
                id: 'graph.value',
                label: 'Value',
                kind: _propertyKindForValue(keyframe.value),
                value: _displayValueFor(keyframe.value),
                isEditable: true,
              ),
              _enum(
                id: 'graph.interpolation',
                label: 'Interpolation',
                value: keyframe.interpolationToNext.kind.name,
                isEditable: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  CompositionWorkspaceInspectorSection _styleSection({
    double? opacity,
    required bool isEnabled,
    bool? isLocked,
    String? blendMode,
  }) {
    return CompositionWorkspaceInspectorSection(
      id: 'style',
      label: 'Style',
      kind: CompositionWorkspaceInspectorSectionKind.style,
      properties: <CompositionWorkspaceInspectorProperty>[
        _boolean(
          id: 'style.enabled',
          label: 'Enabled',
          value: isEnabled,
          isEditable: true,
        ),
        if (isLocked != null)
          _boolean(
            id: 'style.locked',
            label: 'Locked',
            value: isLocked,
            isEditable: true,
          ),
        if (opacity != null)
          _number(
            id: 'style.opacity',
            label: 'Opacity',
            value: opacity,
            isEditable: true,
          ),
        if (blendMode != null)
          _enum(
            id: 'style.blendMode',
            label: 'Blend Mode',
            value: blendMode,
            isEditable: true,
          ),
      ],
    );
  }

  _SceneLayerResult _sceneAndLayerFor(
    CompositionWorkspaceModel workspace,
    CompositionWorkspaceSelection selection,
  ) {
    final sourceSceneId = selection.sourceSceneId;
    final scene =
        sourceSceneId == null ? null : workspace.sceneById(sourceSceneId);
    if (scene == null) {
      return _SceneLayerResult(
        issue: CompositionWorkspaceInspectorIssue(
          code: CompositionWorkspaceInspectorIssueCode.missingSourceScene,
          message:
              'Selected source composition `$sourceSceneId` was not found.',
          targetId: sourceSceneId,
        ),
      );
    }
    final layer = _layerById(scene, selection.layerId);
    if (layer == null) {
      return _SceneLayerResult(
        issue: CompositionWorkspaceInspectorIssue(
          code: CompositionWorkspaceInspectorIssueCode.missingLayer,
          message:
              'Selected layer `${selection.layerId}` was not found in source composition `$sourceSceneId`.',
          targetId: selection.layerId,
        ),
      );
    }
    return _SceneLayerResult(scene: scene, layer: layer);
  }

  _SceneLayerElementResult _sceneLayerAndElementFor(
    CompositionWorkspaceModel workspace,
    CompositionWorkspaceSelection selection,
  ) {
    final layerResult = _sceneAndLayerFor(workspace, selection);
    if (layerResult.issue != null) {
      return _SceneLayerElementResult(issue: layerResult.issue);
    }
    final element = _elementById(layerResult.layer!, selection.elementId);
    if (element == null) {
      return _SceneLayerElementResult(
        issue: CompositionWorkspaceInspectorIssue(
          code: CompositionWorkspaceInspectorIssueCode.missingElement,
          message:
              'Selected element `${selection.elementId}` was not found in layer `${selection.layerId}`.',
          targetId: selection.elementId,
        ),
      );
    }
    return _SceneLayerElementResult(
      scene: layerResult.scene,
      layer: layerResult.layer,
      element: element,
    );
  }

  MotionLayerModel? _layerById(MotionSceneModel scene, String? layerId) {
    if (layerId == null) {
      return null;
    }
    for (final layer in scene.layers) {
      if (layer.id == layerId) {
        return layer;
      }
    }
    return null;
  }

  MotionElementModel? _elementById(
    MotionLayerModel layer,
    String? elementId,
  ) {
    if (elementId == null) {
      return null;
    }
    for (final element in layer.elements) {
      if (element.id == elementId) {
        return element;
      }
    }
    return null;
  }

  MotionPropertyChannelModel? _channelById(
    List<MotionPropertyChannelModel> channels,
    String? channelId,
  ) {
    if (channelId == null) {
      return null;
    }
    for (final channel in channels) {
      if (channel.id == channelId) {
        return channel;
      }
    }
    return null;
  }

  MotionKeyframeModel? _keyframeById(
    MotionPropertyChannelModel channel,
    String? keyframeId,
  ) {
    if (keyframeId == null) {
      return null;
    }
    for (final keyframe in channel.keyframes) {
      if (keyframe.id == keyframeId) {
        return keyframe;
      }
    }
    return null;
  }

  List<MotionPropertyChannelModel> _channelsForTarget(
    List<MotionPropertyChannelModel> channels,
    String targetId,
  ) {
    return channels
        .where((channel) => channel.target.targetId == targetId)
        .toList(growable: false);
  }

  double? _opacityFromAssignments(List<MotionPropertyAssignment> assignments) {
    for (final assignment in assignments) {
      if (assignment.definition.id == MotionPropertyCatalog.opacity.id) {
        final value = assignment.value.rawValue;
        if (value is double) {
          return value;
        }
      }
    }
    return null;
  }

  CompositionWorkspaceInspectorResult _issueResult({
    required CompositionWorkspaceInspectorIssueCode code,
    required String message,
    String? targetId,
  }) {
    return CompositionWorkspaceInspectorResult(
      issues: <CompositionWorkspaceInspectorIssue>[
        CompositionWorkspaceInspectorIssue(
          code: code,
          message: message,
          targetId: targetId,
        ),
      ],
    );
  }

  CompositionWorkspaceInspectorProperty _string({
    required String id,
    required String label,
    required String? value,
    bool isEditable = false,
  }) {
    return CompositionWorkspaceInspectorProperty(
      id: id,
      label: label,
      kind: CompositionWorkspaceInspectorPropertyKind.stringValue,
      value: value,
      isEditable: isEditable,
    );
  }

  CompositionWorkspaceInspectorProperty _number({
    required String id,
    required String label,
    required double value,
    String? unit,
    bool isEditable = false,
  }) {
    return CompositionWorkspaceInspectorProperty(
      id: id,
      label: label,
      kind: CompositionWorkspaceInspectorPropertyKind.number,
      value: value,
      unit: unit,
      isEditable: isEditable,
    );
  }

  CompositionWorkspaceInspectorProperty _integer({
    required String id,
    required String label,
    required int value,
    bool isEditable = false,
  }) {
    return CompositionWorkspaceInspectorProperty(
      id: id,
      label: label,
      kind: CompositionWorkspaceInspectorPropertyKind.integer,
      value: value,
      isEditable: isEditable,
    );
  }

  CompositionWorkspaceInspectorProperty _boolean({
    required String id,
    required String label,
    required bool value,
    bool isEditable = false,
  }) {
    return CompositionWorkspaceInspectorProperty(
      id: id,
      label: label,
      kind: CompositionWorkspaceInspectorPropertyKind.boolean,
      value: value,
      isEditable: isEditable,
    );
  }

  CompositionWorkspaceInspectorProperty _time({
    required String id,
    required String label,
    required int valueMs,
    bool isEditable = false,
  }) {
    return CompositionWorkspaceInspectorProperty(
      id: id,
      label: label,
      kind: CompositionWorkspaceInspectorPropertyKind.timeMs,
      value: valueMs,
      unit: 'ms',
      isEditable: isEditable,
    );
  }

  CompositionWorkspaceInspectorProperty _enum({
    required String id,
    required String label,
    required String? value,
    bool isEditable = false,
  }) {
    return CompositionWorkspaceInspectorProperty(
      id: id,
      label: label,
      kind: CompositionWorkspaceInspectorPropertyKind.enumValue,
      value: value,
      isEditable: isEditable,
    );
  }

  CompositionWorkspaceInspectorPropertyKind _propertyKindForValue(
    MotionPropertyValue value,
  ) {
    return switch (value.kind) {
      MotionPropertyValueKind.scalar =>
        CompositionWorkspaceInspectorPropertyKind.number,
      MotionPropertyValueKind.integer =>
        CompositionWorkspaceInspectorPropertyKind.integer,
      MotionPropertyValueKind.boolean =>
        CompositionWorkspaceInspectorPropertyKind.boolean,
      MotionPropertyValueKind.colorArgb =>
        CompositionWorkspaceInspectorPropertyKind.colorArgb,
      MotionPropertyValueKind.enumValue =>
        CompositionWorkspaceInspectorPropertyKind.enumValue,
      MotionPropertyValueKind.stringValue ||
      MotionPropertyValueKind.point2D ||
      MotionPropertyValueKind.size2D ||
      MotionPropertyValueKind.rect =>
        CompositionWorkspaceInspectorPropertyKind.stringValue,
    };
  }

  Object? _displayValueFor(MotionPropertyValue value) {
    return switch (value.kind) {
      MotionPropertyValueKind.point2D => _pointLabel(value.rawValue),
      MotionPropertyValueKind.size2D => _sizeLabel(value.rawValue),
      MotionPropertyValueKind.rect => _rectLabel(value.rawValue),
      _ => value.rawValue,
    };
  }

  String _pointLabel(Object value) {
    if (value is MotionPoint2D) {
      return '${value.x}, ${value.y}';
    }
    return value.toString();
  }

  String _sizeLabel(Object value) {
    if (value is MotionSize2D) {
      return '${value.width} x ${value.height}';
    }
    return value.toString();
  }

  String _rectLabel(Object value) {
    if (value is MotionRect) {
      return '${value.left}, ${value.top}, ${value.width} x ${value.height}';
    }
    return value.toString();
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
}

class _SceneLayerResult {
  const _SceneLayerResult({
    this.scene,
    this.layer,
    this.issue,
  });

  final MotionSceneModel? scene;
  final MotionLayerModel? layer;
  final CompositionWorkspaceInspectorIssue? issue;
}

class _SceneLayerElementResult {
  const _SceneLayerElementResult({
    this.scene,
    this.layer,
    this.element,
    this.issue,
  });

  final MotionSceneModel? scene;
  final MotionLayerModel? layer;
  final MotionElementModel? element;
  final CompositionWorkspaceInspectorIssue? issue;
}
