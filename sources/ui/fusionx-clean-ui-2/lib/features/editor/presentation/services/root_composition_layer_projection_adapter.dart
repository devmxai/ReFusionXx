import '../../domain/models/composition_scene_clip_models.dart';
import '../../domain/models/composition_workspace_models.dart';
import '../models/timeline_time.dart';

enum RootCompositionLayerProjectionKind {
  background,
  sceneClip,
}

enum RootCompositionLayerProjectionIssueCode {
  invalidBackgroundLayer,
  invalidSceneClip,
}

class RootCompositionLayerProjectionIssue {
  const RootCompositionLayerProjectionIssue({
    required this.code,
    required this.message,
    this.layerId,
    this.sceneClipId,
  });

  final RootCompositionLayerProjectionIssueCode code;
  final String message;
  final String? layerId;
  final String? sceneClipId;
}

class RootCompositionLayerProjection {
  RootCompositionLayerProjection({
    required this.id,
    required this.kind,
    required this.rootRange,
    required this.zIndex,
    required this.opacity,
    required this.label,
    this.backgroundLayer,
    this.sceneClip,
  })  : assert(opacity >= 0 && opacity <= 1),
        metadata = Map.unmodifiable(
          backgroundLayer?.metadata ??
              sceneClip?.instanceVisualStyle.metadata ??
              const <String, String>{},
        );

  final String id;
  final RootCompositionLayerProjectionKind kind;
  final TimelineTimeRange rootRange;
  final int zIndex;
  final double opacity;
  final String label;
  final CompositionRootBackgroundLayerModel? backgroundLayer;
  final CompositionSceneClipModel? sceneClip;
  final Map<String, String> metadata;

  bool get isBackground =>
      kind == RootCompositionLayerProjectionKind.background;

  bool get isSceneClip => kind == RootCompositionLayerProjectionKind.sceneClip;

  String? get sourceSceneId => sceneClip?.sourceSceneId;

  CompositionSceneClipInstanceTransform? get sceneClipTransform {
    return sceneClip?.instanceVisualStyle.transform;
  }

  List<String> get sceneClipEffectIds {
    return sceneClip?.instanceVisualStyle.effectIds ?? const <String>[];
  }

  bool containsRootTime(TimelineTime rootTime) => rootRange.contains(rootTime);
}

class RootCompositionLayerProjectionResult {
  RootCompositionLayerProjectionResult({
    required List<RootCompositionLayerProjection> layers,
    List<RootCompositionLayerProjectionIssue> issues =
        const <RootCompositionLayerProjectionIssue>[],
  })  : layers = List.unmodifiable(layers),
        issues = List.unmodifiable(issues);

  final List<RootCompositionLayerProjection> layers;
  final List<RootCompositionLayerProjectionIssue> issues;

  bool get hasIssues => issues.isNotEmpty;

  List<RootCompositionLayerProjection> layersAtRootTime(
    TimelineTime rootTime,
  ) {
    return List<RootCompositionLayerProjection>.unmodifiable(
      layers.where((layer) => layer.containsRootTime(rootTime)),
    );
  }
}

class RootCompositionLayerProjectionAdapter {
  const RootCompositionLayerProjectionAdapter();

  RootCompositionLayerProjectionResult projectWorkspace(
    CompositionWorkspaceModel workspace,
  ) {
    return project(
      rootRange: TimelineTimeRange(
        start: TimelineTime.zero,
        endExclusive: workspace.rootDurationTime,
      ),
      backgroundLayers: workspace.rootBackgroundLayers,
      sceneClips: workspace.sceneClips,
    );
  }

  RootCompositionLayerProjectionResult project({
    required TimelineTimeRange rootRange,
    List<CompositionRootBackgroundLayerModel> backgroundLayers =
        const <CompositionRootBackgroundLayerModel>[],
    List<CompositionSceneClipModel> sceneClips =
        const <CompositionSceneClipModel>[],
  }) {
    final layers = <RootCompositionLayerProjection>[];
    final issues = <RootCompositionLayerProjectionIssue>[];

    for (final backgroundLayer in backgroundLayers) {
      if (!backgroundLayer.isEnabled) {
        continue;
      }
      if (!backgroundLayer.hasValidOpacity ||
          !backgroundLayer.hasValidVisibleRange) {
        issues.add(
          RootCompositionLayerProjectionIssue(
            code:
                RootCompositionLayerProjectionIssueCode.invalidBackgroundLayer,
            message:
                'Root background layer `${backgroundLayer.id}` has invalid opacity or timing.',
            layerId: backgroundLayer.id,
          ),
        );
        continue;
      }

      final projectedRange = _intersectRanges(
        backgroundLayer.visibleRange ?? rootRange,
        rootRange,
      );
      if (projectedRange == null) {
        continue;
      }

      layers.add(
        RootCompositionLayerProjection(
          id: backgroundLayer.id,
          kind: RootCompositionLayerProjectionKind.background,
          rootRange: projectedRange,
          zIndex: backgroundLayer.zIndex,
          opacity: backgroundLayer.opacity,
          label: _backgroundLabelFor(backgroundLayer),
          backgroundLayer: backgroundLayer,
        ),
      );
    }

    for (final sceneClip in sceneClips) {
      if (!sceneClip.isEnabled) {
        continue;
      }

      final clipIssues = sceneClip.validate();
      if (clipIssues.isNotEmpty) {
        issues.add(
          RootCompositionLayerProjectionIssue(
            code: RootCompositionLayerProjectionIssueCode.invalidSceneClip,
            message: clipIssues.map((issue) => issue.message).join(' '),
            sceneClipId: sceneClip.id,
          ),
        );
        continue;
      }

      final projectedRange = _intersectRanges(sceneClip.rootRange, rootRange);
      if (projectedRange == null) {
        continue;
      }

      layers.add(
        RootCompositionLayerProjection(
          id: sceneClip.id,
          kind: RootCompositionLayerProjectionKind.sceneClip,
          rootRange: projectedRange,
          zIndex: sceneClip.instanceVisualStyle.zIndex,
          opacity: sceneClip.instanceVisualStyle.opacity,
          label: _sceneClipLabelFor(sceneClip),
          sceneClip: sceneClip,
        ),
      );
    }

    layers.sort(_compareProjectedLayers);
    return RootCompositionLayerProjectionResult(
      layers: layers,
      issues: issues,
    );
  }

  TimelineTimeRange? _intersectRanges(
    TimelineTimeRange left,
    TimelineTimeRange right,
  ) {
    final start = left.start > right.start ? left.start : right.start;
    final end = left.endExclusive < right.endExclusive
        ? left.endExclusive
        : right.endExclusive;
    if (end <= start) {
      return null;
    }
    return TimelineTimeRange(start: start, endExclusive: end);
  }

  int _compareProjectedLayers(
    RootCompositionLayerProjection left,
    RootCompositionLayerProjection right,
  ) {
    final zCompare = left.zIndex.compareTo(right.zIndex);
    if (zCompare != 0) {
      return zCompare;
    }

    final startCompare = left.rootRange.start.compareTo(right.rootRange.start);
    if (startCompare != 0) {
      return startCompare;
    }

    final kindCompare = left.kind.index.compareTo(right.kind.index);
    if (kindCompare != 0) {
      return kindCompare;
    }

    return left.id.compareTo(right.id);
  }

  String _backgroundLabelFor(CompositionRootBackgroundLayerModel layer) {
    final name = layer.name?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    return 'Root Background';
  }

  String _sceneClipLabelFor(CompositionSceneClipModel sceneClip) {
    final name = sceneClip.name?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    return sceneClip.sourceSceneId;
  }
}
