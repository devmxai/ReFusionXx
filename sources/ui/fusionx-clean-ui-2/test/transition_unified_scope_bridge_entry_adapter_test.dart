import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/domain/services/normal_transition_graph_authoring_service.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_mock_models.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';
import 'package:refusion_app/features/editor/presentation/services/transition_unified_scope_bridge_entry_adapter.dart';
import 'package:refusion_app/features/editor/presentation/services/transition_unified_scope_entry_gate.dart';

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

  TransitionUnifiedScopeBridgeEntryRequest request({
    TimelineTransitionPreset preset = TimelineTransitionPreset.crossDissolve,
    TimelineClipData? left,
    TimelineClipData? right,
    TimelineClipData? middle,
  }) {
    final resolvedLeft = left ?? clip(id: 'clip-a', milliseconds: 8000);
    final resolvedRight = right ?? clip(id: 'clip-b', milliseconds: 6000);
    return TransitionUnifiedScopeBridgeEntryRequest(
      track: TimelineTrackData(
        kind: TimelineTrackKind.video,
        clips: <TimelineClipData>[
          resolvedLeft,
          if (middle != null) middle,
          resolvedRight,
        ],
      ),
      leftClip: resolvedLeft,
      rightClip: resolvedRight,
      preset: preset,
      projectId: 'project',
      sceneId: 'scene',
      trackId: 'video-main',
      format: const MotionProjectFormat(
        canvasSize: MotionSize2D(width: 1080, height: 1920),
      ),
      frameRate: const MotionFrameRate(numerator: 60, denominator: 1),
    );
  }

  test('unsupported preset is blocked with a clear issue when enabled', () {
    final adapter = TransitionUnifiedScopeBridgeEntryAdapter();

    final result = adapter.resolveBridgeEntry(
      request(preset: TimelineTransitionPreset.manual),
    );

    expect(result.opensUnifiedScope, isFalse);
    expect(
      result.blockReason,
      TransitionUnifiedScopeBridgeFallbackReason.unsupportedPreset,
    );
    expect(result.issues.single.path, 'preset');
  });

  test('enabled cross dissolve bridge opens unified transition scope', () {
    final adapter = TransitionUnifiedScopeBridgeEntryAdapter();

    final result = adapter.resolveBridgeEntry(request());

    expect(result.opensUnifiedScope, isTrue);
    expect(result.blockReason, isNull);
    expect(result.definition!.definitionId, 'cross_dissolve');
    expect(result.factoryResult!.canBuild, isTrue);
    expect(
      result.entryResult!.unifiedScope!.lanes!.lanes.map((lane) => lane.label),
      <String>['Outgoing Opacity', 'Incoming Opacity'],
    );
    expect(result.session, isNotNull);
    expect(result.session!.hasEditableLanes, isTrue);
    expect(result.session!.project.id, 'project');
    expect(result.session!.trackId, 'video-main');
    expect(result.session!.leftClipId, 'clip-a');
    expect(result.session!.rightClipId, 'clip-b');
    expect(
      result.session!.transitionWindowId,
      result.entryResult!.unifiedScope!.graph.bundle!.transitionWindowId,
    );
    expect(
      result.session!.initialLocalTime,
      result.session!.globalToLocal(result.session!.boundaryTime),
    );
    expect(
      result.session!.localToGlobal(result.session!.initialLocalTime),
      result.session!.boundaryTime,
    );
    expect(
      result.session!
          .lanesForRole(NormalTransitionGraphChannelRole.outgoing)
          .map((lane) => lane.label),
      <String>['Outgoing Opacity'],
    );
    expect(
      result.session!
          .lanesForRole(NormalTransitionGraphChannelRole.incoming)
          .map((lane) => lane.label),
      <String>['Incoming Opacity'],
    );
    expect(
      result.session!.bindingForLane(result.session!.lanes.first.id)!.metadata,
      containsPair('presetId', 'cross_dissolve'),
    );
  });

  test('enabled fade black and zoom bridges open graph-backed lanes', () {
    final adapter = TransitionUnifiedScopeBridgeEntryAdapter();

    final fade = adapter.resolveBridgeEntry(
      request(preset: TimelineTransitionPreset.fadeBlack),
    );
    final zoom = adapter.resolveBridgeEntry(
      request(preset: TimelineTransitionPreset.zoomInCamera),
    );

    expect(fade.opensUnifiedScope, isTrue);
    expect(fade.definition!.definitionId, 'fade_black');
    expect(
      fade.entryResult!.unifiedScope!.lanes!.lanes.map((lane) => lane.label),
      <String>['Outgoing Opacity', 'Incoming Opacity'],
    );
    expect(zoom.opensUnifiedScope, isTrue);
    expect(zoom.definition!.definitionId, 'zoom_in_camera');
    expect(
      zoom.entryResult!.unifiedScope!.lanes!.lanes.map((lane) => lane.label),
      <String>[
        'Outgoing Opacity',
        'Outgoing Scale X',
        'Outgoing Scale Y',
        'Incoming Opacity',
        'Incoming Scale X',
        'Incoming Scale Y',
      ],
    );
  });

  test('invalid boundary is blocked before opening unified scope', () {
    final adapter = TransitionUnifiedScopeBridgeEntryAdapter();

    final result = adapter.resolveBridgeEntry(
      request(middle: clip(id: 'middle', milliseconds: 1000)),
    );

    expect(result.opensUnifiedScope, isFalse);
    expect(
      result.blockReason,
      TransitionUnifiedScopeBridgeFallbackReason.requestBlocked,
    );
    expect(result.factoryResult!.canBuild, isFalse);
    expect(result.issues.single.path, 'boundary');
  });

  test('insufficient handles is blocked through the entry gate', () {
    final adapter = TransitionUnifiedScopeBridgeEntryAdapter();

    final result = adapter.resolveBridgeEntry(
      request(
        left: clip(id: 'clip-a', milliseconds: 1),
        right: clip(id: 'clip-b', milliseconds: 6000),
      ),
    );

    expect(result.opensUnifiedScope, isFalse);
    expect(
      result.blockReason,
      TransitionUnifiedScopeBridgeFallbackReason.entryGateBlocked,
    );
    expect(
      result.entryResult!.blockReason,
      TransitionUnifiedScopeEntryFallbackReason.graphApplyBlocked,
    );
    expect(result.issues.map((issue) => issue.path), contains('leftClipId'));
  });
}
