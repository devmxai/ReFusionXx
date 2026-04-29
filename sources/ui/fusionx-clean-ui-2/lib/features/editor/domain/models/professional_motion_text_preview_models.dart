import 'package:flutter/foundation.dart';

import '../../presentation/models/timeline_time.dart';
import 'professional_motion_compilation_models.dart';
import 'professional_motion_evaluation_models.dart';
import 'professional_motion_models.dart';
import 'professional_motion_text_models.dart';

const int kMotionTextPreviewDefaultColorArgb = 0xFFF3F3F3;

@immutable
class MotionTextPreviewTransformState {
  const MotionTextPreviewTransformState({
    required this.positionX,
    required this.positionY,
    required this.scaleX,
    required this.scaleY,
    required this.rotationDegrees,
  });

  final double positionX;
  final double positionY;
  final double scaleX;
  final double scaleY;
  final double rotationDegrees;
}

@immutable
class MotionTextPreviewStyleState {
  const MotionTextPreviewStyleState({
    required this.opacity,
    required this.blurAmount,
    this.blurHorizontal = 100,
    this.blurVertical = 100,
    this.blurMix = 100,
    this.blurEdgeMode = 0,
    this.blurCrop = 0,
    required this.fontSize,
    required this.letterSpacing,
    required this.colorArgb,
  });

  final double opacity;
  final double blurAmount;
  final double blurHorizontal;
  final double blurVertical;
  final double blurMix;
  final double blurEdgeMode;
  final double blurCrop;
  final double fontSize;
  final double letterSpacing;
  final int colorArgb;
}

@immutable
class MotionTextPreviewNode {
  MotionTextPreviewNode({
    required this.id,
    required this.targetElementId,
    required this.sceneId,
    required this.layerId,
    required this.projectRange,
    required this.activationState,
    required this.fullText,
    required this.visibleText,
    required this.revealUnit,
    required this.revealDirection,
    required this.transform,
    required this.style,
    required List<MotionTextAnimationKind> animationKinds,
    this.name,
    this.presetId,
    this.textAnimationId,
    this.revealProgress,
    this.zIndex = 0,
    this.blendMode = MotionBlendMode.normal,
  }) : animationKinds = List.unmodifiable(animationKinds);

  final String id;
  final String targetElementId;
  final String sceneId;
  final String layerId;
  final TimelineTimeRange projectRange;
  final MotionActivationState activationState;
  final String fullText;
  final String visibleText;
  final MotionTextRevealUnit revealUnit;
  final MotionTextRevealDirection revealDirection;
  final MotionTextPreviewTransformState transform;
  final MotionTextPreviewStyleState style;
  final String? name;
  final String? presetId;
  final String? textAnimationId;
  final double? revealProgress;
  final int zIndex;
  final MotionBlendMode blendMode;
  final List<MotionTextAnimationKind> animationKinds;
}

@immutable
class MotionTextPreviewSnapshot {
  MotionTextPreviewSnapshot({
    required this.projectId,
    required this.time,
    required List<MotionTextPreviewNode> nodes,
    List<MotionEvaluationDiagnostic> diagnostics =
        const <MotionEvaluationDiagnostic>[],
  })  : nodes = List.unmodifiable(nodes),
        diagnostics = List.unmodifiable(diagnostics);

  final String projectId;
  final TimelineTime time;
  final List<MotionTextPreviewNode> nodes;
  final List<MotionEvaluationDiagnostic> diagnostics;
}

abstract class MotionTextPreviewBinder {
  const MotionTextPreviewBinder();

  MotionTextPreviewSnapshot bind({
    required MotionNormalizedComposition composition,
    required MotionEvaluationSnapshot evaluation,
  });
}

class BasicMotionTextPreviewBinder implements MotionTextPreviewBinder {
  BasicMotionTextPreviewBinder({
    List<MotionTextPresetDefinition>? presetCatalog,
  }) : _presetCatalog = {
          for (final preset in presetCatalog ?? MotionBuiltInTextPresets.all)
            preset.id: preset,
        };

  final Map<String, MotionTextPresetDefinition> _presetCatalog;

  @override
  MotionTextPreviewSnapshot bind({
    required MotionNormalizedComposition composition,
    required MotionEvaluationSnapshot evaluation,
  }) {
    final diagnostics = <MotionEvaluationDiagnostic>[];
    final nodes = <MotionTextPreviewNode>[];

    final resolvedElementsById = <String, MotionResolvedElementModel>{};
    for (final scene in composition.scenes) {
      for (final layer in scene.layers) {
        for (final element in layer.elements) {
          resolvedElementsById[element.id] = element;
        }
      }
    }

    final textAnimationsByElementId =
        <String, MotionEvaluatedTextAnimationState>{};
    for (final textAnimation in evaluation.textAnimations) {
      textAnimationsByElementId[textAnimation.targetElementId] = textAnimation;
    }

    for (final scene in evaluation.scenes) {
      for (final layer in scene.layers) {
        final layerOpacity = _scalarPropertyOrDefault(
          layer.properties,
          MotionPropertyCatalog.opacity,
        );

        for (final element in layer.elements) {
          if (element.kind != MotionElementKind.text) {
            continue;
          }

          final resolvedElement = resolvedElementsById[element.id];
          if (resolvedElement == null) {
            diagnostics.add(
              MotionEvaluationDiagnostic(
                code: 'text_preview.missing_resolved_element',
                message:
                    'Missing resolved element for text preview target `${element.id}`.',
                sceneId: scene.id,
                layerId: layer.id,
                elementId: element.id,
              ),
            );
            continue;
          }

          final textAnimation = textAnimationsByElementId[element.id];
          final revealProgress = textAnimation?.revealProgress ??
              _scalarPropertyOrDefault(
                element.properties,
                MotionPropertyCatalog.revealProgress,
              );
          final revealUnit =
              textAnimation?.revealUnit ?? MotionTextRevealUnit.wholeText;
          final fullText = _resolveFullText(
            element: element,
            resolvedElement: resolvedElement,
            textAnimation: textAnimation,
          );
          final visibleText = _resolveVisibleText(
            fullText: fullText,
            revealProgress: revealProgress,
            revealUnit: revealUnit,
            revealDirection: textAnimation?.revealDirection ??
                MotionTextRevealDirection.forward,
            animationKinds: textAnimation?.animationKinds ??
                const <MotionTextAnimationKind>[],
          );

          nodes.add(
            MotionTextPreviewNode(
              id: 'text-preview:${element.id}',
              targetElementId: element.id,
              sceneId: scene.id,
              layerId: layer.id,
              projectRange: element.projectRange,
              activationState: element.activationState,
              name: element.name,
              presetId: textAnimation?.presetId,
              textAnimationId: textAnimation?.id,
              fullText: fullText,
              visibleText: visibleText,
              revealProgress: revealProgress,
              revealUnit: revealUnit,
              revealDirection: textAnimation?.revealDirection ??
                  MotionTextRevealDirection.forward,
              zIndex: layer.zIndex,
              blendMode: layer.blendMode,
              animationKinds: textAnimation?.animationKinds ??
                  const <MotionTextAnimationKind>[],
              transform: MotionTextPreviewTransformState(
                positionX: _scalarPropertyOrDefault(
                  element.properties,
                  MotionPropertyCatalog.positionX,
                ),
                positionY: _scalarPropertyOrDefault(
                  element.properties,
                  MotionPropertyCatalog.positionY,
                ),
                scaleX: _scalarPropertyOrDefault(
                  element.properties,
                  MotionPropertyCatalog.scaleX,
                ),
                scaleY: _scalarPropertyOrDefault(
                  element.properties,
                  MotionPropertyCatalog.scaleY,
                ),
                rotationDegrees: _scalarPropertyOrDefault(
                  element.properties,
                  MotionPropertyCatalog.rotationDegrees,
                ),
              ),
              style: MotionTextPreviewStyleState(
                opacity: layerOpacity *
                    _scalarPropertyOrDefault(
                      element.properties,
                      MotionPropertyCatalog.opacity,
                    ),
                blurAmount: _scalarPropertyOrDefault(
                  element.properties,
                  MotionPropertyCatalog.blurAmount,
                ),
                blurHorizontal: _scalarPropertyOrDefault(
                  element.properties,
                  MotionPropertyCatalog.blurHorizontal,
                ),
                blurVertical: _scalarPropertyOrDefault(
                  element.properties,
                  MotionPropertyCatalog.blurVertical,
                ),
                blurMix: _scalarPropertyOrDefault(
                  element.properties,
                  MotionPropertyCatalog.blurMix,
                ),
                blurEdgeMode: _scalarPropertyOrDefault(
                  element.properties,
                  MotionPropertyCatalog.blurEdgeMode,
                ),
                blurCrop: _scalarPropertyOrDefault(
                  element.properties,
                  MotionPropertyCatalog.blurCrop,
                ),
                fontSize: _scalarPropertyOrDefault(
                  element.properties,
                  MotionPropertyCatalog.fontSize,
                ),
                letterSpacing: _scalarPropertyOrDefault(
                  element.properties,
                  MotionPropertyCatalog.letterSpacing,
                ),
                colorArgb: _colorPropertyOrDefault(element.properties),
              ),
            ),
          );
        }
      }
    }

    nodes.sort((left, right) {
      final zOrder = left.zIndex.compareTo(right.zIndex);
      if (zOrder != 0) {
        return zOrder;
      }
      return left.targetElementId.compareTo(right.targetElementId);
    });

    return MotionTextPreviewSnapshot(
      projectId: evaluation.projectId,
      time: evaluation.time,
      nodes: nodes,
      diagnostics: diagnostics,
    );
  }

  String _resolveFullText({
    required MotionEvaluatedElementState element,
    required MotionResolvedElementModel resolvedElement,
    required MotionEvaluatedTextAnimationState? textAnimation,
  }) {
    final sourceBinding = resolvedElement.sourceBinding;
    final metadata = sourceBinding?.metadata;
    final metadataText = metadata?['text'] ??
        metadata?['content'] ??
        metadata?['value'] ??
        metadata?['displayText'];
    if (metadataText != null && metadataText.isNotEmpty) {
      return metadataText;
    }
    if (sourceBinding?.label != null && sourceBinding!.label!.isNotEmpty) {
      return sourceBinding.label!;
    }
    final presetId = textAnimation?.presetId;
    final preset = presetId == null ? null : _presetCatalog[presetId];
    if (preset != null && preset.defaultText.isNotEmpty) {
      return preset.defaultText;
    }
    if (resolvedElement.name != null && resolvedElement.name!.isNotEmpty) {
      return resolvedElement.name!;
    }
    if (element.name != null && element.name!.isNotEmpty) {
      return element.name!;
    }
    return '';
  }

  String _resolveVisibleText({
    required String fullText,
    required double? revealProgress,
    required MotionTextRevealUnit revealUnit,
    required MotionTextRevealDirection revealDirection,
    required List<MotionTextAnimationKind> animationKinds,
  }) {
    if (fullText.isEmpty) {
      return fullText;
    }

    final hasRevealAnimation =
        animationKinds.contains(MotionTextAnimationKind.wordReveal) ||
            animationKinds.contains(MotionTextAnimationKind.letterReveal) ||
            animationKinds.contains(MotionTextAnimationKind.typewriter) ||
            (revealUnit != MotionTextRevealUnit.wholeText &&
                revealProgress != null);
    if (!hasRevealAnimation) {
      return fullText;
    }

    final normalized = (revealProgress ?? 1).clamp(0.0, 1.0);
    if (normalized <= 0) {
      return '';
    }
    if (normalized >= 1) {
      return fullText;
    }

    switch (revealUnit) {
      case MotionTextRevealUnit.wholeText:
        return fullText;
      case MotionTextRevealUnit.word:
        final words = fullText
            .split(RegExp(r'\s+'))
            .where((word) => word.isNotEmpty)
            .toList(growable: false);
        if (words.isEmpty) {
          return '';
        }
        final count = (words.length * normalized).ceil().clamp(0, words.length);
        final visible = revealDirection == MotionTextRevealDirection.reverse
            ? words.skip(words.length - count).toList(growable: false)
            : words.take(count).toList(growable: false);
        return visible.join(' ');
      case MotionTextRevealUnit.letter:
        final scalarRunes = fullText.runes.toList(growable: false);
        final count = (scalarRunes.length * normalized)
            .ceil()
            .clamp(0, scalarRunes.length);
        final visible = revealDirection == MotionTextRevealDirection.reverse
            ? scalarRunes
                .skip(scalarRunes.length - count)
                .toList(growable: false)
            : scalarRunes.take(count).toList(growable: false);
        return String.fromCharCodes(visible);
    }
  }

  double _scalarPropertyOrDefault(
    List<MotionEvaluatedPropertyValue> properties,
    MotionPropertyDefinition definition,
  ) {
    for (final property in properties) {
      if (property.definition.id != definition.id) {
        continue;
      }
      if (property.value.kind != MotionPropertyValueKind.scalar) {
        break;
      }
      return property.value.rawValue as double;
    }
    return definition.defaultValue.rawValue as double;
  }

  int _colorPropertyOrDefault(List<MotionEvaluatedPropertyValue> properties) {
    for (final property in properties) {
      if (property.definition.id != 'visual.color') {
        continue;
      }
      if (property.value.kind != MotionPropertyValueKind.colorArgb) {
        break;
      }
      return property.value.rawValue as int;
    }
    return kMotionTextPreviewDefaultColorArgb;
  }
}
