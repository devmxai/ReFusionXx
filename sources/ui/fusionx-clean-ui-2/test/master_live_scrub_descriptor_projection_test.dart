import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/master_live_scrub_descriptor_models.dart';
import 'package:refusion_app/features/editor/domain/models/master_live_scrub_visual_program_models.dart';
import 'package:refusion_app/features/editor/domain/models/master_time_models.dart';
import 'package:refusion_app/features/editor/domain/models/master_value_truth_models.dart';
import 'package:refusion_app/features/editor/domain/services/master_live_scrub_descriptor_projection.dart';
import 'package:refusion_app/features/editor/domain/services/timeline_clock_coordinator.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';

void main() {
  TimelineTime ms(int value) => TimelineTime.fromMilliseconds(value);

  test('projects stable descriptor id and exact source-time mapping', () {
    final clock = TimelineClockCoordinator(
      timelineDuration: ms(10000),
      initialTime: ms(2500),
    );
    final time = MasterTimeSnapshot.fromClockSnapshot(
      clock: clock.snapshot,
      frameRate: 30,
      renderMode: MasterRenderMode.liveScrub,
      sourceScope: MasterTimeScope.rootComposition,
    );
    final program = LiveScrubVisualProgram(
      time: time,
      surfaces: <LiveScrubVisualSurface>[
        LiveScrubVisualSurface(
          targetId: 'element-1',
          sourceKind: LiveScrubSourceKind.video,
          source: const LiveScrubSurfaceSource(
            targetId: 'element-1',
            kind: LiveScrubSourceKind.video,
            sourceUri: '/media/video-a.mp4',
            scrubStoreKey: 'clip-1',
            sourceWidth: 1920,
            sourceHeight: 1080,
          ),
          transform: const LiveScrubSurfaceTransform(
            positionX: 120,
            positionY: -30,
            scaleX: 1.1,
            scaleY: 0.9,
            rotationRadians: math.pi / 4,
          ),
          opacity: 0.8,
          effects: const <LiveScrubEffectBinding>[
            LiveScrubEffectBinding(
              id: 'gaussianBlur',
              rendererValue: 5.0,
              rendererUnit: MasterValueUnit.shaderSigmaPx,
            ),
          ],
          blockers: const <String>[],
        ),
      ],
      blockers: const <String>[],
      diagnostics: const <String>[],
      transitionState: LiveScrubTransitionState(
        activeTransitionIds: const <String>[],
        hasRenderableTransitionPixels: false,
        reason: 'phase1_domain_contract_only',
      ),
    );
    const projection = MasterLiveScrubDescriptorProjection();
    const sourceWindow = LiveScrubTimelineSourceWindow(
      targetId: 'element-1',
      timelineStartMs: 1000,
      timelineEndMs: 5000,
      sourceStartMs: 5000,
      sourceDurationMs: 4000,
      playbackRate: 1.5,
    );

    final first = projection.project(
      program: program,
      sourceWindowsByTargetId: <String, LiveScrubTimelineSourceWindow>{
        'element-1': sourceWindow,
      },
    );
    final second = projection.project(
      program: program,
      sourceWindowsByTargetId: <String, LiveScrubTimelineSourceWindow>{
        'element-1': sourceWindow,
      },
    );

    expect(first.canProject, isTrue);
    expect(first.blockers, isEmpty);
    expect(first.descriptors.length, 1);

    final descriptor = first.descriptors.single;
    expect(descriptor.id, 'lsd:element-1:clip-1');
    expect(second.descriptors.single.id, descriptor.id);
    expect(descriptor.timelinePositionMs, 2500);
    expect(descriptor.sourcePositionMs, 7250);
    expect(descriptor.opacity, closeTo(0.8, 0.0001));
    expect(descriptor.effectProgramIds, contains('gaussianBlur'));
    expect(descriptor.transformMatrix3x3.length, 9);
    expect(descriptor.isValid, isTrue);
  });

  test('reports blockers when source window is missing', () {
    final clock = TimelineClockCoordinator(
      timelineDuration: ms(5000),
      initialTime: ms(1500),
    );
    final time = MasterTimeSnapshot.fromClockSnapshot(
      clock: clock.snapshot,
      frameRate: 30,
      renderMode: MasterRenderMode.liveScrub,
      sourceScope: MasterTimeScope.rootComposition,
    );
    final program = LiveScrubVisualProgram(
      time: time,
      surfaces: <LiveScrubVisualSurface>[
        LiveScrubVisualSurface(
          targetId: 'layer-1',
          sourceKind: LiveScrubSourceKind.video,
          source: const LiveScrubSurfaceSource(
            targetId: 'layer-1',
            kind: LiveScrubSourceKind.video,
            sourceUri: '/media/video-b.mp4',
          ),
          blockers: const <String>[],
        ),
      ],
      blockers: const <String>[],
      diagnostics: const <String>[],
      transitionState: LiveScrubTransitionState(
        activeTransitionIds: const <String>[],
        hasRenderableTransitionPixels: false,
        reason: 'phase1_domain_contract_only',
      ),
    );
    const projection = MasterLiveScrubDescriptorProjection();
    final result = projection.project(program: program);
    expect(result.canProject, isFalse);
    expect(result.blockers, contains('missing_source_window:layer-1'));
    expect(result.descriptors.single.isValid, isFalse);
  });
}
