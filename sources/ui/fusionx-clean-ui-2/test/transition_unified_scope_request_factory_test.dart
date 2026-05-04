import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/domain/services/composition_timeline_projection.dart';
import 'package:refusion_app/features/editor/domain/services/normal_transition_catalog.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_mock_models.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';
import 'package:refusion_app/features/editor/presentation/services/transition_unified_scope_entry_gate.dart';
import 'package:refusion_app/features/editor/presentation/services/transition_unified_scope_request_factory.dart';

void main() {
  const factory = TransitionUnifiedScopeRequestFactory();

  TimelineClipData clip({
    required String id,
    required int seconds,
    String? assetId,
    String? label,
  }) {
    return TimelineClipData(
      id: id,
      type: TimelineClipType.media,
      tone: TimelineClipTone.hero,
      durationTime: TimelineTime.fromSecondsDouble(seconds.toDouble()),
      sourceDurationTime: TimelineTime.fromSecondsDouble(seconds.toDouble()),
      assetId: assetId,
      label: label,
    );
  }

  TimelineTrackData track({
    required TimelineClipData left,
    required TimelineClipData right,
    TimelineClipData? before,
  }) {
    return TimelineTrackData(
      kind: TimelineTrackKind.video,
      clips: <TimelineClipData>[
        if (before != null) before,
        left,
        right,
      ],
    );
  }

  test('builds a transition-scope request from adjacent timeline clips', () {
    final left = clip(id: 'clip-a', seconds: 8, assetId: 'asset-a');
    final right = clip(id: 'clip-b', seconds: 6, assetId: 'asset-b');
    final definition =
        const NormalTransitionCatalog().loadBuiltIns().definitionById(
              'cross_dissolve',
            )!;

    final result = factory.createForBoundary(
      track: track(left: left, right: right),
      leftClip: left,
      rightClip: right,
      definition: definition,
      projectId: 'project',
      sceneId: 'scene',
      trackId: 'video-main',
    );

    expect(result.canBuild, isTrue);
    expect(result.boundaryTime, TimelineTime.fromSecondsDouble(8));
    expect(result.project!.durationTime, TimelineTime.fromSecondsDouble(14));
    expect(result.project!.scenes.single.layers, hasLength(2));
    expect(
      result.project!.scenes.single.layers.map((layer) => layer.kind),
      <MotionLayerKind>[MotionLayerKind.video, MotionLayerKind.video],
    );
    expect(result.request!.boundaryTime, TimelineTime.fromSecondsDouble(8));
    expect(result.request!.leftAvailableTail, left.durationTime);
    expect(result.request!.rightAvailableHead, right.durationTime);
    expect(result.request!.outgoingTarget.layerId, result.outgoingLayerId);
    expect(result.request!.incomingTarget.layerId, result.incomingLayerId);
  });

  test('keeps real boundary time when the transition is not at timeline zero',
      () {
    final before = clip(id: 'intro', seconds: 3);
    final left = clip(id: 'clip-a', seconds: 8);
    final right = clip(id: 'clip-b', seconds: 6);
    final definition =
        const NormalTransitionCatalog().loadBuiltIns().definitionById(
              'cross_dissolve',
            )!;

    final result = factory.createForBoundary(
      track: track(left: left, right: right, before: before),
      leftClip: left,
      rightClip: right,
      definition: definition,
      projectId: 'project',
      sceneId: 'scene',
      trackId: 'video-main',
    );

    expect(result.canBuild, isTrue);
    expect(result.boundaryTime, TimelineTime.fromSecondsDouble(11));
    expect(
      result.project!.scenes.single.layers.first.visibleRange.start,
      TimelineTime.fromSecondsDouble(3),
    );
    expect(
      result.project!.scenes.single.layers.last.visibleRange.start,
      TimelineTime.fromSecondsDouble(11),
    );
  });

  test('result opens graph-backed unified transition scope through the gate',
      () {
    final left = clip(id: 'clip-a', seconds: 8);
    final right = clip(id: 'clip-b', seconds: 6);
    final definition =
        const NormalTransitionCatalog().loadBuiltIns().definitionById(
              'cross_dissolve',
            )!;
    final request = factory
        .createForBoundary(
          track: track(left: left, right: right),
          leftClip: left,
          rightClip: right,
          definition: definition,
          projectId: 'project',
          sceneId: 'scene',
          trackId: 'video-main',
        )
        .request!;
    final gate = TransitionUnifiedScopeEntryGate();

    final result = gate.resolveEntry(request);

    expect(result.opensUnifiedScope, isTrue);
    expect(result.unifiedScope!.scope!.mode, CompositionScopeMode.transition);
    expect(
      result.unifiedScope!.lanes!.lanes.map((lane) => lane.label),
      <String>['Outgoing Opacity', 'Incoming Opacity'],
    );
  });

  test('rejects non-adjacent clips before reaching graph authoring', () {
    final left = clip(id: 'clip-a', seconds: 8);
    final middle = clip(id: 'middle', seconds: 2);
    final right = clip(id: 'clip-b', seconds: 6);
    final definition =
        const NormalTransitionCatalog().loadBuiltIns().definitionById(
              'cross_dissolve',
            )!;

    final result = factory.createForBoundary(
      track: TimelineTrackData(
        kind: TimelineTrackKind.video,
        clips: <TimelineClipData>[left, middle, right],
      ),
      leftClip: left,
      rightClip: right,
      definition: definition,
      projectId: 'project',
      sceneId: 'scene',
      trackId: 'video-main',
    );

    expect(result.canBuild, isFalse);
    expect(result.request, isNull);
    expect(result.issues.single.path, 'boundary');
  });
}
