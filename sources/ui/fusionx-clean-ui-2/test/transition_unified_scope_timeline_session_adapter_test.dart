import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_mock_models.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';
import 'package:refusion_app/features/editor/presentation/services/transition_unified_scope_bridge_entry_adapter.dart';
import 'package:refusion_app/features/editor/presentation/services/transition_unified_scope_entry_gate.dart';
import 'package:refusion_app/features/editor/presentation/services/transition_unified_scope_timeline_session_adapter.dart';

void main() {
  TimelineClipData clip({
    required String id,
    required int milliseconds,
    String? assetId,
    String? label,
  }) {
    return TimelineClipData(
      id: id,
      type: TimelineClipType.media,
      tone: TimelineClipTone.hero,
      durationTime: TimelineTime.fromMilliseconds(milliseconds),
      sourceDurationTime: TimelineTime.fromMilliseconds(milliseconds),
      assetId: assetId,
      label: label,
    );
  }

  TransitionUnifiedScopeBridgeSession session() {
    final left = clip(
      id: 'clip-a',
      milliseconds: 8000,
      assetId: 'asset-a',
      label: 'Left shot',
    );
    final right = clip(
      id: 'clip-b',
      milliseconds: 6000,
      assetId: 'asset-b',
      label: 'Right shot',
    );
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

  test(
      'builds layer-scope style timeline tracks from unified transition session',
      () {
    final viewModel = const TransitionUnifiedScopeTimelineSessionAdapter()
        .viewModelForSession(
      session(),
    );

    expect(viewModel.canShowTimeline, isTrue);
    expect(viewModel.hasEditableLanes, isTrue);
    expect(viewModel.tracks, hasLength(1));
    expect(viewModel.tracks.single.kind, TimelineTrackKind.video);
    expect(viewModel.tracks.single.clips, hasLength(2));
    expect(viewModel.tracks.single.clips.first.label, 'Left shot');
    expect(viewModel.tracks.single.clips.last.label, 'Right shot');
    expect(
      viewModel.tracks.single.clips.first.durationTime +
          viewModel.tracks.single.clips.last.durationTime,
      viewModel.durationTime,
    );
    expect(viewModel.tracks.single.animationLanes, viewModel.lanes);
    expect(
      viewModel.lanes.map((lane) => lane.label),
      <String>['Outgoing Opacity', 'Incoming Opacity'],
    );
    expect(
      viewModel.lanes.map((lane) => lane.targetClipId).toSet(),
      <String>{viewModel.tracks.single.clips.first.id},
    );
  });

  test('keeps transition seam inside local timeline coordinates', () {
    final viewModel = const TransitionUnifiedScopeTimelineSessionAdapter()
        .viewModelForSession(
      session(),
    );

    expect(viewModel.seamLocalTime > TimelineTime.zero, isTrue);
    expect(viewModel.seamLocalTime < viewModel.durationTime, isTrue);
    expect(
      viewModel.timeDisplayOffset + viewModel.seamLocalTime,
      TimelineTime.fromMilliseconds(8000),
    );
  });
}
