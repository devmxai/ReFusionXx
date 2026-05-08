import 'dart:math' as math;

import '../models/refusion_scene_program_models.dart';
import '../models/scene_runtime_node.dart';
import 'scene_runtime_component_tree.dart';
import 'scene_runtime_transform_composer.dart';

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
    this.enforceOverflowAsError = false,
    SceneRuntimeTransformComposer? transformComposer,
  }) : _transformComposer =
            transformComposer ?? const SceneRuntimeTransformComposer();

  static const int _fullProbeBudget = 9;
  static const int _fallbackProbeBudget = 5;
  static const int _probeTimeBudgetMs = 800;
  static const double _defaultCanvasWidth = 1080;
  static const double _defaultCanvasHeight = 1920;
  static const double _safeAreaInset = 24;
  static const String _proofTag = 'TF_SCENE_VISUAL_FRAME_QA_PROOF';

  final bool enforceOverflowAsError;
  final SceneRuntimeTransformComposer _transformComposer;

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
    final records = <_EvaluatedNodeRecord>[];
    for (var layerIndex = 0;
        layerIndex < program.layers.length;
        layerIndex += 1) {
      final layer = program.layers[layerIndex];
      final layerStart = layer.startMs;
      final layerEnd = layer.startMs + layer.durationMs;
      if (timelineTimeMs < layerStart || timelineTimeMs > layerEnd) {
        continue;
      }
      final nodes = <SceneRuntimeNode>[
        SceneRuntimeNode(
          id: '__layer__${layer.id}__root',
          nodeType: SceneRuntimeNodeType.group,
          metadata: const <String, Object?>{
            'x': 0.0,
            'y': 0.0,
            'width': _defaultCanvasWidth,
            'height': _defaultCanvasHeight,
            'localLeft': 0.0,
            'localTop': 0.0,
          },
        ),
      ];
      final elementByRuntimeId = <String, ReFusionSceneProgramElement>{};
      final elementIndexByRuntimeId = <String, int>{};
      final stateByRuntimeId = <String, _ElementEvaluationState>{};

      for (var elementIndex = 0;
          elementIndex < layer.elements.length;
          elementIndex += 1) {
        final element = layer.elements[elementIndex];
        final runtimeId = _runtimeNodeId(layer.id, element.id);
        final parentId = _resolveRuntimeParentId(
          layerId: layer.id,
          element: element,
        );
        final state = _evaluateElementState(
          layer: layer,
          element: element,
          timelineTimeMs: timelineTimeMs,
        );
        stateByRuntimeId[runtimeId] = state;
        elementByRuntimeId[runtimeId] = element;
        elementIndexByRuntimeId[runtimeId] = elementIndex;
        nodes.add(
          SceneRuntimeNode(
            id: runtimeId,
            nodeType: _runtimeTypeForElementKind(element.kind),
            parentId: parentId,
            sourceLayerId: layer.id,
            metadata: <String, Object?>{
              'x': state.x,
              'y': state.y,
              'scaleX': state.scaleX,
              'scaleY': state.scaleY,
              'rotationDeg': state.rotationDeg,
              'opacity': state.opacity,
              'width': state.width,
              'height': state.height,
              'localLeft': 0.0,
              'localTop': 0.0,
              'startMs': layer.startMs,
              'endMs': layer.startMs + layer.durationMs,
              'typewriterProgress': state.typewriterProgress,
            },
          ),
        );
      }

      final treeResult = SceneRuntimeComponentTree.build(nodes);
      if (!treeResult.isValid || treeResult.tree == null) {
        for (final issue in treeResult.issues) {
          issues.add(
            ReFusionSceneProgramIssue(
              severity: ReFusionSceneProgramIssueSeverity.error,
              message:
                  'Runtime probe tree invalid for layer `${layer.id}`: ${issue.message}',
              path: issue.path ?? 'layers[$layerIndex]',
            ),
          );
        }
        continue;
      }

      final composition = _transformComposer.compose(
        tree: treeResult.tree!,
        timelineTimeMs: timelineTimeMs,
      );
      for (final entry in composition.recordsByNodeId.entries) {
        final nodeId = entry.key;
        final element = elementByRuntimeId[nodeId];
        if (element == null) {
          continue;
        }
        final elementIndex = elementIndexByRuntimeId[nodeId] ?? 0;
        final state = stateByRuntimeId[nodeId]!;
        final record = entry.value;
        final parentId = treeResult.tree!.parentOf[nodeId];
        final parentRecord =
            parentId == null ? null : composition.recordsByNodeId[parentId];
        records.add(
          _EvaluatedNodeRecord(
            layerIndex: layerIndex,
            elementIndex: elementIndex,
            layer: layer,
            element: element,
            nodeId: nodeId,
            parentNodeId: parentId,
            state: state,
            worldBounds: _Rect(
              x: record.worldBounds.left,
              y: record.worldBounds.top,
              width: record.worldBounds.width,
              height: record.worldBounds.height,
            ),
            parentWorldBounds: parentRecord == null
                ? null
                : _Rect(
                    x: parentRecord.worldBounds.left,
                    y: parentRecord.worldBounds.top,
                    width: parentRecord.worldBounds.width,
                    height: parentRecord.worldBounds.height,
                  ),
            active: record.active,
            effectiveOpacity: record.effectiveOpacity,
          ),
        );
      }
    }
    return _ProgramProbeSnapshot(
      timelineTimeMs: timelineTimeMs,
      records: records,
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
    final activeRecords =
        snapshot.records.where((record) => record.active).toList();
    final overlapKeys = _computeOverlapKeys(activeRecords);
    final perfExceeded = elapsedMs > _probeTimeBudgetMs;

    for (final record in activeRecords) {
      if (_normalizeToken(record.element.kind) != 'text') {
        _emitProbeProof(
          record: record,
          probeIndex: probeIndex,
          probeCount: probeCount,
          textOverflow: false,
          overflowPx: 0.0,
          clippingPx: _clippingPixels(record.worldBounds),
          overlapDetected: overlapKeys.contains(record.nodeId),
          safeAreaViolation: _violatesSafeArea(record.worldBounds),
          parentChildDesync: _detectParentChildDesync(
            record: record,
            baselineOffsets: baselineOffsets,
          ),
          passed: true,
          failureReason: 'none',
          severity: ReFusionSceneProgramIssueSeverity.info,
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
      final normalizedFitPolicy = _normalizeToken(fitPolicy);
      final supportedFitPolicy = normalizedFitPolicy == 'shrinktofit' ||
          normalizedFitPolicy == 'wraptolines' ||
          normalizedFitPolicy == 'ellipsisaftermaxlines' ||
          normalizedFitPolicy == 'cliptoframe' ||
          normalizedFitPolicy == 'shorten' ||
          normalizedFitPolicy == 'scalexfornumericonly';
      final maxLines =
          _doubleFromMap(textFrame, const <String>['maxLines']) ?? 1.0;
      final estimatedWidth = _estimateTextWidth(
        record.element,
        fontSize: record.state.fontSize,
        letterSpacing: record.state.letterSpacing,
        typewriterProgress: record.state.typewriterProgress,
      );
      final estimatedHeight = _estimateTextHeight(
            record.element,
            fontSize: record.state.fontSize,
            lineHeight: record.state.lineHeight,
          ) *
          maxLines;
      final overflowX = math.max(0.0, estimatedWidth - frameWidth);
      final overflowY = math.max(0.0, estimatedHeight - frameHeight);
      final overflowPx = math.max(overflowX, overflowY).toDouble();
      final overflowDetected = overflowPx > 1.0;
      final permissiveLegacyPolicy =
          !enforceOverflowAsError && normalizedFitPolicy == 'none';
      final overflowSeverity = (supportedFitPolicy || permissiveLegacyPolicy)
          ? ReFusionSceneProgramIssueSeverity.warning
          : ReFusionSceneProgramIssueSeverity.error;
      if (overflowDetected) {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: overflowSeverity,
            message: 'Text element `${record.element.id}` '
                '${hasTypewriter ? 'reveal' : 'static'} bounded frame overflow detected. '
                'fitPolicy=$fitPolicy '
                'estimatedWidth=${estimatedWidth.toStringAsFixed(2)} '
                'estimatedHeight=${estimatedHeight.toStringAsFixed(2)} '
                'frameWidth=${frameWidth.toStringAsFixed(2)} '
                'frameHeight=${frameHeight.toStringAsFixed(2)} '
                'timelineTimeMs=${snapshot.timelineTimeMs}',
            path:
                'layers[${record.layerIndex}].elements[${record.elementIndex}].properties.textFrame',
          ),
        );
      }

      final clippingPx = _clippingPixels(record.worldBounds);
      final clipped = clippingPx > 0.0;
      final safeAreaViolation = _violatesSafeArea(record.worldBounds);
      final overlap = overlapKeys.contains(record.nodeId);
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

      if (clipped) {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.warning,
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
            severity: ReFusionSceneProgramIssueSeverity.warning,
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
            severity: ReFusionSceneProgramIssueSeverity.warning,
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
            severity: ReFusionSceneProgramIssueSeverity.warning,
            message:
                'Text element `${record.element.id}` is desynced from parent at frame ${snapshot.timelineTimeMs}ms.',
            path:
                'layers[${record.layerIndex}].elements[${record.elementIndex}]',
          ),
        );
      }

      final passed = !overflowDetected &&
          !clipped &&
          !safeAreaViolation &&
          !overlap &&
          !parentChildDesync &&
          contrastPass &&
          !unfinishedMotion;
      final failureReason = passed
          ? 'none'
          : _firstFailureReason(
              textOverflow: overflowDetected,
              clipped: clipped,
              overlap: overlap,
              safeAreaViolation: safeAreaViolation,
              parentChildDesync: parentChildDesync,
              unfinishedMotion: unfinishedMotion,
            );
      _emitProbeProof(
        record: record,
        probeIndex: probeIndex,
        probeCount: probeCount,
        textOverflow: overflowDetected,
        overflowPx: overflowPx,
        clippingPx: clippingPx,
        overlapDetected: overlap,
        safeAreaViolation: safeAreaViolation,
        parentChildDesync: parentChildDesync,
        passed: passed,
        failureReason: failureReason,
        severity: passed
            ? ReFusionSceneProgramIssueSeverity.info
            : ReFusionSceneProgramIssueSeverity.error,
        fallbackReason: perfExceeded ? 'probe_budget_exceeded' : fallbackReason,
        timelineTimeMs: snapshot.timelineTimeMs,
        issues: issues,
      );
    }
  }

  void _emitProbeProof({
    required _EvaluatedNodeRecord record,
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

  _ElementEvaluationState _evaluateElementState({
    required ReFusionSceneProgramLayer layer,
    required ReFusionSceneProgramElement element,
    required int timelineTimeMs,
  }) {
    var x = _readPosition(element.properties, 'x');
    var y = _readPosition(element.properties, 'y');
    var width = _readScalar(
      element.properties,
      const <String>['width', 'w'],
    );
    var height = _readScalar(
      element.properties,
      const <String>['height', 'h'],
    );
    final textFrame = _mapFromProperties(
      element.properties,
      const <String>['textFrame', 'layoutTextFrame'],
    );
    width ??= _doubleFromMap(textFrame, const <String>['width', 'maxWidth']);
    height ??= _doubleFromMap(textFrame, const <String>['height', 'maxHeight']);
    var scaleX = _readScalar(
          element.properties,
          const <String>['scaleX'],
        ) ??
        _readScalar(
          element.properties,
          const <String>['scale'],
        ) ??
        1.0;
    var scaleY = _readScalar(
          element.properties,
          const <String>['scaleY'],
        ) ??
        _readScalar(
          element.properties,
          const <String>['scale'],
        ) ??
        1.0;
    var rotationDeg = _readScalar(
          element.properties,
          const <String>['rotationDeg', 'rotation'],
        ) ??
        0.0;
    var opacity = _readScalar(
          element.properties,
          const <String>['opacity', 'alpha'],
        ) ??
        1.0;
    var fontSize = _readScalar(
          element.properties,
          const <String>['fontSize', 'fontsize'],
        ) ??
        16.0;
    var lineHeight = _readScalar(
          element.properties,
          const <String>['lineHeight', 'lineheight'],
        ) ??
        1.0;
    var letterSpacing = _readScalar(
          element.properties,
          const <String>['letterSpacing', 'tracking'],
        ) ??
        0.0;
    var typewriterProgress = _readScalar(
          element.properties,
          const <String>['typewriterProgress'],
        ) ??
        1.0;

    final allChannels = <ReFusionSceneProgramChannel>[
      ...layer.channels.where(
        (channel) =>
            _normalizeToken(channel.target) == _normalizeToken(element.id),
      ),
      ...element.channels,
    ];
    for (final channel in allChannels) {
      final property = _normalizeToken(channel.property);
      final value = _evaluateChannel(channel, timelineTimeMs);
      if (value == null) {
        continue;
      }
      if (property == 'x' ||
          property == 'left' ||
          property == 'positionx' ||
          property == 'position.x') {
        x = value;
      } else if (property == 'y' ||
          property == 'top' ||
          property == 'positiony' ||
          property == 'position.y') {
        y = value;
      } else if (property == 'width' || property == 'w') {
        width = value;
      } else if (property == 'height' || property == 'h') {
        height = value;
      } else if (property == 'scale' || property == 'scalex') {
        scaleX = value;
      } else if (property == 'scaley') {
        scaleY = value;
      } else if (property == 'rotation' || property == 'rotationdeg') {
        rotationDeg = value;
      } else if (property == 'opacity' || property == 'alpha') {
        opacity = value;
      } else if (property == 'fontsize') {
        fontSize = value;
      } else if (property == 'lineheight') {
        lineHeight = value;
      } else if (property == 'letterspacing' || property == 'tracking') {
        letterSpacing = value;
      } else if (property == 'typewriterprogress') {
        typewriterProgress = value.clamp(0.0, 1.0);
      }
    }

    width ??= _estimateTextWidth(
      element,
      fontSize: fontSize,
      letterSpacing: letterSpacing,
      typewriterProgress: 1.0,
    );
    height ??= _estimateTextHeight(
      element,
      fontSize: fontSize,
      lineHeight: lineHeight,
    );

    return _ElementEvaluationState(
      x: x ?? 0.0,
      y: y ?? 0.0,
      width: math.max(1.0, width ?? 1.0),
      height: math.max(1.0, height ?? 1.0),
      scaleX: scaleX,
      scaleY: scaleY,
      rotationDeg: rotationDeg,
      opacity: opacity,
      fontSize: fontSize,
      lineHeight: lineHeight,
      letterSpacing: letterSpacing,
      typewriterProgress: typewriterProgress.clamp(0.0, 1.0),
    );
  }

  double? _evaluateChannel(
    ReFusionSceneProgramChannel channel,
    int timelineTimeMs,
  ) {
    if (channel.keyframes.isEmpty) {
      return null;
    }
    final keyframes = channel.keyframes.toList(growable: false)
      ..sort((left, right) => left.timeMs.compareTo(right.timeMs));
    if (timelineTimeMs <= keyframes.first.timeMs) {
      return _asDouble(keyframes.first.value);
    }
    if (timelineTimeMs >= keyframes.last.timeMs) {
      return _asDouble(keyframes.last.value);
    }
    for (var index = 1; index < keyframes.length; index += 1) {
      final left = keyframes[index - 1];
      final right = keyframes[index];
      if (timelineTimeMs < left.timeMs || timelineTimeMs > right.timeMs) {
        continue;
      }
      final leftValue = _asDouble(left.value);
      final rightValue = _asDouble(right.value);
      if (leftValue == null || rightValue == null) {
        return leftValue ?? rightValue;
      }
      final span = right.timeMs - left.timeMs;
      if (span <= 0) {
        return rightValue;
      }
      final rawT = (timelineTimeMs - left.timeMs) / span;
      final easedT = _applyEasing(
        easing: right.easing ?? left.easing ?? 'linear',
        t: rawT.clamp(0.0, 1.0),
      );
      return leftValue + ((rightValue - leftValue) * easedT);
    }
    return null;
  }

  double _applyEasing({required String easing, required double t}) {
    final normalized = _normalizeToken(easing);
    if (normalized == 'linear') {
      return t;
    }
    if (normalized == 'easein' || normalized == 'slowfast') {
      return t * t;
    }
    if (normalized == 'easeout' || normalized == 'fastslow') {
      final inv = 1.0 - t;
      return 1.0 - (inv * inv);
    }
    if (normalized == 'easeinout' ||
        normalized == 'easyease' ||
        normalized == 'cinematicease' ||
        normalized == 'slowfastslow') {
      return t * t * (3 - (2 * t));
    }
    if (normalized == 'fastslowfast') {
      return 0.5 - (math.cos(math.pi * t) / 2.0);
    }
    return t;
  }

  String _resolveRuntimeParentId({
    required String layerId,
    required ReFusionSceneProgramElement element,
  }) {
    final parentValue = element.properties['parentId'];
    if (parentValue is! String || parentValue.trim().isEmpty) {
      return '__layer__${layerId}__root';
    }
    return _runtimeNodeId(layerId, parentValue.trim());
  }

  SceneRuntimeNodeType _runtimeTypeForElementKind(String kind) {
    final normalized = _normalizeToken(kind);
    switch (normalized) {
      case 'text':
        return SceneRuntimeNodeType.text;
      case 'icon':
        return SceneRuntimeNodeType.icon;
      case 'image':
        return SceneRuntimeNodeType.image;
      case 'video':
        return SceneRuntimeNodeType.video;
      case 'shape':
      default:
        return SceneRuntimeNodeType.shape;
    }
  }

  String _runtimeNodeId(String layerId, String elementId) =>
      '__layer__${layerId}__element__${elementId}';

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
  });

  final int timelineTimeMs;
  final List<_EvaluatedNodeRecord> records;
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
}

class _ElementEvaluationState {
  const _ElementEvaluationState({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.scaleX,
    required this.scaleY,
    required this.rotationDeg,
    required this.opacity,
    required this.fontSize,
    required this.lineHeight,
    required this.letterSpacing,
    required this.typewriterProgress,
  });

  final double x;
  final double y;
  final double width;
  final double height;
  final double scaleX;
  final double scaleY;
  final double rotationDeg;
  final double opacity;
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
