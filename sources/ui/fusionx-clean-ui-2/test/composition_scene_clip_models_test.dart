import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/composition_scene_clip_models.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';

void main() {
  TimelineTime ms(int value) => TimelineTime.fromMilliseconds(value);

  test('maps root timeline time into source and local scene time', () {
    final clip = CompositionSceneClipModel(
      id: 'clip-intro',
      sourceSceneId: 'scene-intro',
      startTime: ms(2000),
      durationTime: ms(5000),
      sourceInTime: ms(0),
      sourceOutTime: ms(5000),
    );

    expect(clip.rootRange.start.inMilliseconds, 2000);
    expect(clip.rootRange.endExclusive.inMilliseconds, 7000);
    expect(clip.rootToSourceTime(ms(2000)).inMilliseconds, 0);
    expect(clip.rootToSourceTime(ms(3500)).inMilliseconds, 1500);
    expect(clip.rootToLocalTime(ms(2000)).inMilliseconds, 0);
    expect(clip.rootToLocalTime(ms(3500)).inMilliseconds, 1500);
    expect(clip.rootToLocalTime(ms(7000)).inMilliseconds, 5000);
    expect(clip.rootToLocalTime(ms(9000)).inMilliseconds, 5000);
  });

  test('maps source and local scene time back into root timeline time', () {
    final clip = CompositionSceneClipModel(
      id: 'clip-offer',
      sourceSceneId: 'scene-offer',
      startTime: ms(7000),
      durationTime: ms(3000),
      sourceInTime: ms(1000),
      sourceOutTime: ms(4000),
    );

    expect(clip.sourceToRootTime(ms(1000)).inMilliseconds, 7000);
    expect(clip.sourceToRootTime(ms(2500)).inMilliseconds, 8500);
    expect(clip.sourceToRootTime(ms(4000)).inMilliseconds, 10000);
    expect(clip.localToRootTime(ms(0)).inMilliseconds, 7000);
    expect(clip.localToRootTime(ms(1500)).inMilliseconds, 8500);
    expect(clip.localToRootTime(ms(3000)).inMilliseconds, 10000);
    expect(clip.localToRootTime(ms(5000)).inMilliseconds, 10000);
  });

  test('supports time-scale mapping for scene clip instances', () {
    final clip = CompositionSceneClipModel(
      id: 'clip-slowmo',
      sourceSceneId: 'scene-motion',
      startTime: ms(1000),
      durationTime: ms(4000),
      sourceInTime: ms(0),
      sourceOutTime: ms(2000),
      timeScale: 0.5,
    );

    expect(clip.rootToLocalTime(ms(3000)).inMilliseconds, 1000);
    expect(clip.localToRootTime(ms(1000)).inMilliseconds, 3000);
    expect(clip.rootToSourceTime(ms(5000)).inMilliseconds, 2000);
  });

  test('keeps multiple instances pointing to the same source scene', () {
    final clips = CompositionSceneClipCollection(
      clips: <CompositionSceneClipModel>[
        CompositionSceneClipModel(
          id: 'clip-a',
          sourceSceneId: 'scene-reusable',
          startTime: ms(0),
          durationTime: ms(1000),
        ),
        CompositionSceneClipModel(
          id: 'clip-b',
          sourceSceneId: 'scene-reusable',
          startTime: ms(2000),
          durationTime: ms(1000),
        ),
        CompositionSceneClipModel(
          id: 'clip-c',
          sourceSceneId: 'scene-other',
          startTime: ms(4000),
          durationTime: ms(1000),
        ),
      ],
    );

    expect(
      clips.clipsForSourceScene('scene-reusable').map((clip) => clip.id),
      <String>['clip-a', 'clip-b'],
    );
    expect(clips.clipAtRootTime(ms(500))!.id, 'clip-a');
    expect(clips.clipAtRootTime(ms(2500))!.id, 'clip-b');
    expect(clips.clipAtRootTime(ms(1500)), isNull);
  });

  test('reports invalid clip duration and source ranges', () {
    final clips = CompositionSceneClipCollection(
      clips: <CompositionSceneClipModel>[
        CompositionSceneClipModel(
          id: 'clip-empty-duration',
          sourceSceneId: 'scene-a',
          startTime: ms(0),
          durationTime: ms(0),
        ),
        CompositionSceneClipModel(
          id: 'clip-empty-source',
          sourceSceneId: 'scene-b',
          startTime: ms(0),
          durationTime: ms(1000),
          sourceInTime: ms(500),
          sourceOutTime: ms(500),
        ),
        CompositionSceneClipModel(
          id: 'clip-invalid-scale',
          sourceSceneId: 'scene-c',
          startTime: ms(0),
          durationTime: ms(1000),
          timeScale: -1,
        ),
      ],
    );

    final issueCodes = clips.validate().map((issue) => issue.code);
    expect(issueCodes, contains(CompositionSceneClipIssueCode.invalidDuration));
    expect(
      issueCodes,
      contains(CompositionSceneClipIssueCode.invalidSourceRange),
    );
    expect(
        issueCodes, contains(CompositionSceneClipIssueCode.invalidTimeScale));
  });

  test('defaults source duration from root duration and time scale', () {
    final clip = CompositionSceneClipModel(
      id: 'clip-scaled-default',
      sourceSceneId: 'scene-fast',
      startTime: ms(0),
      durationTime: ms(3000),
      sourceInTime: ms(1000),
      timeScale: 2,
    );

    expect(clip.sourceOutTime.inMilliseconds, 7000);
    expect(clip.rootToSourceTime(ms(1500)).inMilliseconds, 4000);
    expect(clip.rootToLocalTime(ms(1500)).inMilliseconds, 3000);
  });
}
