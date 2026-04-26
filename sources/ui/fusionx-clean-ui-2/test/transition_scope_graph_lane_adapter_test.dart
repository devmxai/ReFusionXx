import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/domain/services/composition_timeline_projection.dart';
import 'package:refusion_app/features/editor/domain/services/normal_transition_catalog.dart';
import 'package:refusion_app/features/editor/domain/services/normal_transition_graph_authoring_service.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';
import 'package:refusion_app/features/editor/presentation/services/transition_scope_graph_lane_adapter.dart';

void main() {
  const transitionService = NormalTransitionGraphAuthoringService();
  const resolver = CompositionTimelineProjectionResolver();
  const laneAdapter = TransitionScopeGraphLaneAdapter();

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

  NormalTransitionGraphApplyResult transitionResult() {
    final definition =
        const NormalTransitionCatalog().loadBuiltIns().definitionById(
              'cross_dissolve',
            )!;
    return transitionService.createFromDefinition(
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
  }

  ScopeProjection transitionScope(NormalTransitionGraphApplyResult result) {
    return resolver
        .resolveTransitionScope(
          project: project(),
          context: TransitionScopeContext(
            id: result.bundle!.transitionWindowId,
            sceneId: 'scene',
            outgoingLayerId: 'outgoing-layer',
            incomingLayerId: 'incoming-layer',
            windowRange: result.bundle!.windowRange,
          ),
          globalTime: at(10),
          channels: result.bundle!.channels,
        )
        .projection!;
  }

  test('projects transition bundle lanes with stable role metadata', () {
    final result = transitionResult();
    final projection = laneAdapter.lanesForBundle(
      projection: transitionScope(result),
      bundle: result.bundle!,
    );

    expect(projection.hasIssues, isFalse);
    expect(projection.animationGroupId, result.bundle!.animationGroupId);
    expect(projection.presetId, 'cross_dissolve');
    expect(projection.transitionWindowId, result.bundle!.transitionWindowId);
    expect(
      projection.lanes.map((lane) => lane.label),
      <String>['Outgoing Opacity', 'Incoming Opacity'],
    );
    expect(
      projection.bindings.map((binding) => binding.role),
      <NormalTransitionGraphChannelRole>[
        NormalTransitionGraphChannelRole.outgoing,
        NormalTransitionGraphChannelRole.incoming,
      ],
    );

    final firstBinding = projection.bindingForLane(projection.lanes.first.id)!;
    expect(firstBinding.metadata['animationGroupId'],
        result.bundle!.animationGroupId);
    expect(firstBinding.metadata['presetId'], 'cross_dissolve');
    expect(firstBinding.metadata['role'], 'outgoing');
    expect(
        firstBinding.metadata['propertyId'], MotionPropertyCatalog.opacity.id);
  });

  test('returns lanes by outgoing and incoming role', () {
    final result = transitionResult();
    final projection = laneAdapter.lanesForBundle(
      projection: transitionScope(result),
      bundle: result.bundle!,
    );

    expect(
      projection
          .lanesForRole(NormalTransitionGraphChannelRole.outgoing)
          .map((lane) => lane.label),
      <String>['Outgoing Opacity'],
    );
    expect(
      projection
          .lanesForRole(NormalTransitionGraphChannelRole.incoming)
          .map((lane) => lane.label),
      <String>['Incoming Opacity'],
    );
  });

  test('rejects non-transition scope for transition bundle lanes', () {
    final result = transitionResult();
    final sceneScope = resolver
        .resolveSceneScope(
          project: project(),
          sceneId: 'scene',
          globalTime: at(10),
          channels: result.bundle!.channels,
        )
        .projection!;

    final projection = laneAdapter.lanesForBundle(
      projection: sceneScope,
      bundle: result.bundle!,
    );

    expect(projection.lanes, isEmpty);
    expect(
      projection.issues.single.code,
      TransitionScopeGraphLaneIssueCode.nonTransitionScope,
    );
  });

  test('rejects mismatched transition window ids', () {
    final result = transitionResult();
    final scope = transitionScope(result);
    final mismatchedScope = ScopeProjection(
      id: scope.id,
      mode: scope.mode,
      projectId: scope.projectId,
      sceneId: scope.sceneId,
      globalRange: scope.globalRange,
      localRange: scope.localRange,
      globalTime: scope.globalTime,
      localTime: scope.localTime,
      layers: scope.layers,
      elements: scope.elements,
      channels: scope.channels,
      transitionWindowId: 'different-window',
    );

    final projection = laneAdapter.lanesForBundle(
      projection: mismatchedScope,
      bundle: result.bundle!,
    );

    expect(projection.lanes, isEmpty);
    expect(
      projection.issues.single.code,
      TransitionScopeGraphLaneIssueCode.transitionWindowMismatch,
    );
  });
}
