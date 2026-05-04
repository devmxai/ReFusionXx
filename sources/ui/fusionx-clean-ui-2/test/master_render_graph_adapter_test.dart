import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/master_render_graph_models.dart';
import 'package:refusion_app/features/editor/domain/models/master_time_models.dart';
import 'package:refusion_app/features/editor/domain/models/master_value_truth_models.dart';
import 'package:refusion_app/features/editor/domain/models/master_visual_program_models.dart';
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
          targetId: 'layer-a',
          sourceKind: MasterVisualSourceKind.video,
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
            .any((node) => node.family == MasterRenderGraphNodeFamily.effect),
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
    final binding = first.bindingForTarget('layer-a');
    expect(binding, isNotNull);
    expect(binding!.effectNodeIds.length, 2);
    expect(binding.transitionNodeId, isNotNull);
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
