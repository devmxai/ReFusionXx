import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/services/professional_video_transition_compositor.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_mock_models.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';
import 'package:refusion_app/features/editor/presentation/services/professional_video_transition_render_plan_adapter.dart';

void main() {
  const adapter = ProfessionalVideoTransitionRenderPlanAdapter();

  test('builds source-bound render plan from adjacent video clips', () {
    final result = adapter.build(
      ProfessionalVideoTransitionRenderPlanRequest(
        transition: TimelineTrackTransitionData(
          id: 'transition-a-b',
          leftClipId: 'clip-a',
          rightClipId: 'clip-b',
          preset: TimelineTransitionPreset.zoomInCamera,
          durationTime: TimelineTime.fromMilliseconds(4000),
        ),
        definitionId:
            ProfessionalVideoTransitionCompositorKind.zoomInCamera.name,
        outgoingClip: TimelineClipData(
          id: 'clip-a',
          type: TimelineClipType.media,
          tone: TimelineClipTone.hero,
          assetId: 'asset-a',
          durationTime: TimelineTime.fromMilliseconds(10000),
          sourceStartTime: TimelineTime.fromMilliseconds(20000),
          sourceDurationTime: TimelineTime.fromMilliseconds(10000),
        ),
        incomingClip: TimelineClipData(
          id: 'clip-b',
          type: TimelineClipType.media,
          tone: TimelineClipTone.hero,
          assetId: 'asset-b',
          durationTime: TimelineTime.fromMilliseconds(8000),
          sourceStartTime: TimelineTime.fromMilliseconds(5000),
          sourceDurationTime: TimelineTime.fromMilliseconds(8000),
        ),
        boundaryTime: TimelineTime.fromMilliseconds(10000),
        canvasWidth: 1080,
        canvasHeight: 1920,
        sourceUriForAsset: (assetId) => 'file:///$assetId.mp4',
        edgePolicy: const <String, Object?>{
          'mode': 'mirrorTile',
        },
        motionBlurPolicy: const <String, Object?>{
          'mode': 'temporalShutter',
          'sampleCount': 8,
        },
      ),
    );

    expect(result.canBuild, isTrue);
    final plan = result.plan!;
    expect(plan.definitionId,
        ProfessionalVideoTransitionCompositorKind.zoomInCamera.name);
    expect(plan.transitionId, 'transition-a-b');
    expect(plan.boundaryTime.inMilliseconds, 10000);
    expect(plan.leadingDuration.inMilliseconds, 2000);
    expect(plan.trailingDuration.inMilliseconds, 2000);
    expect(plan.requiredCapabilities, contains('dualVideoSampling'));
    expect(plan.samplingPolicy['sourceRoles'], <String>[
      'outgoing',
      'incoming',
    ]);
    expect(plan.edgePolicy['mode'], 'mirrorTile');
    expect(plan.motionBlurPolicy['mode'], 'temporalShutter');

    final outgoing = plan.sources[0];
    final incoming = plan.sources[1];
    expect(outgoing.sourceUri, 'file:///asset-a.mp4');
    expect(outgoing.timelineRange.start.inMilliseconds, 8000);
    expect(outgoing.timelineRange.endExclusive.inMilliseconds, 10000);
    expect(outgoing.sourceStartTime.inMilliseconds, 28000);
    expect(outgoing.sourceDuration.inMilliseconds, 2000);
    expect(
      outgoing
          .sourceTimeForTimelineTime(TimelineTime.fromMilliseconds(9000))
          .inMilliseconds,
      29000,
    );

    expect(incoming.sourceUri, 'file:///asset-b.mp4');
    expect(incoming.timelineRange.start.inMilliseconds, 10000);
    expect(incoming.timelineRange.endExclusive.inMilliseconds, 12000);
    expect(incoming.sourceStartTime.inMilliseconds, 5000);
    expect(incoming.sourceDuration.inMilliseconds, 2000);
    expect(
      incoming
          .sourceTimeForTimelineTime(TimelineTime.fromMilliseconds(11000))
          .inMilliseconds,
      6000,
    );
  });

  test('fails when a source uri cannot be resolved', () {
    final result = adapter.build(
      ProfessionalVideoTransitionRenderPlanRequest(
        transition: TimelineTrackTransitionData(
          id: 'transition-a-b',
          leftClipId: 'clip-a',
          rightClipId: 'clip-b',
          preset: TimelineTransitionPreset.crossDissolve,
          durationTime: TimelineTime.fromMilliseconds(2000),
        ),
        definitionId:
            ProfessionalVideoTransitionCompositorKind.crossDissolve.name,
        outgoingClip: _clip('clip-a', 'asset-a'),
        incomingClip: _clip('clip-b', 'asset-b'),
        boundaryTime: TimelineTime.fromMilliseconds(10000),
        canvasWidth: 1080,
        canvasHeight: 1920,
        sourceUriForAsset: (assetId) =>
            assetId == 'asset-a' ? 'file:///asset-a.mp4' : null,
      ),
    );

    expect(result.canBuild, isFalse);
    expect(result.plan, isNull);
    expect(
      result.issues.map((issue) => issue.code),
      contains('incoming_source_uri_missing'),
    );
    expect(
      result.issues
          .singleWhere(
            (issue) => issue.code == 'incoming_source_uri_missing',
          )
          .path,
      'sources[1].sourceUri',
    );
  });

  test('fails when the requested transition window exceeds real handles', () {
    final result = adapter.build(
      ProfessionalVideoTransitionRenderPlanRequest(
        transition: TimelineTrackTransitionData(
          id: 'transition-a-b',
          leftClipId: 'clip-a',
          rightClipId: 'clip-b',
          preset: TimelineTransitionPreset.zoomInCamera,
          durationTime: TimelineTime.fromMilliseconds(4000),
        ),
        definitionId:
            ProfessionalVideoTransitionCompositorKind.zoomInCamera.name,
        outgoingClip: TimelineClipData(
          id: 'clip-a',
          type: TimelineClipType.media,
          tone: TimelineClipTone.hero,
          assetId: 'asset-a',
          durationTime: TimelineTime.fromMilliseconds(1000),
          sourceStartTime: TimelineTime.fromMilliseconds(20000),
          sourceDurationTime: TimelineTime.fromMilliseconds(1000),
        ),
        incomingClip: _clip('clip-b', 'asset-b'),
        boundaryTime: TimelineTime.fromMilliseconds(10000),
        canvasWidth: 1080,
        canvasHeight: 1920,
        sourceUriForAsset: (assetId) => 'file:///$assetId.mp4',
      ),
    );

    expect(result.canBuild, isFalse);
    expect(
      result.issues.map((issue) => issue.code),
      containsAll(<String>[
        'outgoing_visible_handle_too_short',
        'outgoing_source_handle_too_short',
      ]),
    );
  });

  test('rejects speed-overridden clips until source rate mapping is explicit',
      () {
    final result = adapter.build(
      ProfessionalVideoTransitionRenderPlanRequest(
        transition: TimelineTrackTransitionData(
          id: 'transition-a-b',
          leftClipId: 'clip-a',
          rightClipId: 'clip-b',
          preset: TimelineTransitionPreset.zoomInCamera,
          durationTime: TimelineTime.fromMilliseconds(4000),
        ),
        definitionId:
            ProfessionalVideoTransitionCompositorKind.zoomInCamera.name,
        outgoingClip: TimelineClipData(
          id: 'clip-a',
          type: TimelineClipType.media,
          tone: TimelineClipTone.hero,
          assetId: 'asset-a',
          durationTime: TimelineTime.fromMilliseconds(10000),
          sourceStartTime: TimelineTime.zero,
          sourceDurationTime: TimelineTime.fromMilliseconds(10000),
          playbackRate: 2.0,
        ),
        incomingClip: _clip('clip-b', 'asset-b'),
        boundaryTime: TimelineTime.fromMilliseconds(10000),
        canvasWidth: 1080,
        canvasHeight: 1920,
        sourceUriForAsset: (assetId) => 'file:///$assetId.mp4',
      ),
    );

    expect(result.canBuild, isFalse);
    expect(
      result.issues.map((issue) => issue.code),
      contains('outgoing_playback_rate_unsupported'),
    );
  });
}

TimelineClipData _clip(String id, String assetId) {
  return TimelineClipData(
    id: id,
    type: TimelineClipType.media,
    tone: TimelineClipTone.hero,
    assetId: assetId,
    durationTime: TimelineTime.fromMilliseconds(10000),
    sourceStartTime: TimelineTime.zero,
    sourceDurationTime: TimelineTime.fromMilliseconds(10000),
  );
}
