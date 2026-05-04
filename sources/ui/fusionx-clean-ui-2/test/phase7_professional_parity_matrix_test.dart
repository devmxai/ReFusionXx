import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/master_frame_evaluation_models.dart';
import 'package:refusion_app/features/editor/domain/models/master_live_scrub_descriptor_models.dart';
import 'package:refusion_app/features/editor/domain/models/master_render_graph_models.dart';
import 'package:refusion_app/features/editor/domain/models/master_renderer_adapter_models.dart';
import 'package:refusion_app/features/editor/domain/models/master_renderer_contract_models.dart';
import 'package:refusion_app/features/editor/domain/models/master_time_models.dart';
import 'package:refusion_app/features/editor/domain/models/master_value_truth_models.dart';
import 'package:refusion_app/features/editor/domain/models/master_visual_program_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_animation_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/domain/services/master_render_graph_adapter.dart';
import 'package:refusion_app/features/editor/domain/services/master_renderer_frame_adapters.dart';
import 'package:refusion_app/features/editor/domain/services/master_value_truth_registry.dart';
import 'package:refusion_app/features/editor/domain/services/master_visual_program_adapter.dart';
import 'package:refusion_app/features/editor/domain/services/timeline_clock_coordinator.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';

class _EvalInput {
  _EvalInput({
    required this.targetId,
    required this.channelId,
    required this.channelDefinition,
    required this.propertyDefinitionId,
    required this.value,
    this.domain = const MasterTimeDomain.scene('scene-1'),
    this.status = 'resolved',
  });

  final String targetId;
  final String channelId;
  final MotionPropertyDefinition channelDefinition;
  final String propertyDefinitionId;
  final MotionPropertyValue value;
  final MasterTimeDomain domain;
  final String status;
}

class _ChainResult {
  const _ChainResult({
    required this.frame,
    required this.program,
    required this.graph,
    required this.rendererResult,
  });

  final MasterFrameEvaluation frame;
  final MasterVisualProgram program;
  final MasterRenderGraph graph;
  final MasterRendererFrameResult rendererResult;
}

void main() {
  TimelineTime ms(int value) => TimelineTime.fromMilliseconds(value);

  MotionPropertyDefinition visualColorDefinition() => MotionPropertyDefinition(
        id: 'visual.color',
        path: const MotionPropertyPath(
          group: MotionPropertyGroup.visual,
          name: 'color',
        ),
        valueKind: MotionPropertyValueKind.colorArgb,
        supportedTargets: const <MotionTargetKind>[MotionTargetKind.element],
        defaultValue: const MotionPropertyValue.colorArgb(0xFFFFFFFF),
      );

  MotionPropertyDefinition maskRevealDefinition() => MotionPropertyDefinition(
        id: 'mask.revealProgress',
        path: const MotionPropertyPath(
          group: MotionPropertyGroup.shape,
          name: 'maskRevealProgress',
        ),
        valueKind: MotionPropertyValueKind.scalar,
        supportedTargets: const <MotionTargetKind>[MotionTargetKind.element],
        defaultValue: const MotionPropertyValue.scalar(0),
      );

  MasterTimeSnapshot buildTime({
    required MasterRenderMode mode,
    required int rootTimeMs,
  }) {
    final clock = TimelineClockCoordinator(
      timelineDuration: ms(24000),
      initialTime: ms(rootTimeMs),
    );
    final snapshot = MasterTimeSnapshot.fromClockSnapshot(
      clock: clock.snapshot,
      frameRate: 30,
      renderMode: mode,
      sourceScope: MasterTimeScope.rootComposition,
    );
    clock.dispose();
    return snapshot;
  }

  MotionPropertyTarget targetFor(String targetId) => MotionPropertyTarget(
        kind: MotionTargetKind.element,
        targetId: targetId,
        projectId: 'project-1',
        sceneId: 'scene-1',
        layerId: 'layer-${targetId.replaceAll('element-', '')}',
        elementId: targetId,
      );

  _ChainResult runChain({
    required MasterRenderMode mode,
    required int rootTimeMs,
    required List<String> visibleLayerIds,
    required Map<String, MasterVisualSourceBinding> sourcesByTargetId,
    required List<_EvalInput> evaluatedInputs,
    List<String> activeTransitionIds = const <String>[],
    Map<String, MasterVisualTransitionRole> transitionRolesByTargetId =
        const <String, MasterVisualTransitionRole>{},
    List<MasterTimeProjection> projections = const <MasterTimeProjection>[],
  }) {
    final registry = MasterValueTruthRegistry();
    const visualAdapter = MasterVisualProgramAdapter();
    const graphAdapter = MasterRenderGraphAdapter();
    const frameAdapters = MasterRendererFrameAdapters();
    final time = buildTime(mode: mode, rootTimeMs: rootTimeMs);

    MasterPropertyValueMapping mappingFor(
      String propertyDefinitionId,
      MotionPropertyValue value,
    ) {
      final definition = registry.definitionById(propertyDefinitionId);
      expect(definition, isNotNull,
          reason: 'missing master definition: $propertyDefinitionId');
      return registry.mapValue(definition: definition!, value: value);
    }

    final channels = <MotionPropertyChannelModel>[
      for (final input in evaluatedInputs)
        MotionPropertyChannelModel(
          id: input.channelId,
          target: targetFor(input.targetId),
          definition: input.channelDefinition,
          keyframes: const <MotionKeyframeModel>[],
        ),
    ];

    final frame = MasterFrameEvaluation(
      time: time,
      projections: projections,
      visibleLayerIds: visibleLayerIds,
      activeTransitionIds: activeTransitionIds,
      evaluatedChannels: <MasterEvaluatedPropertyValue>[
        for (final input in evaluatedInputs)
          MasterEvaluatedPropertyValue(
            targetId: input.targetId,
            propertyDefinitionId: input.propertyDefinitionId,
            domain: input.domain,
            mapping: mappingFor(input.propertyDefinitionId, input.value),
            sourceChannelId: input.channelId,
            status: input.status,
          ),
      ],
    );

    final program = visualAdapter.build(
      frame: frame,
      sourcesByTargetId: sourcesByTargetId,
      transitionRolesByTargetId: transitionRolesByTargetId,
      channels: channels,
    );
    final graph = graphAdapter.build(program: program);

    final requestedSourceIds = <String>[
      for (final surface in program.surfaces)
        if (surface.source != null) surface.targetId,
    ];
    final surfaceId = MasterRendererContracts.runtimeBridgeSurfaceIdForMode(
      switch (mode) {
        MasterRenderMode.preview => MasterRendererAdapterMode.preview,
        MasterRenderMode.playback => MasterRendererAdapterMode.playback,
        MasterRenderMode.liveScrub ||
        MasterRenderMode.settle ||
        MasterRenderMode.test =>
          MasterRendererAdapterMode.liveScrub,
        MasterRenderMode.export => MasterRendererAdapterMode.export,
      },
    );
    final requestId =
        'phase7:${mode.name}:${time.commitFrameNumber}:${time.frameIndex}';
    final sourceRevision =
        'phase7-source:${Object.hashAll(requestedSourceIds)}';

    final rendererResult = switch (mode) {
      MasterRenderMode.preview => frameAdapters.projectPreview(
          program: program,
          renderGraph: graph,
          requestId: requestId,
          sourceRevision: sourceRevision,
          surfaceId: surfaceId,
          nativePresentationAck: true,
          presentedRootTimeMs: time.rootTime.inMilliseconds,
          presentedFrameIndex: time.frameIndex,
          presentedCommitFrameNumber: time.commitFrameNumber,
          presentedSourceIds: requestedSourceIds,
        ),
      MasterRenderMode.playback => frameAdapters.projectPlayback(
          program: program,
          renderGraph: graph,
          requestId: requestId,
          sourceRevision: sourceRevision,
          surfaceId: surfaceId,
          nativePresentationAck: true,
          presentedRootTimeMs: time.rootTime.inMilliseconds,
          presentedFrameIndex: time.frameIndex,
          presentedCommitFrameNumber: time.commitFrameNumber,
          presentedSourceIds: requestedSourceIds,
        ),
      MasterRenderMode.liveScrub ||
      MasterRenderMode.settle ||
      MasterRenderMode.test =>
        frameAdapters.projectLiveScrub(
          program: program,
          renderGraph: graph,
          requestId: requestId,
          sourceRevision: sourceRevision,
          surfaceId: surfaceId,
          nativePresentationAck: true,
          presentedRootTimeMs: time.rootTime.inMilliseconds,
          presentedFrameIndex: time.frameIndex,
          presentedCommitFrameNumber: time.commitFrameNumber,
          presentedSourceIds: requestedSourceIds,
        ),
      MasterRenderMode.export => frameAdapters.projectExport(
          program: program,
          renderGraph: graph,
          requestId: requestId,
          sourceRevision: sourceRevision,
          surfaceId: surfaceId,
          nativePresentationAck: true,
          presentedRootTimeMs: time.rootTime.inMilliseconds,
          presentedFrameIndex: time.frameIndex,
          presentedCommitFrameNumber: time.commitFrameNumber,
          presentedSourceIds: requestedSourceIds,
        ),
    };

    return _ChainResult(
      frame: frame,
      program: program,
      graph: graph,
      rendererResult: rendererResult,
    );
  }

  void expectParityChain(
    _ChainResult result, {
    int? expectedScopeLocalMs,
    MasterTimeDomainKind expectedScopeKind = MasterTimeDomainKind.scene,
  }) {
    final frame = result.frame;
    final program = result.program;
    final graph = result.graph;
    final proof = result.rendererResult.proof;

    final sourceIds = <String>[
      for (final surface in program.surfaces)
        if (surface.source != null) surface.targetId,
    ]..sort();
    final proofRequested = [...proof.requestedSourceIds]..sort();

    expect(frame.evaluatedChannels, isNotEmpty);
    expect(frame.time.rootTime.inMilliseconds, graph.rootTimeMs);
    expect(frame.time.rootTime.inMilliseconds, proof.requestedRootTimeMs);
    expect(frame.time.frameIndex, graph.frameIndex);
    expect(frame.time.frameIndex, proof.requestedFrameIndex);
    expect(frame.time.commitFrameNumber, proof.requestedCommitFrameNumber);
    expect(proofRequested, sourceIds);
    expect(result.program.blockers, isEmpty);
    expect(result.graph.blockers, isEmpty);
    expect(result.rendererResult.blockers, isEmpty);
    expect(proof.matchState, RendererPresentationMatchState.matched);
    expect(proof.matchReason, 'renderer_acknowledged');
    expect(graph.outputNodeId, 'output:${frame.time.renderMode.name}');
    expect(proof.surfaceId, isNotNull);

    if (expectedScopeLocalMs != null) {
      final projection = frame.projections.firstWhere(
        (candidate) => candidate.toDomain.kind == expectedScopeKind,
      );
      expect(projection.outputTime.inMilliseconds, expectedScopeLocalMs);
    }
  }

  Map<String, MasterVisualSourceBinding> sourcesAB() =>
      const <String, MasterVisualSourceBinding>{
        'element-a': MasterVisualSourceBinding(
          targetId: 'element-a',
          kind: MasterVisualSourceKind.video,
          sourceUri: '/media/a.mp4',
          scrubStoreKey: 'clip-a',
        ),
        'element-b': MasterVisualSourceBinding(
          targetId: 'element-b',
          kind: MasterVisualSourceKind.video,
          sourceUri: '/media/b.mp4',
          scrubStoreKey: 'clip-b',
        ),
      };

  test('phase7 parity: video scale keyframes', () {
    final result = runChain(
      mode: MasterRenderMode.preview,
      rootTimeMs: 1000,
      visibleLayerIds: const <String>['element-a'],
      sourcesByTargetId: const <String, MasterVisualSourceBinding>{
        'element-a': MasterVisualSourceBinding(
          targetId: 'element-a',
          kind: MasterVisualSourceKind.video,
          sourceUri: '/media/a.mp4',
        ),
      },
      evaluatedInputs: <_EvalInput>[
        _EvalInput(
          targetId: 'element-a',
          channelId: 'ch.scale.x',
          channelDefinition: MotionPropertyCatalog.scaleX,
          propertyDefinitionId: 'scale',
          value: MotionPropertyValue.scalar(1.4),
        ),
      ],
    );
    expect(result.program.surfaces.single.transform.scaleX, closeTo(1.4, 1e-6));
    expectParityChain(result);
  });

  test('phase7 parity: video rotation keyframes', () {
    final result = runChain(
      mode: MasterRenderMode.preview,
      rootTimeMs: 1200,
      visibleLayerIds: const <String>['element-a'],
      sourcesByTargetId: const <String, MasterVisualSourceBinding>{
        'element-a': MasterVisualSourceBinding(
          targetId: 'element-a',
          kind: MasterVisualSourceKind.video,
          sourceUri: '/media/a.mp4',
        ),
      },
      evaluatedInputs: <_EvalInput>[
        _EvalInput(
          targetId: 'element-a',
          channelId: 'ch.rotation',
          channelDefinition: MotionPropertyCatalog.rotationDegrees,
          propertyDefinitionId: 'rotation',
          value: MotionPropertyValue.scalar(90),
        ),
      ],
    );
    expect(
      result.program.surfaces.single.transform.rotationRadians,
      closeTo(1.5707963267, 1e-6),
    );
    expectParityChain(result);
  });

  test('phase7 parity: track A + B without transition', () {
    final result = runChain(
      mode: MasterRenderMode.playback,
      rootTimeMs: 1800,
      visibleLayerIds: const <String>['element-a', 'element-b'],
      sourcesByTargetId: sourcesAB(),
      evaluatedInputs: <_EvalInput>[
        _EvalInput(
          targetId: 'element-a',
          channelId: 'ch.a.opacity',
          channelDefinition: MotionPropertyCatalog.opacity,
          propertyDefinitionId: 'opacity',
          value: MotionPropertyValue.scalar(100),
        ),
        _EvalInput(
          targetId: 'element-b',
          channelId: 'ch.b.opacity',
          channelDefinition: MotionPropertyCatalog.opacity,
          propertyDefinitionId: 'opacity',
          value: MotionPropertyValue.scalar(100),
        ),
      ],
    );
    expect(result.program.transitionState.activeTransitionIds, isEmpty);
    expectParityChain(result);
  });

  test('phase7 parity: track A + B with manual transition', () {
    final result = runChain(
      mode: MasterRenderMode.liveScrub,
      rootTimeMs: 2050,
      visibleLayerIds: const <String>['element-a', 'element-b'],
      sourcesByTargetId: sourcesAB(),
      activeTransitionIds: const <String>['tr-manual-1'],
      transitionRolesByTargetId: const <String, MasterVisualTransitionRole>{
        'element-a': MasterVisualTransitionRole.outgoing,
        'element-b': MasterVisualTransitionRole.incoming,
      },
      evaluatedInputs: <_EvalInput>[
        _EvalInput(
          targetId: 'element-a',
          channelId: 'ch.a.scale',
          channelDefinition: MotionPropertyCatalog.scaleX,
          propertyDefinitionId: 'scale',
          value: MotionPropertyValue.scalar(1.1),
        ),
        _EvalInput(
          targetId: 'element-b',
          channelId: 'ch.b.scale',
          channelDefinition: MotionPropertyCatalog.scaleX,
          propertyDefinitionId: 'scale',
          value: MotionPropertyValue.scalar(0.9),
        ),
      ],
    );
    expect(result.program.transitionState.hasTransitionWindow, isTrue);
    expectParityChain(result);
  });

  test('phase7 parity: track A + B with normal transition', () {
    final result = runChain(
      mode: MasterRenderMode.preview,
      rootTimeMs: 2080,
      visibleLayerIds: const <String>['element-a', 'element-b'],
      sourcesByTargetId: sourcesAB(),
      activeTransitionIds: const <String>['tr-normal-1'],
      transitionRolesByTargetId: const <String, MasterVisualTransitionRole>{
        'element-a': MasterVisualTransitionRole.outgoing,
        'element-b': MasterVisualTransitionRole.incoming,
      },
      evaluatedInputs: <_EvalInput>[
        _EvalInput(
          targetId: 'element-a',
          channelId: 'ch.a.opacity',
          channelDefinition: MotionPropertyCatalog.opacity,
          propertyDefinitionId: 'opacity',
          value: MotionPropertyValue.scalar(70),
        ),
        _EvalInput(
          targetId: 'element-b',
          channelId: 'ch.b.opacity',
          channelDefinition: MotionPropertyCatalog.opacity,
          propertyDefinitionId: 'opacity',
          value: MotionPropertyValue.scalar(60),
        ),
      ],
    );
    expect(result.program.transitionState.hasTransitionWindow, isTrue);
    expectParityChain(result);
  });

  test('phase7 parity: image layer transform animation', () {
    final result = runChain(
      mode: MasterRenderMode.preview,
      rootTimeMs: 1400,
      visibleLayerIds: const <String>['element-image'],
      sourcesByTargetId: const <String, MasterVisualSourceBinding>{
        'element-image': MasterVisualSourceBinding(
          targetId: 'element-image',
          kind: MasterVisualSourceKind.image,
          sourceUri: '/media/image.png',
        ),
      },
      evaluatedInputs: <_EvalInput>[
        _EvalInput(
          targetId: 'element-image',
          channelId: 'ch.img.pos.x',
          channelDefinition: MotionPropertyCatalog.positionX,
          propertyDefinitionId: 'position',
          value: MotionPropertyValue.scalar(220),
        ),
        _EvalInput(
          targetId: 'element-image',
          channelId: 'ch.img.pos.y',
          channelDefinition: MotionPropertyCatalog.positionY,
          propertyDefinitionId: 'position',
          value: MotionPropertyValue.scalar(-120),
        ),
      ],
    );
    expect(result.program.surfaces.single.sourceKind,
        MasterVisualSourceKind.image);
    expectParityChain(result);
  });

  test('phase7 parity: text layer transform/style animation', () {
    final result = runChain(
      mode: MasterRenderMode.preview,
      rootTimeMs: 1500,
      visibleLayerIds: const <String>['element-text'],
      sourcesByTargetId: const <String, MasterVisualSourceBinding>{
        'element-text': MasterVisualSourceBinding(
          targetId: 'element-text',
          kind: MasterVisualSourceKind.image,
          sourceUri: '/media/text-raster.png',
        ),
      },
      evaluatedInputs: <_EvalInput>[
        _EvalInput(
          targetId: 'element-text',
          channelId: 'ch.text.fontSize',
          channelDefinition: MotionPropertyCatalog.fontSize,
          propertyDefinitionId: 'textFontSize',
          value: MotionPropertyValue.scalar(56),
        ),
        _EvalInput(
          targetId: 'element-text',
          channelId: 'ch.text.fontFamily',
          channelDefinition: MotionPropertyCatalog.fontFamily,
          propertyDefinitionId: 'textFontFamily',
          value: MotionPropertyValue.stringValue('Inter'),
        ),
      ],
    );
    expect(
        result.program.surfaces.single.textStyle.fontSize, closeTo(56, 1e-6));
    expect(result.program.surfaces.single.textStyle.fontFamily, 'Inter');
    expectParityChain(result);
  });

  test('phase7 parity: shape layer geometry/style animation', () {
    final result = runChain(
      mode: MasterRenderMode.preview,
      rootTimeMs: 1600,
      visibleLayerIds: const <String>['element-shape'],
      sourcesByTargetId: const <String, MasterVisualSourceBinding>{
        'element-shape': MasterVisualSourceBinding(
          targetId: 'element-shape',
          kind: MasterVisualSourceKind.image,
          sourceUri: '/media/shape.png',
        ),
      },
      evaluatedInputs: <_EvalInput>[
        _EvalInput(
          targetId: 'element-shape',
          channelId: 'ch.shape.width',
          channelDefinition: MotionPropertyCatalog.width,
          propertyDefinitionId: 'shapeWidth',
          value: MotionPropertyValue.scalar(640),
        ),
        _EvalInput(
          targetId: 'element-shape',
          channelId: 'ch.shape.height',
          channelDefinition: MotionPropertyCatalog.height,
          propertyDefinitionId: 'shapeHeight',
          value: MotionPropertyValue.scalar(360),
        ),
        _EvalInput(
          targetId: 'element-shape',
          channelId: 'ch.shape.corner',
          channelDefinition: MotionPropertyCatalog.cornerRadius,
          propertyDefinitionId: 'shapeCornerRadius',
          value: MotionPropertyValue.scalar(24),
        ),
      ],
    );
    final surface = result.program.surfaces.single;
    expect(surface.shapeStyle.width, closeTo(640, 1e-6));
    expect(surface.shapeStyle.height, closeTo(360, 1e-6));
    expectParityChain(result);
  });

  test('phase7 parity: scene clip instance transform animation', () {
    final result = runChain(
      mode: MasterRenderMode.playback,
      rootTimeMs: 2400,
      visibleLayerIds: const <String>['element-a'],
      sourcesByTargetId: const <String, MasterVisualSourceBinding>{
        'element-a': MasterVisualSourceBinding(
          targetId: 'element-a',
          kind: MasterVisualSourceKind.video,
          sourceUri: '/media/a.mp4',
        ),
      },
      projections: <MasterTimeProjection>[
        MasterTimeProjection(
          fromDomain: const MasterTimeDomain.root(),
          toDomain: const MasterTimeDomain.scene('scene-1'),
          inputTime: ms(2400),
          outputTime: ms(400),
          policy: MasterTimeProjectionPolicy.clamp,
          reason: 'scene_instance_projection',
        ),
      ],
      evaluatedInputs: <_EvalInput>[
        _EvalInput(
          targetId: 'element-a',
          channelId: 'ch.scene.pos.x',
          channelDefinition: MotionPropertyCatalog.positionX,
          propertyDefinitionId: 'position',
          value: MotionPropertyValue.scalar(140),
        ),
      ],
    );
    expectParityChain(result, expectedScopeLocalMs: 400);
  });

  test('phase7 parity: nested scene scope layer animation', () {
    final result = runChain(
      mode: MasterRenderMode.preview,
      rootTimeMs: 3500,
      visibleLayerIds: const <String>['element-a'],
      sourcesByTargetId: const <String, MasterVisualSourceBinding>{
        'element-a': MasterVisualSourceBinding(
          targetId: 'element-a',
          kind: MasterVisualSourceKind.video,
          sourceUri: '/media/a.mp4',
        ),
      },
      projections: <MasterTimeProjection>[
        MasterTimeProjection(
          fromDomain: const MasterTimeDomain.root(),
          toDomain: const MasterTimeDomain.composition('scene-nested'),
          inputTime: ms(3500),
          outputTime: ms(500),
          policy: MasterTimeProjectionPolicy.sourceRateAdjusted,
          reason: 'nested_scope_projection',
        ),
      ],
      evaluatedInputs: <_EvalInput>[
        _EvalInput(
          targetId: 'element-a',
          channelId: 'ch.nested.opacity',
          channelDefinition: MotionPropertyCatalog.opacity,
          propertyDefinitionId: 'opacity',
          value: MotionPropertyValue.scalar(82),
          domain: MasterTimeDomain.composition('scene-nested'),
        ),
      ],
    );
    expectParityChain(
      result,
      expectedScopeLocalMs: 500,
      expectedScopeKind: MasterTimeDomainKind.composition,
    );
  });

  test('phase7 parity: scrub forward then backward across boundary', () {
    final forward = runChain(
      mode: MasterRenderMode.liveScrub,
      rootTimeMs: 3990,
      visibleLayerIds: const <String>['element-a', 'element-b'],
      sourcesByTargetId: sourcesAB(),
      evaluatedInputs: <_EvalInput>[
        _EvalInput(
          targetId: 'element-a',
          channelId: 'ch.scrub.forward',
          channelDefinition: MotionPropertyCatalog.opacity,
          propertyDefinitionId: 'opacity',
          value: MotionPropertyValue.scalar(98),
        ),
      ],
    );
    final backward = runChain(
      mode: MasterRenderMode.liveScrub,
      rootTimeMs: 2010,
      visibleLayerIds: const <String>['element-a', 'element-b'],
      sourcesByTargetId: sourcesAB(),
      evaluatedInputs: <_EvalInput>[
        _EvalInput(
          targetId: 'element-b',
          channelId: 'ch.scrub.backward',
          channelDefinition: MotionPropertyCatalog.opacity,
          propertyDefinitionId: 'opacity',
          value: MotionPropertyValue.scalar(96),
        ),
      ],
    );
    expectParityChain(forward);
    expectParityChain(backward);
    expect(
      forward.rendererResult.proof.requestedRootTimeMs >
          backward.rendererResult.proof.requestedRootTimeMs,
      isTrue,
    );
  });

  test('phase7 parity: scrub, release, then play on same frame', () {
    final scrub = runChain(
      mode: MasterRenderMode.liveScrub,
      rootTimeMs: 2500,
      visibleLayerIds: const <String>['element-a'],
      sourcesByTargetId: const <String, MasterVisualSourceBinding>{
        'element-a': MasterVisualSourceBinding(
          targetId: 'element-a',
          kind: MasterVisualSourceKind.video,
          sourceUri: '/media/a.mp4',
        ),
      },
      evaluatedInputs: <_EvalInput>[
        _EvalInput(
          targetId: 'element-a',
          channelId: 'ch.scrub.scale',
          channelDefinition: MotionPropertyCatalog.scaleX,
          propertyDefinitionId: 'scale',
          value: MotionPropertyValue.scalar(1.2),
        ),
      ],
    );
    final play = runChain(
      mode: MasterRenderMode.playback,
      rootTimeMs: 2500,
      visibleLayerIds: const <String>['element-a'],
      sourcesByTargetId: const <String, MasterVisualSourceBinding>{
        'element-a': MasterVisualSourceBinding(
          targetId: 'element-a',
          kind: MasterVisualSourceKind.video,
          sourceUri: '/media/a.mp4',
        ),
      },
      evaluatedInputs: <_EvalInput>[
        _EvalInput(
          targetId: 'element-a',
          channelId: 'ch.play.scale',
          channelDefinition: MotionPropertyCatalog.scaleX,
          propertyDefinitionId: 'scale',
          value: MotionPropertyValue.scalar(1.2),
        ),
      ],
    );
    expectParityChain(scrub);
    expectParityChain(play);
    expect(
      scrub.rendererResult.proof.requestedRootTimeMs,
      play.rendererResult.proof.requestedRootTimeMs,
    );
    expect(
      scrub.program.surfaces.single.transform.scaleX,
      play.program.surfaces.single.transform.scaleX,
    );
  });

  test('phase7 parity: play, pause, scrub, play again', () {
    final playA = runChain(
      mode: MasterRenderMode.playback,
      rootTimeMs: 1800,
      visibleLayerIds: const <String>['element-a'],
      sourcesByTargetId: const <String, MasterVisualSourceBinding>{
        'element-a': MasterVisualSourceBinding(
          targetId: 'element-a',
          kind: MasterVisualSourceKind.video,
          sourceUri: '/media/a.mp4',
        ),
      },
      evaluatedInputs: <_EvalInput>[
        _EvalInput(
          targetId: 'element-a',
          channelId: 'ch.playA.opacity',
          channelDefinition: MotionPropertyCatalog.opacity,
          propertyDefinitionId: 'opacity',
          value: MotionPropertyValue.scalar(88),
        ),
      ],
    );
    final scrub = runChain(
      mode: MasterRenderMode.liveScrub,
      rootTimeMs: 2200,
      visibleLayerIds: const <String>['element-a'],
      sourcesByTargetId: const <String, MasterVisualSourceBinding>{
        'element-a': MasterVisualSourceBinding(
          targetId: 'element-a',
          kind: MasterVisualSourceKind.video,
          sourceUri: '/media/a.mp4',
        ),
      },
      evaluatedInputs: <_EvalInput>[
        _EvalInput(
          targetId: 'element-a',
          channelId: 'ch.pause.scrub.opacity',
          channelDefinition: MotionPropertyCatalog.opacity,
          propertyDefinitionId: 'opacity',
          value: MotionPropertyValue.scalar(76),
        ),
      ],
    );
    final playB = runChain(
      mode: MasterRenderMode.playback,
      rootTimeMs: 2200,
      visibleLayerIds: const <String>['element-a'],
      sourcesByTargetId: const <String, MasterVisualSourceBinding>{
        'element-a': MasterVisualSourceBinding(
          targetId: 'element-a',
          kind: MasterVisualSourceKind.video,
          sourceUri: '/media/a.mp4',
        ),
      },
      evaluatedInputs: <_EvalInput>[
        _EvalInput(
          targetId: 'element-a',
          channelId: 'ch.playB.opacity',
          channelDefinition: MotionPropertyCatalog.opacity,
          propertyDefinitionId: 'opacity',
          value: MotionPropertyValue.scalar(76),
        ),
      ],
    );
    expectParityChain(playA);
    expectParityChain(scrub);
    expectParityChain(playB);
    expect(
      scrub.rendererResult.proof.requestedRootTimeMs,
      playB.rendererResult.proof.requestedRootTimeMs,
    );
  });

  test('phase7 parity: export sample at same frame', () {
    final result = runChain(
      mode: MasterRenderMode.export,
      rootTimeMs: 5000,
      visibleLayerIds: const <String>['element-a'],
      sourcesByTargetId: const <String, MasterVisualSourceBinding>{
        'element-a': MasterVisualSourceBinding(
          targetId: 'element-a',
          kind: MasterVisualSourceKind.video,
          sourceUri: '/media/a.mp4',
        ),
      },
      evaluatedInputs: <_EvalInput>[
        _EvalInput(
          targetId: 'element-a',
          channelId: 'ch.export.scale',
          channelDefinition: MotionPropertyCatalog.scaleY,
          propertyDefinitionId: 'scale',
          value: MotionPropertyValue.scalar(1.35),
        ),
      ],
    );
    expect(result.rendererResult.mode, MasterRendererAdapterMode.export);
    expectParityChain(result);
  });

  test('phase7 parity: expression-driven property at fixed frame', () {
    final result = runChain(
      mode: MasterRenderMode.preview,
      rootTimeMs: 2100,
      visibleLayerIds: const <String>['element-a'],
      sourcesByTargetId: const <String, MasterVisualSourceBinding>{
        'element-a': MasterVisualSourceBinding(
          targetId: 'element-a',
          kind: MasterVisualSourceKind.video,
          sourceUri: '/media/a.mp4',
        ),
      },
      evaluatedInputs: <_EvalInput>[
        _EvalInput(
          targetId: 'element-a',
          channelId: 'ch.expr.blur',
          channelDefinition: MotionPropertyCatalog.blurAmount,
          propertyDefinitionId: 'gaussianBlur',
          value: MotionPropertyValue.scalar(12),
          status: 'resolved_expression',
        ),
      ],
    );
    expect(
      result.frame.evaluatedChannels.single.status,
      'resolved_expression',
    );
    expectParityChain(result);
  });

  test('phase7 parity: crop/mask/effect sample at fixed frame', () {
    final result = runChain(
      mode: MasterRenderMode.preview,
      rootTimeMs: 3000,
      visibleLayerIds: const <String>['element-a'],
      sourcesByTargetId: const <String, MasterVisualSourceBinding>{
        'element-a': MasterVisualSourceBinding(
          targetId: 'element-a',
          kind: MasterVisualSourceKind.video,
          sourceUri: '/media/a.mp4',
        ),
      },
      evaluatedInputs: <_EvalInput>[
        _EvalInput(
          targetId: 'element-a',
          channelId: 'ch.crop.rect',
          channelDefinition: MotionPropertyCatalog.cropRect,
          propertyDefinitionId: 'cropRect',
          value: MotionPropertyValue.rect(
            MotionRect(left: 0.1, top: 0.15, width: 0.8, height: 0.7),
          ),
        ),
        _EvalInput(
          targetId: 'element-a',
          channelId: 'ch.mask.reveal',
          channelDefinition: maskRevealDefinition(),
          propertyDefinitionId: 'maskRevealProgress',
          value: const MotionPropertyValue.scalar(55),
        ),
        _EvalInput(
          targetId: 'element-a',
          channelId: 'ch.shadow.color',
          channelDefinition: MotionPropertyCatalog.shadowColor,
          propertyDefinitionId: 'shadowColor',
          value: MotionPropertyValue.colorArgb(0xFF223344),
        ),
        _EvalInput(
          targetId: 'element-a',
          channelId: 'ch.visual.color',
          channelDefinition: visualColorDefinition(),
          propertyDefinitionId: 'visualColor',
          value: const MotionPropertyValue.colorArgb(0xFFAACCEE),
        ),
        _EvalInput(
          targetId: 'element-a',
          channelId: 'ch.gaussian.blur',
          channelDefinition: MotionPropertyCatalog.blurAmount,
          propertyDefinitionId: 'gaussianBlur',
          value: MotionPropertyValue.scalar(9),
        ),
      ],
    );
    final surface = result.program.surfaces.single;
    expect(surface.crop.hasCrop, isTrue);
    expect(surface.mask.hasMask, isTrue);
    expect(surface.colors.hasColorStyle, isTrue);
    expectParityChain(result);
  });
}
