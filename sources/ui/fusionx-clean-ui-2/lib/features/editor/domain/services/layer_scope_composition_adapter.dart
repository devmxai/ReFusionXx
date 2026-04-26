import '../models/professional_canvas_timeline_authoring_models.dart';
import '../models/professional_motion_animation_models.dart';
import '../models/professional_motion_models.dart';
import '../../presentation/models/timeline_time.dart';
import 'canvas_timeline_unified_keyframe_adapter.dart';
import 'composition_timeline_projection.dart';

class LayerScopeCompositionAdapter {
  const LayerScopeCompositionAdapter({
    this.projectionResolver = const CompositionTimelineProjectionResolver(),
    this.keyframeAdapter,
  });

  final CompositionTimelineProjectionResolver projectionResolver;
  final CanvasTimelineUnifiedKeyframeAdapter? keyframeAdapter;

  CanvasTimelineUnifiedKeyframeAdapter get _keyframes =>
      keyframeAdapter ?? CanvasTimelineUnifiedKeyframeAdapter();

  ScopeProjectionResult resolveScope({
    required MotionProjectModel project,
    required String sceneId,
    required String layerId,
    required TimelineTime globalTime,
    List<MotionPropertyChannelModel> channels =
        const <MotionPropertyChannelModel>[],
  }) {
    return projectionResolver.resolveLayerScope(
      project: project,
      sceneId: sceneId,
      layerId: layerId,
      globalTime: globalTime,
      channels: channels,
    );
  }

  CanvasTimelineAuthoringResult addKeyframe(
    LayerScopeCompositionKeyframeRequest request,
  ) {
    final issue = _validateTarget(request.projection, request.target);
    if (issue != null) {
      return CanvasTimelineAuthoringResult(
        channels: request.channels,
        issues: <CanvasTimelineAuthoringIssue>[issue],
      );
    }
    return _keyframes.addKeyframe(
      CanvasTimelineKeyframeRequest(
        channels: request.channels,
        target: request.target,
        activeRange: request.projection.localRange,
        definition: request.definition,
        time: request.localTime.clamp(
          request.projection.localRange.start,
          request.projection.localRange.endExclusive,
        ),
        value: request.value,
        interpolation: request.interpolation,
      ),
    );
  }

  CanvasTimelineAuthoringResult moveKeyframe(
    LayerScopeCompositionMoveKeyframeRequest request,
  ) {
    return _keyframes.moveKeyframe(
      CanvasTimelineMoveKeyframeRequest(
        channels: request.channels,
        channelId: request.channelId,
        keyframeId: request.keyframeId,
        activeRange: request.projection.localRange,
        time: request.localTime.clamp(
          request.projection.localRange.start,
          request.projection.localRange.endExclusive,
        ),
      ),
    );
  }

  CanvasTimelineAuthoringResult setKeyframeValue(
    LayerScopeCompositionKeyframeValueRequest request,
  ) {
    return _keyframes.setKeyframeValue(
      CanvasTimelineKeyframeValueRequest(
        channels: request.channels,
        channelId: request.channelId,
        keyframeId: request.keyframeId,
        value: request.value,
      ),
    );
  }

  CanvasTimelineAuthoringResult setKeyframeInterpolation(
    LayerScopeCompositionKeyframeInterpolationRequest request,
  ) {
    return _keyframes.setKeyframeInterpolation(
      CanvasTimelineKeyframeInterpolationRequest(
        channels: request.channels,
        channelId: request.channelId,
        keyframeId: request.keyframeId,
        interpolation: request.interpolation,
      ),
    );
  }

  CanvasTimelineAuthoringResult deleteKeyframe(
    LayerScopeCompositionDeleteKeyframeRequest request,
  ) {
    return _keyframes.deleteKeyframe(
      CanvasTimelineDeleteKeyframeRequest(
        channels: request.channels,
        channelId: request.channelId,
        keyframeId: request.keyframeId,
      ),
    );
  }

  CanvasTimelineAuthoringIssue? _validateTarget(
    ScopeProjection projection,
    MotionPropertyTarget target,
  ) {
    final layerIds = projection.layers.map((layer) => layer.id).toSet();
    final elementIds = projection.elements.map((element) => element.id).toSet();
    final belongsToScope = switch (target.kind) {
      MotionTargetKind.layer => layerIds.contains(target.targetId) ||
          (target.layerId != null && layerIds.contains(target.layerId)),
      MotionTargetKind.element => elementIds.contains(target.targetId) ||
          (target.elementId != null && elementIds.contains(target.elementId)),
      MotionTargetKind.project || MotionTargetKind.scene => false,
    };
    if (belongsToScope) {
      return null;
    }
    return CanvasTimelineAuthoringIssue(
      code: CanvasTimelineAuthoringIssueCode.unsupportedTarget,
      message: 'Target "${target.canonicalAddress}" is outside this scope.',
    );
  }
}

class LayerScopeCompositionKeyframeRequest {
  LayerScopeCompositionKeyframeRequest({
    required this.projection,
    required List<MotionPropertyChannelModel> channels,
    required this.target,
    required this.definition,
    required this.localTime,
    required this.value,
    this.interpolation = const MotionInterpolationSpec.linear(),
  }) : channels = List.unmodifiable(channels);

  final ScopeProjection projection;
  final List<MotionPropertyChannelModel> channels;
  final MotionPropertyTarget target;
  final MotionPropertyDefinition definition;
  final TimelineTime localTime;
  final MotionPropertyValue value;
  final MotionInterpolationSpec interpolation;
}

class LayerScopeCompositionMoveKeyframeRequest {
  LayerScopeCompositionMoveKeyframeRequest({
    required this.projection,
    required List<MotionPropertyChannelModel> channels,
    required this.channelId,
    required this.keyframeId,
    required this.localTime,
  }) : channels = List.unmodifiable(channels);

  final ScopeProjection projection;
  final List<MotionPropertyChannelModel> channels;
  final String channelId;
  final String keyframeId;
  final TimelineTime localTime;
}

class LayerScopeCompositionKeyframeValueRequest {
  LayerScopeCompositionKeyframeValueRequest({
    required List<MotionPropertyChannelModel> channels,
    required this.channelId,
    required this.keyframeId,
    required this.value,
  }) : channels = List.unmodifiable(channels);

  final List<MotionPropertyChannelModel> channels;
  final String channelId;
  final String keyframeId;
  final MotionPropertyValue value;
}

class LayerScopeCompositionKeyframeInterpolationRequest {
  LayerScopeCompositionKeyframeInterpolationRequest({
    required List<MotionPropertyChannelModel> channels,
    required this.channelId,
    required this.keyframeId,
    required this.interpolation,
  }) : channels = List.unmodifiable(channels);

  final List<MotionPropertyChannelModel> channels;
  final String channelId;
  final String keyframeId;
  final MotionInterpolationSpec interpolation;
}

class LayerScopeCompositionDeleteKeyframeRequest {
  LayerScopeCompositionDeleteKeyframeRequest({
    required List<MotionPropertyChannelModel> channels,
    required this.channelId,
    required this.keyframeId,
  }) : channels = List.unmodifiable(channels);

  final List<MotionPropertyChannelModel> channels;
  final String channelId;
  final String keyframeId;
}
