import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/composition_scene_clip_models.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_mock_models.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';
import 'package:refusion_app/features/editor/presentation/services/root_scene_clip_projection_adapter.dart';

void main() {
  const adapter = RootSceneClipProjectionAdapter();

  TimelineTime ms(int value) => TimelineTime.fromMilliseconds(value);

  CompositionSceneClipModel sceneClip({
    String id = 'scene-clip',
    String sourceSceneId = 'source-scene',
    String? name = 'Generated Scene',
    int startMs = 0,
    int durationMs = 3000,
    int sourceInMs = 0,
    int? sourceOutMs,
    bool isEnabled = true,
  }) {
    return CompositionSceneClipModel(
      id: id,
      sourceSceneId: sourceSceneId,
      name: name,
      startTime: ms(startMs),
      durationTime: ms(durationMs),
      sourceInTime: ms(sourceInMs),
      sourceOutTime: ms(sourceOutMs ?? sourceInMs + durationMs),
      isEnabled: isEnabled,
    );
  }

  test('projects one scene clip as one root timeline clip', () {
    final result = adapter.projectSceneTrack(
      sceneClips: <CompositionSceneClipModel>[
        sceneClip(),
      ],
    );

    expect(result.hasIssues, isFalse);
    expect(result.track.isSceneTrack, isTrue);
    expect(result.track.contentKind, TimelineTrackContentKind.scene);
    expect(result.track.clips, hasLength(1));

    final timelineClip = result.track.clips.single;
    expect(timelineClip.isSceneClip, isTrue);
    expect(timelineClip.type, TimelineClipType.placeholder);
    expect(timelineClip.contentKind, TimelineClipContentKind.scene);
    expect(timelineClip.id, 'scene-clip');
    expect(timelineClip.sourceSceneId, 'source-scene');
    expect(timelineClip.label, 'Generated Scene');
    expect(timelineClip.durationTime.inMilliseconds, 3000);
    expect(timelineClip.sourceRange.start.inMilliseconds, 0);
    expect(timelineClip.sourceRange.endExclusive.inMilliseconds, 3000);
    expect(result.sceneClipByTimelineClipId['scene-clip']!.sourceSceneId,
        'source-scene');
  });

  test('keeps root timing by inserting gap placeholders before scene clips',
      () {
    final result = adapter.projectSceneTrack(
      sceneClips: <CompositionSceneClipModel>[
        sceneClip(startMs: 2000, durationMs: 3000),
      ],
    );

    expect(result.track.clips, hasLength(2));
    expect(result.track.clips.first.isGapPlaceholder, isTrue);
    expect(result.track.clips.first.durationTime.inMilliseconds, 2000);
    expect(result.track.clips.last.isSceneClip, isTrue);
    expect(result.track.clips.last.durationTime.inMilliseconds, 3000);
  });

  test('sorts scene clips and rejects overlaps instead of showing internals',
      () {
    final result = adapter.projectSceneTrack(
      sceneClips: <CompositionSceneClipModel>[
        sceneClip(
          id: 'second',
          sourceSceneId: 'source-second',
          name: 'Second',
          startMs: 3000,
          durationMs: 1000,
        ),
        sceneClip(
          id: 'first',
          sourceSceneId: 'source-first',
          name: 'First',
          startMs: 0,
          durationMs: 2000,
        ),
        sceneClip(
          id: 'overlap',
          sourceSceneId: 'source-overlap',
          name: 'Overlap',
          startMs: 3500,
          durationMs: 1000,
        ),
      ],
    );

    expect(
      result.track.clips.map((clip) => clip.id),
      <String>['first', 'scene_gap_1', 'second'],
    );
    expect(result.hasIssues, isTrue);
    expect(result.issues.single.code,
        RootSceneClipProjectionIssueCode.overlappingSceneClip);
    expect(result.sceneClipByTimelineClipId.keys, <String>['first', 'second']);
  });

  test(
      'mergeSceneTrack preserves existing media tracks and replaces scene track',
      () {
    final videoTrack = TimelineTrackData(
      kind: TimelineTrackKind.video,
      clips: <TimelineClipData>[
        TimelineClipData(
          id: 'video-a',
          type: TimelineClipType.media,
          tone: TimelineClipTone.hero,
          durationTime: ms(2000),
        ),
      ],
    );
    final oldSceneTrack = TimelineTrackData(
      kind: TimelineTrackKind.text,
      contentKind: TimelineTrackContentKind.scene,
      clips: <TimelineClipData>[
        TimelineClipData(
          id: 'old-scene',
          type: TimelineClipType.placeholder,
          tone: TimelineClipTone.aiGenerated,
          contentKind: TimelineClipContentKind.scene,
          sourceSceneId: 'old-source',
          durationTime: ms(1000),
        ),
      ],
    );

    final tracks = adapter.mergeSceneTrack(
      existingTracks: <TimelineTrackData>[videoTrack, oldSceneTrack],
      sceneClips: <CompositionSceneClipModel>[
        sceneClip(id: 'new-scene', sourceSceneId: 'new-source'),
      ],
    );

    expect(tracks, hasLength(2));
    expect(tracks.first, same(videoTrack));
    expect(tracks.last.isSceneTrack, isTrue);
    expect(tracks.last.clips.single.id, 'new-scene');
  });
}
