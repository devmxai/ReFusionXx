import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_animation_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_normal_transition_models.dart';
import 'package:refusion_app/features/editor/domain/services/composition_timeline_projection.dart';
import 'package:refusion_app/features/editor/domain/services/normal_transition_authoring_service.dart';
import 'package:refusion_app/features/editor/domain/services/normal_transition_catalog.dart';
import 'package:refusion_app/features/editor/domain/services/normal_transition_motion_graph_lowerer.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';

void main() {
  const lowerer = NormalTransitionMotionGraphLowerer();
  const resolver = CompositionTimelineProjectionResolver();
  const authoring = NormalTransitionAuthoringService();

  TimelineTime at(double seconds) => TimelineTime.fromSecondsDouble(seconds);

  TimelineTimeRange range(double start, double end) {
    return TimelineTimeRange(
      start: at(start),
      endExclusive: at(end),
    );
  }

  MotionPropertyTarget elementTarget({
    required String layerId,
    required String elementId,
  }) {
    return MotionPropertyTarget(
      kind: MotionTargetKind.element,
      targetId: elementId,
      projectId: 'project',
      sceneId: 'scene',
      layerId: layerId,
      elementId: elementId,
    );
  }

  MotionElementModel element({
    required String layerId,
    required String elementId,
    required MotionElementKind kind,
  }) {
    return MotionElementModel(
      id: elementId,
      layerId: layerId,
      kind: kind,
      localRange: range(0, 12),
    );
  }

  MotionLayerModel layer({
    required String layerId,
    required MotionLayerKind layerKind,
    required MotionElementModel element,
    required TimelineTimeRange visibleRange,
  }) {
    return MotionLayerModel(
      id: layerId,
      sceneId: 'scene',
      kind: layerKind,
      visibleRange: visibleRange,
      elements: <MotionElementModel>[element],
    );
  }

  MotionProjectModel project() {
    final outgoing = element(
      layerId: 'outgoing-layer',
      elementId: 'outgoing-element',
      kind: MotionElementKind.videoClip,
    );
    final incoming = element(
      layerId: 'incoming-layer',
      elementId: 'incoming-element',
      kind: MotionElementKind.videoClip,
    );
    return MotionProjectModel(
      id: 'project',
      format: const MotionProjectFormat(
        canvasSize: MotionSize2D(width: 1080, height: 1920),
      ),
      frameRate: const MotionFrameRate(numerator: 60, denominator: 1),
      scenes: <MotionSceneModel>[
        MotionSceneModel(
          id: 'scene',
          projectRange: range(0, 20),
          layers: <MotionLayerModel>[
            layer(
              layerId: 'outgoing-layer',
              layerKind: MotionLayerKind.video,
              element: outgoing,
              visibleRange: range(0, 10),
            ),
            layer(
              layerId: 'incoming-layer',
              layerKind: MotionLayerKind.video,
              element: incoming,
              visibleRange: range(10, 20),
            ),
          ],
        ),
      ],
    );
  }

  NormalTransitionApplyResult crossDissolve() {
    final definition =
        const NormalTransitionCatalog().loadBuiltIns().definitionById(
              'cross_dissolve',
            )!;
    return authoring.createFromDefinition(
      NormalTransitionApplyRequest(
        definition: definition,
        trackId: 'main-video',
        leftClipId: 'clip-a',
        rightClipId: 'clip-b',
        boundaryTime: at(10),
        leftAvailableTail: at(2),
        rightAvailableHead: at(2),
      ),
    );
  }

  test('lowers cross dissolve recipe into editable opacity channels', () {
    final applied = crossDissolve();
    expect(applied.canApply, isTrue);

    final result = lowerer.lower(
      NormalTransitionMotionGraphLoweringRequest(
        node: applied.node!,
        instance: applied.instance!,
        window: applied.window!,
        outgoingTarget: elementTarget(
          layerId: 'outgoing-layer',
          elementId: 'outgoing-element',
        ),
        incomingTarget: elementTarget(
          layerId: 'incoming-layer',
          elementId: 'incoming-element',
        ),
      ),
    );

    expect(result.hasErrors, isFalse);
    expect(result.channels, hasLength(2));
    expect(
      result.channels.map((channel) => channel.definition.id),
      <String>[
        MotionPropertyCatalog.opacity.id,
        MotionPropertyCatalog.opacity.id,
      ],
    );
    expect(
      result.channels.map((channel) => channel.target.targetId),
      <String>['outgoing-element', 'incoming-element'],
    );

    final outgoing = result.channels.first;
    final incoming = result.channels.last;
    expect(outgoing.activeRange!.start, TimelineTime.zero);
    expect(outgoing.activeRange!.endExclusive, applied.window!.duration);
    expect(
      outgoing.keyframes.map((keyframe) => keyframe.time),
      <TimelineTime>[TimelineTime.zero, applied.window!.duration],
    );
    expect(
      outgoing.keyframes.map((keyframe) => keyframe.value.rawValue),
      <double>[1, 0],
    );
    expect(
      incoming.keyframes.map((keyframe) => keyframe.value.rawValue),
      <double>[0, 1],
    );
  });

  test('projects lowered transition channels through transition scope', () {
    final applied = crossDissolve();
    final channels = lowerer
        .lower(
          NormalTransitionMotionGraphLoweringRequest(
            node: applied.node!,
            instance: applied.instance!,
            window: applied.window!,
            outgoingTarget: elementTarget(
              layerId: 'outgoing-layer',
              elementId: 'outgoing-element',
            ),
            incomingTarget: elementTarget(
              layerId: 'incoming-layer',
              elementId: 'incoming-element',
            ),
          ),
        )
        .channels;

    final scope = resolver
        .resolveTransitionScope(
          project: project(),
          context: TransitionScopeContext(
            id: applied.node!.id,
            sceneId: 'scene',
            outgoingLayerId: 'outgoing-layer',
            incomingLayerId: 'incoming-layer',
            windowRange: TimelineTimeRange(
              start: applied.window!.start,
              endExclusive: applied.window!.endExclusive,
            ),
          ),
          globalTime: at(10),
          channels: channels,
        )
        .projection!;

    expect(scope.mode, CompositionScopeMode.transition);
    expect(scope.channels, hasLength(2));
    expect(scope.localRange.endExclusive, applied.window!.duration);
    expect(
      scope.channels.expand((channel) => channel.keyframes).map(
            (keyframe) => keyframe.time,
          ),
      everyElement(
        isIn(<TimelineTime>[TimelineTime.zero, applied.window!.duration]),
      ),
    );
  });

  test('supports parameter-backed scalar values in imported recipes', () {
    final instance = NormalTransitionInstance(
      id: 'instance',
      nodeId: 'node',
      definitionId: 'custom_blur',
      sourceKind: NormalTransitionSourceKind.importedScript,
      sourceHash: 'script',
      schemaVersion: kNormalTransitionSchemaVersion,
      parameterValues: const <String, Object>{'peakBlur': 18.0},
      channels: <NormalTransitionChannelSpec>[
        NormalTransitionChannelSpec(
          target: 'to',
          property: 'blurAmount',
          keyframes: const <NormalTransitionKeyframeSpec>[
            NormalTransitionKeyframeSpec(
              normalizedTime: 0,
              value: 0,
            ),
            NormalTransitionKeyframeSpec(
              normalizedTime: 0.5,
              value: r'$peakBlur',
              easing: 'easeOut',
            ),
            NormalTransitionKeyframeSpec(
              normalizedTime: 1,
              value: 0,
            ),
          ],
        ),
      ],
    );
    final node = NormalTransitionNode(
      id: 'node',
      trackId: 'main',
      leftClipId: 'clip-a',
      rightClipId: 'clip-b',
      definitionId: 'custom_blur',
      duration: at(1),
    );
    final window = node.resolveOverlap(boundaryTime: at(10));

    final result = lowerer.lower(
      NormalTransitionMotionGraphLoweringRequest(
        node: node,
        instance: instance,
        window: window,
        outgoingTarget: elementTarget(
          layerId: 'outgoing-layer',
          elementId: 'outgoing-element',
        ),
        incomingTarget: elementTarget(
          layerId: 'incoming-layer',
          elementId: 'incoming-element',
        ),
      ),
    );

    expect(result.hasErrors, isFalse);
    final channel = result.channels.single;
    expect(channel.definition.id, MotionPropertyCatalog.blurAmount.id);
    expect(
      channel.keyframes.map((keyframe) => keyframe.value.rawValue),
      <double>[0, 18, 0],
    );
    expect(
      channel.keyframes[1].interpolationToNext.kind,
      MotionInterpolationKind.easeOut,
    );
  });

  test('reports unsupported targets properties and values without hiding data',
      () {
    final instance = NormalTransitionInstance(
      id: 'instance',
      nodeId: 'node',
      definitionId: 'bad_recipe',
      sourceKind: NormalTransitionSourceKind.importedScript,
      sourceHash: 'script',
      schemaVersion: kNormalTransitionSchemaVersion,
      channels: <NormalTransitionChannelSpec>[
        NormalTransitionChannelSpec(
          target: 'center',
          property: 'opacity',
          keyframes: const <NormalTransitionKeyframeSpec>[
            NormalTransitionKeyframeSpec(normalizedTime: 0, value: 1),
          ],
        ),
        NormalTransitionChannelSpec(
          target: 'from',
          property: 'mystery',
          keyframes: const <NormalTransitionKeyframeSpec>[
            NormalTransitionKeyframeSpec(normalizedTime: 0, value: 1),
          ],
        ),
        NormalTransitionChannelSpec(
          target: 'to',
          property: 'opacity',
          keyframes: const <NormalTransitionKeyframeSpec>[
            NormalTransitionKeyframeSpec(normalizedTime: 0, value: 'bad'),
          ],
        ),
      ],
    );
    final node = NormalTransitionNode(
      id: 'node',
      trackId: 'main',
      leftClipId: 'clip-a',
      rightClipId: 'clip-b',
      definitionId: 'bad_recipe',
      duration: at(1),
    );

    final result = lowerer.lower(
      NormalTransitionMotionGraphLoweringRequest(
        node: node,
        instance: instance,
        window: node.resolveOverlap(boundaryTime: at(10)),
        outgoingTarget: elementTarget(
          layerId: 'outgoing-layer',
          elementId: 'outgoing-element',
        ),
        incomingTarget: elementTarget(
          layerId: 'incoming-layer',
          elementId: 'incoming-element',
        ),
      ),
    );

    expect(result.channels, isEmpty);
    expect(result.hasErrors, isTrue);
    expect(
      result.issues.map((issue) => issue.path),
      containsAll(<String>[
        'channels[0].target',
        'channels[1].property',
        'channels[2].keyframes[0].value',
      ]),
    );
  });
}
