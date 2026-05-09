import 'dart:math' as math;

import '../models/refusion_scene_program_models.dart';
import 'evaluated_frame_truth.dart';
import 'scene_evaluation_pipeline.dart';
import 'scene_shape_stroke_contract.dart';
import 'scene_shared_text_layout_engine.dart';
import 'scene_shared_text_layout_models.dart';

class SceneVisualFrameQaValidationResult {
  SceneVisualFrameQaValidationResult({
    required List<ReFusionSceneProgramIssue> issues,
  }) : issues = List.unmodifiable(issues);

  final List<ReFusionSceneProgramIssue> issues;

  bool get isValid => !issues.any(
        (issue) => issue.severity == ReFusionSceneProgramIssueSeverity.error,
      );
}

class SceneVisualFrameQaValidator {
  const SceneVisualFrameQaValidator({
    this.enforceOverflowAsError = true,
    SceneEvaluationPipeline? evaluationPipeline,
    SceneSharedTextLayoutEngine? textLayoutEngine,
    SceneShapeStrokeContract? strokeContract,
  })  : _evaluationPipeline =
            evaluationPipeline ?? const SceneEvaluationPipeline(),
        _textLayoutEngine =
            textLayoutEngine ?? const SceneSharedTextLayoutEngine(),
        _strokeContract = strokeContract ?? const SceneShapeStrokeContract();

  static const int _fullProbeBudget = 9;
  static const int _fallbackProbeBudget = 5;
  static const int _probeTimeBudgetMs = 800;
  static const double _defaultCanvasWidth = 1080;
  static const double _defaultCanvasHeight = 1920;
  static const double _safeAreaInset = 24;
  static const String _proofTag = 'TF_SCENE_VISUAL_FRAME_QA_PROOF';
  static const String _parentCascadeProofTag =
      'TF_SCENE_PARENT_EXIT_CASCADE_PROOF';

  final bool enforceOverflowAsError;
  final SceneEvaluationPipeline _evaluationPipeline;
  final SceneSharedTextLayoutEngine _textLayoutEngine;
  final SceneShapeStrokeContract _strokeContract;

  SceneVisualFrameQaValidationResult validate(ReFusionSceneProgram program) {
    final stopwatch = Stopwatch()..start();
    final issues = <ReFusionSceneProgramIssue>[];

    final allProbeTimes = _collectProgramProbeTimes(program);
    if (allProbeTimes.isEmpty) {
      return SceneVisualFrameQaValidationResult(issues: issues);
    }
    final heavyScene = _isHeavyScene(program);
    final frameBudget = heavyScene ? _fallbackProbeBudget : _fullProbeBudget;
    final probeTimes = _trimProbeTimes(allProbeTimes, maxCount: frameBudget);
    final fallbackReason =
        heavyScene && probeTimes.length <= _fallbackProbeBudget
            ? 'heavy_scene_probe_budget'
            : 'none';

    final baselineOffsets = <String, ({double dx, double dy})>{};
    for (var probeIndex = 0; probeIndex < probeTimes.length; probeIndex += 1) {
      final probeTime = probeTimes[probeIndex];
      final snapshot = _evaluateProbeSnapshot(
        program: program,
        timelineTimeMs: probeTime,
        issues: issues,
      );
      _lintProbeSnapshot(
        snapshot: snapshot,
        probeIndex: probeIndex,
        probeCount: probeTimes.length,
        sceneDuration: program.durationMs,
        elapsedMs: stopwatch.elapsedMilliseconds,
        fallbackReason: fallbackReason,
        baselineOffsets: baselineOffsets,
        issues: issues,
      );
    }

    stopwatch.stop();
    return SceneVisualFrameQaValidationResult(issues: issues);
  }

  _ProgramProbeSnapshot _evaluateProbeSnapshot({
    required ReFusionSceneProgram program,
    required int timelineTimeMs,
    required List<ReFusionSceneProgramIssue> issues,
  }) {
    final evaluation = _evaluationPipeline.evaluate(
      SceneEvaluationPipelineRequest(
        program: program,
        globalTimeMs: timelineTimeMs,
      ),
    );
    issues.addAll(evaluation.issues);

    final layerLookup =
        <String, (int index, ReFusionSceneProgramLayer layer)>{};
    final elementLookup =
        <String, (int index, ReFusionSceneProgramElement element)>{};
    for (var layerIndex = 0;
        layerIndex < program.layers.length;
        layerIndex += 1) {
      final layer = program.layers[layerIndex];
      layerLookup[layer.id] = (layerIndex, layer);
      for (var elementIndex = 0;
          elementIndex < layer.elements.length;
          elementIndex += 1) {
        final element = layer.elements[elementIndex];
        elementLookup['${layer.id}::${element.id}'] = (elementIndex, element);
      }
    }

    final records = <_EvaluatedNodeRecord>[];
    final nodes = evaluation.truth.nodesById.values.toList(growable: false)
      ..sort((left, right) => left.zOrder.compareTo(right.zOrder));
    for (final node in nodes) {
      final layerId = node.sourceLayerId;
      final elementId = node.sourceElementId;
      if (layerId == null || elementId == null) {
        continue;
      }
      final layerMeta = layerLookup[layerId];
      final elementMeta = elementLookup['$layerId::$elementId'];
      if (layerMeta == null || elementMeta == null) {
        continue;
      }
      final parentViewport = node.parentNodeId == null
          ? null
          : evaluation.truth.nodesById[node.parentNodeId!]?.viewportBounds;
      records.add(
        _EvaluatedNodeRecord(
          layerIndex: layerMeta.$1,
          elementIndex: elementMeta.$1,
          layer: layerMeta.$2,
          element: elementMeta.$2,
          nodeId: node.nodeId,
          parentNodeId: node.parentNodeId,
          state: _stateFromEvaluatedNode(node, elementMeta.$2),
          worldBounds: _Rect(
            x: node.viewportBounds.left,
            y: node.viewportBounds.top,
            width: node.viewportBounds.width,
            height: node.viewportBounds.height,
          ),
          parentWorldBounds: parentViewport == null
              ? null
              : _Rect(
                  x: parentViewport.left,
                  y: parentViewport.top,
                  width: parentViewport.width,
                  height: parentViewport.height,
                ),
          active: node.active,
          effectiveOpacity: node.effectiveOpacity,
          worldScaleX: math.sqrt(
              (node.worldTransform.m00 * node.worldTransform.m00) +
                  (node.worldTransform.m10 * node.worldTransform.m10)),
          worldScaleY: math.sqrt(
              (node.worldTransform.m01 * node.worldTransform.m01) +
                  (node.worldTransform.m11 * node.worldTransform.m11)),
        ),
      );
    }
    return _ProgramProbeSnapshot(
      timelineTimeMs: timelineTimeMs,
      records: records,
      geometryHash: evaluation.truth.geometryHash,
      frameTruthHash: evaluation.truth.frameHash,
      coordinateSystem: evaluation.truth.coordinateSystem.name,
      usedSharedPipeline: true,
    );
  }

  void _lintProbeSnapshot({
    required _ProgramProbeSnapshot snapshot,
    required int probeIndex,
    required int probeCount,
    required int sceneDuration,
    required int elapsedMs,
    required String fallbackReason,
    required Map<String, ({double dx, double dy})> baselineOffsets,
    required List<ReFusionSceneProgramIssue> issues,
  }) {
    final recordsByNodeId = <String, _EvaluatedNodeRecord>{
      for (final record in snapshot.records) record.nodeId: record,
    };
    _emitParentCascadeViolations(
      snapshot: snapshot,
      recordsByNodeId: recordsByNodeId,
      issues: issues,
    );
    final activeRecords =
        snapshot.records.where((record) => record.active).toList();
    final overlapKeys = _computeOverlapKeys(activeRecords);
    final perfExceeded = elapsedMs > _probeTimeBudgetMs;

    for (final record in activeRecords) {
      if (_normalizeToken(record.element.kind) != 'text') {
        final geometryCritical = _isGeometryCritical(record);
        final clippingPx =
            geometryCritical ? _clippingPixels(record.worldBounds) : 0.0;
        final clipped = geometryCritical && clippingPx > 0.0;
        final safeAreaViolation = geometryCritical &&
            !_isCanvasBackground(record) &&
            _violatesSafeArea(record.worldBounds);
        final overlap = geometryCritical && overlapKeys.contains(record.nodeId);
        final parentChildDesync = _detectParentChildDesync(
          record: record,
          baselineOffsets: baselineOffsets,
        );
        final strokeContract = _strokeContract.evaluate(
          SceneShapeStrokeContractRequest(
            elementId: record.element.id,
            elementKind: record.element.kind,
            properties: record.element.properties,
            scaleX: record.worldScaleX,
            scaleY: record.worldScaleY,
          ),
        );
        issues.addAll(strokeContract.issues);
        final strokeFailure = strokeContract.issues.any(
          (issue) => issue.severity == ReFusionSceneProgramIssueSeverity.error,
        );
        final passed = !clipped &&
            !safeAreaViolation &&
            !overlap &&
            !parentChildDesync &&
            !strokeFailure;
        if (clipped) {
          issues.add(
            ReFusionSceneProgramIssue(
              severity: _visualDefectSeverity(),
              message:
                  '${record.element.kind} `${record.element.id}` is clipped at frame ${snapshot.timelineTimeMs}ms.',
              path:
                  'layers[${record.layerIndex}].elements[${record.elementIndex}]',
            ),
          );
        }
        if (safeAreaViolation) {
          issues.add(
            ReFusionSceneProgramIssue(
              severity: _visualDefectSeverity(),
              message:
                  '${record.element.kind} `${record.element.id}` violates safe area at frame ${snapshot.timelineTimeMs}ms.',
              path:
                  'layers[${record.layerIndex}].elements[${record.elementIndex}]',
            ),
          );
        }
        if (overlap) {
          issues.add(
            ReFusionSceneProgramIssue(
              severity: _visualDefectSeverity(),
              message:
                  '${record.element.kind} `${record.element.id}` overlaps sibling elements at frame ${snapshot.timelineTimeMs}ms.',
              path:
                  'layers[${record.layerIndex}].elements[${record.elementIndex}]',
            ),
          );
        }
        if (parentChildDesync) {
          issues.add(
            ReFusionSceneProgramIssue(
              severity: _visualDefectSeverity(),
              message:
                  '${record.element.kind} `${record.element.id}` is desynced from parent at frame ${snapshot.timelineTimeMs}ms.',
              path:
                  'layers[${record.layerIndex}].elements[${record.elementIndex}]',
            ),
          );
        }
        _emitProbeProof(
          record: record,
          snapshot: snapshot,
          probeIndex: probeIndex,
          probeCount: probeCount,
          textOverflow: false,
          overflowPx: 0.0,
          clippingPx: clippingPx,
          overlapDetected: overlap,
          safeAreaViolation: safeAreaViolation,
          parentChildDesync: parentChildDesync,
          passed: passed,
          failureReason: passed
              ? 'none'
              : _firstFailureReasonForNonText(
                  clipped: clipped,
                  overlap: overlap,
                  safeAreaViolation: safeAreaViolation,
                  parentChildDesync: parentChildDesync,
                  strokeFailure: strokeFailure,
                ),
          severity: passed
              ? ReFusionSceneProgramIssueSeverity.info
              : _visualDefectSeverity(),
          fallbackReason:
              perfExceeded ? 'probe_budget_exceeded' : fallbackReason,
          timelineTimeMs: snapshot.timelineTimeMs,
          issues: issues,
        );
        continue;
      }

      final textFrame = _mapFromProperties(
        record.element.properties,
        const <String>['textFrame', 'layoutTextFrame'],
      );
      if (textFrame == null) {
        continue;
      }
      final hasTypewriter = _hasTypewriterChannel(
        layerChannels: record.layer.channels,
        element: record.element,
      );
      final frameWidth = _doubleFromMap(
            textFrame,
            const <String>['width', 'maxWidth'],
          ) ??
          record.worldBounds.width;
      final frameHeight = _doubleFromMap(
            textFrame,
            const <String>['height', 'maxHeight'],
          ) ??
          record.worldBounds.height;
      final fitPolicy = (_stringFromMap(
                textFrame,
                const <String>['fitPolicy'],
              ) ??
              'none')
          .trim();
      final maxLines =
          (_doubleFromMap(textFrame, const <String>['maxLines']) ?? 1.0)
              .round();
      final layout = _textLayoutEngine.layout(
        SceneSharedTextLayoutRequest(
          text: record.element.text ?? '',
          frameWidth: frameWidth,
          frameHeight: frameHeight,
          fontSize: record.state.fontSize,
          lineHeight: record.state.lineHeight,
          letterSpacing: record.state.letterSpacing,
          maxLines: maxLines,
          fitPolicy: fitPolicy,
          minFontSize:
              _doubleFromMap(textFrame, const <String>['minFontSize']) ?? 12.0,
        ),
      );
      final estimatedWidth = layout.measuredWidth;
      final estimatedHeight = layout.measuredHeight;
      final overflowPx = layout.overflowPx;
      final overflowDetected = overflowPx > 1.0;
      final overflowBlocking = overflowDetected && !layout.fits;
      if (overflowBlocking) {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: _visualDefectSeverity(),
            message: 'Text element `${record.element.id}` '
                '${hasTypewriter ? 'reveal' : 'static'} bounded frame overflow detected. '
                'fitPolicy=$fitPolicy '
                'estimatedWidth=${estimatedWidth.toStringAsFixed(2)} '
                'estimatedHeight=${estimatedHeight.toStringAsFixed(2)} '
                'frameWidth=${frameWidth.toStringAsFixed(2)} '
                'frameHeight=${frameHeight.toStringAsFixed(2)} '
                'effectiveFontSize=${layout.effectiveFontSize.toStringAsFixed(2)} '
                '${SceneSharedTextLayoutEngine.proofTag} '
                'policy=${layout.normalizedFitPolicy} '
                'policyAllowsOverflow=${layout.policyAllowsOverflow.toString()} '
                'timelineTimeMs=${snapshot.timelineTimeMs}',
            path:
                'layers[${record.layerIndex}].elements[${record.elementIndex}].properties.textFrame',
          ),
        );
      }

      final clippingPx = _clippingPixels(record.worldBounds);
      final geometryCritical = _isGeometryCritical(record);
      final clipped = geometryCritical && clippingPx > 0.0;
      final safeAreaViolation = geometryCritical &&
          !_isCanvasBackground(record) &&
          _violatesSafeArea(record.worldBounds);
      final overlap = geometryCritical && overlapKeys.contains(record.nodeId);
      final parentChildDesync = _detectParentChildDesync(
        record: record,
        baselineOffsets: baselineOffsets,
      );
      final unfinishedMotion = _unfinishedMotionAtBoundary(
        timelineTimeMs: snapshot.timelineTimeMs,
        sceneDuration: sceneDuration,
        hasReveal: hasTypewriter,
        typewriterProgress: record.state.typewriterProgress,
      );
      final contrastPass = _contrastPass(record.effectiveOpacity);
      final enforceReadableHold = _isReadableHoldFrame(
        probeIndex: probeIndex,
        probeCount: probeCount,
        hasReveal: hasTypewriter,
        typewriterProgress: record.state.typewriterProgress,
      );
      if (!overflowBlocking) {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.info,
            message: '${SceneSharedTextLayoutEngine.proofTag} '
                'text=${record.element.id} '
                'fitPolicy=${layout.normalizedFitPolicy} '
                'frameWidth=${frameWidth.toStringAsFixed(2)} '
                'frameHeight=${frameHeight.toStringAsFixed(2)} '
                'measuredWidth=${layout.measuredWidth.toStringAsFixed(2)} '
                'measuredHeight=${layout.measuredHeight.toStringAsFixed(2)} '
                'effectiveFontSize=${layout.effectiveFontSize.toStringAsFixed(2)} '
                'estimatedLines=${layout.estimatedLines} '
                'fits=${layout.fits.toString()} '
                'timelineTimeMs=${snapshot.timelineTimeMs}',
            path:
                'layers[${record.layerIndex}].elements[${record.elementIndex}].properties.textFrame',
          ),
        );
      }

      if (clipped) {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: _visualDefectSeverity(),
            message:
                'Text element `${record.element.id}` is clipped at frame ${snapshot.timelineTimeMs}ms.',
            path:
                'layers[${record.layerIndex}].elements[${record.elementIndex}]',
          ),
        );
      }
      if (safeAreaViolation) {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: _visualDefectSeverity(),
            message:
                'Text element `${record.element.id}` violates safe area at frame ${snapshot.timelineTimeMs}ms.',
            path:
                'layers[${record.layerIndex}].elements[${record.elementIndex}]',
          ),
        );
      }
      if (overlap) {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: _visualDefectSeverity(),
            message:
                'Text element `${record.element.id}` overlaps sibling elements at frame ${snapshot.timelineTimeMs}ms.',
            path:
                'layers[${record.layerIndex}].elements[${record.elementIndex}]',
          ),
        );
      }
      if (parentChildDesync) {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: _visualDefectSeverity(),
            message:
                'Text element `${record.element.id}` is desynced from parent at frame ${snapshot.timelineTimeMs}ms.',
            path:
                'layers[${record.layerIndex}].elements[${record.elementIndex}]',
          ),
        );
      }
      if (enforceReadableHold && !contrastPass) {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: _visualDefectSeverity(),
            message:
                'Text element `${record.element.id}` is unreadable at frame ${snapshot.timelineTimeMs}ms (effectiveOpacity=${record.effectiveOpacity.toStringAsFixed(2)}).',
            path:
                'layers[${record.layerIndex}].elements[${record.elementIndex}]',
          ),
        );
      }
      if (unfinishedMotion) {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: _visualDefectSeverity(),
            message:
                'Text element `${record.element.id}` has unreadable hold timing near scene boundary at frame ${snapshot.timelineTimeMs}ms.',
            path:
                'layers[${record.layerIndex}].elements[${record.elementIndex}]',
          ),
        );
      }

      final passed = !overflowBlocking &&
          !clipped &&
          !safeAreaViolation &&
          !overlap &&
          !parentChildDesync &&
          (!enforceReadableHold || contrastPass) &&
          !unfinishedMotion;
      final failureReason = passed
          ? 'none'
          : _firstFailureReason(
              textOverflow: overflowBlocking,
              clipped: clipped,
              overlap: overlap,
              safeAreaViolation: safeAreaViolation,
              parentChildDesync: parentChildDesync,
              unfinishedMotion: unfinishedMotion,
            );
      _emitProbeProof(
        record: record,
        snapshot: snapshot,
        probeIndex: probeIndex,
        probeCount: probeCount,
        textOverflow: overflowBlocking,
        overflowPx: overflowPx,
        clippingPx: clippingPx,
        overlapDetected: overlap,
        safeAreaViolation: safeAreaViolation,
        parentChildDesync: parentChildDesync,
        passed: passed,
        failureReason: failureReason,
        severity: passed
            ? ReFusionSceneProgramIssueSeverity.info
            : _visualDefectSeverity(),
        fallbackReason: perfExceeded ? 'probe_budget_exceeded' : fallbackReason,
        timelineTimeMs: snapshot.timelineTimeMs,
        issues: issues,
      );
    }
  }

  void _emitParentCascadeViolations({
    required _ProgramProbeSnapshot snapshot,
    required Map<String, _EvaluatedNodeRecord> recordsByNodeId,
    required List<ReFusionSceneProgramIssue> issues,
  }) {
    for (final child in recordsByNodeId.values) {
      final parentNodeId = child.parentNodeId;
      if (parentNodeId == null) {
        continue;
      }
      final parent = recordsByNodeId[parentNodeId];
      if (parent == null) {
        continue;
      }
      final childVisible = child.active && child.effectiveOpacity > 0.001;
      final parentVisible = parent.active && parent.effectiveOpacity > 0.001;
      if (!childVisible || parentVisible) {
        continue;
      }
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message: 'Child `${child.element.id}` is visible while parent '
              '`${parent.element.id}` is inactive/hidden at frame '
              '${snapshot.timelineTimeMs}ms. $_parentCascadeProofTag '
              'nodeId=${child.nodeId} parentNodeId=$parentNodeId '
              'childActive=${child.active} parentActive=${parent.active} '
              'childOpacity=${child.effectiveOpacity.toStringAsFixed(3)} '
              'parentOpacity=${parent.effectiveOpacity.toStringAsFixed(3)}',
          path: 'layers[${child.layerIndex}].elements[${child.elementIndex}]',
        ),
      );
    }
  }

  void _emitProbeProof({
    required _EvaluatedNodeRecord record,
    required _ProgramProbeSnapshot snapshot,
    required int probeIndex,
    required int probeCount,
    required bool textOverflow,
    required double overflowPx,
    required double clippingPx,
    required bool overlapDetected,
    required bool safeAreaViolation,
    required bool parentChildDesync,
    required bool passed,
    required String failureReason,
    required ReFusionSceneProgramIssueSeverity severity,
    required String fallbackReason,
    required int timelineTimeMs,
    required List<ReFusionSceneProgramIssue> issues,
  }) {
    final slotId = _slotIdFromElement(record.element);
    final slotBounds = _slotBounds(record);
    final proof = StringBuffer()
      ..write('$_proofTag ')
      ..write('frameIndex=${probeIndex + 1} ')
      ..write('frameCount=$probeCount ')
      ..write('probeCount=$probeCount ')
      ..write('timelineTimeMs=$timelineTimeMs ')
      ..write('nodeId=${record.nodeId} ')
      ..write('componentId=${record.element.id} ')
      ..write('slotId=${slotId ?? 'none'} ')
      ..write(
        'worldBounds=${_rectAsText(record.worldBounds)} ',
      )
      ..write('slotBounds=${_rectAsText(slotBounds)} ')
      ..write('geometryHash=${snapshot.geometryHash} ')
      ..write('evaluatedFrameTruthHash=${snapshot.frameTruthHash} ')
      ..write('coordinateSystem=${snapshot.coordinateSystem} ')
      ..write('qaUsedSharedPipeline=${snapshot.usedSharedPipeline.toString()} ')
      ..write('textOverflow=${textOverflow.toString()} ')
      ..write('overflowPx=${overflowPx.toStringAsFixed(2)} ')
      ..write('clippingPx=${clippingPx.toStringAsFixed(2)} ')
      ..write('overlapDetected=${overlapDetected.toString()} ')
      ..write('safeAreaViolation=${safeAreaViolation.toString()} ')
      ..write('parentChildDesync=${parentChildDesync.toString()} ')
      ..write('passed=${passed.toString()} ')
      ..write('failureReason=$failureReason ')
      ..write('severity=${severity.name} ')
      ..write('fallbackReason=$fallbackReason');
    issues.add(
      ReFusionSceneProgramIssue(
        severity: ReFusionSceneProgramIssueSeverity.info,
        message: proof.toString(),
        path:
            'layers[${record.layerIndex}].elements[${record.elementIndex}].probe[$probeIndex]',
      ),
    );
  }

  Set<String> _computeOverlapKeys(List<_EvaluatedNodeRecord> records) {
    final overlaps = <String>{};
    for (var i = 0; i < records.length; i += 1) {
      final left = records[i];
      for (var j = i + 1; j < records.length; j += 1) {
        final right = records[j];
        if (left.layerIndex != right.layerIndex) {
          continue;
        }
        if (left.parentNodeId != right.parentNodeId) {
          continue;
        }
        if (_intersects(left.worldBounds, right.worldBounds)) {
          overlaps.add(left.nodeId);
          overlaps.add(right.nodeId);
        }
      }
    }
    return overlaps;
  }

  bool _detectParentChildDesync({
    required _EvaluatedNodeRecord record,
    required Map<String, ({double dx, double dy})> baselineOffsets,
  }) {
    final parent = record.parentWorldBounds;
    if (parent == null) {
      return false;
    }
    final dx = record.worldBounds.x - parent.x;
    final dy = record.worldBounds.y - parent.y;
    final key = record.nodeId;
    final baseline = baselineOffsets[key];
    if (baseline == null) {
      baselineOffsets[key] = (dx: dx, dy: dy);
      return false;
    }
    final drift = math.sqrt(
      math.pow(dx - baseline.dx, 2) + math.pow(dy - baseline.dy, 2),
    );
    final threshold = math.max(
      16.0,
      math.min(parent.width, parent.height) * 0.12,
    );
    return drift > threshold;
  }

  _ElementEvaluationState _stateFromEvaluatedNode(
    EvaluatedSceneNode node,
    ReFusionSceneProgramElement element,
  ) {
    final metrics = node.textMetrics;
    final fontSize = metrics?.fontSize ??
        _readScalar(
            element.properties, const <String>['fontSize', 'fontsize']) ??
        16.0;
    final lineHeight = metrics?.lineHeight ??
        _readScalar(
            element.properties, const <String>['lineHeight', 'lineheight']) ??
        1.0;
    final letterSpacing = metrics?.letterSpacing ??
        _readScalar(
            element.properties, const <String>['letterSpacing', 'tracking']) ??
        0.0;
    final typewriterProgress = metrics?.typewriterProgress ??
        _readScalar(element.properties, const <String>['typewriterProgress']) ??
        1.0;
    return _ElementEvaluationState(
      fontSize: fontSize,
      lineHeight: lineHeight,
      letterSpacing: letterSpacing,
      typewriterProgress: typewriterProgress.clamp(0.0, 1.0),
    );
  }

  _Rect _slotBounds(_EvaluatedNodeRecord record) {
    final parent = record.parentWorldBounds;
    if (parent == null) {
      return record.worldBounds;
    }
    return parent;
  }

  String? _slotIdFromElement(ReFusionSceneProgramElement element) {
    final layout = _mapFromProperties(
      element.properties,
      const <String>['layout'],
    );
    if (layout == null) {
      return null;
    }
    final value = layout['slot'];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }

  String _rectAsText(_Rect rect) =>
      '${rect.x.toStringAsFixed(2)},${rect.y.toStringAsFixed(2)},'
      '${rect.width.toStringAsFixed(2)},${rect.height.toStringAsFixed(2)}';

  List<int> _collectProgramProbeTimes(ReFusionSceneProgram program) {
    final probes = <int>{0, program.durationMs};

    void absorbChannel(ReFusionSceneProgramChannel channel) {
      final sorted = channel.keyframes.toList(growable: false)
        ..sort((left, right) => left.timeMs.compareTo(right.timeMs));
      for (var index = 0; index < sorted.length; index += 1) {
        probes.add(sorted[index].timeMs.clamp(0, program.durationMs));
        if (index > 0) {
          final previous = sorted[index - 1].timeMs;
          final current = sorted[index].timeMs;
          probes.add(
            ((previous + current) / 2).round().clamp(0, program.durationMs),
          );
        }
      }
    }

    for (final layer in program.layers) {
      probes.add(layer.startMs.clamp(0, program.durationMs));
      probes
          .add((layer.startMs + layer.durationMs).clamp(0, program.durationMs));
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

  bool _isHeavyScene(ReFusionSceneProgram program) {
    final layerCount = program.layers.length;
    final elementCount = program.layers.fold<int>(
      0,
      (sum, layer) => sum + layer.elements.length,
    );
    final channelCount = program.layers.fold<int>(
      0,
      (sum, layer) =>
          sum +
          layer.channels.length +
          layer.elements.fold<int>(
            0,
            (elementSum, element) => elementSum + element.channels.length,
          ),
    );
    return layerCount > 8 || elementCount > 24 || channelCount > 48;
  }

  double _estimateTextWidth(
    ReFusionSceneProgramElement element, {
    required double fontSize,
    required double letterSpacing,
    required double typewriterProgress,
  }) {
    final text = (element.text ?? '').trim();
    if (text.isEmpty) {
      return 0;
    }
    final visibleCount =
        (text.runes.length * typewriterProgress.clamp(0.0, 1.0)).ceil();
    final estimatedGlyphWidth = fontSize * 0.56;
    final spacing = math.max(0, visibleCount - 1) * letterSpacing;
    return (estimatedGlyphWidth * visibleCount) + spacing;
  }

  double _estimateTextHeight(
    ReFusionSceneProgramElement element, {
    required double fontSize,
    required double lineHeight,
  }) {
    final text = (element.text ?? '').trim();
    if (text.isEmpty) {
      return 0;
    }
    return fontSize * lineHeight;
  }

  bool _unfinishedMotionAtBoundary({
    required int timelineTimeMs,
    required int sceneDuration,
    required bool hasReveal,
    required double typewriterProgress,
  }) {
    if (!hasReveal) {
      return false;
    }
    final nearBoundary = timelineTimeMs >= sceneDuration - 1;
    if (!nearBoundary) {
      return false;
    }
    return typewriterProgress < 0.99;
  }

  bool _contrastPass(double opacity) => opacity >= 0.35;

  String _firstFailureReason({
    required bool textOverflow,
    required bool clipped,
    required bool overlap,
    required bool safeAreaViolation,
    required bool parentChildDesync,
    required bool unfinishedMotion,
  }) {
    if (textOverflow) {
      return 'text_overflow';
    }
    if (clipped) {
      return 'clipped';
    }
    if (safeAreaViolation) {
      return 'safe_area_violation';
    }
    if (overlap) {
      return 'overlap';
    }
    if (parentChildDesync) {
      return 'parent_child_desync';
    }
    if (unfinishedMotion) {
      return 'unfinished_motion';
    }
    return 'unknown';
  }

  String _firstFailureReasonForNonText({
    required bool clipped,
    required bool overlap,
    required bool safeAreaViolation,
    required bool parentChildDesync,
    required bool strokeFailure,
  }) {
    if (clipped) {
      return 'clipped';
    }
    if (safeAreaViolation) {
      return 'safe_area_violation';
    }
    if (overlap) {
      return 'overlap';
    }
    if (parentChildDesync) {
      return 'parent_child_desync';
    }
    if (strokeFailure) {
      return 'stroke_contract';
    }
    return 'unknown';
  }

  ReFusionSceneProgramIssueSeverity _visualDefectSeverity() =>
      enforceOverflowAsError
          ? ReFusionSceneProgramIssueSeverity.error
          : ReFusionSceneProgramIssueSeverity.warning;

  bool _isGeometryCritical(_EvaluatedNodeRecord record) {
    if (_isCanvasBackground(record)) {
      return false;
    }
    final hasParent = record.parentNodeId != null &&
        !_isLayerRootNodeId(record.parentNodeId!);
    final slotId = _slotIdFromElement(record.element);
    if (slotId != null && slotId.trim().isNotEmpty) {
      return true;
    }
    final layout = _mapFromProperties(
      record.element.properties,
      const <String>['layout'],
    );
    final hasLayoutMetadata = layout != null && layout.isNotEmpty;
    if (_normalizeToken(record.element.kind) == 'text') {
      final hasExplicitPosition =
          _readPosition(record.element.properties, 'x') != null ||
              _readPosition(record.element.properties, 'y') != null;
      return hasParent || hasLayoutMetadata || hasExplicitPosition;
    }
    return hasParent || hasLayoutMetadata;
  }

  bool _isLayerRootNodeId(String nodeId) =>
      nodeId.startsWith('__layer__') && nodeId.endsWith('__root');

  bool _isReadableHoldFrame({
    required int probeIndex,
    required int probeCount,
    required bool hasReveal,
    required double typewriterProgress,
  }) {
    if (probeCount <= 2) {
      return true;
    }
    final isBoundary = probeIndex == 0 || probeIndex == probeCount - 1;
    if (isBoundary) {
      return false;
    }
    if (!hasReveal) {
      return true;
    }
    return typewriterProgress >= 0.95;
  }

  bool _isCanvasBackground(_EvaluatedNodeRecord record) {
    final normalizedKind = _normalizeToken(record.element.kind);
    if (normalizedKind != 'shape' &&
        normalizedKind != 'solid' &&
        normalizedKind != 'background') {
      return false;
    }
    final rect = record.worldBounds;
    return rect.x <= 1.0 &&
        rect.y <= 1.0 &&
        rect.width >= _defaultCanvasWidth - 2.0 &&
        rect.height >= _defaultCanvasHeight - 2.0;
  }

  double _clippingPixels(_Rect rect) {
    final leftClip = math.max(0, -rect.x);
    final topClip = math.max(0, -rect.y);
    final rightClip = math.max(0, (rect.x + rect.width) - _defaultCanvasWidth);
    final bottomClip =
        math.max(0, (rect.y + rect.height) - _defaultCanvasHeight);
    return (leftClip + topClip + rightClip + bottomClip).toDouble();
  }

  bool _intersects(_Rect a, _Rect b) {
    final ax2 = a.x + a.width;
    final ay2 = a.y + a.height;
    final bx2 = b.x + b.width;
    final by2 = b.y + b.height;
    return a.x < bx2 && ax2 > b.x && a.y < by2 && ay2 > b.y;
  }

  bool _violatesSafeArea(_Rect rect) {
    return rect.x < _safeAreaInset ||
        rect.y < _safeAreaInset ||
        rect.x + rect.width > _defaultCanvasWidth - _safeAreaInset ||
        rect.y + rect.height > _defaultCanvasHeight - _safeAreaInset;
  }

  bool _hasTypewriterChannel({
    required List<ReFusionSceneProgramChannel> layerChannels,
    required ReFusionSceneProgramElement element,
  }) {
    bool matches(ReFusionSceneProgramChannel channel) {
      final property = _normalizeToken(channel.property);
      final target = _normalizeToken(channel.target);
      return property == 'typewriterprogress' &&
          target == _normalizeToken(element.id);
    }

    for (final channel in layerChannels) {
      if (matches(channel)) {
        return true;
      }
    }
    for (final channel in element.channels) {
      if (_normalizeToken(channel.property) == 'typewriterprogress') {
        return true;
      }
    }
    return false;
  }

  Map<String, Object?>? _mapFromProperties(
    Map<String, Object?> properties,
    List<String> keys,
  ) {
    final normalized = keys.map(_normalizeToken).toSet();
    for (final entry in properties.entries) {
      if (!normalized.contains(_normalizeToken(entry.key))) {
        continue;
      }
      final value = entry.value;
      if (value is Map) {
        return value.cast<String, Object?>();
      }
      return null;
    }
    return null;
  }

  double? _doubleFromMap(Map<String, Object?>? map, List<String> keys) {
    if (map == null) {
      return null;
    }
    final normalized = keys.map(_normalizeToken).toSet();
    for (final entry in map.entries) {
      if (!normalized.contains(_normalizeToken(entry.key))) {
        continue;
      }
      return _asDouble(entry.value);
    }
    return null;
  }

  String? _stringFromMap(Map<String, Object?>? map, List<String> keys) {
    if (map == null) {
      return null;
    }
    final normalized = keys.map(_normalizeToken).toSet();
    for (final entry in map.entries) {
      if (!normalized.contains(_normalizeToken(entry.key))) {
        continue;
      }
      final value = entry.value;
      if (value is String) {
        return value.trim();
      }
    }
    return null;
  }

  double? _readPosition(Map<String, Object?> map, String axis) {
    final direct = _readScalar(
      map,
      axis == 'x'
          ? const <String>['x', 'left', 'positionX']
          : const <String>['y', 'top', 'positionY'],
    );
    if (direct != null) {
      return direct;
    }
    final positionRaw = map['position'];
    if (positionRaw is Map<String, Object?>) {
      final key = axis == 'x' ? 'x' : 'y';
      return _asDouble(positionRaw[key]);
    }
    if (positionRaw is List && positionRaw.length >= 2) {
      final index = axis == 'x' ? 0 : 1;
      return _asDouble(positionRaw[index]);
    }
    return null;
  }

  double? _readScalar(Map<String, Object?> map, List<String> keys) {
    final normalized = keys.map(_normalizeToken).toSet();
    for (final entry in map.entries) {
      if (!normalized.contains(_normalizeToken(entry.key))) {
        continue;
      }
      return _asDouble(entry.value);
    }
    return null;
  }

  double? _asDouble(Object? value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim());
    }
    return null;
  }

  String _normalizeToken(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9.]+'), '');
}

class _ProgramProbeSnapshot {
  const _ProgramProbeSnapshot({
    required this.timelineTimeMs,
    required this.records,
    required this.geometryHash,
    required this.frameTruthHash,
    required this.coordinateSystem,
    required this.usedSharedPipeline,
  });

  final int timelineTimeMs;
  final List<_EvaluatedNodeRecord> records;
  final String geometryHash;
  final String frameTruthHash;
  final String coordinateSystem;
  final bool usedSharedPipeline;
}

class _EvaluatedNodeRecord {
  const _EvaluatedNodeRecord({
    required this.layerIndex,
    required this.elementIndex,
    required this.layer,
    required this.element,
    required this.nodeId,
    required this.parentNodeId,
    required this.state,
    required this.worldBounds,
    required this.parentWorldBounds,
    required this.active,
    required this.effectiveOpacity,
    required this.worldScaleX,
    required this.worldScaleY,
  });

  final int layerIndex;
  final int elementIndex;
  final ReFusionSceneProgramLayer layer;
  final ReFusionSceneProgramElement element;
  final String nodeId;
  final String? parentNodeId;
  final _ElementEvaluationState state;
  final _Rect worldBounds;
  final _Rect? parentWorldBounds;
  final bool active;
  final double effectiveOpacity;
  final double worldScaleX;
  final double worldScaleY;
}

class _ElementEvaluationState {
  const _ElementEvaluationState({
    required this.fontSize,
    required this.lineHeight,
    required this.letterSpacing,
    required this.typewriterProgress,
  });

  final double fontSize;
  final double lineHeight;
  final double letterSpacing;
  final double typewriterProgress;
}

class _Rect {
  const _Rect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final double x;
  final double y;
  final double width;
  final double height;
}
