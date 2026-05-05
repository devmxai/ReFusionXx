import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/master_time_models.dart';
import 'package:refusion_app/features/editor/domain/models/master_value_truth_models.dart';
import 'package:refusion_app/features/editor/domain/models/master_visual_program_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/domain/models/trueframe_execution_graph_models.dart';
import 'package:refusion_app/features/editor/domain/services/master_render_graph_adapter.dart';
import 'package:refusion_app/features/editor/domain/services/timeline_clock_coordinator.dart';
import 'package:refusion_app/features/editor/domain/services/trueframe_execution_graph_adapter.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';

void main() {
  TimelineTime ms(int value) => TimelineTime.fromMilliseconds(value);

  MasterVisualProgram _manualTransitionProgram() {
    final clock = TimelineClockCoordinator(
      timelineDuration: ms(12000),
      initialTime: ms(6100),
    );
    final time = MasterTimeSnapshot.fromClockSnapshot(
      clock: clock.snapshot,
      frameRate: 30,
      renderMode: MasterRenderMode.liveScrub,
      sourceScope: MasterTimeScope.rootComposition,
    );
    return MasterVisualProgram(
      time: time,
      surfaces: <MasterVisualSurface>[
        MasterVisualSurface(
          targetId: 'clip-A',
          sourceKind: MasterVisualSourceKind.video,
          drawOrder: 0,
          source: const MasterVisualSourceBinding(
            targetId: 'clip-A',
            kind: MasterVisualSourceKind.video,
            sourceUri: '/media/a.mp4',
            scrubStoreKey: 'asset-a',
            sourceWidth: 1920,
            sourceHeight: 1080,
          ),
          transitionRole: MasterVisualTransitionRole.outgoing,
          transform: const MasterVisualTransform(
            positionX: -40,
            positionY: 0,
            scaleX: 1.1,
            scaleY: 1.1,
            rotationRadians: 0.12,
          ),
          motionBlur: const MasterMotionBlurPolicy(
            enabled: true,
            amount: 0.8,
            shutterAngleDegrees: 180,
            shutterPhaseDegrees: -90,
            samples: 6,
            adaptiveSampleLimit: 12,
          ),
          effects: const <MasterVisualEffectBinding>[
            MasterVisualEffectBinding(
              id: 'gaussianBlur',
              rendererValue: 8,
              rendererUnit: MasterValueUnit.shaderSigmaPx,
            ),
          ],
        ),
        MasterVisualSurface(
          targetId: 'clip-B',
          sourceKind: MasterVisualSourceKind.video,
          drawOrder: 1,
          source: const MasterVisualSourceBinding(
            targetId: 'clip-B',
            kind: MasterVisualSourceKind.video,
            sourceUri: '/media/b.mp4',
            scrubStoreKey: 'asset-b',
            sourceWidth: 1920,
            sourceHeight: 1080,
          ),
          transitionRole: MasterVisualTransitionRole.incoming,
          transform: const MasterVisualTransform(
            positionX: 0,
            positionY: 0,
            scaleX: 1.0,
            scaleY: 1.0,
            rotationRadians: 0.0,
          ),
        ),
      ],
      transitionState: MasterVisualTransitionState(
        activeTransitionIds: const <String>['transition-1'],
        hasRenderableTransitionPixels: false,
        reason: 'manual_transition_graph_slice',
      ),
    );
  }

  test(
      'projects master render graph into trueframe graph with core node families',
      () {
    const masterAdapter = MasterRenderGraphAdapter();
    final masterGraph =
        masterAdapter.build(program: _manualTransitionProgram());

    const adapter = TrueFrameExecutionGraphAdapter();
    final projection = adapter.project(
      TrueFrameExecutionGraphProjectionRequest(
        masterGraph: masterGraph,
        transitionId: 'transition-1',
        outgoingTargetId: 'clip-A',
        incomingTargetId: 'clip-B',
      ),
    );

    expect(projection.blockers, isEmpty);
    expect(projection.graph.canExecuteTruthfully, isTrue);
    expect(projection.graph.sourceGraphRevision, masterGraph.revision);
    expect(
        projection.graph.nodes.length, greaterThan(masterGraph.nodes.length));
    expect(
      projection.graph.nodes.any(
        (node) => node.family == TrueFrameExecutionNodeFamily.sourceSample,
      ),
      isTrue,
    );
    expect(
      projection.graph.nodes.any(
        (node) => node.family == TrueFrameExecutionNodeFamily.layerTransform,
      ),
      isTrue,
    );
    expect(
      projection.graph.nodes.any(
        (node) => node.family == TrueFrameExecutionNodeFamily.effect,
      ),
      isTrue,
    );
    expect(
      projection.graph.nodes.any(
        (node) =>
            node.family == TrueFrameExecutionNodeFamily.temporalMotionBlur,
      ),
      isTrue,
    );
    expect(
      projection.graph.nodes.any(
        (node) => node.family == TrueFrameExecutionNodeFamily.transition,
      ),
      isTrue,
    );
    expect(
      projection.graph.nodes.any(
        (node) => node.family == TrueFrameExecutionNodeFamily.blendComposite,
      ),
      isTrue,
    );
    expect(
      projection.graph.nodes.any(
        (node) => node.family == TrueFrameExecutionNodeFamily.outputSurface,
      ),
      isTrue,
    );
    expect(
      projection.graph.nodes.any(
        (node) => node.family == TrueFrameExecutionNodeFamily.videoLayer,
      ),
      isTrue,
    );
    expect(
      projection.diagnostics,
      contains('trueframe_transition_node_resolved:transition-1'),
    );
  });

  test('adds blockers when required manual transition bindings are missing',
      () {
    const masterAdapter = MasterRenderGraphAdapter();
    final masterGraph =
        masterAdapter.build(program: _manualTransitionProgram());

    const adapter = TrueFrameExecutionGraphAdapter();
    final projection = adapter.project(
      TrueFrameExecutionGraphProjectionRequest(
        masterGraph: masterGraph,
        transitionId: 'transition-missing',
        outgoingTargetId: 'clip-A',
        incomingTargetId: 'clip-Z',
      ),
    );

    expect(
      projection.blockers,
      contains('trueframe_missing_incoming_target_binding:clip-Z'),
    );
    expect(
      projection.blockers,
      contains('trueframe_missing_transition_node:transition-missing'),
    );
  });

  test('projects image layer family for phase I expansion', () {
    final clock = TimelineClockCoordinator(
      timelineDuration: ms(8000),
      initialTime: ms(1000),
    );
    final time = MasterTimeSnapshot.fromClockSnapshot(
      clock: clock.snapshot,
      frameRate: 30,
      renderMode: MasterRenderMode.preview,
      sourceScope: MasterTimeScope.rootComposition,
    );
    final program = MasterVisualProgram(
      time: time,
      surfaces: <MasterVisualSurface>[
        MasterVisualSurface(
          targetId: 'image-layer-1',
          sourceKind: MasterVisualSourceKind.image,
          source: const MasterVisualSourceBinding(
            targetId: 'image-layer-1',
            kind: MasterVisualSourceKind.image,
            sourceUri: '/media/image.png',
          ),
          textStyle: const MasterVisualTextStyle(
            fontSize: 42,
            alignment: 'center',
          ),
          shapeStyle: const MasterVisualShapeStyle(
            width: 220,
            height: 180,
          ),
        ),
      ],
      transitionState: MasterVisualTransitionState(
        hasRenderableTransitionPixels: false,
        reason: 'phase_i_visual_layer_projection',
      ),
    );

    const masterAdapter = MasterRenderGraphAdapter();
    final graph = masterAdapter.build(program: program);
    const adapter = TrueFrameExecutionGraphAdapter();
    final projection = adapter.project(
      TrueFrameExecutionGraphProjectionRequest(masterGraph: graph),
    );

    expect(
      projection.graph.nodes.any(
        (node) => node.family == TrueFrameExecutionNodeFamily.imageLayer,
      ),
      isTrue,
    );
    expect(projection.graph.nodes, isNotEmpty);
  });

  test('projects group/scene clip/adjustment layer families for phase I', () {
    final clock = TimelineClockCoordinator(
      timelineDuration: ms(9000),
      initialTime: ms(1200),
    );
    final time = MasterTimeSnapshot.fromClockSnapshot(
      clock: clock.snapshot,
      frameRate: 30,
      renderMode: MasterRenderMode.preview,
      sourceScope: MasterTimeScope.rootComposition,
    );
    final program = MasterVisualProgram(
      time: time,
      surfaces: <MasterVisualSurface>[
        MasterVisualSurface(
          targetId: 'unit-a',
          sourceKind: MasterVisualSourceKind.video,
          coreLayerFamilyHint: MasterVisualLayerFamilyHint.groupPrecomp,
          source: const MasterVisualSourceBinding(
            targetId: 'unit-a',
            kind: MasterVisualSourceKind.video,
            sourceUri: '/media/group.mp4',
          ),
        ),
        MasterVisualSurface(
          targetId: 'unit-b',
          sourceKind: MasterVisualSourceKind.image,
          coreLayerFamilyHint: MasterVisualLayerFamilyHint.sceneClipInstance,
          source: const MasterVisualSourceBinding(
            targetId: 'unit-b',
            kind: MasterVisualSourceKind.image,
            sourceUri: '/media/scene.png',
          ),
        ),
        MasterVisualSurface(
          targetId: 'unit-c',
          sourceKind: MasterVisualSourceKind.video,
          coreLayerFamilyHint: MasterVisualLayerFamilyHint.adjustmentControl,
          source: const MasterVisualSourceBinding(
            targetId: 'unit-c',
            kind: MasterVisualSourceKind.video,
            sourceUri: '/media/adjust.mp4',
          ),
        ),
      ],
      transitionState: MasterVisualTransitionState(
        hasRenderableTransitionPixels: false,
        reason: 'phase_i_group_scene_adjustment_projection',
      ),
    );

    const masterAdapter = MasterRenderGraphAdapter();
    final graph = masterAdapter.build(program: program);
    const adapter = TrueFrameExecutionGraphAdapter();
    final projection = adapter.project(
      TrueFrameExecutionGraphProjectionRequest(masterGraph: graph),
    );

    expect(
      projection.graph.nodes.any(
        (node) => node.family == TrueFrameExecutionNodeFamily.groupPrecomp,
      ),
      isTrue,
    );
    expect(
      projection.graph.nodes.any(
        (node) => node.family == TrueFrameExecutionNodeFamily.sceneClipInstance,
      ),
      isTrue,
    );
    expect(
      projection.graph.nodes.any(
        (node) => node.family == TrueFrameExecutionNodeFamily.adjustmentControl,
      ),
      isTrue,
    );
    expect(
      projection.graph.nodes.any(
        (node) => node.diagnostics
            .contains('trueframe_phase_i_family_from_core_hint:groupPrecomp'),
      ),
      isTrue,
    );
    expect(
      projection.graph.nodes.any(
        (node) => node.diagnostics
            .contains('trueframe_phase_i_family_legacy_target_fallback'),
      ),
      isFalse,
    );
  });
}
