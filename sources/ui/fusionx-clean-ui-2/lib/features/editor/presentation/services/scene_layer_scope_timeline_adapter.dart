import '../../domain/models/professional_motion_animation_models.dart';
import '../../domain/models/professional_motion_models.dart';
import '../../domain/services/composition_timeline_projection.dart';
import '../../domain/services/scene_scope_session.dart';
import '../models/timeline_mock_models.dart';
import '../models/timeline_time.dart';
import 'unified_scope_timeline_projection_adapter.dart';

enum SceneLayerScopeTimelineIssueCode {
  missingLayer,
  unsupportedLayerKind,
  missingProjection,
}

class SceneLayerScopeTimelineIssue {
  const SceneLayerScopeTimelineIssue({
    required this.code,
    required this.message,
    this.layerId,
  });

  final SceneLayerScopeTimelineIssueCode code;
  final String message;
  final String? layerId;
}

class SceneLayerScopeTimelineResult {
  SceneLayerScopeTimelineResult({
    this.viewModel,
    List<SceneLayerScopeTimelineIssue> issues =
        const <SceneLayerScopeTimelineIssue>[],
  }) : issues = List.unmodifiable(issues);

  final SceneLayerScopeTimelineViewModel? viewModel;
  final List<SceneLayerScopeTimelineIssue> issues;

  bool get hasIssues => issues.isNotEmpty;
}

class SceneLayerScopeTimelineViewModel {
  SceneLayerScopeTimelineViewModel({
    required this.sessionId,
    required this.sceneClipId,
    required this.sourceSceneId,
    required this.layer,
    required this.sourceStartTime,
    required this.durationTime,
    required this.track,
    required this.projection,
    required SceneScopeSession sceneSession,
  }) : _sceneSession = sceneSession;

  final String sessionId;
  final String sceneClipId;
  final String sourceSceneId;
  final MotionLayerModel layer;
  final TimelineTime sourceStartTime;
  final TimelineTime durationTime;
  final TimelineTrackData track;
  final ScopeProjection projection;
  final SceneScopeSession _sceneSession;

  String get layerId => layer.id;
  TimelineTime get sourceEndTime => sourceStartTime + durationTime;
  List<TimelineTrackData> get tracks => <TimelineTrackData>[track];

  TimelineTime localToRoot(TimelineTime localTime) {
    final sourceTime = (sourceStartTime + localTime).clamp(
      sourceStartTime,
      sourceEndTime,
    );
    return _sceneSession.sourceToRoot(sourceTime);
  }

  TimelineTime rootToLocal(TimelineTime rootTime) {
    final sourceTime = _sceneSession.rootToSource(rootTime).clamp(
          sourceStartTime,
          sourceEndTime,
        );
    return (sourceTime - sourceStartTime).clamp(
      TimelineTime.zero,
      durationTime,
    );
  }
}

class SceneLayerScopeTimelineAdapter {
  const SceneLayerScopeTimelineAdapter({
    this.projectionResolver = const CompositionTimelineProjectionResolver(),
    this.laneProjectionAdapter = const UnifiedScopeTimelineProjectionAdapter(),
  });

  final CompositionTimelineProjectionResolver projectionResolver;
  final UnifiedScopeTimelineProjectionAdapter laneProjectionAdapter;

  SceneLayerScopeTimelineResult viewModelForLayer({
    required MotionProjectModel project,
    required SceneScopeSession sceneSession,
    required String layerId,
    List<MotionPropertyChannelModel> channels =
        const <MotionPropertyChannelModel>[],
  }) {
    final layer = _findLayer(sceneSession.layers, layerId);
    if (layer == null) {
      return SceneLayerScopeTimelineResult(
        issues: <SceneLayerScopeTimelineIssue>[
          SceneLayerScopeTimelineIssue(
            code: SceneLayerScopeTimelineIssueCode.missingLayer,
            message: 'Layer `$layerId` was not found in this Scene Scope.',
            layerId: layerId,
          ),
        ],
      );
    }
    if (!_supportsLayerKind(layer.kind)) {
      return SceneLayerScopeTimelineResult(
        issues: <SceneLayerScopeTimelineIssue>[
          SceneLayerScopeTimelineIssue(
            code: SceneLayerScopeTimelineIssueCode.unsupportedLayerKind,
            message:
                '${_layerKindLabel(layer.kind)} Layer Scope is not enabled yet.',
            layerId: layerId,
          ),
        ],
      );
    }

    final projectionResult = projectionResolver.resolveLayerScope(
      project: project,
      sceneId: sceneSession.sourceSceneId,
      layerId: layer.id,
      globalTime: sceneSession.sourceTime,
      channels: channels,
    );
    final projection = projectionResult.projection;
    if (projection == null) {
      return SceneLayerScopeTimelineResult(
        issues: projectionResult.issues
            .map(
              (issue) => SceneLayerScopeTimelineIssue(
                code: SceneLayerScopeTimelineIssueCode.missingProjection,
                message: issue.message,
                layerId: layer.id,
              ),
            )
            .toList(growable: false),
      );
    }

    final duration = projection.localRange.duration;
    if (duration <= TimelineTime.zero) {
      return SceneLayerScopeTimelineResult(
        issues: <SceneLayerScopeTimelineIssue>[
          SceneLayerScopeTimelineIssue(
            code: SceneLayerScopeTimelineIssueCode.missingProjection,
            message: 'Layer `${layer.id}` has no editable duration.',
            layerId: layer.id,
          ),
        ],
      );
    }

    final localProjection = _projectionWithLayerLocalChannels(projection);
    final lanes = laneProjectionAdapter.animationLanesForScope(
      localProjection,
      targetClipId: layer.id,
    );
    final clip = TimelineClipData(
      id: layer.id,
      type: TimelineClipType.placeholder,
      tone: TimelineClipTone.aiGenerated,
      durationTime: duration,
      sourceStartTime: TimelineTime.zero,
      sourceDurationTime: duration,
      label: _layerLabel(layer),
      visualKind: _visualKindForLayer(layer),
    );
    final track = TimelineTrackData(
      kind: _trackKindForLayer(layer),
      contentKind: _trackContentKindForLayer(layer),
      visualKind: _visualKindForLayer(layer),
      placeholderLabel: _layerKindLabel(layer.kind),
      clips: <TimelineClipData>[clip],
      animationLanes: lanes,
    );

    return SceneLayerScopeTimelineResult(
      viewModel: SceneLayerScopeTimelineViewModel(
        sessionId: 'scene-layer-scope.${sceneSession.sceneClipId}.${layer.id}',
        sceneClipId: sceneSession.sceneClipId,
        sourceSceneId: sceneSession.sourceSceneId,
        layer: layer,
        sourceStartTime: projection.globalRange.start,
        durationTime: duration,
        track: track,
        projection: localProjection,
        sceneSession: sceneSession,
      ),
    );
  }

  ScopeProjection _projectionWithLayerLocalChannels(
      ScopeProjection projection) {
    final globalStart = projection.globalRange.start;
    final globalEnd = projection.globalRange.endExclusive;
    final duration = projection.localRange.duration;
    final localChannels = <MotionPropertyChannelModel>[
      for (final channel in projection.channels)
        _channelWithLayerLocalTime(
          channel: channel,
          globalStart: globalStart,
          globalEnd: globalEnd,
          duration: duration,
        ),
    ];
    return ScopeProjection(
      id: projection.id,
      mode: projection.mode,
      projectId: projection.projectId,
      sceneId: projection.sceneId,
      layerId: projection.layerId,
      transitionWindowId: projection.transitionWindowId,
      globalRange: projection.globalRange,
      localRange: projection.localRange,
      globalTime: projection.globalTime,
      localTime: projection.localTime,
      layers: projection.layers,
      elements: projection.elements,
      channels: localChannels,
    );
  }

  MotionPropertyChannelModel _channelWithLayerLocalTime({
    required MotionPropertyChannelModel channel,
    required TimelineTime globalStart,
    required TimelineTime globalEnd,
    required TimelineTime duration,
  }) {
    final normalizedKeyframes = channel.keyframes
        .map(
          (keyframe) => keyframe.copyWith(
            time: _layerLocalTimeFor(
              keyframe.time,
              globalStart: globalStart,
              globalEnd: globalEnd,
              duration: duration,
            ),
          ),
        )
        .toList(growable: false)
      ..sort((left, right) => left.time.compareTo(right.time));
    final activeRange = channel.activeRange;
    final normalizedActiveRange = activeRange == null
        ? null
        : TimelineTimeRange(
            start: _layerLocalTimeFor(
              activeRange.start,
              globalStart: globalStart,
              globalEnd: globalEnd,
              duration: duration,
            ),
            endExclusive: _layerLocalTimeFor(
              activeRange.endExclusive,
              globalStart: globalStart,
              globalEnd: globalEnd,
              duration: duration,
            ),
          );
    return channel.copyWith(
      activeRange: normalizedActiveRange,
      clearActiveRange: normalizedActiveRange == null,
      keyframes: normalizedKeyframes,
    );
  }

  TimelineTime _layerLocalTimeFor(
    TimelineTime time, {
    required TimelineTime globalStart,
    required TimelineTime globalEnd,
    required TimelineTime duration,
  }) {
    if (time >= globalStart && time <= globalEnd) {
      return (time - globalStart).clamp(TimelineTime.zero, duration);
    }
    return time.clamp(TimelineTime.zero, duration);
  }

  MotionLayerModel? _findLayer(List<MotionLayerModel> layers, String layerId) {
    for (final layer in layers) {
      if (layer.id == layerId) {
        return layer;
      }
    }
    return null;
  }

  bool _supportsLayerKind(MotionLayerKind kind) {
    return switch (kind) {
      MotionLayerKind.text ||
      MotionLayerKind.shape ||
      MotionLayerKind.image ||
      MotionLayerKind.video =>
        true,
      MotionLayerKind.audio ||
      MotionLayerKind.camera ||
      MotionLayerKind.effectControl =>
        false,
    };
  }

  TimelineTrackKind _trackKindForLayer(MotionLayerModel layer) {
    return switch (layer.kind) {
      MotionLayerKind.image => TimelineTrackKind.image,
      MotionLayerKind.video => TimelineTrackKind.video,
      MotionLayerKind.audio => TimelineTrackKind.audio,
      MotionLayerKind.text ||
      MotionLayerKind.shape ||
      MotionLayerKind.camera ||
      MotionLayerKind.effectControl =>
        TimelineTrackKind.text,
    };
  }

  TimelineTrackContentKind _trackContentKindForLayer(MotionLayerModel layer) {
    return switch (layer.kind) {
      MotionLayerKind.image => TimelineTrackContentKind.image,
      MotionLayerKind.video => TimelineTrackContentKind.video,
      MotionLayerKind.audio => TimelineTrackContentKind.audio,
      MotionLayerKind.text ||
      MotionLayerKind.shape ||
      MotionLayerKind.camera ||
      MotionLayerKind.effectControl =>
        TimelineTrackContentKind.text,
    };
  }

  TimelineVisualKind _visualKindForLayer(MotionLayerModel layer) {
    return switch (layer.kind) {
      MotionLayerKind.video => TimelineVisualKind.video,
      MotionLayerKind.image => TimelineVisualKind.image,
      MotionLayerKind.text => TimelineVisualKind.text,
      MotionLayerKind.shape => TimelineVisualKind.shape,
      MotionLayerKind.audio => TimelineVisualKind.audio,
      MotionLayerKind.camera => TimelineVisualKind.camera,
      MotionLayerKind.effectControl => TimelineVisualKind.control,
    };
  }

  String _layerKindLabel(MotionLayerKind kind) {
    return switch (kind) {
      MotionLayerKind.video => 'Video',
      MotionLayerKind.image => 'Image',
      MotionLayerKind.text => 'Text',
      MotionLayerKind.shape => 'Shape',
      MotionLayerKind.audio => 'Audio',
      MotionLayerKind.camera => 'Camera',
      MotionLayerKind.effectControl => 'Control',
    };
  }

  String _layerLabel(MotionLayerModel layer) {
    final name = layer.name?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    for (final element in layer.elements) {
      final elementName = element.name?.trim();
      if (elementName != null && elementName.isNotEmpty) {
        return elementName;
      }
    }
    return '${_layerKindLabel(layer.kind)} Layer';
  }
}
