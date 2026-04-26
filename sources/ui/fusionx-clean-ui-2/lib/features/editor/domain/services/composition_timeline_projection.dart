import 'package:flutter/foundation.dart';

import '../../presentation/models/timeline_time.dart';
import '../models/professional_motion_animation_models.dart';
import '../models/professional_motion_models.dart';

enum CompositionScopeMode {
  scene,
  layer,
  transition,
}

enum CompositionProjectionIssueCode {
  missingScene,
  missingLayer,
  invalidTransitionWindow,
}

@immutable
class CompositionProjectionIssue {
  const CompositionProjectionIssue({
    required this.code,
    required this.message,
    this.sceneId,
    this.layerId,
    this.transitionWindowId,
  });

  final CompositionProjectionIssueCode code;
  final String message;
  final String? sceneId;
  final String? layerId;
  final String? transitionWindowId;
}

@immutable
class CompositionTimelineProjection {
  CompositionTimelineProjection({
    required this.projectId,
    required this.sceneId,
    required this.compositionRange,
    required this.globalTime,
    required List<MotionLayerModel> layers,
    required List<MotionPropertyChannelModel> channels,
  })  : layers = List.unmodifiable(layers),
        channels = List.unmodifiable(channels);

  final String projectId;
  final String sceneId;
  final TimelineTimeRange compositionRange;
  final TimelineTime globalTime;
  final List<MotionLayerModel> layers;
  final List<MotionPropertyChannelModel> channels;

  TimelineTime get duration => compositionRange.duration;
}

@immutable
class ScopeProjection {
  ScopeProjection({
    required this.id,
    required this.mode,
    required this.projectId,
    required this.sceneId,
    required this.globalRange,
    required this.localRange,
    required this.globalTime,
    required this.localTime,
    required List<MotionLayerModel> layers,
    required List<MotionElementModel> elements,
    required List<MotionPropertyChannelModel> channels,
    this.layerId,
    this.transitionWindowId,
  })  : layers = List.unmodifiable(layers),
        elements = List.unmodifiable(elements),
        channels = List.unmodifiable(channels);

  final String id;
  final CompositionScopeMode mode;
  final String projectId;
  final String sceneId;
  final String? layerId;
  final String? transitionWindowId;
  final TimelineTimeRange globalRange;
  final TimelineTimeRange localRange;
  final TimelineTime globalTime;
  final TimelineTime localTime;
  final List<MotionLayerModel> layers;
  final List<MotionElementModel> elements;
  final List<MotionPropertyChannelModel> channels;

  TimelineTime localToGlobal(TimelineTime local) {
    return (globalRange.start + local).clamp(
      globalRange.start,
      globalRange.endExclusive,
    );
  }

  TimelineTime globalToLocal(TimelineTime global) {
    return _localTimeForRange(globalRange: globalRange, globalTime: global);
  }
}

@immutable
class TransitionScopeContext {
  const TransitionScopeContext({
    required this.id,
    required this.sceneId,
    required this.outgoingLayerId,
    required this.incomingLayerId,
    required this.windowRange,
  });

  final String id;
  final String sceneId;
  final String outgoingLayerId;
  final String incomingLayerId;
  final TimelineTimeRange windowRange;
}

@immutable
class CompositionTimelineProjectionResult {
  CompositionTimelineProjectionResult({
    this.projection,
    List<CompositionProjectionIssue> issues =
        const <CompositionProjectionIssue>[],
  }) : issues = List.unmodifiable(issues);

  final CompositionTimelineProjection? projection;
  final List<CompositionProjectionIssue> issues;

  bool get hasIssues => issues.isNotEmpty;
}

@immutable
class ScopeProjectionResult {
  ScopeProjectionResult({
    this.projection,
    List<CompositionProjectionIssue> issues =
        const <CompositionProjectionIssue>[],
  }) : issues = List.unmodifiable(issues);

  final ScopeProjection? projection;
  final List<CompositionProjectionIssue> issues;

  bool get hasIssues => issues.isNotEmpty;
}

class CompositionTimelineProjectionResolver {
  const CompositionTimelineProjectionResolver();

  CompositionTimelineProjectionResult resolveComposition({
    required MotionProjectModel project,
    required String sceneId,
    required TimelineTime globalTime,
    List<MotionPropertyChannelModel> channels =
        const <MotionPropertyChannelModel>[],
  }) {
    final scene = _findScene(project: project, sceneId: sceneId);
    if (scene == null) {
      return CompositionTimelineProjectionResult(
        issues: <CompositionProjectionIssue>[
          CompositionProjectionIssue(
            code: CompositionProjectionIssueCode.missingScene,
            message: 'Scene "$sceneId" was not found.',
            sceneId: sceneId,
          ),
        ],
      );
    }

    final sceneChannels = channels
        .where((channel) => _channelTargetsScene(channel, scene))
        .toList(growable: false);
    final enabledLayers = scene.layers
        .where((layer) => layer.isEnabled)
        .toList(growable: false)
      ..sort((left, right) => left.zIndex.compareTo(right.zIndex));

    return CompositionTimelineProjectionResult(
      projection: CompositionTimelineProjection(
        projectId: project.id,
        sceneId: scene.id,
        compositionRange: scene.projectRange,
        globalTime: globalTime.clamp(
          scene.projectRange.start,
          scene.projectRange.endExclusive,
        ),
        layers: enabledLayers,
        channels: sceneChannels,
      ),
    );
  }

  ScopeProjectionResult resolveSceneScope({
    required MotionProjectModel project,
    required String sceneId,
    required TimelineTime globalTime,
    List<MotionPropertyChannelModel> channels =
        const <MotionPropertyChannelModel>[],
  }) {
    final composition = resolveComposition(
      project: project,
      sceneId: sceneId,
      globalTime: globalTime,
      channels: channels,
    );
    final projection = composition.projection;
    if (projection == null) {
      return ScopeProjectionResult(issues: composition.issues);
    }

    return ScopeProjectionResult(
      projection: ScopeProjection(
        id: 'scope.scene.${projection.sceneId}',
        mode: CompositionScopeMode.scene,
        projectId: projection.projectId,
        sceneId: projection.sceneId,
        globalRange: projection.compositionRange,
        localRange: _localRangeFor(projection.compositionRange),
        globalTime: projection.globalTime,
        localTime: _localTimeForRange(
          globalRange: projection.compositionRange,
          globalTime: projection.globalTime,
        ),
        layers: projection.layers,
        elements: projection.layers
            .expand((layer) => layer.elements)
            .toList(growable: false),
        channels: projection.channels,
      ),
    );
  }

  ScopeProjectionResult resolveLayerScope({
    required MotionProjectModel project,
    required String sceneId,
    required String layerId,
    required TimelineTime globalTime,
    List<MotionPropertyChannelModel> channels =
        const <MotionPropertyChannelModel>[],
  }) {
    final scene = _findScene(project: project, sceneId: sceneId);
    if (scene == null) {
      return ScopeProjectionResult(
        issues: <CompositionProjectionIssue>[
          CompositionProjectionIssue(
            code: CompositionProjectionIssueCode.missingScene,
            message: 'Scene "$sceneId" was not found.',
            sceneId: sceneId,
          ),
        ],
      );
    }
    final layer = _findLayer(scene: scene, layerId: layerId);
    if (layer == null) {
      return ScopeProjectionResult(
        issues: <CompositionProjectionIssue>[
          CompositionProjectionIssue(
            code: CompositionProjectionIssueCode.missingLayer,
            message: 'Layer "$layerId" was not found.',
            sceneId: sceneId,
            layerId: layerId,
          ),
        ],
      );
    }

    return ScopeProjectionResult(
      projection: ScopeProjection(
        id: 'scope.layer.${scene.id}.${layer.id}',
        mode: CompositionScopeMode.layer,
        projectId: project.id,
        sceneId: scene.id,
        layerId: layer.id,
        globalRange: layer.visibleRange,
        localRange: _localRangeFor(layer.visibleRange),
        globalTime: globalTime.clamp(
          layer.visibleRange.start,
          layer.visibleRange.endExclusive,
        ),
        localTime: _localTimeForRange(
          globalRange: layer.visibleRange,
          globalTime: globalTime,
        ),
        layers: <MotionLayerModel>[layer],
        elements: layer.elements,
        channels: channels
            .where((channel) => _channelTargetsLayer(channel, layer))
            .toList(growable: false),
      ),
    );
  }

  ScopeProjectionResult resolveTransitionScope({
    required MotionProjectModel project,
    required TransitionScopeContext context,
    required TimelineTime globalTime,
    List<MotionPropertyChannelModel> channels =
        const <MotionPropertyChannelModel>[],
  }) {
    final scene = _findScene(project: project, sceneId: context.sceneId);
    if (scene == null) {
      return ScopeProjectionResult(
        issues: <CompositionProjectionIssue>[
          CompositionProjectionIssue(
            code: CompositionProjectionIssueCode.missingScene,
            message: 'Scene "${context.sceneId}" was not found.',
            sceneId: context.sceneId,
            transitionWindowId: context.id,
          ),
        ],
      );
    }
    final outgoing = _findLayer(scene: scene, layerId: context.outgoingLayerId);
    final incoming = _findLayer(scene: scene, layerId: context.incomingLayerId);
    final issues = <CompositionProjectionIssue>[
      if (outgoing == null)
        CompositionProjectionIssue(
          code: CompositionProjectionIssueCode.missingLayer,
          message: 'Outgoing layer "${context.outgoingLayerId}" was not found.',
          sceneId: scene.id,
          layerId: context.outgoingLayerId,
          transitionWindowId: context.id,
        ),
      if (incoming == null)
        CompositionProjectionIssue(
          code: CompositionProjectionIssueCode.missingLayer,
          message: 'Incoming layer "${context.incomingLayerId}" was not found.',
          sceneId: scene.id,
          layerId: context.incomingLayerId,
          transitionWindowId: context.id,
        ),
      if (context.windowRange.duration <= TimelineTime.zero)
        CompositionProjectionIssue(
          code: CompositionProjectionIssueCode.invalidTransitionWindow,
          message: 'Transition window "${context.id}" has no duration.',
          sceneId: scene.id,
          transitionWindowId: context.id,
        ),
    ];
    if (issues.isNotEmpty) {
      return ScopeProjectionResult(issues: issues);
    }

    final layers = <MotionLayerModel>[outgoing!, incoming!];
    final targetLayerIds = layers.map((layer) => layer.id).toSet();
    final targetChannels = channels.where((channel) {
      final target = channel.target;
      return target.layerId != null &&
              targetLayerIds.contains(target.layerId) ||
          targetLayerIds.contains(target.targetId) ||
          layers.any((layer) => _channelTargetsLayer(channel, layer));
    }).toList(growable: false);

    return ScopeProjectionResult(
      projection: ScopeProjection(
        id: 'scope.transition.${scene.id}.${context.id}',
        mode: CompositionScopeMode.transition,
        projectId: project.id,
        sceneId: scene.id,
        transitionWindowId: context.id,
        globalRange: context.windowRange,
        localRange: _localRangeFor(context.windowRange),
        globalTime: globalTime.clamp(
          context.windowRange.start,
          context.windowRange.endExclusive,
        ),
        localTime: _localTimeForRange(
          globalRange: context.windowRange,
          globalTime: globalTime,
        ),
        layers: layers,
        elements: layers.expand((layer) => layer.elements).toList(),
        channels: targetChannels,
      ),
    );
  }

  MotionSceneModel? _findScene({
    required MotionProjectModel project,
    required String sceneId,
  }) {
    for (final scene in project.scenes) {
      if (scene.id == sceneId) {
        return scene;
      }
    }
    return null;
  }

  MotionLayerModel? _findLayer({
    required MotionSceneModel scene,
    required String layerId,
  }) {
    for (final layer in scene.layers) {
      if (layer.id == layerId) {
        return layer;
      }
    }
    return null;
  }

  bool _channelTargetsScene(
    MotionPropertyChannelModel channel,
    MotionSceneModel scene,
  ) {
    final target = channel.target;
    if (target.kind == MotionTargetKind.scene && target.targetId == scene.id) {
      return true;
    }
    if (target.sceneId != null && target.sceneId != scene.id) {
      return false;
    }
    return scene.layers.any((layer) => _channelTargetsLayer(channel, layer));
  }

  bool _channelTargetsLayer(
    MotionPropertyChannelModel channel,
    MotionLayerModel layer,
  ) {
    final target = channel.target;
    if (target.kind == MotionTargetKind.layer && target.targetId == layer.id) {
      return true;
    }
    if (target.layerId == layer.id) {
      return true;
    }
    final elementIds = layer.elements.map((element) => element.id).toSet();
    if (target.elementId != null && elementIds.contains(target.elementId)) {
      return true;
    }
    return target.kind == MotionTargetKind.element &&
        elementIds.contains(target.targetId);
  }
}

TimelineTimeRange _localRangeFor(TimelineTimeRange globalRange) {
  return TimelineTimeRange(
    start: TimelineTime.zero,
    endExclusive: globalRange.duration,
  );
}

TimelineTime _localTimeForRange({
  required TimelineTimeRange globalRange,
  required TimelineTime globalTime,
}) {
  return (globalTime - globalRange.start).clamp(
    TimelineTime.zero,
    globalRange.duration,
  );
}
