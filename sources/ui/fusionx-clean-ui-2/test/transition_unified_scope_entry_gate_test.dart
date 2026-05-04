import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/domain/services/composition_timeline_projection.dart';
import 'package:refusion_app/features/editor/domain/services/normal_transition_catalog.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';
import 'package:refusion_app/features/editor/presentation/services/transition_scope_graph_authoring_adapter.dart';
import 'package:refusion_app/features/editor/presentation/services/transition_unified_scope_entry_gate.dart';

void main() {
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

  TransitionScopeGraphAuthoringRequest request({
    String incomingLayerId = 'incoming-layer',
    TimelineTime? leftAvailableTail,
  }) {
    final definition =
        const NormalTransitionCatalog().loadBuiltIns().definitionById(
              'cross_dissolve',
            )!;
    return TransitionScopeGraphAuthoringRequest(
      project: project(),
      sceneId: 'scene',
      definition: definition,
      trackId: 'main-video',
      leftClipId: 'clip-a',
      rightClipId: 'clip-b',
      outgoingLayerId: 'outgoing-layer',
      incomingLayerId: incomingLayerId,
      boundaryTime: at(10),
      leftAvailableTail: leftAvailableTail ?? at(2),
      rightAvailableHead: at(2),
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

  test('feature-enabled entry opens graph-backed unified scope', () {
    final gate = TransitionUnifiedScopeEntryGate();

    final result = gate.resolveEntry(request());

    expect(result.opensUnifiedScope, isTrue);
    expect(result.fallbackReason, isNull);
    expect(result.unifiedScope!.canOpenUnifiedScope, isTrue);
    expect(result.unifiedScope!.scope!.mode, CompositionScopeMode.transition);
    expect(
      result.unifiedScope!.lanes!.lanes.map((lane) => lane.label),
      <String>['Outgoing Opacity', 'Incoming Opacity'],
    );
  });

  test('blocked graph apply falls back with graph issues', () {
    final gate = TransitionUnifiedScopeEntryGate();

    final result = gate.resolveEntry(
      request(leftAvailableTail: TimelineTime.fromMilliseconds(1)),
    );

    expect(result.opensUnifiedScope, isFalse);
    expect(
      result.fallbackReason,
      TransitionUnifiedScopeEntryFallbackReason.graphApplyBlocked,
    );
    expect(result.unifiedScope!.graph.canApply, isFalse);
    expect(
        result.graphIssues.map((issue) => issue.path), contains('leftClipId'));
  });

  test('invalid transition scope falls back with projection issues', () {
    final gate = TransitionUnifiedScopeEntryGate();

    final result = gate.resolveEntry(
      request(incomingLayerId: 'missing-layer'),
    );

    expect(result.opensUnifiedScope, isFalse);
    expect(
      result.fallbackReason,
      TransitionUnifiedScopeEntryFallbackReason.projectionBlocked,
    );
    expect(
      result.projectionIssues.single.code,
      CompositionProjectionIssueCode.missingLayer,
    );
  });
}
