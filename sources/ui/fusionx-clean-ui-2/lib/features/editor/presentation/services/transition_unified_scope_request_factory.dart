import '../../domain/models/professional_motion_models.dart';
import '../../domain/models/professional_normal_transition_models.dart';
import '../models/timeline_mock_models.dart';
import '../models/timeline_time.dart';
import 'transition_scope_graph_authoring_adapter.dart';

class TransitionUnifiedScopeRequestFactory {
  const TransitionUnifiedScopeRequestFactory();

  TransitionUnifiedScopeRequestFactoryResult createForBoundary({
    required TimelineTrackData track,
    required TimelineClipData leftClip,
    required TimelineClipData rightClip,
    required NormalTransitionDefinition definition,
    required String projectId,
    required String sceneId,
    required String trackId,
    TimelineTrackTransitionData? transition,
    MotionProjectFormat format = const MotionProjectFormat(
      canvasSize: MotionSize2D(width: 1080, height: 1920),
    ),
    MotionFrameRate frameRate =
        const MotionFrameRate(numerator: 30, denominator: 1),
  }) {
    final issues = <NormalTransitionIssue>[];
    if (track.kind != TimelineTrackKind.video) {
      issues.add(
        const NormalTransitionIssue(
          severity: NormalTransitionIssueSeverity.error,
          message: 'Unified transition scope requires a video track.',
          path: 'track.kind',
        ),
      );
    }

    final leftIndex = track.clips.indexWhere((clip) => clip.id == leftClip.id);
    final rightIndex =
        track.clips.indexWhere((clip) => clip.id == rightClip.id);
    if (leftIndex < 0) {
      issues.add(
        NormalTransitionIssue(
          severity: NormalTransitionIssueSeverity.error,
          message: 'Left transition clip `${leftClip.id}` was not found.',
          path: 'leftClipId',
        ),
      );
    }
    if (rightIndex < 0) {
      issues.add(
        NormalTransitionIssue(
          severity: NormalTransitionIssueSeverity.error,
          message: 'Right transition clip `${rightClip.id}` was not found.',
          path: 'rightClipId',
        ),
      );
    }
    if (leftIndex >= 0 && rightIndex >= 0 && rightIndex != leftIndex + 1) {
      issues.add(
        const NormalTransitionIssue(
          severity: NormalTransitionIssueSeverity.error,
          message:
              'Unified transition scope requires adjacent left and right clips.',
          path: 'boundary',
        ),
      );
    }
    if (leftClip.durationTime <= TimelineTime.zero) {
      issues.add(
        NormalTransitionIssue(
          severity: NormalTransitionIssueSeverity.error,
          message: 'Left transition clip `${leftClip.id}` has no duration.',
          path: 'leftClip.duration',
        ),
      );
    }
    if (rightClip.durationTime <= TimelineTime.zero) {
      issues.add(
        NormalTransitionIssue(
          severity: NormalTransitionIssueSeverity.error,
          message: 'Right transition clip `${rightClip.id}` has no duration.',
          path: 'rightClip.duration',
        ),
      );
    }
    if (_hasErrors(issues)) {
      return TransitionUnifiedScopeRequestFactoryResult(issues: issues);
    }

    final starts = _clipStartTimes(track.clips);
    final leftStart = starts[leftClip.id] ?? TimelineTime.zero;
    final rightStart =
        starts[rightClip.id] ?? leftStart + leftClip.durationTime;
    final leftEnd = leftStart + leftClip.durationTime;
    final rightEnd = rightStart + rightClip.durationTime;
    final timelineEnd = _trackDuration(track);
    final transitionId = transition?.id ??
        'transition.${_safeId(leftClip.id)}.${_safeId(rightClip.id)}';
    final instanceId = '$transitionId.instance';
    final outgoingLayerId = '$transitionId.outgoing.layer';
    final incomingLayerId = '$transitionId.incoming.layer';
    final outgoingElementId = '$transitionId.outgoing.element';
    final incomingElementId = '$transitionId.incoming.element';

    final project = MotionProjectModel(
      id: projectId,
      format: format,
      frameRate: frameRate,
      scenes: <MotionSceneModel>[
        MotionSceneModel(
          id: sceneId,
          projectRange: TimelineTimeRange(
            start: TimelineTime.zero,
            endExclusive: timelineEnd,
          ),
          layers: <MotionLayerModel>[
            _clipLayer(
              sceneId: sceneId,
              layerId: outgoingLayerId,
              elementId: outgoingElementId,
              clip: leftClip,
              visibleRange: TimelineTimeRange(
                start: leftStart,
                endExclusive: leftEnd,
              ),
              sourceRole: 'outgoing',
            ),
            _clipLayer(
              sceneId: sceneId,
              layerId: incomingLayerId,
              elementId: incomingElementId,
              clip: rightClip,
              visibleRange: TimelineTimeRange(
                start: rightStart,
                endExclusive: rightEnd,
              ),
              sourceRole: 'incoming',
            ),
          ],
          name: 'Transition Scope Scene',
        ),
      ],
      name: 'Transition Scope Project',
    );

    final request = TransitionScopeGraphAuthoringRequest(
      project: project,
      sceneId: sceneId,
      definition: definition,
      trackId: trackId,
      leftClipId: leftClip.id,
      rightClipId: rightClip.id,
      outgoingLayerId: outgoingLayerId,
      incomingLayerId: incomingLayerId,
      boundaryTime: leftEnd,
      leftAvailableTail: leftClip.durationTime,
      rightAvailableHead: rightClip.durationTime,
      outgoingTarget: _elementTarget(
        projectId: projectId,
        sceneId: sceneId,
        layerId: outgoingLayerId,
        elementId: outgoingElementId,
      ),
      incomingTarget: _elementTarget(
        projectId: projectId,
        sceneId: sceneId,
        layerId: incomingLayerId,
        elementId: incomingElementId,
      ),
      nodeId: transitionId,
      instanceId: instanceId,
      duration: transition?.durationTime,
      parameterOverrides:
          transition?.parameterValues ?? const <String, double>{},
    );

    return TransitionUnifiedScopeRequestFactoryResult(
      request: request,
      project: project,
      transitionId: transitionId,
      outgoingLayerId: outgoingLayerId,
      incomingLayerId: incomingLayerId,
      outgoingElementId: outgoingElementId,
      incomingElementId: incomingElementId,
      boundaryTime: leftEnd,
      issues: issues,
    );
  }

  Map<String, TimelineTime> _clipStartTimes(List<TimelineClipData> clips) {
    final starts = <String, TimelineTime>{};
    var cursor = TimelineTime.zero;
    for (final clip in clips) {
      starts[clip.id] = cursor;
      cursor += clip.durationTime;
    }
    return starts;
  }

  TimelineTime _trackDuration(TimelineTrackData track) {
    var total = TimelineTime.zero;
    for (final clip in track.clips) {
      total += clip.durationTime;
    }
    return total;
  }

  MotionLayerModel _clipLayer({
    required String sceneId,
    required String layerId,
    required String elementId,
    required TimelineClipData clip,
    required TimelineTimeRange visibleRange,
    required String sourceRole,
  }) {
    return MotionLayerModel(
      id: layerId,
      sceneId: sceneId,
      kind: MotionLayerKind.video,
      visibleRange: visibleRange,
      name: '${clip.label ?? clip.id} $sourceRole',
      elements: <MotionElementModel>[
        MotionElementModel(
          id: elementId,
          layerId: layerId,
          kind: MotionElementKind.videoClip,
          localRange: TimelineTimeRange(
            start: TimelineTime.zero,
            endExclusive: clip.durationTime,
          ),
          name: clip.label ?? clip.id,
          sourceBinding: MotionElementSourceBinding(
            kind: MotionSourceKind.video,
            sourceId: clip.id,
            assetId: clip.assetId,
            label: clip.label,
            sourceRange: clip.sourceRange,
            metadata: <String, String>{
              'timelineClipId': clip.id,
              'transitionRole': sourceRole,
            },
          ),
        ),
      ],
    );
  }

  MotionPropertyTarget _elementTarget({
    required String projectId,
    required String sceneId,
    required String layerId,
    required String elementId,
  }) {
    return MotionPropertyTarget(
      kind: MotionTargetKind.element,
      targetId: elementId,
      projectId: projectId,
      sceneId: sceneId,
      layerId: layerId,
      elementId: elementId,
    );
  }

  bool _hasErrors(List<NormalTransitionIssue> issues) {
    return issues.any(
      (issue) => issue.severity == NormalTransitionIssueSeverity.error,
    );
  }

  String _safeId(String value) {
    final sanitized = value
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9_.-]+'), '-')
        .replaceAll(RegExp('-+'), '-');
    return sanitized.isEmpty ? 'clip' : sanitized;
  }
}

class TransitionUnifiedScopeRequestFactoryResult {
  TransitionUnifiedScopeRequestFactoryResult({
    List<NormalTransitionIssue> issues = const <NormalTransitionIssue>[],
    this.request,
    this.project,
    this.transitionId,
    this.outgoingLayerId,
    this.incomingLayerId,
    this.outgoingElementId,
    this.incomingElementId,
    this.boundaryTime,
  }) : issues = List.unmodifiable(issues);

  final TransitionScopeGraphAuthoringRequest? request;
  final MotionProjectModel? project;
  final String? transitionId;
  final String? outgoingLayerId;
  final String? incomingLayerId;
  final String? outgoingElementId;
  final String? incomingElementId;
  final TimelineTime? boundaryTime;
  final List<NormalTransitionIssue> issues;

  bool get hasErrors => issues.any(
        (issue) => issue.severity == NormalTransitionIssueSeverity.error,
      );

  bool get canBuild => request != null && !hasErrors;
}
