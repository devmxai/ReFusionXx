import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/master_render_graph_models.dart';
import 'package:refusion_app/features/editor/domain/models/master_time_models.dart';
import 'package:refusion_app/features/editor/domain/models/master_value_truth_models.dart';
import 'package:refusion_app/features/editor/domain/models/master_visual_program_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/domain/services/master_render_graph_adapter.dart';
import 'package:refusion_app/features/editor/domain/services/timeline_clock_coordinator.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';

void main() {
  TimelineTime ms(int value) => TimelineTime.fromMilliseconds(value);

  test('builds deterministic graph revision and chained effect nodes', () {
    final clock = TimelineClockCoordinator(
      timelineDuration: ms(12000),
      initialTime: ms(2400),
    );
    final time = MasterTimeSnapshot.fromClockSnapshot(
      clock: clock.snapshot,
      frameRate: 30,
      renderMode: MasterRenderMode.liveScrub,
      sourceScope: MasterTimeScope.rootComposition,
    );
    final program = MasterVisualProgram(
      time: time,
      surfaces: <MasterVisualSurface>[
        MasterVisualSurface(
          targetId: 'layer-b',
          sourceKind: MasterVisualSourceKind.image,
          coreLayerFamilyHint: MasterVisualLayerFamilyHint.shapeLayer,
          drawOrder: 0,
          source: const MasterVisualSourceBinding(
            targetId: 'layer-b',
            kind: MasterVisualSourceKind.image,
            sourceUri: '/media/b.png',
            scrubStoreKey: 'clip-b',
            sourceWidth: 1200,
            sourceHeight: 1200,
          ),
          crop: const MasterVisualCrop(
            rect: MotionRect(left: 0.1, top: 0.2, width: 0.7, height: 0.6),
          ),
          mask: const MasterVisualMask(revealProgress: 0.4),
          colors: const MasterVisualColorStyle(
            visualColorArgb: 0xFF112233,
            shadowColorArgb: 0xFF445566,
          ),
          textStyle: const MasterVisualTextStyle(
            fontSize: 42,
            fontFamily: 'Inter',
          ),
          shapeStyle: const MasterVisualShapeStyle(
            width: 640,
            height: 360,
            trimStart: 0.1,
            trimEnd: 0.9,
          ),
        ),
        MasterVisualSurface(
          targetId: 'layer-a',
          sourceKind: MasterVisualSourceKind.video,
          coreLayerFamilyHint: MasterVisualLayerFamilyHint.videoLayer,
          drawOrder: 1,
          source: const MasterVisualSourceBinding(
            targetId: 'layer-a',
            kind: MasterVisualSourceKind.video,
            sourceUri: '/media/a.mp4',
            scrubStoreKey: 'clip-a',
            sourceWidth: 1920,
            sourceHeight: 1080,
          ),
          transitionRole: MasterVisualTransitionRole.outgoing,
          transform: const MasterVisualTransform(
            positionX: 10,
            positionY: -20,
            scaleX: 1.1,
            scaleY: 0.9,
            rotationRadians: 0.25,
          ),
          opacity: 0.8,
          motionBlur: const MasterMotionBlurPolicy(
            enabled: true,
            amount: 1,
            shutterAngleDegrees: 180,
            shutterPhaseDegrees: -90,
            samples: 5,
            adaptiveSampleLimit: 8,
            maxTrailPx: 320,
          ),
          effects: const <MasterVisualEffectBinding>[
            MasterVisualEffectBinding(
              id: 'tileOutputScale',
              rendererValue: 1.5,
              rendererUnit: MasterValueUnit.multiplier,
            ),
            MasterVisualEffectBinding(
              id: 'gaussianBlur',
              rendererValue: 8.0,
              rendererUnit: MasterValueUnit.shaderSigmaPx,
            ),
          ],
        ),
      ],
      transitionState: MasterVisualTransitionState(
        activeTransitionIds: const <String>['tr-1'],
        hasRenderableTransitionPixels: false,
        reason: 'phase5_foundation',
      ),
    );
    const adapter = MasterRenderGraphAdapter();
    final first =
        adapter.build(program: program, outputWidth: 1080, outputHeight: 1920);
    final second =
        adapter.build(program: program, outputWidth: 1080, outputHeight: 1920);

    expect(first.revision, second.revision);
    expect(first.outputNodeId, 'output:liveScrub');
    expect(
        first.nodes.any(
            (node) => node.family == MasterRenderGraphNodeFamily.sourceSample),
        isTrue);
    expect(
        first.nodes.any((node) =>
            node.family == MasterRenderGraphNodeFamily.layerTransform),
        isTrue);
    expect(
        first.nodes
            .any((node) => node.family == MasterRenderGraphNodeFamily.crop),
        isTrue);
    expect(
        first.nodes
            .any((node) => node.family == MasterRenderGraphNodeFamily.mask),
        isTrue);
    expect(
        first.nodes
            .any((node) => node.family == MasterRenderGraphNodeFamily.style),
        isTrue);
    expect(
        first.nodes
            .any((node) => node.family == MasterRenderGraphNodeFamily.effect),
        isTrue);
    expect(
        first.nodes.any((node) =>
            node.family == MasterRenderGraphNodeFamily.temporalMotionBlur),
        isTrue);
    expect(
        first.nodes.any(
            (node) => node.family == MasterRenderGraphNodeFamily.transition),
        isTrue);
    expect(
        first.nodes.any(
            (node) => node.family == MasterRenderGraphNodeFamily.composite),
        isTrue);
    expect(first.nodes.last.family, MasterRenderGraphNodeFamily.outputSurface);
    final layerABinding = first.bindingForTarget('layer-a');
    final layerBBinding = first.bindingForTarget('layer-b');
    expect(layerABinding, isNotNull);
    expect(layerBBinding, isNotNull);
    expect(layerABinding!.effectNodeIds.length, 2);
    expect(layerABinding.motionBlurNodeId, 'motionBlur:layer-a');
    expect(layerABinding.transitionNodeId, isNotNull);
    expect(layerBBinding!.cropNodeId, isNotNull);
    expect(layerBBinding.maskNodeId, isNotNull);
    expect(layerBBinding.styleNodeId, isNotNull);
    final outputNode =
        first.nodes.firstWhere((node) => node.id == first.outputNodeId);
    expect(outputNode.inputNodeIds.first, layerBBinding.compositeNodeId);
    expect(outputNode.inputNodeIds.last, layerABinding.compositeNodeId);
    final motionBlurNode =
        first.nodes.firstWhere((node) => node.id == 'motionBlur:layer-a');
    expect(
        motionBlurNode.inputNodeIds.single, layerABinding.effectNodeIds.last);
    expect(motionBlurNode.attributes['effectId'], 'temporalMotionBlur');
    expect(motionBlurNode.attributes['requiresTemporalSampling'], isTrue);
    expect(motionBlurNode.attributes['fallbackAllowed'], isFalse);
    expect(motionBlurNode.attributes['isSyntheticBlur'], isFalse);
    expect(motionBlurNode.attributes['coreLayerFamilyHint'], 'videoLayer');
    expect(motionBlurNode.attributes['sampleOffsetsMs'], hasLength(5));
    final layerBCompositeNode =
        first.nodes.firstWhere((node) => node.id == 'composite:layer-b');
    expect(layerBCompositeNode.attributes['coreLayerFamilyHint'], 'shapeLayer');
    expect(first.canRenderTruthfully, isTrue);
  });

  test('emits blockers when visual surface has no source binding', () {
    final clock = TimelineClockCoordinator(
      timelineDuration: ms(6000),
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
          targetId: 'layer-b',
          sourceKind: MasterVisualSourceKind.unknown,
        ),
      ],
      transitionState: MasterVisualTransitionState(
        activeTransitionIds: const <String>[],
        hasRenderableTransitionPixels: false,
        reason: 'no_transition',
      ),
    );
    const adapter = MasterRenderGraphAdapter();
    final graph = adapter.build(program: program);
    expect(graph.canRenderTruthfully, isFalse);
    expect(graph.blockers, contains('missing_source_binding:layer-b'));
  });
}
