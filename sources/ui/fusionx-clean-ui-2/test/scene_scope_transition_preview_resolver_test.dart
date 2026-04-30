import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/composition_scene_clip_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/domain/services/scene_scope_session.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_mock_models.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';
import 'package:refusion_app/features/editor/presentation/services/scene_scope_transition_preview_resolver.dart';

void main() {
  const resolver = SceneScopeTransitionPreviewResolver();

  TimelineTime ms(int value) => TimelineTime.fromMilliseconds(value);

  TimelineTimeRange range(int startMs, int endMs) {
    return TimelineTimeRange(
      start: ms(startMs),
      endExclusive: ms(endMs),
    );
  }

  SceneScopeSession session() {
    final project = MotionProjectModel(
      id: 'project',
      format: const MotionProjectFormat(
        canvasSize: MotionSize2D(width: 1080, height: 1920),
      ),
      frameRate: const MotionFrameRate(numerator: 30, denominator: 1),
      scenes: <MotionSceneModel>[
        MotionSceneModel(
          id: 'root',
          projectRange: range(0, 7000),
          layers: const <MotionLayerModel>[],
        ),
        MotionSceneModel(
          id: 'source',
          projectRange: range(0, 5000),
          layers: const <MotionLayerModel>[],
        ),
      ],
    );
    return const SceneScopeSessionResolver()
        .open(
          SceneScopeSessionRequest(
            project: project,
            rootTime: ms(2500),
            sceneClipId: 'scene-clip',
            sceneClips: <CompositionSceneClipModel>[
              CompositionSceneClipModel(
                id: 'scene-clip',
                sourceSceneId: 'source',
                startTime: ms(2000),
                durationTime: ms(5000),
                sourceInTime: TimelineTime.zero,
                sourceOutTime: ms(5000),
              ),
            ],
          ),
        )
        .session!;
  }

  TimelineTrackData sceneVideoTrack({bool withTransition = true}) {
    final clips = <TimelineClipData>[
      TimelineClipData(
        id: 'video-a',
        type: TimelineClipType.placeholder,
        tone: TimelineClipTone.aiGenerated,
        assetId: 'asset-a',
        durationTime: ms(1800),
        contentKind: TimelineClipContentKind.scene,
        visualKind: TimelineVisualKind.video,
      ),
      TimelineClipData(
        id: 'video-b',
        type: TimelineClipType.placeholder,
        tone: TimelineClipTone.aiGenerated,
        assetId: 'asset-b',
        durationTime: ms(2200),
        contentKind: TimelineClipContentKind.scene,
        visualKind: TimelineVisualKind.video,
      ),
    ];
    return TimelineTrackData(
      kind: TimelineTrackKind.video,
      contentKind: TimelineTrackContentKind.scene,
      visualKind: TimelineVisualKind.video,
      clips: clips,
      transitions: withTransition
          ? <TimelineTrackTransitionData>[
              TimelineTrackTransitionData(
                id: 'transition',
                leftClipId: 'video-a',
                rightClipId: 'video-b',
                preset: TimelineTransitionPreset.fadeBlack,
                durationTime: ms(600),
              ),
            ]
          : const <TimelineTrackTransitionData>[],
    );
  }

  test('maps root time into scene-local transition preview time', () {
    final projection = resolver.resolve(
      session: session(),
      sceneScopeTracks: <TimelineTrackData>[sceneVideoTrack()],
      rootTime: ms(2600),
    );

    expect(projection, isNotNull);
    expect(projection!.localTime, ms(600));
    expect(projection.localDuration, ms(5000));
    expect(projection.track.transitions.single.id, 'transition');
  });

  test('ignores scene tracks without transitions', () {
    final projection = resolver.resolve(
      session: session(),
      sceneScopeTracks: <TimelineTrackData>[
        sceneVideoTrack(withTransition: false),
      ],
      rootTime: ms(2600),
    );

    expect(projection, isNull);
  });
}
