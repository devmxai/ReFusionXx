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
      );

      for (final node in qaEvaluation.truth.nodesById.values) {
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
              severity: ReFusionSceneProgramIssueSeverity.warning,
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
        final delta = _boundsDeltaPx(qaBounds, previewBounds);
        final matched = delta <= tolerancePx;
        if (!matched) {
          mismatchCount += 1;
        }
        issues.add(
          ReFusionSceneProgramIssue(
            severity: matched
                ? ReFusionSceneProgramIssueSeverity.info
                : ReFusionSceneProgramIssueSeverity.warning,
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
                'boundsDeltaPx=${delta.toStringAsFixed(2)} '
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
            element.kind == MotionElementKind.text ? 320.0 : 180.0,
          );
          final height = _scalar(
            properties,
            MotionPropertyCatalog.height.id,
            element.kind == MotionElementKind.text ? 56.0 : 120.0,
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
        _clampProbeTime(layer.startMs + layer.durationMs, program.durationMs),
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

  double _boundsDeltaPx(SceneViewportRect qa, SceneViewportRect preview) {
    return <double>[
      (qa.left - preview.left).abs(),
      (qa.top - preview.top).abs(),
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
