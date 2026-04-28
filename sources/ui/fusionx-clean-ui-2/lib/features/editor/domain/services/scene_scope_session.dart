import 'package:flutter/foundation.dart';

import '../../presentation/models/timeline_time.dart';
import '../models/composition_scene_clip_models.dart';
import '../models/professional_motion_animation_models.dart';
import '../models/professional_motion_models.dart';
import 'composition_timeline_projection.dart';

enum SceneScopeSessionIssueCode {
  missingSceneClip,
  invalidSceneClip,
  missingSourceScene,
}

@immutable
class SceneScopeSessionIssue {
  const SceneScopeSessionIssue({
    required this.code,
    required this.message,
    this.sceneClipId,
    this.sourceSceneId,
  });

  final SceneScopeSessionIssueCode code;
  final String message;
  final String? sceneClipId;
  final String? sourceSceneId;
}

@immutable
class SceneScopeSessionRequest {
  SceneScopeSessionRequest({
    required this.project,
    required this.rootTime,
    List<CompositionSceneClipModel> sceneClips =
        const <CompositionSceneClipModel>[],
    List<MotionPropertyChannelModel> channels =
        const <MotionPropertyChannelModel>[],
    this.sceneClipId,
  })  : sceneClips = List.unmodifiable(sceneClips),
        channels = List.unmodifiable(channels);

  final MotionProjectModel project;
  final TimelineTime rootTime;
  final String? sceneClipId;
  final List<CompositionSceneClipModel> sceneClips;
  final List<MotionPropertyChannelModel> channels;
}

@immutable
class SceneScopeSession {
  const SceneScopeSession({
    required this.id,
    required this.sceneClip,
    required this.projection,
    required this.rootTime,
    required this.sourceTime,
    required this.localTime,
  });

  final String id;
  final CompositionSceneClipModel sceneClip;
  final ScopeProjection projection;
  final TimelineTime rootTime;
  final TimelineTime sourceTime;
  final TimelineTime localTime;

  String get projectId => projection.projectId;
  String get sceneClipId => sceneClip.id;
  String get sourceSceneId => sceneClip.sourceSceneId;
  TimelineTimeRange get rootRange => sceneClip.rootRange;
  TimelineTimeRange get sourceRange => sceneClip.sourceRange;
  TimelineTimeRange get localRange => sceneClip.sourceLocalRange;
  List<MotionLayerModel> get layers => projection.layers;
  List<MotionElementModel> get elements => projection.elements;
  List<MotionPropertyChannelModel> get channels => projection.channels;

  TimelineTime rootToLocal(TimelineTime time) {
    return sceneClip.rootToLocalTime(time);
  }

  TimelineTime localToRoot(TimelineTime time) {
    return sceneClip.localToRootTime(time);
  }

  TimelineTime rootToSource(TimelineTime time) {
    return sceneClip.rootToSourceTime(time);
  }

  TimelineTime sourceToRoot(TimelineTime time) {
    return sceneClip.sourceToRootTime(time);
  }
}

@immutable
class SceneScopeSessionResult {
  SceneScopeSessionResult({
    this.session,
    List<SceneScopeSessionIssue> issues = const <SceneScopeSessionIssue>[],
  }) : issues = List.unmodifiable(issues);

  final SceneScopeSession? session;
  final List<SceneScopeSessionIssue> issues;

  bool get hasIssues => issues.isNotEmpty;
}

enum ScopeStackFrameKind {
  root,
  scene,
}

@immutable
class ScopeStackFrame {
  const ScopeStackFrame({
    required this.kind,
    required this.projectId,
    required this.sceneId,
    this.sceneClipId,
  });

  factory ScopeStackFrame.root({
    required String projectId,
    required String sceneId,
  }) {
    return ScopeStackFrame(
      kind: ScopeStackFrameKind.root,
      projectId: projectId,
      sceneId: sceneId,
    );
  }

  factory ScopeStackFrame.scene(SceneScopeSession session) {
    return ScopeStackFrame(
      kind: ScopeStackFrameKind.scene,
      projectId: session.projectId,
      sceneId: session.sourceSceneId,
      sceneClipId: session.sceneClipId,
    );
  }

  final ScopeStackFrameKind kind;
  final String projectId;
  final String sceneId;
  final String? sceneClipId;
}

@immutable
class ScopeStack {
  ScopeStack({
    List<ScopeStackFrame> frames = const <ScopeStackFrame>[],
  }) : frames = List.unmodifiable(frames);

  final List<ScopeStackFrame> frames;

  ScopeStackFrame? get current => frames.isEmpty ? null : frames.last;
  bool get canPop => frames.length > 1;

  ScopeStack push(ScopeStackFrame frame) {
    return ScopeStack(frames: <ScopeStackFrame>[...frames, frame]);
  }

  ScopeStack pop() {
    if (!canPop) {
      return this;
    }
    return ScopeStack(frames: frames.sublist(0, frames.length - 1));
  }
}

class SceneScopeSessionResolver {
  const SceneScopeSessionResolver({
    this.projectionResolver = const CompositionTimelineProjectionResolver(),
  });

  final CompositionTimelineProjectionResolver projectionResolver;

  SceneScopeSessionResult open(SceneScopeSessionRequest request) {
    final sceneClip = _resolveSceneClip(
      sceneClips: request.sceneClips,
      sceneClipId: request.sceneClipId,
      rootTime: request.rootTime,
    );
    if (sceneClip == null) {
      return SceneScopeSessionResult(
        issues: <SceneScopeSessionIssue>[
          SceneScopeSessionIssue(
            code: SceneScopeSessionIssueCode.missingSceneClip,
            message: request.sceneClipId == null
                ? 'No scene clip contains the requested root time.'
                : 'Scene clip `${request.sceneClipId}` was not found.',
            sceneClipId: request.sceneClipId,
          ),
        ],
      );
    }

    final clipIssues = sceneClip.validate();
    if (clipIssues.isNotEmpty) {
      return SceneScopeSessionResult(
        issues: clipIssues
            .map(
              (issue) => SceneScopeSessionIssue(
                code: SceneScopeSessionIssueCode.invalidSceneClip,
                message: issue.message,
                sceneClipId: sceneClip.id,
                sourceSceneId: sceneClip.sourceSceneId,
              ),
            )
            .toList(growable: false),
      );
    }

    final sourceTime = sceneClip.rootToSourceTime(request.rootTime);
    final projectionResult = projectionResolver.resolveSceneScope(
      project: request.project,
      sceneId: sceneClip.sourceSceneId,
      globalTime: sourceTime,
      channels: request.channels,
    );
    final projection = projectionResult.projection;
    if (projection == null) {
      return SceneScopeSessionResult(
        issues: projectionResult.issues
            .map(
              (issue) => SceneScopeSessionIssue(
                code: SceneScopeSessionIssueCode.missingSourceScene,
                message: issue.message,
                sceneClipId: sceneClip.id,
                sourceSceneId: sceneClip.sourceSceneId,
              ),
            )
            .toList(growable: false),
      );
    }

    return SceneScopeSessionResult(
      session: SceneScopeSession(
        id: 'scene-scope.${sceneClip.id}.${sceneClip.sourceSceneId}',
        sceneClip: sceneClip,
        projection: projection,
        rootTime: request.rootTime.clamp(
          sceneClip.rootRange.start,
          sceneClip.rootRange.endExclusive,
        ),
        sourceTime: sourceTime,
        localTime: sceneClip.rootToLocalTime(request.rootTime),
      ),
    );
  }

  CompositionSceneClipModel? _resolveSceneClip({
    required List<CompositionSceneClipModel> sceneClips,
    required String? sceneClipId,
    required TimelineTime rootTime,
  }) {
    if (sceneClipId != null) {
      for (final sceneClip in sceneClips) {
        if (sceneClip.id == sceneClipId) {
          return sceneClip;
        }
      }
      return null;
    }
    return CompositionSceneClipCollection(clips: sceneClips)
        .clipAtRootTime(rootTime);
  }
}
