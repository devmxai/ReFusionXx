import 'dart:math' as math;

import '../../presentation/models/timeline_time.dart';
import '../models/professional_motion_animation_models.dart';
import '../models/professional_motion_compilation_models.dart';
import '../models/professional_motion_evaluation_models.dart';
import '../models/professional_motion_models.dart';
import '../models/professional_motion_runtime_helpers.dart';
import '../models/professional_motion_text_models.dart';
import '../models/refusion_scene_program_models.dart';
import 'scene_coordinate_system.dart';
import 'scene_evaluation_pipeline.dart';

class SceneRenderTruthAlignmentResult {
  SceneRenderTruthAlignmentResult({
    required List<ReFusionSceneProgramIssue> issues,
    required this.aligned,
    required this.mismatchCount,
  }) : issues = List.unmodifiable(issues);

  final List<ReFusionSceneProgramIssue> issues;
  final bool aligned;
  final int mismatchCount;
}

class SceneRenderTruthAlignmentValidator {
  SceneRenderTruthAlignmentValidator({
    this.tolerancePx = 1.0,
    this.enforceSizeAlignment = false,
    this.sizeTolerancePx = 2.0,
    this.mismatchSeverity = ReFusionSceneProgramIssueSeverity.warning,
    SceneEvaluationPipeline? evaluationPipeline,
    BasicMotionCompositionCompiler? compositionCompiler,
    BasicMotionRuntimeEvaluator? runtimeEvaluator,
  })  : _evaluationPipeline =
            evaluationPipeline ?? const SceneEvaluationPipeline(),
        _compositionCompiler =
            compositionCompiler ?? BasicMotionCompositionCompiler(),
        _runtimeEvaluator =
            runtimeEvaluator ?? const BasicMotionRuntimeEvaluator();

  static const String proofTag = 'TF_SCENE_RENDER_TRUTH_ALIGNMENT_PROOF';

  final double tolerancePx;
  final bool enforceSizeAlignment;
  final double sizeTolerancePx;
  final ReFusionSceneProgramIssueSeverity mismatchSeverity;
  final SceneEvaluationPipeline _evaluationPipeline;
  final BasicMotionCompositionCompiler _compositionCompiler;
  final BasicMotionRuntimeEvaluator _runtimeEvaluator;

  SceneRenderTruthAlignmentResult validate({
    required ReFusionSceneProgram program,
    required MotionProjectModel project,
    required List<MotionPropertyChannelModel> channels,
    required List<MotionTextAnimationBindingModel> textAnimationBindings,
  }) {
    final issues = <ReFusionSceneProgramIssue>[];
    final programElementsById = <String, ReFusionSceneProgramElement>{
      for (final layer in program.layers)
        for (final element in layer.elements) element.id: element,
    };
    final probeTimes = _trimProbeTimes(
      _collectProgramProbeTimes(program),
      maxCount: 5,
    );
    if (probeTimes.isEmpty) {
      return SceneRenderTruthAlignmentResult(
        issues: issues,
        aligned: true,
        mismatchCount: 0,
      );
    }

    final compile = _compositionCompiler.compile(
      MotionCompileRequest(
        project: project,
        propertyChannels: channels,
        textAnimationBindings: textAnimationBindings,
      ),
    );
    final compileErrors = compile.issues
        .where((issue) => issue.severity == MotionCompileIssueSeverity.error)
        .toList(growable: false);
    if (compileErrors.isNotEmpty) {
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message:
              '$proofTag compileErrors=${compileErrors.length} fallbackReason=composition_compile_failed',
          path: 'scene.renderTruthAlignment',
        ),
      );
      return SceneRenderTruthAlignmentResult(
        issues: issues,
        aligned: false,
        mismatchCount: compileErrors.length,
      );
    }
    final composition = compile.composition;
    if (composition == null) {
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message:
              '$proofTag compileErrors=1 fallbackReason=missing_composition',
          path: 'scene.renderTruthAlignment',
        ),
      );
      return SceneRenderTruthAlignmentResult(
        issues: issues,
        aligned: false,
        mismatchCount: 1,
      );
    }

    var mismatchCount = 0;
    final canvas = SceneCanvasMetrics(
      width: project.format.canvasSize.width,
      height: project.format.canvasSize.height,
    );
    for (final probeTime in probeTimes) {
      final qaEvaluation = _evaluationPipeline.evaluate(
        SceneEvaluationPipelineRequest(
          program: program,
          globalTimeMs: probeTime,
          canvas: canvas,
        ),
      );
      issues.addAll(qaEvaluation.issues.where(
        (issue) => issue.severity == ReFusionSceneProgramIssueSeverity.error,
      ));

      final previewSnapshot = _runtimeEvaluator.evaluate(
        MotionEvaluationRequest(
          composition: composition,
          time: TimelineTime.fromMilliseconds(probeTime),
          includeInactiveScenes: false,
          includeInactiveLayers: false,
          includeInactiveElements: false,
        ),
      );
      final previewBoundsByElementId = _previewBoundsByElementId(
        snapshot: previewSnapshot,
        canvas: canvas,
        sourceElementsById: programElementsById,
      );

      for (final node in qaEvaluation.truth.nodesById.values) {
        if (!node.active) {
          continue;
        }
        final elementId = node.sourceElementId;
        if (elementId == null || elementId.isEmpty) {
          continue;
        }
        final previewBounds = previewBoundsByElementId[elementId];
        final qaBounds = node.viewportBounds;
        if (previewBounds == null) {
          mismatchCount += 1;
          issues.add(
            ReFusionSceneProgramIssue(
              severity: mismatchSeverity,
              message: '$proofTag '
                  'sceneId=${program.name} '
                  'globalTimeMs=$probeTime '
                  'nodeId=${node.nodeId} '
                  'targetId=$elementId '
                  'propertyPath=element.viewportBounds '
                  'channelId=none '
                  'keyframeId=none '
                  'segmentId=none '
                  'qaViewportBounds=${_rectText(qaBounds)} '
                  'previewViewportBounds=missing '
                  'boundsDeltaPx=9999.0 '
                  'matched=false '
                  'fallbackReason=preview_element_missing',
              path: 'scene.renderTruthAlignment.$elementId',
            ),
          );
          continue;
        }
        final centerDelta = _centerDeltaPx(qaBounds, previewBounds);
        final sizeDelta = _sizeDeltaPx(qaBounds, previewBounds);
        final sizeMatched = sizeDelta <= sizeTolerancePx;
        final matched = centerDelta <= tolerancePx &&
            (!enforceSizeAlignment || sizeMatched);
        if (!matched) {
          mismatchCount += 1;
        }
        issues.add(
          ReFusionSceneProgramIssue(
            severity: matched
                ? ReFusionSceneProgramIssueSeverity.info
                : mismatchSeverity,
            message: '$proofTag '
                'sceneId=${program.name} '
                'globalTimeMs=$probeTime '
                'nodeId=${node.nodeId} '
                'targetId=$elementId '
                'propertyPath=element.viewportBounds '
                'channelId=none '
                'keyframeId=none '
                'segmentId=none '
                'qaViewportBounds=${_rectText(qaBounds)} '
                'previewViewportBounds=${_rectText(previewBounds)} '
                'centerDeltaPx=${centerDelta.toStringAsFixed(2)} '
                'sizeDeltaPx=${sizeDelta.toStringAsFixed(2)} '
                'sizeMatched=${sizeMatched.toString()} '
                'matched=${matched.toString()} '
                'fallbackReason=${matched ? 'none' : 'delta_exceeded'}',
            path: 'scene.renderTruthAlignment.$elementId',
          ),
        );
      }
    }

    return SceneRenderTruthAlignmentResult(
      issues: issues,
      aligned: mismatchCount == 0,
      mismatchCount: mismatchCount,
    );
  }

  Map<String, SceneViewportRect> _previewBoundsByElementId({
    required MotionEvaluationSnapshot snapshot,
    required SceneCanvasMetrics canvas,
    required Map<String, ReFusionSceneProgramElement> sourceElementsById,
  }) {
    final output = <String, SceneViewportRect>{};
    for (final scene in snapshot.scenes) {
      if (scene.activationState != MotionActivationState.active) {
        continue;
      }
      for (final layer in scene.layers) {
        if (layer.activationState != MotionActivationState.active) {
          continue;
        }
        for (final element in layer.elements) {
          if (element.activationState != MotionActivationState.active) {
            continue;
          }
          final properties = <String, MotionPropertyValue>{
            for (final property in element.properties)
              property.definition.id: property.value,
          };
          final x =
              _scalar(properties, MotionPropertyCatalog.positionX.id, 0.0);
          final y =
              _scalar(properties, MotionPropertyCatalog.positionY.id, 0.0);
          final width = _scalar(
            properties,
            MotionPropertyCatalog.width.id,
            _fallbackWidthForElement(
              runtimeElement: element,
              sourceElement: sourceElementsById[element.sourceElementId],
              properties: properties,
            ),
          );
          final height = _scalar(
            properties,
            MotionPropertyCatalog.height.id,
            _fallbackHeightForElement(
              runtimeElement: element,
              sourceElement: sourceElementsById[element.sourceElementId],
              properties: properties,
            ),
          );
          final scaleX =
              _scalar(properties, MotionPropertyCatalog.scaleX.id, 1.0);
          final scaleY =
              _scalar(properties, MotionPropertyCatalog.scaleY.id, 1.0);
          final scaledWidth = math.max(1.0, width * scaleX.abs());
          final scaledHeight = math.max(1.0, height * scaleY.abs());
          final center = SceneCoordinateSystem.centerToViewportPoint(
            point: ScenePoint(x: x, y: y),
            canvas: canvas,
          );
          output[element.sourceElementId] = SceneViewportRect(
            left: center.left - (scaledWidth / 2.0),
            top: center.top - (scaledHeight / 2.0),
            width: scaledWidth,
            height: scaledHeight,
          );
        }
      }
    }
    return output;
  }

  List<int> _collectProgramProbeTimes(ReFusionSceneProgram program) {
    final lastFrameProbe = math.max(0, program.durationMs - 1);
    final probes = <int>{0, lastFrameProbe};

    void absorbChannel(ReFusionSceneProgramChannel channel) {
      final sorted = channel.keyframes.toList(growable: false)
        ..sort((left, right) => left.timeMs.compareTo(right.timeMs));
      for (var index = 0; index < sorted.length; index += 1) {
        probes.add(_clampProbeTime(sorted[index].timeMs, program.durationMs));
        if (index > 0) {
          final previous = sorted[index - 1].timeMs;
          final current = sorted[index].timeMs;
          probes.add(
            _clampProbeTime(
              ((previous + current) / 2).round(),
              program.durationMs,
            ),
          );
        }
      }
    }

    for (final layer in program.layers) {
      probes.add(_clampProbeTime(layer.startMs, program.durationMs));
      probes.add(
        _clampProbeTime(
          math.max(layer.startMs, (layer.startMs + layer.durationMs) - 1),
          program.durationMs,
        ),
      );
      for (final channel in layer.channels) {
        absorbChannel(channel);
      }
      for (final element in layer.elements) {
        for (final channel in element.channels) {
          absorbChannel(channel);
        }
      }
    }
    final sorted = probes.toList(growable: false)..sort();
    return sorted;
  }

  int _clampProbeTime(int value, int durationMs) {
    final maxProbe = math.max(0, durationMs - 1);
    return value.clamp(0, maxProbe);
  }

  List<int> _trimProbeTimes(List<int> values, {required int maxCount}) {
    if (values.length <= maxCount) {
      return values;
    }
    final selected = <int>{values.first, values.last};
    if (values.length > 2) {
      selected.add(values[(values.length / 2).floor()]);
    }
    var index = 1;
    while (selected.length < maxCount && index < values.length - 1) {
      selected.add(values[index]);
      if (selected.length >= maxCount) {
        break;
      }
      selected.add(values[values.length - 1 - index]);
      index += 1;
    }
    final sorted = selected.toList(growable: false)..sort();
    return sorted.take(maxCount).toList(growable: false);
  }

  double _scalar(
    Map<String, MotionPropertyValue> values,
    String id,
    double fallback,
  ) {
    final value = values[id];
    if (value == null || value.kind != MotionPropertyValueKind.scalar) {
      return fallback;
    }
    final raw = value.rawValue;
    if (raw is! num) {
      return fallback;
    }
    return raw.toDouble();
  }

  double _fallbackWidthForElement({
    required MotionEvaluatedElementState runtimeElement,
    required ReFusionSceneProgramElement? sourceElement,
    required Map<String, MotionPropertyValue> properties,
  }) {
    if (runtimeElement.kind != MotionElementKind.text ||
        sourceElement == null) {
      return 180.0;
    }
    final fontSize = _scalar(
      properties,
      MotionPropertyCatalog.fontSize.id,
      16.0,
    );
    final letterSpacing = _scalar(
      properties,
      MotionPropertyCatalog.letterSpacing.id,
      0.0,
    );
    final reveal = _scalar(
      properties,
      MotionPropertyCatalog.revealProgress.id,
      1.0,
    ).clamp(0.0, 1.0);
    final text = (sourceElement.text ?? '').trim();
    if (text.isEmpty) {
      return 120.0;
    }
    final visibleCount = (text.runes.length * reveal).ceil();
    final glyphWidth = fontSize * 0.56;
    final spacing = math.max(0, visibleCount - 1) * letterSpacing;
    return math.max(1.0, (visibleCount * glyphWidth) + spacing);
  }

  double _fallbackHeightForElement({
    required MotionEvaluatedElementState runtimeElement,
    required ReFusionSceneProgramElement? sourceElement,
    required Map<String, MotionPropertyValue> properties,
  }) {
    if (runtimeElement.kind != MotionElementKind.text ||
        sourceElement == null) {
      return 120.0;
    }
    final fontSize = _scalar(
      properties,
      MotionPropertyCatalog.fontSize.id,
      16.0,
    );
    final lineHeight = _scalar(
      properties,
      MotionPropertyCatalog.lineHeight.id,
      1.0,
    );
    final maxLines = _maxLinesFromSource(sourceElement) ?? 1;
    return math.max(1.0, fontSize * math.max(1.0, lineHeight) * maxLines);
  }

  int? _maxLinesFromSource(ReFusionSceneProgramElement sourceElement) {
    final textFrame = sourceElement.properties['textFrame'];
    if (textFrame is! Map<String, Object?>) {
      return null;
    }
    final raw = textFrame['maxLines'];
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.toInt();
    }
    if (raw is String) {
      return int.tryParse(raw.trim());
    }
    return null;
  }

  double _centerDeltaPx(SceneViewportRect qa, SceneViewportRect preview) {
    final qaCenterX = qa.left + (qa.width / 2.0);
    final qaCenterY = qa.top + (qa.height / 2.0);
    final previewCenterX = preview.left + (preview.width / 2.0);
    final previewCenterY = preview.top + (preview.height / 2.0);
    return <double>[
      (qaCenterX - previewCenterX).abs(),
      (qaCenterY - previewCenterY).abs(),
    ].fold<double>(0.0, math.max);
  }

  double _sizeDeltaPx(SceneViewportRect qa, SceneViewportRect preview) {
    return <double>[
      (qa.width - preview.width).abs(),
      (qa.height - preview.height).abs(),
    ].fold<double>(0.0, math.max);
  }

  String _rectText(SceneViewportRect rect) {
    return '${rect.left.toStringAsFixed(2)},'
        '${rect.top.toStringAsFixed(2)},'
        '${rect.width.toStringAsFixed(2)},'
        '${rect.height.toStringAsFixed(2)}';
  }
}
