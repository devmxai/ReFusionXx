import 'package:flutter/foundation.dart';

import '../../presentation/models/timeline_time.dart';
import 'professional_motion_models.dart';
import 'professional_motion_text_models.dart';

typedef MotionIdFactory = String Function(String prefix);

enum MotionTextInsertionIssueCode {
  missingScene,
  missingPreset,
  invalidRange,
  invalidLayer,
}

@immutable
class MotionTextInsertionIssue {
  const MotionTextInsertionIssue({
    required this.code,
    required this.message,
    this.sceneId,
    this.layerId,
    this.elementId,
  });

  final MotionTextInsertionIssueCode code;
  final String message;
  final String? sceneId;
  final String? layerId;
  final String? elementId;
}

@immutable
class MotionTextElementInsertionRequest {
  MotionTextElementInsertionRequest({
    required this.project,
    required this.sceneId,
    required this.projectRange,
    this.preferredLayerId,
    this.presetId,
    this.text,
    this.elementName,
    this.layerName,
    this.layerZIndex,
    this.createLayerIfMissing = true,
    Map<String, MotionPropertyValue> parameterValues =
        const <String, MotionPropertyValue>{},
    List<MotionTextAnimationBlock> animationBlocks =
        const <MotionTextAnimationBlock>[],
    List<MotionPropertyAssignment> elementProperties =
        const <MotionPropertyAssignment>[],
  }) : parameterValues = Map.unmodifiable(parameterValues),
       animationBlocks = List.unmodifiable(animationBlocks),
       elementProperties = List.unmodifiable(elementProperties);

  final MotionProjectModel project;
  final String sceneId;
  final TimelineTimeRange projectRange;
  final String? preferredLayerId;
  final String? presetId;
  final String? text;
  final String? elementName;
  final String? layerName;
  final int? layerZIndex;
  final bool createLayerIfMissing;
  final Map<String, MotionPropertyValue> parameterValues;
  final List<MotionTextAnimationBlock> animationBlocks;
  final List<MotionPropertyAssignment> elementProperties;
}

@immutable
class MotionTextElementInsertionResult {
  MotionTextElementInsertionResult({
    required this.didApply,
    required this.project,
    required this.sceneId,
    required List<MotionTextAnimationBindingModel> generatedBindings,
    required List<MotionTextInsertionIssue> issues,
    this.layerId,
    this.elementId,
    this.createdLayer = false,
  }) : generatedBindings = List.unmodifiable(generatedBindings),
       issues = List.unmodifiable(issues);

  final bool didApply;
  final MotionProjectModel project;
  final String sceneId;
  final String? layerId;
  final String? elementId;
  final bool createdLayer;
  final List<MotionTextAnimationBindingModel> generatedBindings;
  final List<MotionTextInsertionIssue> issues;
}

abstract class MotionTextElementAuthoringService {
  const MotionTextElementAuthoringService();

  MotionTextElementInsertionResult insertTextPreset(
    MotionTextElementInsertionRequest request,
  );
}

class BasicMotionTextElementAuthoringService
    implements MotionTextElementAuthoringService {
  BasicMotionTextElementAuthoringService({
    List<MotionTextPresetDefinition>? presetCatalog,
    MotionIdFactory? idFactory,
  }) : _presetCatalog = {
         for (final preset in presetCatalog ?? MotionBuiltInTextPresets.all)
           preset.id: preset,
       },
       _idFactory = idFactory ?? _defaultMotionIdFactory;

  final Map<String, MotionTextPresetDefinition> _presetCatalog;
  final MotionIdFactory _idFactory;

  @override
  MotionTextElementInsertionResult insertTextPreset(
    MotionTextElementInsertionRequest request,
  ) {
    final issues = <MotionTextInsertionIssue>[];
    final sceneIndex = request.project.scenes.indexWhere(
      (scene) => scene.id == request.sceneId,
    );
    if (sceneIndex < 0) {
      issues.add(
        MotionTextInsertionIssue(
          code: MotionTextInsertionIssueCode.missingScene,
          message: 'Text insertion target scene `${request.sceneId}` was not found.',
          sceneId: request.sceneId,
        ),
      );
      return MotionTextElementInsertionResult(
        didApply: false,
        project: request.project,
        sceneId: request.sceneId,
        generatedBindings: const <MotionTextAnimationBindingModel>[],
        issues: issues,
      );
    }

    final scene = request.project.scenes[sceneIndex];
    if (request.projectRange.start < scene.projectRange.start ||
        request.projectRange.endExclusive > scene.projectRange.endExclusive ||
        request.projectRange.start >= request.projectRange.endExclusive) {
      issues.add(
        MotionTextInsertionIssue(
          code: MotionTextInsertionIssueCode.invalidRange,
          message:
              'Text insertion range `${request.projectRange}` is outside scene `${scene.id}`.',
          sceneId: scene.id,
        ),
      );
      return MotionTextElementInsertionResult(
        didApply: false,
        project: request.project,
        sceneId: scene.id,
        generatedBindings: const <MotionTextAnimationBindingModel>[],
        issues: issues,
      );
    }

    final preset = request.presetId == null
        ? null
        : _presetCatalog[request.presetId!];
    if (request.presetId != null && preset == null) {
      issues.add(
        MotionTextInsertionIssue(
          code: MotionTextInsertionIssueCode.missingPreset,
          message: 'Text preset `${request.presetId}` was not found.',
          sceneId: scene.id,
        ),
      );
      return MotionTextElementInsertionResult(
        didApply: false,
        project: request.project,
        sceneId: scene.id,
        generatedBindings: const <MotionTextAnimationBindingModel>[],
        issues: issues,
      );
    }

    final resolvedLayerSelection = _resolveTextLayer(
      scene: scene,
      preferredLayerId: request.preferredLayerId,
      layerName: request.layerName,
      requestedZIndex: request.layerZIndex,
      createLayerIfMissing: request.createLayerIfMissing,
      issues: issues,
    );
    if (resolvedLayerSelection == null) {
      return MotionTextElementInsertionResult(
        didApply: false,
        project: request.project,
        sceneId: scene.id,
        generatedBindings: const <MotionTextAnimationBindingModel>[],
        issues: issues,
      );
    }

    final layer = resolvedLayerSelection.layer;
    final textValue = _resolveDisplayText(
      rawText: request.text,
      elementName: request.elementName,
      preset: preset,
    );
    final elementId = _idFactory('text-element');
    final sourceId = _idFactory('generated-text');
    final localRange = TimelineTimeRange(
      start: request.projectRange.start - scene.projectRange.start,
      endExclusive: request.projectRange.endExclusive - scene.projectRange.start,
    );
    final elementTarget = MotionPropertyTarget(
      kind: MotionTargetKind.element,
      targetId: elementId,
      projectId: request.project.id,
      sceneId: scene.id,
      layerId: layer.id,
      elementId: elementId,
    );

    final element = MotionElementModel(
      id: elementId,
      layerId: layer.id,
      kind: MotionElementKind.text,
      localRange: localRange,
      name: request.elementName ?? preset?.label ?? textValue,
      sourceBinding: MotionElementSourceBinding(
        kind: MotionSourceKind.generatedText,
        sourceId: sourceId,
        label: textValue,
        metadata: <String, String>{
          'text': textValue,
          if (request.presetId != null) 'presetId': request.presetId!,
          if (preset != null) 'presetLabel': preset.label,
        },
      ),
      properties: <MotionPropertyAssignment>[
        ...request.elementProperties,
      ],
    );

    final updatedLayer = layer.copyWith(
      visibleRange: _expandedLayerRange(layer.visibleRange, element.localRange),
      elements: <MotionElementModel>[
        ...layer.elements,
        element,
      ],
    );

    final updatedSceneLayers = scene.layers.map((candidateLayer) {
      if (candidateLayer.id == layer.id) {
        return updatedLayer;
      }
      return candidateLayer;
    }).toList(growable: false);

    final effectiveSceneLayers = resolvedLayerSelection.createdLayer
        ? <MotionLayerModel>[
            ...updatedSceneLayers,
            if (!updatedSceneLayers.any(
              (candidateLayer) => candidateLayer.id == updatedLayer.id,
            ))
              updatedLayer,
          ]
        : updatedSceneLayers;

    final updatedScene = scene.copyWith(layers: effectiveSceneLayers);
    final updatedScenes = List<MotionSceneModel>.from(request.project.scenes)
      ..[sceneIndex] = updatedScene;

    final binding = MotionTextAnimationBindingModel(
      id: _idFactory('text-binding'),
      elementTarget: elementTarget,
      activeRange: request.projectRange,
      presetId: request.presetId,
      animationBlocks: request.animationBlocks,
      parameterValues: request.parameterValues,
    );

    return MotionTextElementInsertionResult(
      didApply: true,
      project: request.project.copyWith(scenes: updatedScenes),
      sceneId: scene.id,
      layerId: updatedLayer.id,
      elementId: element.id,
      createdLayer: resolvedLayerSelection.createdLayer,
      generatedBindings: <MotionTextAnimationBindingModel>[binding],
      issues: issues,
    );
  }

  _ResolvedTextLayerSelection? _resolveTextLayer({
    required MotionSceneModel scene,
    required String? preferredLayerId,
    required String? layerName,
    required int? requestedZIndex,
    required bool createLayerIfMissing,
    required List<MotionTextInsertionIssue> issues,
  }) {
    if (preferredLayerId != null) {
      final preferredLayer = scene.layers.cast<MotionLayerModel?>().firstWhere(
        (layer) => layer?.id == preferredLayerId,
        orElse: () => null,
      );
      if (preferredLayer == null) {
        issues.add(
          MotionTextInsertionIssue(
            code: MotionTextInsertionIssueCode.invalidLayer,
            message:
                'Preferred text layer `$preferredLayerId` was not found in scene `${scene.id}`.',
            sceneId: scene.id,
            layerId: preferredLayerId,
          ),
        );
        return null;
      }
      if (preferredLayer.kind != MotionLayerKind.text) {
        issues.add(
          MotionTextInsertionIssue(
            code: MotionTextInsertionIssueCode.invalidLayer,
            message:
                'Preferred layer `$preferredLayerId` is not a text layer.',
            sceneId: scene.id,
            layerId: preferredLayerId,
          ),
        );
        return null;
      }
      return _ResolvedTextLayerSelection(
        layer: preferredLayer,
        createdLayer: false,
      );
    }

    for (final layer in scene.layers) {
      if (layer.kind == MotionLayerKind.text) {
        return _ResolvedTextLayerSelection(
          layer: layer,
          createdLayer: false,
        );
      }
    }

    if (!createLayerIfMissing) {
      issues.add(
        MotionTextInsertionIssue(
          code: MotionTextInsertionIssueCode.invalidLayer,
          message:
              'No text layer exists in scene `${scene.id}` and automatic creation is disabled.',
          sceneId: scene.id,
        ),
      );
      return null;
    }

    final nextZIndex = requestedZIndex ?? _nextLayerZIndex(scene.layers);
    return _ResolvedTextLayerSelection(
      createdLayer: true,
      layer: MotionLayerModel(
        id: _idFactory('text-layer'),
        sceneId: scene.id,
        kind: MotionLayerKind.text,
        visibleRange: TimelineTimeRange(
          start: TimelineTime.zero,
          endExclusive: scene.durationTime,
        ),
        elements: const <MotionElementModel>[],
        name: layerName ?? 'Text',
        zIndex: nextZIndex,
      ),
    );
  }

  String _resolveDisplayText({
    required String? rawText,
    required String? elementName,
    required MotionTextPresetDefinition? preset,
  }) {
    final trimmedText = rawText?.trim();
    if (trimmedText != null && trimmedText.isNotEmpty) {
      return trimmedText;
    }
    if (preset != null && preset.defaultText.trim().isNotEmpty) {
      return preset.defaultText.trim();
    }
    final trimmedName = elementName?.trim();
    if (trimmedName != null && trimmedName.isNotEmpty) {
      return trimmedName;
    }
    return 'Text';
  }

  TimelineTimeRange _expandedLayerRange(
    TimelineTimeRange original,
    TimelineTimeRange inserted,
  ) {
    final start = original.start <= inserted.start ? original.start : inserted.start;
    final end = original.endExclusive >= inserted.endExclusive
        ? original.endExclusive
        : inserted.endExclusive;
    return TimelineTimeRange(start: start, endExclusive: end);
  }

  int _nextLayerZIndex(List<MotionLayerModel> layers) {
    var maxZIndex = -1;
    for (final layer in layers) {
      if (layer.zIndex > maxZIndex) {
        maxZIndex = layer.zIndex;
      }
    }
    return maxZIndex + 1;
  }

  static String _defaultMotionIdFactory(String prefix) {
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}';
  }
}

@immutable
class _ResolvedTextLayerSelection {
  const _ResolvedTextLayerSelection({
    required this.layer,
    required this.createdLayer,
  });

  final MotionLayerModel layer;
  final bool createdLayer;
}
