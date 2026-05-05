import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/master_time_models.dart';
import 'package:refusion_app/features/editor/domain/models/master_value_truth_models.dart';
import 'package:refusion_app/features/editor/domain/models/master_visual_program_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/domain/models/trueframe_execution_graph_models.dart';
import 'package:refusion_app/features/editor/domain/models/trueframe_runtime_evaluator_models.dart';
import 'package:refusion_app/features/editor/domain/services/master_render_graph_adapter.dart';
import 'package:refusion_app/features/editor/domain/services/timeline_clock_coordinator.dart';
import 'package:refusion_app/features/editor/domain/services/trueframe_core_runtime_evaluator.dart';
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
            positionX: 12,
            positionY: -8,
            scaleX: 1.08,
            scaleY: 1.04,
            rotationRadians: 0.21,
          ),
          opacity: 0.82,
          motionBlur: const MasterMotionBlurPolicy(
            enabled: true,
            amount: 1,
            shutterAngleDegrees: 180,
            shutterPhaseDegrees: -90,
            samples: 7,
            adaptiveSampleLimit: 12,
          ),
          effects: const <MasterVisualEffectBinding>[
            MasterVisualEffectBinding(
              id: 'gaussianBlur',
              rendererValue: 9,
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
        ),
      ],
      transitionState: MasterVisualTransitionState(
        activeTransitionIds: const <String>['transition-1'],
        hasRenderableTransitionPixels: false,
        reason: 'manual_transition_runtime_slice',
      ),
    );
  }

  MasterVisualProgram _phaseILayerFamilyProgram() {
    final clock = TimelineClockCoordinator(
      timelineDuration: ms(12000),
      initialTime: ms(3000),
    );
    final time = MasterTimeSnapshot.fromClockSnapshot(
      clock: clock.snapshot,
      frameRate: 30,
      renderMode: MasterRenderMode.preview,
      sourceScope: MasterTimeScope.rootComposition,
    );
    return MasterVisualProgram(
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
        reason: 'phase_i_runtime_layer_families',
      ),
    );
  }

  test(
      'evaluates composition/node states from trueframe graph deterministically',
      () {
    const masterAdapter = MasterRenderGraphAdapter();
    final masterGraph =
        masterAdapter.build(program: _manualTransitionProgram());
    const graphAdapter = TrueFrameExecutionGraphAdapter();
    final trueFrameGraph = graphAdapter
        .project(
          TrueFrameExecutionGraphProjectionRequest(
            masterGraph: masterGraph,
            transitionId: 'transition-1',
            outgoingTargetId: 'clip-A',
            incomingTargetId: 'clip-B',
          ),
        )
        .graph;

    const evaluator = TrueFrameCoreRuntimeEvaluator();
    final frameState = evaluator.evaluateCompositionAt(
      graph: trueFrameGraph,
      qualityMode: TrueFrameSamplingQualityMode.playback,
    );

    expect(frameState.blockers, isEmpty);
    expect(frameState.nodeStatesByNodeId.length, 2);
    final outgoing = frameState.nodeStatesByNodeId['composite:clip-A'];
    final incoming = frameState.nodeStatesByNodeId['composite:clip-B'];
    expect(outgoing, isNotNull);
    expect(incoming, isNotNull);
    expect(outgoing!.visibility, isTrue);
    expect(
      outgoing.resolvedLayerFamilies,
      contains(TrueFrameExecutionNodeFamily.videoLayer.name),
    );
    expect(outgoing.gaussianBlurSigmaPx, 9);
    expect(outgoing.opacity, closeTo(0.82, 1e-9));
    expect(outgoing.motionBlurSamplingPlan, isNotNull);
    expect(outgoing.motionBlurSamplingPlan!.enabled, isTrue);
    expect(
      outgoing.motionBlurSamplingPlan!.sampleCount,
      lessThanOrEqualTo(7),
    );
    expect(
      outgoing.motionBlurSamplingPlan!.sampleCount,
      greaterThan(1),
    );
    expect(incoming!.motionBlurSamplingPlan, isNull);
  });

  test('buildSamplingPlan respects quality profile sample caps', () {
    const masterAdapter = MasterRenderGraphAdapter();
    final masterGraph =
        masterAdapter.build(program: _manualTransitionProgram());
    const graphAdapter = TrueFrameExecutionGraphAdapter();
    final trueFrameGraph = graphAdapter
        .project(
          TrueFrameExecutionGraphProjectionRequest(
            masterGraph: masterGraph,
            transitionId: 'transition-1',
            outgoingTargetId: 'clip-A',
            incomingTargetId: 'clip-B',
          ),
        )
        .graph;

    const evaluator = TrueFrameCoreRuntimeEvaluator();
    final previewPlan = evaluator.buildSamplingPlan(
      graph: trueFrameGraph,
      nodeId: 'clip-A',
      qualityMode: TrueFrameSamplingQualityMode.preview,
    );
    final exportPlan = evaluator.buildSamplingPlan(
      graph: trueFrameGraph,
      nodeId: 'clip-A',
      qualityMode: TrueFrameSamplingQualityMode.export,
    );

    expect(previewPlan.enabled, isTrue);
    expect(exportPlan.enabled, isTrue);
    expect(previewPlan.sampleCount, lessThanOrEqualTo(5));
    expect(
        exportPlan.sampleCount, greaterThanOrEqualTo(previewPlan.sampleCount));
    expect(
      exportPlan.diagnostics,
      contains('trueframe_motion_blur_plan_from_graph'),
    );
  });

  test('runtime evaluator resolves group/scene clip/adjustment layer families',
      () {
    const masterAdapter = MasterRenderGraphAdapter();
    final masterGraph =
        masterAdapter.build(program: _phaseILayerFamilyProgram());
    const graphAdapter = TrueFrameExecutionGraphAdapter();
    final trueFrameGraph = graphAdapter
        .project(
          TrueFrameExecutionGraphProjectionRequest(masterGraph: masterGraph),
        )
        .graph;

    const evaluator = TrueFrameCoreRuntimeEvaluator();
    final frameState = evaluator.evaluateCompositionAt(
      graph: trueFrameGraph,
      qualityMode: TrueFrameSamplingQualityMode.preview,
    );

    final groupState = frameState.nodeStatesByNodeId['composite:unit-a'];
    final sceneState = frameState.nodeStatesByNodeId['composite:unit-b'];
    final adjustmentState = frameState.nodeStatesByNodeId['composite:unit-c'];

    expect(groupState, isNotNull);
    expect(sceneState, isNotNull);
    expect(adjustmentState, isNotNull);

    expect(
      groupState!.resolvedLayerFamilies,
      contains(TrueFrameExecutionNodeFamily.groupPrecomp.name),
    );
    expect(
      sceneState!.resolvedLayerFamilies,
      contains(TrueFrameExecutionNodeFamily.sceneClipInstance.name),
    );
    expect(
      adjustmentState!.resolvedLayerFamilies,
      contains(TrueFrameExecutionNodeFamily.adjustmentControl.name),
    );
  });
}
