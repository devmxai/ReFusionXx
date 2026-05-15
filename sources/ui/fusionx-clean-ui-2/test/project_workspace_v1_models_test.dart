import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/project_workspace_v1_models.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';

void main() {
  group('ProjectWorkspaceV1', () {
    test('create Story profile yields runtime-ready workspace', () {
      final workspace = ProjectWorkspaceV1.create(
        projectId: 'project-story-1',
        compositionId: 'composition-story-1',
        workspaceId: 'workspace-story-1',
        compositionProfile: compositionProfileFromCanvas(
          width: 1080,
          height: 1920,
          fps: 30,
          duration: TimelineTime.fromSecondsDouble(14),
        ),
      );

      expect(workspace.isRuntimeReady, isTrue);
      expect(workspace.compositionProfile.width, 1080);
      expect(workspace.compositionProfile.height, 1920);
      expect(workspace.compositionProfile.canvasBounds['width'], 1080);
      expect(workspace.compositionProfile.canvasBounds['height'], 1920);
    });

    test('create Square profile yields runtime-ready workspace', () {
      final workspace = ProjectWorkspaceV1.create(
        projectId: 'project-square-1',
        compositionId: 'composition-square-1',
        workspaceId: 'workspace-square-1',
        compositionProfile: compositionProfileFromCanvas(
          width: 1080,
          height: 1080,
          fps: 30,
          duration: TimelineTime.fromSecondsDouble(14),
        ),
      );

      expect(workspace.isRuntimeReady, isTrue);
      expect(workspace.compositionProfile.width, 1080);
      expect(workspace.compositionProfile.height, 1080);
    });

    test('placeholder project/composition/workspace are blocked', () {
      final workspace = ProjectWorkspaceV1.create(
        projectId: 'active',
        compositionId: 'comp_1',
        workspaceId: 'workspace',
        compositionProfile: compositionProfileFromCanvas(
          width: 1080,
          height: 1920,
          fps: 30,
          duration: TimelineTime.fromSecondsDouble(14),
        ),
      );

      expect(workspace.isRuntimeReady, isFalse);
    });

    test('copyWithRuntimeState updates identity and revision', () {
      final workspace = ProjectWorkspaceV1.create(
        projectId: 'project-1',
        compositionId: 'composition-1',
        workspaceId: 'workspace-1',
        compositionProfile: compositionProfileFromCanvas(
          width: 1080,
          height: 1920,
          fps: 30,
          duration: TimelineTime.fromSecondsDouble(14),
        ),
      );

      final next = workspace.copyWithRuntimeState(
        projectId: 'project-2',
        compositionId: 'composition-2',
        workspaceId: 'workspace-2',
        revision: 7,
      );

      expect(next.projectId, 'project-2');
      expect(next.compositionId, 'composition-2');
      expect(next.workspaceId, 'workspace-2');
      expect(next.revision, 7);
      expect(
          next.matchesIdentity(
              projectId: 'project-2', compositionId: 'composition-2'),
          isTrue);
      expect(next.isRuntimeReady, isTrue);
    });
  });
}
