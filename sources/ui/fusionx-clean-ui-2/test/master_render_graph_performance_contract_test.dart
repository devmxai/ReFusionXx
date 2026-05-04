import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/master_time_models.dart';
import 'package:refusion_app/features/editor/domain/models/master_visual_program_models.dart';
import 'package:refusion_app/features/editor/domain/services/master_render_graph_adapter.dart';
import 'package:refusion_app/features/editor/domain/services/timeline_clock_coordinator.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';

void main() {
  TimelineTime ms(int value) => TimelineTime.fromMilliseconds(value);

  MasterTimeSnapshot _time({
    required int timeMs,
  }) {
    final clock = TimelineClockCoordinator(
      timelineDuration: ms(10000),
      initialTime: ms(timeMs),
    );
    final snapshot = MasterTimeSnapshot.fromClockSnapshot(
      clock: clock.snapshot,
      frameRate: 30,
      renderMode: MasterRenderMode.liveScrub,
      sourceScope: MasterTimeScope.rootComposition,
    );
    clock.dispose();
    return snapshot;
  }

  MasterVisualProgram _program({
    required MasterTimeSnapshot time,
    double scaleX = 1.2,
  }) {
    return MasterVisualProgram(
      time: time,
      surfaces: <MasterVisualSurface>[
        MasterVisualSurface(
          targetId: 'element-1',
          sourceKind: MasterVisualSourceKind.video,
          drawOrder: 0,
          source: const MasterVisualSourceBinding(
            targetId: 'element-1',
            kind: MasterVisualSourceKind.video,
            sourceUri: '/media/a.mp4',
            scrubStoreKey: 'clip-a',
            sourceWidth: 1920,
            sourceHeight: 1080,
          ),
          transform: MasterVisualTransform(
            scaleX: scaleX,
            scaleY: 0.9,
            positionX: 42,
            positionY: -18,
            rotationRadians: 0.2,
          ),
        ),
      ],
      transitionState: MasterVisualTransitionState(
        activeTransitionIds: <String>[],
        hasRenderableTransitionPixels: false,
        reason: 'no_transition',
      ),
    );
  }

  test('scrub-time changes keep node cache keys stable for identical inputs',
      () {
    const adapter = MasterRenderGraphAdapter();
    final first = adapter.build(
      program: _program(
        time: _time(
          timeMs: 1000,
        ),
      ),
    );
    final second = adapter.build(
      program: _program(
        time: _time(
          timeMs: 1333,
        ),
      ),
    );

    expect(first.revision, isNot(second.revision));
    expect(first.nodes.length, second.nodes.length);
    final firstById = {
      for (final node in first.nodes) node.id: node,
    };
    final secondById = {
      for (final node in second.nodes) node.id: node,
    };
    expect(firstById.keys.toSet(), secondById.keys.toSet());
    for (final id in firstById.keys) {
      expect(firstById[id]!.cacheKey, secondById[id]!.cacheKey);
    }
  });

  test('transform edits invalidate transform without source cache churn', () {
    const adapter = MasterRenderGraphAdapter();
    final baseline = adapter.build(
      program: _program(
        time: _time(
          timeMs: 2000,
        ),
        scaleX: 1.2,
      ),
    );
    final changed = adapter.build(
      program: _program(
        time: _time(
          timeMs: 2000,
        ),
        scaleX: 1.6,
      ),
    );
    final sourceBaseline =
        baseline.nodes.firstWhere((node) => node.id == 'source:element-1');
    final sourceChanged =
        changed.nodes.firstWhere((node) => node.id == 'source:element-1');
    final transformBaseline =
        baseline.nodes.firstWhere((node) => node.id == 'transform:element-1');
    final transformChanged =
        changed.nodes.firstWhere((node) => node.id == 'transform:element-1');
    final compositeBaseline =
        baseline.nodes.firstWhere((node) => node.id == 'composite:element-1');
    final compositeChanged =
        changed.nodes.firstWhere((node) => node.id == 'composite:element-1');

    expect(sourceBaseline.cacheKey, sourceChanged.cacheKey);
    expect(transformBaseline.cacheKey, isNot(transformChanged.cacheKey));
    expect(compositeBaseline.cacheKey, compositeChanged.cacheKey);
  });
}
