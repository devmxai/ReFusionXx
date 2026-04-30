import '../../domain/models/composition_scene_clip_models.dart';
import '../../domain/models/professional_motion_models.dart';
import '../../domain/services/scene_scope_session.dart';
import '../models/timeline_mock_models.dart';
import '../models/timeline_time.dart';

class CompositionMediaPlaybackProjectionResult {
  CompositionMediaPlaybackProjectionResult({
    required List<TimelineTrackData> tracks,
  }) : tracks = List.unmodifiable(tracks);

  final List<TimelineTrackData> tracks;

  bool get hasVisualMedia {
    return tracks.any(
      (track) =>
          track.kind == TimelineTrackKind.video ||
          track.kind == TimelineTrackKind.image,
    );
  }

  bool get hasPlayableVideo {
    return tracks.any(
      (track) =>
          track.kind == TimelineTrackKind.video &&
          track.clips.any(
            (clip) =>
                clip.type == TimelineClipType.media &&
                clip.assetId != null &&
                clip.durationTime > TimelineTime.zero,
          ),
    );
  }
}

class CompositionMediaPlaybackProjectionAdapter {
  const CompositionMediaPlaybackProjectionAdapter();

  CompositionMediaPlaybackProjectionResult projectSceneScope(
    SceneScopeSession session,
  ) {
    return _projectMediaLayers(
      layers: session.layers,
      clipStartForSourceTime: (time) =>
          (time - session.sourceRange.start).clamp(
        TimelineTime.zero,
        session.localRange.duration,
      ),
      clipDurationForSourceRange: (start, end) => end - start,
      sourceRange: session.sourceRange,
      sourceSceneId: session.sourceSceneId,
      clipIdPrefix: 'scene_scope_media',
      playbackRate: 1,
    );
  }

  CompositionMediaPlaybackProjectionResult projectRootComposition({
    required MotionProjectModel project,
    required List<CompositionSceneClipModel> sceneClips,
  }) {
    final projectedClips = <_ProjectedMediaClip>[];
    final sceneById = <String, MotionSceneModel>{
      for (final scene in project.scenes) scene.id: scene,
    };
    final sortedSceneClips = sceneClips
        .where((clip) => clip.isEnabled)
        .toList(growable: false)
      ..sort((left, right) => left.startTime.compareTo(right.startTime));

    for (final sceneClip in sortedSceneClips) {
      if (sceneClip.validate().isNotEmpty) {
        continue;
      }
      final sourceScene = sceneById[sceneClip.sourceSceneId];
      if (sourceScene == null || !sourceScene.isEnabled) {
        continue;
      }
      for (final layer in sourceScene.layers) {
        final mediaElement = _mediaElementForLayer(layer);
        if (mediaElement == null) {
          continue;
        }
        final sourceRange = _visibleSourceRangeFor(
          layer: layer,
          element: mediaElement,
          constraint: sceneClip.sourceRange,
        );
        if (sourceRange == null || sourceRange.duration <= TimelineTime.zero) {
          continue;
        }
        final rootStart = sceneClip.sourceToRootTime(sourceRange.start);
        final rootEnd = sceneClip.sourceToRootTime(sourceRange.endExclusive);
        final rootDuration = rootEnd - rootStart;
        if (rootDuration <= TimelineTime.zero) {
          continue;
        }
        projectedClips.add(
          _ProjectedMediaClip(
            timelineStart: rootStart,
            duration: rootDuration,
            timelineKind: _timelineKindForLayer(layer.kind),
            visualKind: _visualKindForLayer(layer.kind),
            zIndex: layer.zIndex,
            order: projectedClips.length,
            clip: _timelineClipFor(
              id: 'root_media_${sceneClip.id}_${layer.id}_${mediaElement.id}',
              layer: layer,
              element: mediaElement,
              visibleSourceRange: sourceRange,
              duration: rootDuration,
              sourceSceneId: sceneClip.sourceSceneId,
              playbackRate: sceneClip.timeScale,
            ),
          ),
        );
      }
    }

    return CompositionMediaPlaybackProjectionResult(
      tracks: _tracksFromProjectedClips(projectedClips),
    );
  }

  CompositionMediaPlaybackProjectionResult _projectMediaLayers({
    required List<MotionLayerModel> layers,
    required TimelineTime Function(TimelineTime sourceTime)
        clipStartForSourceTime,
    required TimelineTime Function(
            TimelineTime sourceStart, TimelineTime sourceEnd)
        clipDurationForSourceRange,
    required TimelineTimeRange sourceRange,
    required String sourceSceneId,
    required String clipIdPrefix,
    required double playbackRate,
  }) {
    final projectedClips = <_ProjectedMediaClip>[];
    for (final layer in layers) {
      final mediaElement = _mediaElementForLayer(layer);
      if (mediaElement == null) {
        continue;
      }
      final visibleSourceRange = _visibleSourceRangeFor(
        layer: layer,
        element: mediaElement,
        constraint: sourceRange,
      );
      if (visibleSourceRange == null ||
          visibleSourceRange.duration <= TimelineTime.zero) {
        continue;
      }
      final start = clipStartForSourceTime(visibleSourceRange.start);
      final duration = clipDurationForSourceRange(
        visibleSourceRange.start,
        visibleSourceRange.endExclusive,
      );
      if (duration <= TimelineTime.zero) {
        continue;
      }
      projectedClips.add(
        _ProjectedMediaClip(
          timelineStart: start,
          duration: duration,
          timelineKind: _timelineKindForLayer(layer.kind),
          visualKind: _visualKindForLayer(layer.kind),
          zIndex: layer.zIndex,
          order: projectedClips.length,
          clip: _timelineClipFor(
            id: '${clipIdPrefix}_${layer.id}_${mediaElement.id}',
            layer: layer,
            element: mediaElement,
            visibleSourceRange: visibleSourceRange,
            duration: duration,
            sourceSceneId: sourceSceneId,
            playbackRate: playbackRate,
          ),
        ),
      );
    }

    return CompositionMediaPlaybackProjectionResult(
      tracks: _tracksFromProjectedClips(projectedClips),
    );
  }

  TimelineClipData _timelineClipFor({
    required String id,
    required MotionLayerModel layer,
    required MotionElementModel element,
    required TimelineTimeRange visibleSourceRange,
    required TimelineTime duration,
    required String sourceSceneId,
    required double playbackRate,
  }) {
    final sourceBinding = element.sourceBinding;
    final bindingSourceRange = sourceBinding?.sourceRange ??
        TimelineTimeRange(
          start: TimelineTime.zero,
          endExclusive: visibleSourceRange.duration,
        );
    final elementAbsoluteRange = _absoluteRangeForElement(
      layer: layer,
      element: element,
    );
    final sourceOffset = visibleSourceRange.start - elementAbsoluteRange.start;
    final sourceStart = (bindingSourceRange.start + sourceOffset).clamp(
      bindingSourceRange.start,
      bindingSourceRange.endExclusive,
    );
    final remainingSource = bindingSourceRange.endExclusive - sourceStart;
    final sourceDuration = remainingSource < visibleSourceRange.duration
        ? remainingSource
        : visibleSourceRange.duration;
    return TimelineClipData(
      id: id,
      type: TimelineClipType.media,
      tone: TimelineClipTone.hero,
      assetId: sourceBinding?.assetId ?? sourceBinding?.sourceId,
      label: _labelFor(layer, element),
      durationTime: duration,
      sourceStartTime: sourceStart,
      sourceDurationTime: sourceDuration,
      playbackRate: playbackRate <= 0 ? 1 : playbackRate,
      contentKind: TimelineClipContentKind.media,
      visualKind: _visualKindForLayer(layer.kind),
      sourceSceneId: sourceSceneId,
    );
  }

  List<TimelineTrackData> _tracksFromProjectedClips(
    List<_ProjectedMediaClip> clips,
  ) {
    if (clips.isEmpty) {
      return const <TimelineTrackData>[];
    }
    final byKind = <TimelineTrackKind, List<_ProjectedMediaClip>>{};
    for (final clip in clips) {
      byKind.putIfAbsent(clip.timelineKind, () => <_ProjectedMediaClip>[]);
      byKind[clip.timelineKind]!.add(clip);
    }
    final tracks = <TimelineTrackData>[];
    for (final kind in <TimelineTrackKind>[
      TimelineTrackKind.video,
      TimelineTrackKind.image,
    ]) {
      final kindClips = byKind[kind];
      if (kindClips == null || kindClips.isEmpty) {
        continue;
      }
      final projectedKindClips = kind == TimelineTrackKind.video
          ? _visibleVideoProgram(kindClips).toList()
          : kindClips.toList();
      if (projectedKindClips.isEmpty) {
        continue;
      }
      projectedKindClips.sort(
        (left, right) => left.timelineStart.compareTo(right.timelineStart),
      );
      final timelineClips = <TimelineClipData>[];
      var cursor = TimelineTime.zero;
      for (final projected in projectedKindClips) {
        if (projected.timelineStart > cursor) {
          timelineClips.add(
            TimelineClipData(
              id: 'composition_media_gap_${kind.name}_${timelineClips.length}',
              type: TimelineClipType.placeholder,
              tone: TimelineClipTone.placeholder,
              durationTime: projected.timelineStart - cursor,
              label: '',
            ),
          );
        }
        timelineClips.add(projected.clip);
        cursor = projected.timelineStart + projected.duration;
      }
      tracks.add(
        TimelineTrackData(
          kind: kind,
          clips: timelineClips,
          placeholderLabel: kind == TimelineTrackKind.video ? 'Video' : 'Image',
          contentKind: kind == TimelineTrackKind.video
              ? TimelineTrackContentKind.video
              : TimelineTrackContentKind.image,
          visualKind: kindClips.first.visualKind,
        ),
      );
    }
    return List<TimelineTrackData>.unmodifiable(tracks);
  }

  List<_ProjectedMediaClip> _visibleVideoProgram(
    List<_ProjectedMediaClip> clips,
  ) {
    if (clips.length <= 1) {
      return clips.toList(growable: false);
    }
    final boundaries = <TimelineTime>{};
    for (final clip in clips) {
      boundaries
        ..add(clip.timelineStart)
        ..add(clip.timelineEnd);
    }
    final sortedBoundaries = boundaries.toList(growable: false)
      ..sort((left, right) => left.compareTo(right));
    if (sortedBoundaries.length < 2) {
      return const <_ProjectedMediaClip>[];
    }

    final visible = <_ProjectedMediaClip>[];
    for (var index = 0; index < sortedBoundaries.length - 1; index++) {
      final intervalStart = sortedBoundaries[index];
      final intervalEnd = sortedBoundaries[index + 1];
      if (intervalEnd <= intervalStart) {
        continue;
      }
      final active = clips
          .where(
            (clip) =>
                clip.timelineStart < intervalEnd &&
                intervalStart < clip.timelineEnd,
          )
          .toList(growable: false);
      if (active.isEmpty) {
        continue;
      }
      active.sort((left, right) {
        final zCompare = right.zIndex.compareTo(left.zIndex);
        if (zCompare != 0) {
          return zCompare;
        }
        return right.order.compareTo(left.order);
      });
      final topClip = active.first;
      final visibleClip = _projectedClipForVisibleInterval(
        topClip,
        intervalStart: intervalStart,
        intervalEnd: intervalEnd,
        index: visible.length,
      );
      if (visibleClip != null) {
        if (visible.isNotEmpty &&
            _canMergeVisibleVideoClips(visible.last, visibleClip)) {
          final previous = visible.removeLast();
          final mergedDuration = previous.duration + visibleClip.duration;
          visible.add(
            _ProjectedMediaClip(
              timelineStart: previous.timelineStart,
              duration: mergedDuration,
              timelineKind: previous.timelineKind,
              visualKind: previous.visualKind,
              zIndex: previous.zIndex,
              order: previous.order,
              clip: previous.clip.copyWith(
                durationTime: mergedDuration,
                sourceDurationTime: previous.clip.sourceDurationTime +
                    visibleClip.clip.sourceDurationTime,
              ),
            ),
          );
          continue;
        }
        visible.add(visibleClip);
      }
    }
    return List<_ProjectedMediaClip>.unmodifiable(visible);
  }

  bool _canMergeVisibleVideoClips(
    _ProjectedMediaClip left,
    _ProjectedMediaClip right,
  ) {
    return left.order == right.order &&
        left.timelineEnd == right.timelineStart &&
        left.clip.sourceEndTime == right.clip.sourceStartTime;
  }

  _ProjectedMediaClip? _projectedClipForVisibleInterval(
    _ProjectedMediaClip sourceClip, {
    required TimelineTime intervalStart,
    required TimelineTime intervalEnd,
    required int index,
  }) {
    final duration = intervalEnd - intervalStart;
    if (duration <= TimelineTime.zero) {
      return null;
    }
    final playbackRate =
        sourceClip.clip.playbackRate <= 0 ? 1.0 : sourceClip.clip.playbackRate;
    final sourceOffset = _sourceDurationForTimelineDuration(
      intervalStart - sourceClip.timelineStart,
      playbackRate,
    );
    final sourceDuration = _sourceDurationForTimelineDuration(
      duration,
      playbackRate,
    );
    final sourceStart = sourceClip.clip.sourceStartTime + sourceOffset;
    final maxSourceEnd = sourceClip.clip.sourceEndTime;
    if (sourceStart >= maxSourceEnd) {
      return null;
    }
    final safeSourceDuration = sourceStart + sourceDuration > maxSourceEnd
        ? maxSourceEnd - sourceStart
        : sourceDuration;
    if (safeSourceDuration <= TimelineTime.zero) {
      return null;
    }
    final coversSourceClip = intervalStart == sourceClip.timelineStart &&
        intervalEnd == sourceClip.timelineEnd;
    return _ProjectedMediaClip(
      timelineStart: intervalStart,
      duration: duration,
      timelineKind: sourceClip.timelineKind,
      visualKind: sourceClip.visualKind,
      zIndex: sourceClip.zIndex,
      order: sourceClip.order,
      clip: sourceClip.clip.copyWith(
        id: coversSourceClip
            ? sourceClip.clip.id
            : '${sourceClip.clip.id}_visible_$index',
        durationTime: duration,
        sourceStartTime: sourceStart,
        sourceDurationTime: safeSourceDuration,
      ),
    );
  }

  static TimelineTime _sourceDurationForTimelineDuration(
    TimelineTime duration,
    double playbackRate,
  ) {
    final safeRate =
        playbackRate.isFinite && playbackRate > 0 ? playbackRate : 1.0;
    return TimelineTime.fromProjectTicks(
      (duration.inProjectTicks * safeRate).round(),
    );
  }

  static MotionElementModel? _mediaElementForLayer(MotionLayerModel layer) {
    if (!layer.isEnabled ||
        (layer.kind != MotionLayerKind.video &&
            layer.kind != MotionLayerKind.image)) {
      return null;
    }
    for (final element in layer.elements) {
      if (!element.isEnabled) {
        continue;
      }
      if (layer.kind == MotionLayerKind.video &&
          element.kind == MotionElementKind.videoClip &&
          _hasSourceBinding(element)) {
        return element;
      }
      if (layer.kind == MotionLayerKind.image &&
          element.kind == MotionElementKind.image &&
          _hasSourceBinding(element)) {
        return element;
      }
    }
    return null;
  }

  static bool _hasSourceBinding(MotionElementModel element) {
    final binding = element.sourceBinding;
    return binding != null &&
        ((binding.assetId != null && binding.assetId!.isNotEmpty) ||
            binding.sourceId.isNotEmpty);
  }

  static TimelineTimeRange? _visibleSourceRangeFor({
    required MotionLayerModel layer,
    required MotionElementModel element,
    required TimelineTimeRange constraint,
  }) {
    final elementRange = _absoluteRangeForElement(
      layer: layer,
      element: element,
    );
    final start = _maxTime(
      _maxTime(layer.visibleRange.start, elementRange.start),
      constraint.start,
    );
    final end = _minTime(
      _minTime(layer.visibleRange.endExclusive, elementRange.endExclusive),
      constraint.endExclusive,
    );
    if (end <= start) {
      return null;
    }
    return TimelineTimeRange(start: start, endExclusive: end);
  }

  static TimelineTimeRange _absoluteRangeForElement({
    required MotionLayerModel layer,
    required MotionElementModel element,
  }) {
    final relativeCandidate = TimelineTimeRange(
      start: layer.visibleRange.start + element.localRange.start,
      endExclusive: layer.visibleRange.start + element.localRange.endExclusive,
    );
    if (_overlaps(relativeCandidate, layer.visibleRange) &&
        relativeCandidate.endExclusive <= layer.visibleRange.endExclusive) {
      return relativeCandidate;
    }
    if (_overlaps(element.localRange, layer.visibleRange)) {
      return element.localRange;
    }
    return layer.visibleRange;
  }

  static TimelineTrackKind _timelineKindForLayer(MotionLayerKind kind) {
    return switch (kind) {
      MotionLayerKind.video => TimelineTrackKind.video,
      MotionLayerKind.image => TimelineTrackKind.image,
      _ => TimelineTrackKind.text,
    };
  }

  static TimelineVisualKind _visualKindForLayer(MotionLayerKind kind) {
    return switch (kind) {
      MotionLayerKind.video => TimelineVisualKind.video,
      MotionLayerKind.image => TimelineVisualKind.image,
      _ => TimelineVisualKind.control,
    };
  }

  static String _labelFor(MotionLayerModel layer, MotionElementModel element) {
    final layerName = layer.name?.trim();
    if (layerName != null && layerName.isNotEmpty) {
      return layerName;
    }
    final elementName = element.name?.trim();
    if (elementName != null && elementName.isNotEmpty) {
      return elementName;
    }
    return layer.kind == MotionLayerKind.video ? 'Video' : 'Image';
  }

  static bool _overlaps(TimelineTimeRange left, TimelineTimeRange right) {
    return left.start < right.endExclusive && right.start < left.endExclusive;
  }

  static TimelineTime _minTime(TimelineTime left, TimelineTime right) {
    return left <= right ? left : right;
  }

  static TimelineTime _maxTime(TimelineTime left, TimelineTime right) {
    return left >= right ? left : right;
  }
}

class _ProjectedMediaClip {
  const _ProjectedMediaClip({
    required this.timelineStart,
    required this.duration,
    required this.timelineKind,
    required this.visualKind,
    required this.zIndex,
    required this.order,
    required this.clip,
  });

  final TimelineTime timelineStart;
  final TimelineTime duration;
  final TimelineTrackKind timelineKind;
  final TimelineVisualKind visualKind;
  final int zIndex;
  final int order;
  final TimelineClipData clip;

  TimelineTime get timelineEnd => timelineStart + duration;
}
