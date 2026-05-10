import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_mock_models.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';
import 'package:refusion_app/features/editor/presentation/models/unified_timeline_presentation_models.dart';
import 'package:refusion_app/features/editor/presentation/services/unified_timeline_presentation_adapter.dart';

void main() {
  const adapter = UnifiedTimelinePresentationAdapter();

  TimelineTrackData mediaTrack() {
    return TimelineTrackData(
      kind: TimelineTrackKind.video,
      clips: <TimelineClipData>[
        TimelineClipData(
          id: 'clip-a',
          type: TimelineClipType.media,
          tone: TimelineClipTone.hero,
          durationTime: TimelineTime.fromMilliseconds(3000),
          label: 'Intro',
        ),
        TimelineClipData(
          id: 'clip-b',
          type: TimelineClipType.media,
          tone: TimelineClipTone.heroMuted,
          durationTime: TimelineTime.fromMilliseconds(2000),
          label: 'Demo',
        ),
      ],
      transitions: <TimelineTrackTransitionData>[
        TimelineTrackTransitionData(
          id: 'transition-a-b',
          leftClipId: 'clip-a',
          rightClipId: 'clip-b',
          preset: TimelineTransitionPreset.crossDissolve,
          durationTime: TimelineTime.fromMilliseconds(1000),
        ),
      ],
    );
  }

  TimelineTrackData textTrack() {
    return TimelineTrackData(
      kind: TimelineTrackKind.text,
      clips: <TimelineClipData>[
        TimelineClipData(
          id: 'title-clip',
          type: TimelineClipType.placeholder,
          tone: TimelineClipTone.aiGenerated,
          durationTime: TimelineTime.fromMilliseconds(5000),
          label: 'Title',
          visualKind: TimelineVisualKind.text,
        ),
      ],
      animationLanes: const <TimelineAnimationLaneData>[
        TimelineAnimationLaneData(
          id: 'title.opacity',
          label: 'Opacity',
          targetClipId: 'title-clip',
          normalizedKeyframeStops: <double>[0.0, 1.0],
        ),
      ],
    );
  }

  TimelineTrackData audioTrack() {
    return TimelineTrackData(
      kind: TimelineTrackKind.audio,
      clips: <TimelineClipData>[
        TimelineClipData(
          id: 'music-clip',
          type: TimelineClipType.media,
          tone: TimelineClipTone.hero,
          durationTime: TimelineTime.fromMilliseconds(5000),
          label: 'Music',
          visualKind: TimelineVisualKind.audio,
        ),
      ],
    );
  }

  test('builds unified rows from solid seeds, clips, and transitions', () {
    final result = adapter.build(
      UnifiedTimelinePresentationRequest(
        scopeKind: UnifiedTimelineScopeKind.root,
        currentTime: TimelineTime.fromMilliseconds(1200),
        durationTime: TimelineTime.fromMilliseconds(6000),
        tracks: <TimelineTrackData>[
          mediaTrack(),
          textTrack(),
          audioTrack(),
        ],
        selectedRowId: 'clip:0:1:clip-b',
        solidLayers: <UnifiedTimelineSolidLayerSeed>[
          UnifiedTimelineSolidLayerSeed(
            id: 'bg-01',
            label: 'Root Background',
            startTime: TimelineTime.zero,
            durationTime: TimelineTime.fromMilliseconds(6000),
          ),
        ],
      ),
    );

    expect(result.hasIssues, isFalse);
    expect(result.rows, hasLength(6));
    expect(result.rows.first.layerType, UnifiedTimelineLayerType.solid);
    expect(result.rows.first.label, 'Root Background');

    final clipA = result.rows.firstWhere((row) => row.sourceId == 'clip-a');
    final clipB = result.rows.firstWhere((row) => row.sourceId == 'clip-b');
    final transition =
        result.rows.firstWhere((row) => row.sourceId == 'transition-a-b');
    final title = result.rows.firstWhere((row) => row.sourceId == 'title-clip');
    final music = result.rows.firstWhere((row) => row.sourceId == 'music-clip');

    expect(clipA.layerType, UnifiedTimelineLayerType.media);
    expect(clipA.startTime.inMilliseconds, 0);
    expect(clipA.durationTime.inMilliseconds, 3000);

    expect(clipB.layerType, UnifiedTimelineLayerType.media);
    expect(clipB.startTime.inMilliseconds, 3000);
    expect(clipB.durationTime.inMilliseconds, 2000);

    expect(transition.layerType, UnifiedTimelineLayerType.adjustment);
    expect(transition.isTransition, isTrue);
    expect(transition.startTime.inMilliseconds, 2500);
    expect(transition.durationTime.inMilliseconds, 1000);

    expect(title.layerType, UnifiedTimelineLayerType.text);
    expect(title.canFocusKeyframes, isTrue);

    expect(music.layerType, UnifiedTimelineLayerType.audio);
    expect(music.canReceiveEffects, isFalse);
    expect(result.selectedRowId, 'clip:0:1:clip-b');
  });

  test('reports diagnostics for scene mapping and unresolved transitions', () {
    final track = TimelineTrackData(
      kind: TimelineTrackKind.video,
      clips: <TimelineClipData>[
        TimelineClipData(
          id: 'scene-proxy',
          type: TimelineClipType.media,
          tone: TimelineClipTone.aiGenerated,
          durationTime: TimelineTime.fromMilliseconds(2500),
          label: 'Scene Clip',
          contentKind: TimelineClipContentKind.scene,
          visualKind: TimelineVisualKind.composition,
        ),
      ],
      transitions: <TimelineTrackTransitionData>[
        TimelineTrackTransitionData(
          id: 'broken-transition',
          leftClipId: 'missing-a',
          rightClipId: 'missing-b',
          preset: TimelineTransitionPreset.manual,
          durationTime: TimelineTime.fromMilliseconds(700),
        ),
      ],
    );

    final result = adapter.build(
      UnifiedTimelinePresentationRequest(
        scopeKind: UnifiedTimelineScopeKind.scene,
        currentTime: TimelineTime.zero,
        durationTime: TimelineTime.fromMilliseconds(2500),
        tracks: <TimelineTrackData>[track],
      ),
    );

    expect(result.rows, hasLength(1));
    expect(result.rows.single.layerType, UnifiedTimelineLayerType.media);
    expect(
      result.issues.map((issue) => issue.code),
      containsAll(<UnifiedTimelinePresentationIssueCode>[
        UnifiedTimelinePresentationIssueCode.sceneClipMappedAsMedia,
        UnifiedTimelinePresentationIssueCode.transitionBoundaryNotFound,
      ]),
    );
  });

  test('returns immutable rows and issues', () {
    final result = adapter.build(
      UnifiedTimelinePresentationRequest(
        scopeKind: UnifiedTimelineScopeKind.root,
        currentTime: TimelineTime.zero,
        durationTime: TimelineTime.fromMilliseconds(1000),
        tracks: <TimelineTrackData>[audioTrack()],
      ),
    );

    expect(
      () => result.rows.add(
        UnifiedTimelinePresentationRow(
          id: 'x',
          trackId: 't',
          sourceId: 's',
          layerType: UnifiedTimelineLayerType.media,
          sourceKind: 'media',
          label: 'X',
          startTime: TimelineTime.zero,
          durationTime: TimelineTime.fromMilliseconds(1),
          zIndex: 0,
          isVisible: true,
          isLocked: false,
          isMuted: false,
          isTransition: false,
          canFocusKeyframes: false,
          canTrim: false,
          canMove: false,
          canReceiveEffects: false,
        ),
      ),
      throwsUnsupportedError,
    );
    expect(
      () => result.issues.add(
        const UnifiedTimelinePresentationIssue(
          code: UnifiedTimelinePresentationIssueCode.zeroDurationRow,
          message: 'x',
        ),
      ),
      throwsUnsupportedError,
    );
  });
}
