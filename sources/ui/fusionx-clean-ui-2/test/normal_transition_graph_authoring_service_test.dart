import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_normal_transition_models.dart';
import 'package:refusion_app/features/editor/domain/services/composition_timeline_projection.dart';
import 'package:refusion_app/features/editor/domain/services/normal_transition_catalog.dart';
import 'package:refusion_app/features/editor/domain/services/normal_transition_graph_authoring_service.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';
import 'package:refusion_app/features/editor/presentation/services/unified_scope_timeline_projection_adapter.dart';

void main() {
  const service = NormalTransitionGraphAuthoringService();
  const resolver = CompositionTimelineProjectionResolver();
  const laneAdapter = UnifiedScopeTimelineProjectionAdapter();

  TimelineTime at(double seconds) => TimelineTime.fromSecondsDouble(seconds);

  TimelineTimeRange range(double start, double end) {
    return TimelineTimeRange(
      start: at(start),
      endExclusive: at(end),
    );
  }

  MotionPropertyTarget target({
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

  NormalTransitionDefinition crossDissolveDefinition() {
    return const NormalTransitionCatalog().loadBuiltIns().definitionById(
          'cross_dissolve',
        )!;
  }

  NormalTransitionGraphApplyRequest crossDissolveRequest({
    TimelineTime? leftAvailableTail,
    TimelineTime? rightAvailableHead,
  }) {
    return NormalTransitionGraphApplyRequest(
      definition: crossDissolveDefinition(),
      trackId: 'main-video',
      leftClipId: 'clip-a',
      rightClipId: 'clip-b',
      boundaryTime: at(10),
      leftAvailableTail: leftAvailableTail ?? at(2),
      rightAvailableHead: rightAvailableHead ?? at(2),
      outgoingTarget: target(
        layerId: 'outgoing-layer',
        elementId: 'outgoing-element',
      ),
      incomingTarget: target(
        layerId: 'incoming-layer',
        elementId: 'incoming-element',
      ),
    );
  }

  MotionProjectModel project() {
    MotionElementModel element({
      required String layerId,
      required String elementId,
    }) {
      return MotionElementModel(
        id: elementId,
        layerId: layerId,
        kind: MotionElementKind.videoClip,
        localRange: range(0, 10),
      );
    }

    MotionLayerModel layer({
      required String layerId,
      required MotionElementModel element,
      required TimelineTimeRange visibleRange,
    }) {
      return MotionLayerModel(
        id: layerId,
        sceneId: 'scene',
        kind: MotionLayerKind.video,
        visibleRange: visibleRange,
        elements: <MotionElementModel>[element],
      );
    }

    final outgoing = element(
      layerId: 'outgoing-layer',
      elementId: 'outgoing-element',
    );
    final incoming = element(
      layerId: 'incoming-layer',
      elementId: 'incoming-element',
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
              element: outgoing,
              visibleRange: range(0, 10),
            ),
            layer(
              layerId: 'incoming-layer',
              element: incoming,
              visibleRange: range(10, 20),
            ),
          ],
        ),
      ],
    );
  }

  test('creates transition node instance and editable graph channels together',
      () {
    final result = service.createFromDefinition(crossDissolveRequest());

    expect(result.canApply, isTrue);
    expect(result.node!.definitionId, 'cross_dissolve');
    expect(result.instance!.nodeId, result.node!.id);
    expect(result.window!.boundaryTime, at(10));
    expect(result.bundle, isNotNull);
    expect(result.bundle!.presetId, 'cross_dissolve');
    expect(result.bundle!.transitionWindowId, result.node!.id);
    expect(result.bundle!.nodeId, result.node!.id);
    expect(result.bundle!.instanceId, result.instance!.id);
    expect(result.bundle!.windowRange.start, result.window!.start);
    expect(
        result.bundle!.windowRange.endExclusive, result.window!.endExclusive);
    expect(result.graphChannels, hasLength(2));
    expect(
      result.graphChannels.map((channel) => channel.definition.id),
      <String>[
        MotionPropertyCatalog.opacity.id,
        MotionPropertyCatalog.opacity.id,
      ],
    );
    expect(
      result.graphChannels.map((channel) => channel.target.targetId),
      <String>['outgoing-element', 'incoming-element'],
    );
    expect(
      result.bundle!.channelBindings.map((binding) => binding.role),
      <NormalTransitionGraphChannelRole>[
        NormalTransitionGraphChannelRole.outgoing,
        NormalTransitionGraphChannelRole.incoming,
      ],
    );
    expect(
      result.bundle!.channelsForRole(
        NormalTransitionGraphChannelRole.outgoing,
      ),
      <Object>[result.graphChannels.first],
    );
  });

  test('lowered channels project into unified transition scope lanes', () {
    final result = service.createFromDefinition(crossDissolveRequest());

    final scope = resolver
        .resolveTransitionScope(
          project: project(),
          context: TransitionScopeContext(
            id: result.node!.id,
            sceneId: 'scene',
            outgoingLayerId: 'outgoing-layer',
            incomingLayerId: 'incoming-layer',
            windowRange: TimelineTimeRange(
              start: result.window!.start,
              endExclusive: result.window!.endExclusive,
            ),
          ),
          globalTime: at(10),
          channels: result.graphChannels,
        )
        .projection!;
    final lanes = laneAdapter.animationLanesForScope(
      scope,
      targetClipId: result.node!.id,
    );

    expect(scope.mode, CompositionScopeMode.transition);
    expect(lanes, hasLength(2));
    expect(lanes.map((lane) => lane.label), everyElement('Opacity'));
    expect(
      lanes.map((lane) => lane.normalizedKeyframeStops),
      everyElement(<double>[0, 1]),
    );
  });

  test('exposes transition metadata for every graph channel', () {
    final result = service.createFromDefinition(crossDissolveRequest());
    final bundle = result.bundle!;
    final outgoingMetadata = bundle.metadataForChannel(
      result.graphChannels.first.id,
    );
    final incomingMetadata = bundle.metadataForChannel(
      result.graphChannels.last.id,
    );

    expect(outgoingMetadata['animationGroupId'], bundle.animationGroupId);
    expect(outgoingMetadata['presetId'], 'cross_dissolve');
    expect(outgoingMetadata['transitionWindowId'], result.node!.id);
    expect(outgoingMetadata['role'], 'outgoing');
    expect(outgoingMetadata['propertyId'], MotionPropertyCatalog.opacity.id);
    expect(incomingMetadata['role'], 'incoming');
  });

  test('passes parameter overrides through authoring and graph lowering', () {
    final definition = NormalTransitionDefinition(
      definitionId: 'blur_peak',
      schemaVersion: kNormalTransitionSchemaVersion,
      label: 'Blur Peak',
      category: NormalTransitionCategory.blur,
      rendererTier: NormalTransitionRendererTier.primitive,
      defaultDuration: at(1),
      parameters: <NormalTransitionParameterSchema>[
        NormalTransitionParameterSchema(
          name: 'peakBlur',
          type: NormalTransitionParameterType.number,
          defaultValue: 8.0,
          range: const NormalTransitionNumberRange(min: 0, max: 40),
        ),
      ],
      channels: <NormalTransitionChannelSpec>[
        NormalTransitionChannelSpec(
          target: 'to',
          property: 'blurAmount',
          keyframes: const <NormalTransitionKeyframeSpec>[
            NormalTransitionKeyframeSpec(normalizedTime: 0, value: 0),
            NormalTransitionKeyframeSpec(
              normalizedTime: 0.5,
              value: r'$peakBlur',
            ),
            NormalTransitionKeyframeSpec(normalizedTime: 1, value: 0),
          ],
        ),
      ],
    );

    final result = service.createFromDefinition(
      NormalTransitionGraphApplyRequest(
        definition: definition,
        trackId: 'main-video',
        leftClipId: 'clip-a',
        rightClipId: 'clip-b',
        boundaryTime: at(10),
        leftAvailableTail: at(2),
        rightAvailableHead: at(2),
        outgoingTarget: target(
          layerId: 'outgoing-layer',
          elementId: 'outgoing-element',
        ),
        incomingTarget: target(
          layerId: 'incoming-layer',
          elementId: 'incoming-element',
        ),
        parameterOverrides: const <String, Object>{'peakBlur': 18.0},
      ),
    );

    expect(result.canApply, isTrue);
    expect(result.instance!.parameterValues['peakBlur'], 18.0);
    expect(result.graphChannels.single.definition.id,
        MotionPropertyCatalog.blurAmount.id);
    expect(
      result.graphChannels.single.keyframes.map(
        (keyframe) => keyframe.value.rawValue,
      ),
      <double>[0, 18, 0],
    );
  });

  test('blocks graph transition creation when handles are insufficient', () {
    final result = service.createFromDefinition(
      crossDissolveRequest(
        leftAvailableTail: TimelineTime.fromMilliseconds(10),
      ),
    );

    expect(result.canApply, isFalse);
    expect(result.bundle, isNull);
    expect(result.node, isNull);
    expect(result.instance, isNull);
    expect(result.graphChannels, isEmpty);
    expect(result.window, isNotNull);
    expect(
      result.issues.map((issue) => issue.path),
      contains('leftClipId'),
    );
  });

  test('blocks graph transition creation for recipes without graph channels',
      () {
    final definition = NormalTransitionDefinition(
      definitionId: 'empty_transition',
      schemaVersion: kNormalTransitionSchemaVersion,
      label: 'Empty Transition',
      category: NormalTransitionCategory.custom,
      rendererTier: NormalTransitionRendererTier.primitive,
      defaultDuration: at(1),
    );

    final result = service.createFromDefinition(
      NormalTransitionGraphApplyRequest(
        definition: definition,
        trackId: 'main-video',
        leftClipId: 'clip-a',
        rightClipId: 'clip-b',
        boundaryTime: at(10),
        leftAvailableTail: at(2),
        rightAvailableHead: at(2),
        outgoingTarget: target(
          layerId: 'outgoing-layer',
          elementId: 'outgoing-element',
        ),
        incomingTarget: target(
          layerId: 'incoming-layer',
          elementId: 'incoming-element',
        ),
      ),
    );

    expect(result.canApply, isFalse);
    expect(result.bundle, isNotNull);
    expect(result.graphChannels, isEmpty);
    expect(
      result.issues.map((issue) => issue.path),
      contains('channels'),
    );
  });
}
