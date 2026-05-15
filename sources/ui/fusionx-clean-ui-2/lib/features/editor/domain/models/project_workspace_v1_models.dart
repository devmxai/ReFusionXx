import 'package:flutter/foundation.dart';

import '../../presentation/models/timeline_time.dart';

@immutable
class CompositionProfileV1 {
  const CompositionProfileV1({
    required this.width,
    required this.height,
    required this.fps,
    required this.durationMs,
    this.coordinateSystem = 'center-origin',
    this.origin = 'center',
  });

  final int width;
  final int height;
  final int fps;
  final int durationMs;
  final String coordinateSystem;
  final String origin;

  bool get isValid =>
      width > 0 &&
      height > 0 &&
      fps > 0 &&
      durationMs > 0 &&
      coordinateSystem.trim().isNotEmpty &&
      origin.trim().isNotEmpty;

  Map<String, int> get canvasBounds => <String, int>{
        'x': 0,
        'y': 0,
        'width': width,
        'height': height,
      };

  CompositionProfileV1 copyWith({
    int? width,
    int? height,
    int? fps,
    int? durationMs,
    String? coordinateSystem,
    String? origin,
  }) {
    return CompositionProfileV1(
      width: width ?? this.width,
      height: height ?? this.height,
      fps: fps ?? this.fps,
      durationMs: durationMs ?? this.durationMs,
      coordinateSystem: coordinateSystem ?? this.coordinateSystem,
      origin: origin ?? this.origin,
    );
  }
}

@immutable
class WorkspaceRevisionState {
  const WorkspaceRevisionState({
    required this.revision,
  });

  final int revision;

  WorkspaceRevisionState copyWith({
    int? revision,
  }) {
    return WorkspaceRevisionState(
      revision: revision ?? this.revision,
    );
  }
}

@immutable
class WorkspaceSessionState {
  const WorkspaceSessionState({
    required this.workspaceId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String workspaceId;
  final DateTime createdAt;
  final DateTime updatedAt;

  WorkspaceSessionState copyWith({
    String? workspaceId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WorkspaceSessionState(
      workspaceId: workspaceId ?? this.workspaceId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

@immutable
class ProjectWorkspaceV1 {
  const ProjectWorkspaceV1({
    required this.projectId,
    required this.compositionId,
    required this.compositionProfile,
    required this.revisionState,
    required this.sessionState,
  });

  final String projectId;
  final String compositionId;
  final CompositionProfileV1 compositionProfile;
  final WorkspaceRevisionState revisionState;
  final WorkspaceSessionState sessionState;

  String get workspaceId => sessionState.workspaceId;
  int get revision => revisionState.revision;
  DateTime get createdAt => sessionState.createdAt;
  DateTime get updatedAt => sessionState.updatedAt;

  bool get isRuntimeReady =>
      _isRuntimeIdentity(projectId, kind: _IdentityKind.project) &&
      _isRuntimeIdentity(compositionId, kind: _IdentityKind.composition) &&
      _isRuntimeIdentity(workspaceId, kind: _IdentityKind.workspace) &&
      compositionProfile.isValid;

  bool matchesIdentity({
    required String projectId,
    required String compositionId,
  }) {
    return this.projectId == projectId.trim() &&
        this.compositionId == compositionId.trim();
  }

  ProjectWorkspaceV1 copyWith({
    String? projectId,
    String? compositionId,
    CompositionProfileV1? compositionProfile,
    WorkspaceRevisionState? revisionState,
    WorkspaceSessionState? sessionState,
  }) {
    return ProjectWorkspaceV1(
      projectId: projectId ?? this.projectId,
      compositionId: compositionId ?? this.compositionId,
      compositionProfile: compositionProfile ?? this.compositionProfile,
      revisionState: revisionState ?? this.revisionState,
      sessionState: sessionState ?? this.sessionState,
    );
  }

  ProjectWorkspaceV1 copyWithRuntimeState({
    String? projectId,
    String? compositionId,
    String? workspaceId,
    int? revision,
    CompositionProfileV1? compositionProfile,
    DateTime? updatedAt,
  }) {
    return copyWith(
      projectId: projectId,
      compositionId: compositionId,
      compositionProfile: compositionProfile,
      revisionState: revisionState.copyWith(
        revision: revision ?? revisionState.revision,
      ),
      sessionState: sessionState.copyWith(
        workspaceId: workspaceId,
        updatedAt: updatedAt ?? DateTime.now().toUtc(),
      ),
    );
  }

  static ProjectWorkspaceV1 create({
    required String projectId,
    required String compositionId,
    required String workspaceId,
    required CompositionProfileV1 compositionProfile,
    int revision = 0,
    DateTime? nowUtc,
  }) {
    final now = nowUtc ?? DateTime.now().toUtc();
    return ProjectWorkspaceV1(
      projectId: projectId.trim(),
      compositionId: compositionId.trim(),
      compositionProfile: compositionProfile,
      revisionState: WorkspaceRevisionState(revision: revision),
      sessionState: WorkspaceSessionState(
        workspaceId: workspaceId.trim(),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }
}

enum _IdentityKind {
  project,
  composition,
  workspace,
}

bool _isRuntimeIdentity(
  String value, {
  required _IdentityKind kind,
}) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    return false;
  }
  final lower = normalized.toLowerCase();
  final blocked = switch (kind) {
    _IdentityKind.project => const <String>{
        'active',
        'default',
        'project',
        'motion-project',
      },
    _IdentityKind.composition => const <String>{
        'active',
        'default',
        'main',
        'scene-main',
        'comp_1',
        'active-composition',
      },
    _IdentityKind.workspace => const <String>{
        'active',
        'default',
        'workspace',
        'workspace-main',
      },
  };
  return !blocked.contains(lower);
}

CompositionProfileV1 compositionProfileFromCanvas({
  required int width,
  required int height,
  required int fps,
  required TimelineTime duration,
  String coordinateSystem = 'center-origin',
  String origin = 'center',
}) {
  return CompositionProfileV1(
    width: width,
    height: height,
    fps: fps,
    durationMs: duration.inMilliseconds,
    coordinateSystem: coordinateSystem,
    origin: origin,
  );
}
