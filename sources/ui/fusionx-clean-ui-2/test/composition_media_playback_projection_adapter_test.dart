import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/composition_scene_clip_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/domain/services/scene_scope_session.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_mock_models.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';
import 'package:refusion_app/features/editor/presentation/services/composition_media_playback_projection_adapter.dart';

void main() {
  const adapter = CompositionMediaPlaybackProjectionAdapter();

  TimelineTime ms(int value) => TimelineTime.fromMilliseconds(value);

  TimelineTimeRange range(int startMs, int endMs) {
    return TimelineTimeRange(
      start: ms(startMs),
      endExclusive: ms(endMs),
    );
  }

  MotionElementModel videoElement({
    String id = 'video-element',
    String layerId = 'video-layer',
    TimelineTimeRange? localRange,
    TimelineTimeRange? sourceRange,
  }) {
    return MotionElementModel(
      id: id,
      layerId: layerId,
      kind: MotionElementKind.videoClip,
      localRange: localRange ?? range(0, 3000),
      name: 'Nested Video',
      sourceBinding: MotionElementSourceBinding(
        kind: MotionSourceKind.video,
        sourceId: 'asset-video',
        assetId: 'asset-video',
        label: 'Nested Video',
        sourceRange: sourceRange ?? range(1000, 4000),
      ),
    );
  }

  MotionLayerModel videoLayer({
    String id = 'video-layer',
    TimelineTimeRange? visibleRange,
    MotionElementModel? element,
    int zIndex = 0,
  }) {
    return MotionLayerModel(
      id: id,
      sceneId: 'source-scene',
      kind: MotionLayerKind.video,
      visibleRange: visibleRange ?? range(500, 3500),
      elements: <MotionElementModel>[element ?? videoElement()],
      name: 'Nested Video Layer',
      zIndex: zIndex,
    );
  }

  MotionProjectModel project({
    List<MotionLayerModel>? sourceLayers,
  }) {
    return MotionProjectModel(
      id: 'project',
      format: const MotionProjectFormat(
        canvasSize: MotionSize2D(width: 1080, height: 1920),
      ),
      frameRate: const MotionFrameRate(numerator: 30, denominator: 1),
      scenes: <MotionSceneModel>[
        MotionSceneModel(
          id: 'root-scene',
          projectRange: range(0, 6000),
          layers: const <MotionLayerModel>[],
        ),
        MotionSceneModel(
          id: 'source-scene',
          projectRange: range(500, 3500),
          layers: sourceLayers ?? <MotionLayerModel>[videoLayer()],
        ),
      ],
    );
  }

  CompositionSceneClipModel sceneClip({
    int startMs = 2000,
    int durationMs = 3000,
    int sourceInMs = 500,
    int sourceOutMs = 3500,
  }) {
    return CompositionSceneClipModel(
      id: 'scene-clip',
      sourceSceneId: 'source-scene',
      name: 'Scene 01',
      startTime: ms(startMs),
      durationTime: ms(durationMs),
      sourceInTime: ms(sourceInMs),
      sourceOutTime: ms(sourceOutMs),
    );
  }

  SceneScopeSession sceneScopeSession() {
    return const SceneScopeSessionResolver()
        .open(
          SceneScopeSessionRequest(
            project: project(),
            rootTime: ms(2000),
            sceneClipId: 'scene-clip',
            sceneClips: <CompositionSceneClipModel>[sceneClip()],
          ),
        )
        .session!;
  }

  test('projects scene-scope video layers into playable media clips', () {
    final result = adapter.projectSceneScope(sceneScopeSession());

    expect(result.hasPlayableVideo, isTrue);
    expect(result.tracks, hasLength(1));
    expect(result.tracks.single.kind, TimelineTrackKind.video);

    final clip = result.tracks.single.clips.single;
    expect(clip.type, TimelineClipType.media);
    expect(clip.assetId, 'asset-video');
    expect(clip.durationTime.inMilliseconds, 3000);
    expect(clip.sourceStartTime.inMilliseconds, 1000);
    expect(clip.sourceDurationTime.inMilliseconds, 3000);
  });

  test('projects nested scene media back onto the root composition timeline',
      () {
    final result = adapter.projectRootComposition(
      project: project(),
      sceneClips: <CompositionSceneClipModel>[sceneClip()],
    );

    expect(result.hasPlayableVideo, isTrue);
    expect(result.tracks.single.kind, TimelineTrackKind.video);
    expect(result.tracks.single.clips, hasLength(2));
    expect(result.tracks.single.clips.first.isGapPlaceholder, isTrue);
    expect(result.tracks.single.clips.first.durationTime.inMilliseconds, 2000);

    final mediaClip = result.tracks.single.clips.last;
    expect(mediaClip.type, TimelineClipType.media);
    expect(mediaClip.id, 'root_media_scene-clip_video-layer_video-element');
    expect(mediaClip.assetId, 'asset-video');
    expect(mediaClip.durationTime.inMilliseconds, 3000);
    expect(mediaClip.sourceStartTime.inMilliseconds, 1000);
    expect(mediaClip.sourceDurationTime.inMilliseconds, 3000);
  });

  test('clips projected media to the scene clip source range', () {
    final result = adapter.projectRootComposition(
      project: project(),
      sceneClips: <CompositionSceneClipModel>[
        sceneClip(sourceInMs: 1500, sourceOutMs: 3000, durationMs: 1500),
      ],
    );

    final mediaClip = result.tracks.single.clips.last;
    expect(mediaClip.durationTime.inMilliseconds, 1500);
    expect(mediaClip.sourceStartTime.inMilliseconds, 2000);
    expect(mediaClip.sourceDurationTime.inMilliseconds, 1500);
  });

  test('supports media inserted with scene-absolute element ranges', () {
    final absoluteElement = videoElement(localRange: range(1000, 3000));
    final absoluteLayer = videoLayer(
      visibleRange: range(1000, 3000),
      element: absoluteElement,
    );

    final result = adapter.projectRootComposition(
      project: project(sourceLayers: <MotionLayerModel>[absoluteLayer]),
      sceneClips: <CompositionSceneClipModel>[
        sceneClip(sourceInMs: 500, sourceOutMs: 3500),
      ],
    );

    final mediaClip = result.tracks.single.clips.last;
    expect(mediaClip.durationTime.inMilliseconds, 2000);
    expect(mediaClip.sourceStartTime.inMilliseconds, 1000);
    expect(mediaClip.sourceDurationTime.inMilliseconds, 2000);
  });

  test('flattens overlapping video layers to their visible source intervals',
      () {
    final backElement = videoElement(
      id: 'back-element',
      layerId: 'back-layer',
      localRange: range(1000, 5000),
      sourceRange: range(0, 4000),
    );
    final frontElement = videoElement(
      id: 'front-element',
      layerId: 'front-layer',
      localRange: range(500, 3000),
      sourceRange: range(0, 2500),
    );
    final backLayer = videoLayer(
      id: 'back-layer',
      visibleRange: range(1000, 5000),
      element: backElement,
      zIndex: 0,
    );
    final frontLayer = videoLayer(
      id: 'front-layer',
      visibleRange: range(500, 3000),
      element: frontElement,
      zIndex: 10,
    );

    final result = adapter.projectRootComposition(
      project: project(sourceLayers: <MotionLayerModel>[
        backLayer,
        frontLayer,
      ]),
      sceneClips: <CompositionSceneClipModel>[
        sceneClip(sourceInMs: 500, sourceOutMs: 5500, durationMs: 5000),
      ],
    );

    final mediaClips = result.tracks.single.clips
        .where((clip) => clip.type == TimelineClipType.media)
        .toList(growable: false);

    expect(mediaClips, hasLength(2));
    expect(mediaClips.first.id, contains('front-layer'));
    expect(mediaClips.first.durationTime.inMilliseconds, 2500);
    expect(mediaClips.first.sourceStartTime.inMilliseconds, 0);

    expect(mediaClips.last.id, contains('back-layer'));
    expect(mediaClips.last.durationTime.inMilliseconds, 2000);
    expect(mediaClips.last.sourceStartTime.inMilliseconds, 2000);
    expect(mediaClips.last.sourceDurationTime.inMilliseconds, 2000);
  });
}
