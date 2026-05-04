import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/composition_scene_clip_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_animation_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/domain/services/scene_scope_session.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_mock_models.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';
import 'package:refusion_app/features/editor/presentation/services/scene_layer_scope_timeline_adapter.dart';

void main() {
  const sceneResolver = SceneScopeSessionResolver();
  const adapter = SceneLayerScopeTimelineAdapter();

  TimelineTime ms(int value) => TimelineTime.fromMilliseconds(value);

  TimelineTimeRange range(int startMs, int endMs) {
    return TimelineTimeRange(
      start: ms(startMs),
      endExclusive: ms(endMs),
    );
  }

  MotionProjectModel project() {
    final titleElement = MotionElementModel(
      id: 'title-element',
      layerId: 'title-layer',
      kind: MotionElementKind.text,
      localRange: range(0, 3000),
      name: 'Title',
    );
    final lineElement = MotionElementModel(
      id: 'line-element',
      layerId: 'line-layer',
      kind: MotionElementKind.shape,
      localRange: range(0, 3000),
      name: 'Reveal Line',
    );
    final imageElement = MotionElementModel(
      id: 'image-element',
      layerId: 'image-layer',
      kind: MotionElementKind.image,
      localRange: range(0, 3000),
      name: 'Hero Image',
    );
    final videoElement = MotionElementModel(
      id: 'video-element',
      layerId: 'video-layer',
      kind: MotionElementKind.videoClip,
      localRange: range(0, 3000),
      name: 'Hero Video',
    );
    final cameraElement = MotionElementModel(
      id: 'camera-element',
      layerId: 'camera-layer',
      kind: MotionElementKind.camera,
      localRange: range(0, 3000),
      name: 'Camera',
    );
    return MotionProjectModel(
      id: 'project',
      format: const MotionProjectFormat(
        canvasSize: MotionSize2D(width: 1080, height: 1920),
      ),
      frameRate: const MotionFrameRate(numerator: 30, denominator: 1),
      scenes: <MotionSceneModel>[
        MotionSceneModel(
          id: 'root',
          projectRange: range(0, 6000),
          layers: const <MotionLayerModel>[],
        ),
        MotionSceneModel(
          id: 'source',
          projectRange: range(500, 3500),
          layers: <MotionLayerModel>[
            MotionLayerModel(
              id: 'title-layer',
              sceneId: 'source',
              kind: MotionLayerKind.text,
              visibleRange: range(500, 3500),
              elements: <MotionElementModel>[titleElement],
              name: 'Title Layer',
            ),
            MotionLayerModel(
              id: 'line-layer',
              sceneId: 'source',
              kind: MotionLayerKind.shape,
              visibleRange: range(500, 3500),
              elements: <MotionElementModel>[lineElement],
              name: 'Line Layer',
            ),
            MotionLayerModel(
              id: 'image-layer',
              sceneId: 'source',
              kind: MotionLayerKind.image,
              visibleRange: range(500, 3500),
              elements: <MotionElementModel>[imageElement],
              name: 'Image Layer',
            ),
            MotionLayerModel(
              id: 'video-layer',
              sceneId: 'source',
              kind: MotionLayerKind.video,
              visibleRange: range(500, 3500),
              elements: <MotionElementModel>[videoElement],
              name: 'Video Layer',
            ),
            MotionLayerModel(
              id: 'camera-layer',
              sceneId: 'source',
              kind: MotionLayerKind.camera,
              visibleRange: range(500, 3500),
              elements: <MotionElementModel>[cameraElement],
              name: 'Camera Layer',
            ),
          ],
        ),
      ],
    );
  }

  CompositionSceneClipModel sceneClip() {
    return CompositionSceneClipModel(
      id: 'scene-clip',
      sourceSceneId: 'source',
      name: 'Generated Scene',
      startTime: ms(2000),
      durationTime: ms(3000),
      sourceInTime: ms(500),
      sourceOutTime: ms(3500),
    );
  }

  SceneScopeSession sceneSession({
    List<MotionPropertyChannelModel> channels =
        const <MotionPropertyChannelModel>[],
  }) {
    return sceneResolver
        .open(
          SceneScopeSessionRequest(
            project: project(),
            rootTime: ms(2750),
            sceneClipId: 'scene-clip',
            sceneClips: <CompositionSceneClipModel>[sceneClip()],
            channels: channels,
          ),
        )
        .session!;
  }

  MotionPropertyChannelModel opacityChannel() {
    return MotionPropertyChannelModel(
      id: 'title.opacity',
      target: const MotionPropertyTarget(
        kind: MotionTargetKind.element,
        targetId: 'title-element',
        projectId: 'project',
        sceneId: 'source',
        layerId: 'title-layer',
        elementId: 'title-element',
      ),
      definition: MotionPropertyCatalog.opacity,
      activeRange: range(500, 3500),
      keyframes: <MotionKeyframeModel>[
        MotionKeyframeModel(
          id: 'title.opacity.0',
          channelId: 'title.opacity',
          time: ms(500),
          value: const MotionPropertyValue.scalar(0),
          interpolationToNext: const MotionInterpolationSpec.linear(),
        ),
        MotionKeyframeModel(
          id: 'title.opacity.1',
          channelId: 'title.opacity',
          time: ms(3500),
          value: const MotionPropertyValue.scalar(1),
          interpolationToNext: const MotionInterpolationSpec.linear(),
        ),
      ],
    );
  }

  test('opens a scene layer as one editable scope track', () {
    final channel = opacityChannel();
    final result = adapter.viewModelForLayer(
      project: project(),
      sceneSession: sceneSession(channels: <MotionPropertyChannelModel>[
        channel,
      ]),
      layerId: 'title-layer',
      channels: <MotionPropertyChannelModel>[channel],
    );

    expect(result.hasIssues, isFalse);
    final viewModel = result.viewModel!;
    expect(viewModel.sceneClipId, 'scene-clip');
    expect(viewModel.sourceSceneId, 'source');
    expect(viewModel.layerId, 'title-layer');
    expect(viewModel.durationTime.inMilliseconds, 3000);
    expect(viewModel.track.kind, TimelineTrackKind.text);
    expect(viewModel.track.clips.single.id, 'title-layer');
    expect(viewModel.track.clips.single.label, 'Title Layer');
    expect(viewModel.track.animationLanes, hasLength(1));
    expect(viewModel.track.animationLanes.single.id, 'title.opacity');
    expect(
      viewModel.track.animationLanes.single.normalizedKeyframeStops,
      <double>[0.0, 1.0],
    );
    expect(
      viewModel.track.animationLanes.single.keyframeIds,
      <String>['title.opacity.0', 'title.opacity.1'],
    );
  });

  test('keeps root/source/local time mapping for nested layer scope', () {
    final result = adapter.viewModelForLayer(
      project: project(),
      sceneSession: sceneSession(),
      layerId: 'line-layer',
    );

    final viewModel = result.viewModel!;
    expect(viewModel.track.kind, TimelineTrackKind.shape);
    expect(viewModel.track.contentKind, TimelineTrackContentKind.shape);
    expect(viewModel.track.placeholderLabel, 'Shape');
    expect(viewModel.localToRoot(ms(1000)).inMilliseconds, 3000);
    expect(viewModel.rootToLocal(ms(3000)).inMilliseconds, 1000);
  });

  test('preserves visual identity for image layers inside layer scope', () {
    final result = adapter.viewModelForLayer(
      project: project(),
      sceneSession: sceneSession(),
      layerId: 'image-layer',
    );

    expect(result.hasIssues, isFalse);
    final viewModel = result.viewModel!;
    expect(viewModel.track.kind, TimelineTrackKind.image);
    expect(viewModel.track.contentKind, TimelineTrackContentKind.image);
    expect(viewModel.track.visualKind, TimelineVisualKind.image);
    expect(viewModel.track.placeholderLabel, 'Image');
    expect(viewModel.track.clips.single.label, 'Image Layer');
    expect(viewModel.track.clips.single.visualKind, TimelineVisualKind.image);
    expect(
      viewModel.track.clips.single.contentKind,
      TimelineClipContentKind.placeholder,
    );
  });

  test('opens video layers as editable scope tracks', () {
    final result = adapter.viewModelForLayer(
      project: project(),
      sceneSession: sceneSession(),
      layerId: 'video-layer',
    );

    expect(result.hasIssues, isFalse);
    final viewModel = result.viewModel!;
    expect(viewModel.track.kind, TimelineTrackKind.video);
    expect(viewModel.track.contentKind, TimelineTrackContentKind.video);
    expect(viewModel.track.visualKind, TimelineVisualKind.video);
    expect(viewModel.track.placeholderLabel, 'Video');
    expect(viewModel.track.clips.single.label, 'Video Layer');
    expect(viewModel.track.clips.single.visualKind, TimelineVisualKind.video);
    expect(
      viewModel.track.clips.single.contentKind,
      TimelineClipContentKind.placeholder,
    );
  });

  test('reports a missing internal layer without producing tracks', () {
    final result = adapter.viewModelForLayer(
      project: project(),
      sceneSession: sceneSession(),
      layerId: 'missing-layer',
    );

    expect(result.viewModel, isNull);
    expect(result.issues.single.code,
        SceneLayerScopeTimelineIssueCode.missingLayer);
  });

  test('reports unsupported Scene Layer kind without text fallback', () {
    final result = adapter.viewModelForLayer(
      project: project(),
      sceneSession: sceneSession(),
      layerId: 'camera-layer',
    );

    expect(result.viewModel, isNull);
    expect(
      result.issues.single.code,
      SceneLayerScopeTimelineIssueCode.unsupportedLayerKind,
    );
    expect(
      result.issues.single.message,
      contains('Camera Layer Scope is not enabled yet.'),
    );
  });
}
