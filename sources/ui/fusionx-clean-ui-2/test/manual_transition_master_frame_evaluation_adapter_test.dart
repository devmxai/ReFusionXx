import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/master_time_models.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_mock_models.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';
import 'package:refusion_app/features/editor/presentation/services/manual_transition_master_frame_evaluation_adapter.dart';

void main() {
  final adapter = ManualTransitionMasterFrameEvaluationAdapter();

  MasterTimeSnapshot buildTime({
    required int timeMs,
  }) {
    final time = TimelineTime.fromMilliseconds(timeMs);
    return MasterTimeSnapshot(
      rootTime: time,
      presentationTime: time,
      frameIndex: 0,
      frameRate: 30,
      commitFrameNumber: 1,
      monotonicTimeUs: 0,
      phase: MasterClockPhase.paused,
      authority: MasterClockAuthority.user,
      renderMode: MasterRenderMode.preview,
      sourceScope: MasterTimeScope.transition,
    );
  }

  test('evaluates manual scale lane into transition domain renderer values',
      () {
    final transition = TimelineTrackTransitionData(
      id: 'transition-1',
      leftClipId: 'clip-a',
      rightClipId: 'clip-b',
      preset: TimelineTransitionPreset.manual,
      durationTime: TimelineTime.fromMilliseconds(1000),
      manualEffectIds: const <String>['scale'],
      manualAnimationLanes: const <TimelineAnimationLaneData>[
        TimelineAnimationLaneData(
          id: 'scale',
          label: 'Scale',
          targetClipId: 'clip-a',
          normalizedKeyframeStops: <double>[0.0, 1.0],
          keyframeIds: <String>['kf-a', 'kf-b'],
          keyframeValues: <double>[0.0, 100.0],
        ),
      ],
    );
    final result = adapter.evaluate(
      request: ManualTransitionMasterFrameEvaluationRequest(
        time: buildTime(timeMs: 1000),
        transition: transition,
        seamTime: TimelineTime.fromMilliseconds(1000),
        projectId: 'project-1',
      ),
    );

    expect(result.blockers, isEmpty);
    expect(result.channels, isNotEmpty);
    final scaleX = result.evaluatedChannels.firstWhere(
      (value) => value.propertyDefinitionId == 'scale',
    );
    expect(scaleX.targetId, 'clip-a');
    expect(scaleX.mapping.renderer.scalar, closeTo(1.5, 0.0001));
    expect(scaleX.domain, const MasterTimeDomain.transition('transition-1'));
  });

  test('interpolates manual scale from authored keyframe time and value', () {
    final transition = TimelineTrackTransitionData(
      id: 'transition-1',
      leftClipId: 'clip-a',
      rightClipId: 'clip-b',
      preset: TimelineTransitionPreset.manual,
      durationTime: TimelineTime.fromMilliseconds(2000),
      manualEffectIds: const <String>['scale'],
      manualAnimationLanes: const <TimelineAnimationLaneData>[
        TimelineAnimationLaneData(
          id: 'scale',
          label: 'Scale',
          targetClipId: 'clip-a',
          normalizedKeyframeStops: <double>[0.125, 0.5],
          keyframeIds: <String>['kf-1s', 'kf-4s'],
          keyframeValues: <double>[0.0, 70.0],
        ),
      ],
    );
    final result = adapter.evaluate(
      request: ManualTransitionMasterFrameEvaluationRequest(
        time: buildTime(timeMs: 2500),
        transition: transition,
        seamTime: TimelineTime.fromMilliseconds(4000),
        windowStartTime: TimelineTime.zero,
        windowEndTime: TimelineTime.fromMilliseconds(8000),
        projectId: 'project-1',
      ),
    );

    expect(result.blockers, isEmpty);
    final scaleX = result.evaluatedChannels.firstWhere(
      (value) => value.propertyDefinitionId == 'scale',
    );
    expect(scaleX.targetId, 'clip-a');
    expect(scaleX.mapping.renderer.scalar, closeTo(1.35, 0.0001));
  });

  test('reports blockers for unsupported manual lanes', () {
    final transition = TimelineTrackTransitionData(
      id: 'transition-2',
      leftClipId: 'clip-a',
      rightClipId: 'clip-b',
      preset: TimelineTransitionPreset.manual,
      durationTime: TimelineTime.fromMilliseconds(1000),
      manualEffectIds: const <String>['tile'],
      manualAnimationLanes: const <TimelineAnimationLaneData>[
        TimelineAnimationLaneData(
          id: 'tile',
          label: 'Tile',
          targetClipId: 'clip-a',
          normalizedKeyframeStops: <double>[0.0, 1.0],
          keyframeValues: <double>[0.0, 50.0],
        ),
      ],
    );
    final result = adapter.evaluate(
      request: ManualTransitionMasterFrameEvaluationRequest(
        time: buildTime(timeMs: 500),
        transition: transition,
        seamTime: TimelineTime.fromMilliseconds(1000),
        projectId: 'project-1',
      ),
    );

    expect(
      result.blockers.any((entry) => entry.contains('unsupportedLane')),
      isTrue,
    );
    expect(result.evaluatedChannels, isEmpty);
  });
}
