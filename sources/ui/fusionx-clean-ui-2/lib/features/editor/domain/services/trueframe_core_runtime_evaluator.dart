import 'dart:math' as math;

import '../models/trueframe_execution_graph_models.dart';
import '../models/trueframe_runtime_evaluator_models.dart';

class TrueFrameCoreRuntimeEvaluator {
  const TrueFrameCoreRuntimeEvaluator();

  CompositionFrameState evaluateCompositionAt({
    required TrueFrameExecutionGraph graph,
    required TrueFrameSamplingQualityMode qualityMode,
  }) {
    final nodeStatesById = <String, NodeFrameState>{};
    final diagnostics = <String>[
      'trueframe_runtime_eval_root:${graph.rootTimeMs}',
      'trueframe_runtime_eval_quality:${qualityMode.name}',
    ];
    final blockers = <String>[...graph.blockers];
    final compositeNodes = graph.nodes
        .where(
          (node) => node.family == TrueFrameExecutionNodeFamily.blendComposite,
        )
        .toList(growable: false)
      ..sort((left, right) {
        final leftOrder = _nodeDrawOrder(left);
        final rightOrder = _nodeDrawOrder(right);
        if (leftOrder != rightOrder) {
          return leftOrder.compareTo(rightOrder);
        }
        return left.id.compareTo(right.id);
      });
    for (final node in compositeNodes) {
      final state = evaluateNodeAt(
        graph: graph,
        nodeId: node.id,
        qualityMode: qualityMode,
      );
      nodeStatesById[state.nodeId] = state;
      blockers.addAll(state.blockers);
      diagnostics.addAll(state.diagnostics);
    }
    return CompositionFrameState(
      rootTimeMs: graph.rootTimeMs,
      nodeStatesByNodeId:
          Map<String, NodeFrameState>.unmodifiable(nodeStatesById),
      diagnostics: List<String>.unmodifiable(diagnostics),
      blockers: List<String>.unmodifiable(blockers),
    );
  }

  NodeFrameState evaluateNodeAt({
    required TrueFrameExecutionGraph graph,
    required String nodeId,
    required TrueFrameSamplingQualityMode qualityMode,
  }) {
    final nodeById = <String, TrueFrameExecutionNode>{
      for (final node in graph.nodes) node.id: node,
    };
    final compositeNode = nodeById[nodeId];
    if (compositeNode == null ||
        compositeNode.family != TrueFrameExecutionNodeFamily.blendComposite) {
      return NodeFrameState(
        rootTimeMs: graph.rootTimeMs,
        localTimeMs: graph.rootTimeMs,
        sourceTimeMs: graph.rootTimeMs,
        nodeId: nodeId,
        targetId: nodeId,
        sourceId: '',
        visibility: false,
        transformMatrix3x3: const <double>[1, 0, 0, 0, 1, 0, 0, 0, 1],
        positionX: 0,
        positionY: 0,
        scaleX: 1,
        scaleY: 1,
        rotationRadians: 0,
        opacity: 1,
        crop: null,
        maskRevealProgress: null,
        gaussianBlurSigmaPx: null,
        motionBlurSamplingPlan: null,
        effectValues: const <String, Object?>{},
        bounds: null,
        blendMode: 'normal',
        zOrder: 0,
        diagnostics: const <String>[],
        blockers: const <String>['trueframe_node_not_found_or_not_composite'],
      );
    }
    final targetId = compositeNode.targetId;
    final binding = graph.surfaceBindings
        .where((entry) => entry.targetId == targetId)
        .cast<TrueFrameExecutionSurfaceBinding?>()
        .firstWhere(
          (entry) => entry != null,
          orElse: () => null,
        );
    if (binding == null) {
      return NodeFrameState(
        rootTimeMs: graph.rootTimeMs,
        localTimeMs: graph.rootTimeMs,
        sourceTimeMs: graph.rootTimeMs,
        nodeId: nodeId,
        targetId: targetId,
        sourceId: '',
        visibility: false,
        transformMatrix3x3: const <double>[1, 0, 0, 0, 1, 0, 0, 0, 1],
        positionX: 0,
        positionY: 0,
        scaleX: 1,
        scaleY: 1,
        rotationRadians: 0,
        opacity: 1,
        crop: null,
        maskRevealProgress: null,
        gaussianBlurSigmaPx: null,
        motionBlurSamplingPlan: null,
        effectValues: const <String, Object?>{},
        bounds: null,
        blendMode: 'normal',
        zOrder: 0,
        diagnostics: const <String>[],
        blockers: const <String>['trueframe_binding_not_found'],
      );
    }

    final transformNode = nodeById[binding.transformNodeId];
    final sourceNode =
        binding.sourceNodeId == null ? null : nodeById[binding.sourceNodeId!];
    final cropNode =
        binding.cropNodeId == null ? null : nodeById[binding.cropNodeId!];
    final maskNode =
        binding.maskNodeId == null ? null : nodeById[binding.maskNodeId!];
    final motionBlurNode = binding.motionBlurNodeId == null
        ? null
        : nodeById[binding.motionBlurNodeId!];
    final effectNodes = <TrueFrameExecutionNode>[
      for (final id in binding.effectNodeIds)
        if (nodeById[id] != null) nodeById[id]!,
    ];
    final diagnostics = <String>[
      'trueframe_node_eval:$targetId',
      'trueframe_node_quality:${qualityMode.name}',
    ];
    final blockers = <String>[
      ...binding.blockers,
      if (transformNode == null) 'trueframe_transform_node_missing',
    ];

    final positionX = _readDouble(transformNode?.attributes['positionX']);
    final positionY = _readDouble(transformNode?.attributes['positionY']);
    final scaleX =
        _readDouble(transformNode?.attributes['scaleX'], fallback: 1);
    final scaleY =
        _readDouble(transformNode?.attributes['scaleY'], fallback: 1);
    final rotationRadians =
        _readDouble(transformNode?.attributes['rotationRadians']);
    final opacity =
        _readDouble(transformNode?.attributes['opacity'], fallback: 1)
            .clamp(0.0, 1.0)
            .toDouble();
    final matrix = _matrix3x3(
      positionX: positionX,
      positionY: positionY,
      scaleX: scaleX,
      scaleY: scaleY,
      rotationRadians: rotationRadians,
    );
    final gaussianBlurSigmaPx = _extractGaussianBlur(effectNodes);
    final effectValues = <String, Object?>{
      for (final effectNode in effectNodes)
        if (effectNode.attributes['effectId'] is String)
          effectNode.attributes['effectId'] as String: effectNode.attributes,
    };
    final motionBlurPlan = motionBlurNode == null
        ? null
        : buildSamplingPlan(
            graph: graph,
            nodeId: targetId,
            qualityMode: qualityMode,
          );

    return NodeFrameState(
      rootTimeMs: graph.rootTimeMs,
      localTimeMs: graph.rootTimeMs,
      sourceTimeMs: graph.rootTimeMs,
      nodeId: compositeNode.id,
      targetId: targetId,
      sourceId: sourceNode?.targetId ?? targetId,
      visibility: sourceNode != null,
      transformMatrix3x3: matrix,
      positionX: positionX,
      positionY: positionY,
      scaleX: scaleX,
      scaleY: scaleY,
      rotationRadians: rotationRadians,
      opacity: opacity,
      crop: cropNode == null
          ? null
          : MotionCropFrameState(
              left: _readDouble(cropNode.attributes['left']),
              top: _readDouble(cropNode.attributes['top']),
              width: _readDouble(cropNode.attributes['width'], fallback: 1),
              height: _readDouble(cropNode.attributes['height'], fallback: 1),
            ),
      maskRevealProgress: maskNode == null
          ? null
          : _readDouble(maskNode.attributes['revealProgress']),
      gaussianBlurSigmaPx: gaussianBlurSigmaPx,
      motionBlurSamplingPlan: motionBlurPlan,
      effectValues: Map<String, Object?>.unmodifiable(effectValues),
      bounds: MotionBoundsFrameState(
        left: 0,
        top: 0,
        width: graph.outputWidth.toDouble(),
        height: graph.outputHeight.toDouble(),
      ),
      blendMode: 'normal',
      zOrder: binding.drawOrder,
      diagnostics: List<String>.unmodifiable(diagnostics),
      blockers: List<String>.unmodifiable(blockers),
    );
  }

  EffectStackFrameState evaluateEffectStackAt({
    required TrueFrameExecutionGraph graph,
    required String nodeId,
  }) {
    final binding = graph.surfaceBindings
        .where((entry) =>
            entry.compositeNodeId == nodeId || entry.targetId == nodeId)
        .cast<TrueFrameExecutionSurfaceBinding?>()
        .firstWhere((entry) => entry != null, orElse: () => null);
    if (binding == null) {
      return const EffectStackFrameState(
        nodeId: '',
        effectDescriptors: <Map<String, Object?>>[],
        diagnostics: <String>[],
        blockers: <String>['trueframe_effect_stack_binding_missing'],
      );
    }
    final nodeById = <String, TrueFrameExecutionNode>{
      for (final node in graph.nodes) node.id: node,
    };
    final effects = <Map<String, Object?>>[];
    for (final effectNodeId in binding.effectNodeIds) {
      final node = nodeById[effectNodeId];
      if (node == null) {
        continue;
      }
      effects.add(Map<String, Object?>.unmodifiable(node.attributes));
    }
    return EffectStackFrameState(
      nodeId: binding.compositeNodeId,
      effectDescriptors: List<Map<String, Object?>>.unmodifiable(effects),
      diagnostics: const <String>[],
      blockers: const <String>[],
    );
  }

  CoreMotionBlurSamplingPlan buildSamplingPlan({
    required TrueFrameExecutionGraph graph,
    required String nodeId,
    required TrueFrameSamplingQualityMode qualityMode,
  }) {
    final nodeById = <String, TrueFrameExecutionNode>{
      for (final node in graph.nodes) node.id: node,
    };
    final binding = graph.surfaceBindings
        .where((entry) =>
            entry.targetId == nodeId || entry.compositeNodeId == nodeId)
        .cast<TrueFrameExecutionSurfaceBinding?>()
        .firstWhere((entry) => entry != null, orElse: () => null);
    final fallbackDisabled = CoreMotionBlurSamplingPlan(
      enabled: false,
      nodeId: nodeId,
      rootTimeMs: graph.rootTimeMs,
      shutterOpenTimeMs: graph.rootTimeMs,
      shutterCloseTimeMs: graph.rootTimeMs,
      sampleTimesMs: const <int>[],
      sampleWeights: const <double>[],
      sampleTransforms: const <List<double>>[],
      sampleNodeStates: const <TrueFrameNodeMotionBlurSampleState>[],
      amount: 0,
      shutterAngleDegrees: 0,
      shutterPhaseDegrees: 0,
      sampleCount: 0,
      adaptiveSampleLimit: 0,
      qualityMode: qualityMode,
      diagnostics: const <String>[],
      blockers: const <String>[],
    );
    if (binding == null || binding.motionBlurNodeId == null) {
      return fallbackDisabled;
    }
    final motionNode = nodeById[binding.motionBlurNodeId!];
    final transformNode = nodeById[binding.transformNodeId];
    if (motionNode == null || transformNode == null) {
      return CoreMotionBlurSamplingPlan(
        enabled: false,
        nodeId: nodeId,
        rootTimeMs: graph.rootTimeMs,
        shutterOpenTimeMs: graph.rootTimeMs,
        shutterCloseTimeMs: graph.rootTimeMs,
        sampleTimesMs: const <int>[],
        sampleWeights: const <double>[],
        sampleTransforms: const <List<double>>[],
        sampleNodeStates: const <TrueFrameNodeMotionBlurSampleState>[],
        amount: 0,
        shutterAngleDegrees: 0,
        shutterPhaseDegrees: 0,
        sampleCount: 0,
        adaptiveSampleLimit: 0,
        qualityMode: qualityMode,
        diagnostics: const <String>[],
        blockers: const <String>[
          'trueframe_motion_blur_node_or_transform_missing'
        ],
      );
    }
    final enabled = motionNode.attributes['enabled'] == true;
    final amount = _readDouble(motionNode.attributes['amount']).clamp(0.0, 1.0);
    final shutterAngle = _readDouble(
        motionNode.attributes['shutterAngleDegrees'],
        fallback: 180);
    final shutterPhase = _readDouble(
        motionNode.attributes['shutterPhaseDegrees'],
        fallback: -90);
    final adaptiveSampleLimit =
        _readInt(motionNode.attributes['adaptiveSampleLimit'], fallback: 1);
    final sampleOffsetsMs =
        _readDoubleList(motionNode.attributes['sampleOffsetsMs']);
    final effectiveOffsets = _offsetsForQuality(
      rawOffsets: sampleOffsetsMs,
      qualityMode: qualityMode,
    );
    if (!enabled || amount <= 0.0001 || effectiveOffsets.length <= 1) {
      return CoreMotionBlurSamplingPlan(
        enabled: false,
        nodeId: nodeId,
        rootTimeMs: graph.rootTimeMs,
        shutterOpenTimeMs: graph.rootTimeMs,
        shutterCloseTimeMs: graph.rootTimeMs,
        sampleTimesMs: const <int>[],
        sampleWeights: const <double>[],
        sampleTransforms: const <List<double>>[],
        sampleNodeStates: const <TrueFrameNodeMotionBlurSampleState>[],
        amount: amount.toDouble(),
        shutterAngleDegrees: shutterAngle,
        shutterPhaseDegrees: shutterPhase,
        sampleCount: 0,
        adaptiveSampleLimit: adaptiveSampleLimit,
        qualityMode: qualityMode,
        diagnostics: const <String>[
          'trueframe_motion_blur_disabled_or_no_offsets'
        ],
        blockers: const <String>[],
      );
    }
    final positionX = _readDouble(transformNode.attributes['positionX']);
    final positionY = _readDouble(transformNode.attributes['positionY']);
    final scaleX = _readDouble(transformNode.attributes['scaleX'], fallback: 1);
    final scaleY = _readDouble(transformNode.attributes['scaleY'], fallback: 1);
    final rotationRadians =
        _readDouble(transformNode.attributes['rotationRadians']);
    final opacity =
        _readDouble(transformNode.attributes['opacity'], fallback: 1)
            .clamp(0.0, 1.0)
            .toDouble();
    final affectPosition = motionNode.attributes['affectPosition'] == true;
    final affectScale = motionNode.attributes['affectScale'] == true;
    final affectRotation = motionNode.attributes['affectRotation'] == true;

    final sampleTimesMs = <int>[];
    final sampleTransforms = <List<double>>[];
    final sampleStates = <TrueFrameNodeMotionBlurSampleState>[];
    for (final offset in effectiveOffsets) {
      final sampleTime = graph.rootTimeMs + offset.round();
      sampleTimesMs.add(sampleTime);
      final offsetFactor = effectiveOffsets.length <= 1
          ? 0.0
          : (offset / (effectiveOffsets.last - effectiveOffsets.first));
      final centeredFactor = (offsetFactor - 0.5) * 2.0;
      final sampleMatrix = _matrix3x3(
        positionX: affectPosition
            ? positionX + (centeredFactor * amount * 6.0)
            : positionX,
        positionY: affectPosition
            ? positionY + (centeredFactor * amount * 6.0)
            : positionY,
        scaleX: affectScale
            ? scaleX * (1 + centeredFactor * amount * 0.02)
            : scaleX,
        scaleY: affectScale
            ? scaleY * (1 + centeredFactor * amount * 0.02)
            : scaleY,
        rotationRadians: affectRotation
            ? rotationRadians + centeredFactor * amount * 0.02
            : rotationRadians,
      );
      sampleTransforms.add(sampleMatrix);
      sampleStates.add(
        TrueFrameNodeMotionBlurSampleState(
          sampleTimeMs: sampleTime,
          transformMatrix3x3: sampleMatrix,
          opacity: opacity,
          sourceId: binding.sourceNodeId ?? nodeId,
        ),
      );
    }
    final weights = <double>[
      for (var i = 0; i < sampleTimesMs.length; i += 1)
        1 / sampleTimesMs.length,
    ];
    return CoreMotionBlurSamplingPlan(
      enabled: true,
      nodeId: nodeId,
      rootTimeMs: graph.rootTimeMs,
      shutterOpenTimeMs: sampleTimesMs.first,
      shutterCloseTimeMs: sampleTimesMs.last,
      sampleTimesMs: List<int>.unmodifiable(sampleTimesMs),
      sampleWeights: List<double>.unmodifiable(weights),
      sampleTransforms: List<List<double>>.unmodifiable(sampleTransforms),
      sampleNodeStates:
          List<TrueFrameNodeMotionBlurSampleState>.unmodifiable(sampleStates),
      amount: amount.toDouble(),
      shutterAngleDegrees: shutterAngle,
      shutterPhaseDegrees: shutterPhase,
      sampleCount: sampleTimesMs.length,
      adaptiveSampleLimit: adaptiveSampleLimit,
      qualityMode: qualityMode,
      diagnostics: const <String>['trueframe_motion_blur_plan_from_graph'],
      blockers: const <String>[],
    );
  }

  int _nodeDrawOrder(TrueFrameExecutionNode node) {
    final raw = node.attributes['drawOrder'];
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.round();
    }
    return 0;
  }

  List<double> _offsetsForQuality({
    required List<double> rawOffsets,
    required TrueFrameSamplingQualityMode qualityMode,
  }) {
    if (rawOffsets.isEmpty) {
      return const <double>[];
    }
    final maxSamples = switch (qualityMode) {
      TrueFrameSamplingQualityMode.preview => 5,
      TrueFrameSamplingQualityMode.liveScrub => 4,
      TrueFrameSamplingQualityMode.playback => 7,
      TrueFrameSamplingQualityMode.export => rawOffsets.length,
    };
    if (rawOffsets.length <= maxSamples) {
      return List<double>.unmodifiable(rawOffsets);
    }
    final selected = <double>[];
    for (var index = 0; index < maxSamples; index += 1) {
      final t = maxSamples == 1 ? 0.0 : index / (maxSamples - 1);
      final sourceIndex = (t * (rawOffsets.length - 1)).round();
      selected.add(rawOffsets[sourceIndex]);
    }
    return List<double>.unmodifiable(selected);
  }

  double? _extractGaussianBlur(List<TrueFrameExecutionNode> effectNodes) {
    for (final effectNode in effectNodes) {
      final effectId = effectNode.attributes['effectId'];
      if (effectId == 'gaussianBlur') {
        return _readDouble(effectNode.attributes['rendererValue']);
      }
    }
    return null;
  }

  List<double> _matrix3x3({
    required double positionX,
    required double positionY,
    required double scaleX,
    required double scaleY,
    required double rotationRadians,
  }) {
    final cosTheta = math.cos(rotationRadians);
    final sinTheta = math.sin(rotationRadians);
    final m00 = scaleX * cosTheta;
    final m01 = -scaleY * sinTheta;
    final m10 = scaleX * sinTheta;
    final m11 = scaleY * cosTheta;
    return <double>[
      m00,
      m01,
      positionX,
      m10,
      m11,
      positionY,
      0.0,
      0.0,
      1.0,
    ];
  }

  int _readInt(Object? raw, {required int fallback}) {
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.round();
    }
    return fallback;
  }

  double _readDouble(Object? raw, {double fallback = 0.0}) {
    if (raw is num) {
      return raw.toDouble();
    }
    return fallback;
  }

  List<double> _readDoubleList(Object? raw) {
    if (raw is! List) {
      return const <double>[];
    }
    return raw
        .whereType<num>()
        .map((entry) => entry.toDouble())
        .toList(growable: false);
  }
}
