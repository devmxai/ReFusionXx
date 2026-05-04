import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_animation_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/domain/services/unified_keyframe_operations.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_mock_models.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';
import 'package:refusion_app/features/editor/presentation/services/transition_unified_scope_bridge_entry_adapter.dart';
import 'package:refusion_app/features/editor/presentation/services/transition_unified_scope_entry_gate.dart';
import 'package:refusion_app/features/editor/presentation/services/transition_unified_scope_keyframe_adapter.dart';

void main() {
  TimelineClipData clip({
    required String id,
    required int milliseconds,
  }) {
    return TimelineClipData(
      id: id,
      type: TimelineClipType.media,
      tone: TimelineClipTone.hero,
      durationTime: TimelineTime.fromMilliseconds(milliseconds),
      sourceDurationTime: TimelineTime.fromMilliseconds(milliseconds),
    );
  }

  TransitionUnifiedScopeBridgeSession session() {
    final left = clip(id: 'clip-a', milliseconds: 8000);
    final right = clip(id: 'clip-b', milliseconds: 6000);
    final adapter = TransitionUnifiedScopeBridgeEntryAdapter();
    final result = adapter.resolveBridgeEntry(
      TransitionUnifiedScopeBridgeEntryRequest(
        track: TimelineTrackData(
          kind: TimelineTrackKind.video,
          clips: <TimelineClipData>[left, right],
        ),
        leftClip: left,
        rightClip: right,
        preset: TimelineTransitionPreset.crossDissolve,
        projectId: 'project',
        sceneId: 'scene',
        trackId: 'video-main',
        format: const MotionProjectFormat(
          canvasSize: MotionSize2D(width: 1080, height: 1920),
        ),
        frameRate: const MotionFrameRate(numerator: 60, denominator: 1),
      ),
    );
    expect(result.opensUnifiedScope, isTrue);
    return result.session!;
  }

  test('adds a keyframe through the lane binding into the graph channel', () {
    final source = session();
    final lane = source.lanes.first;
    final binding = source.bindingForLane(lane.id)!;
    final channelBefore = source.graphBundle.channels.singleWhere(
      (channel) => channel.id == binding.channelId,
    );
    final targetTime = TimelineTime.fromMilliseconds(
      source.localWorkRange.duration.inMilliseconds ~/ 2,
    );

    final result = const TransitionUnifiedScopeKeyframeAdapter().addKeyframe(
      TransitionUnifiedScopeAddKeyframeRequest(
        session: source,
        laneId: lane.id,
        localTime: targetTime,
        value: const MotionPropertyValue.scalar(42),
      ),
    );

    expect(result.hasIssues, isFalse);
    expect(result.selectedLaneId, lane.id);
    expect(result.primaryKeyframeId, isNotNull);
    final channelAfter = result.session.graphBundle.channels.singleWhere(
      (channel) => channel.id == binding.channelId,
    );
    expect(
        channelAfter.keyframes, hasLength(channelBefore.keyframes.length + 1));
    expect(
      channelAfter.keyframes.any(
        (keyframe) =>
            keyframe.id == result.primaryKeyframeId &&
            keyframe.time == targetTime &&
            keyframe.value.rawValue == 42,
      ),
      isTrue,
    );
    expect(
      result.viewModel.lanes
          .singleWhere((candidate) => candidate.id == lane.id)
          .normalizedKeyframeStops,
      hasLength(lane.normalizedKeyframeStops.length + 1),
    );
  });

  test('moves and edits a transition keyframe while keeping lane selection',
      () {
    final source = session();
    final lane = source.lanes.first;
    final add = const TransitionUnifiedScopeKeyframeAdapter().addKeyframe(
      TransitionUnifiedScopeAddKeyframeRequest(
        session: source,
        laneId: lane.id,
        localTime: TimelineTime.fromMilliseconds(200),
        value: const MotionPropertyValue.scalar(20),
      ),
    );
    final keyframeId = add.primaryKeyframeId!;

    final moved = const TransitionUnifiedScopeKeyframeAdapter().moveKeyframe(
      TransitionUnifiedScopeMoveKeyframeRequest(
        session: add.session,
        laneId: lane.id,
        keyframeId: keyframeId,
        localTime: TimelineTime.fromMilliseconds(500),
      ),
    );
    final valued =
        const TransitionUnifiedScopeKeyframeAdapter().setKeyframeValue(
      TransitionUnifiedScopeSetValueRequest(
        session: moved.session,
        laneId: lane.id,
        keyframeId: keyframeId,
        value: const MotionPropertyValue.scalar(65),
      ),
    );

    expect(moved.hasIssues, isFalse);
    expect(valued.hasIssues, isFalse);
    expect(valued.selectedLaneId, lane.id);
    final binding = valued.session.bindingForLane(lane.id)!;
    final channel = valued.session.graphBundle.channels.singleWhere(
      (candidate) => candidate.id == binding.channelId,
    );
    final keyframe = channel.keyframes.singleWhere(
      (candidate) => candidate.id == keyframeId,
    );
    expect(keyframe.time, TimelineTime.fromMilliseconds(500));
    expect(keyframe.value.rawValue, 65);
  });

  test('deletes a transition keyframe through the same lane binding', () {
    final source = session();
    final lane = source.lanes.first;
    final add = const TransitionUnifiedScopeKeyframeAdapter().addKeyframe(
      TransitionUnifiedScopeAddKeyframeRequest(
        session: source,
        laneId: lane.id,
        localTime: TimelineTime.fromMilliseconds(200),
        value: const MotionPropertyValue.scalar(20),
      ),
    );
    final keyframeId = add.primaryKeyframeId!;

    final deleted =
        const TransitionUnifiedScopeKeyframeAdapter().deleteKeyframe(
      TransitionUnifiedScopeDeleteKeyframeRequest(
        session: add.session,
        laneId: lane.id,
        keyframeId: keyframeId,
      ),
    );

    expect(deleted.hasIssues, isFalse);
    expect(deleted.selectedLaneId, lane.id);
    expect(deleted.changedKeyframeIds, <String>{keyframeId});
    final binding = deleted.session.bindingForLane(lane.id)!;
    final channel = deleted.session.graphBundle.channels.singleWhere(
      (candidate) => candidate.id == binding.channelId,
    );
    expect(
      channel.keyframes.any((candidate) => candidate.id == keyframeId),
      isFalse,
    );
  });

  test('sets transition keyframe interpolation through the lane binding', () {
    final source = session();
    final lane = source.lanes.first;
    final keyframeId = lane.keyframeIds.first;

    final result =
        const TransitionUnifiedScopeKeyframeAdapter().setKeyframeInterpolation(
      TransitionUnifiedScopeSetInterpolationRequest(
        session: source,
        laneId: lane.id,
        keyframeId: keyframeId,
        interpolation: const MotionInterpolationSpec.easeOut(),
      ),
    );

    expect(result.hasIssues, isFalse);
    expect(result.selectedLaneId, lane.id);
    expect(result.primaryKeyframeId, keyframeId);
    final binding = result.session.bindingForLane(lane.id)!;
    final channel = result.session.graphBundle.channels.singleWhere(
      (candidate) => candidate.id == binding.channelId,
    );
    final keyframe = channel.keyframes.singleWhere(
      (candidate) => candidate.id == keyframeId,
    );
    expect(keyframe.interpolationToNext.kind, MotionInterpolationKind.easeOut);
  });

  test('reports a clear issue for an unbound lane', () {
    final result = const TransitionUnifiedScopeKeyframeAdapter().addKeyframe(
      TransitionUnifiedScopeAddKeyframeRequest(
        session: session(),
        laneId: 'missing-lane',
        localTime: TimelineTime.zero,
      ),
    );

    expect(result.hasIssues, isTrue);
    expect(result.issues.single.code, UnifiedKeyframeIssueCode.missingChannel);
  });
}
