import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_capability.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_command.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_command_bus.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_mvp_toolkit.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_scene_program_tools.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_session.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_transaction.dart';
import 'package:refusion_app/features/editor/domain/models/composition_scene_clip_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_animation_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_text_models.dart';

void main() {
  group('RefusionMcpMvpToolkit', () {
    late RefusionMcpCommandBus bus;
    late RefusionMcpSession session;

    setUp(() {
      bus = RefusionMcpCommandBus();
      session = RefusionMcpSession(
        id: 'session_1',
        clientName: 'test',
        clientVersion: '1.0.0',
        transport: 'stdio',
        activeProjectId: 'active',
        activeCompositionId: 'comp_1',
        timelineRevision: 7,
        grantedCapabilities: <RefusionMcpCapability>{
          RefusionMcpCapability.projectRead,
          RefusionMcpCapability.timelineRead,
          RefusionMcpCapability.previewRead,
          RefusionMcpCapability.motionWrite,
          RefusionMcpCapability.sceneWrite,
        },
      );
      const toolkit = RefusionMcpMvpToolkit();
      toolkit.register(
        bus: bus,
        config: RefusionMcpMvpToolkitConfig(
          projectStateReader: () => <String, Object?>{
            'projectId': 'active',
            'revision': 7,
          },
          timelineSummaryReader: () => <String, Object?>{
            'rowCount': 3,
          },
          selectionReader: () => <String, Object?>{
            'selected': <String>['clip_1'],
          },
          previewCaptureReader: (timeMs) => <String, Object?>{
            'timeMs': timeMs ?? 0,
            'resourceUri': 'refusion://preview/frame/${timeMs ?? 0}',
          },
        ),
      );
    });

    test('returns project state from command bus', () {
      final result = bus.execute(
        session: session,
        command: _command(
          type: 'refusion.get_project_state',
          capability: RefusionMcpCapability.projectRead,
        ),
        currentRevision: 7,
      );
      expect(result.ok, isTrue);
      expect(result.payload['projectId'], 'active');
    });

    test('returns preview resource uri', () {
      final result = bus.execute(
        session: session,
        command: _command(
          type: 'refusion.capture_preview_frame',
          capability: RefusionMcpCapability.previewRead,
          payload: <String, Object?>{'timeMs': 1200},
        ),
        currentRevision: 7,
      );
      expect(result.ok, isTrue);
      expect(result.resourceUris, contains('refusion://preview/frame/1200'));
    });

    test('validates scene program source through toolkit', () {
      final source = File(
        '/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/test/fixtures/refusion_scene_programs/first_generated_scene.json',
      ).readAsStringSync();
      final result = bus.execute(
        session: session,
        command: _command(
          type: 'refusion.validate_scene_program',
          capability: RefusionMcpCapability.sceneWrite,
          payload: <String, Object?>{'source': source},
        ),
        currentRevision: 7,
      );
      expect(result.ok, isTrue);
      expect(result.payload['isValid'], isTrue);
    });

    test('apply scene program returns pending transaction in dryRun', () {
      final source = File(
        '/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/test/fixtures/refusion_scene_programs/first_generated_scene.json',
      ).readAsStringSync();
      const tools = RefusionMcpSceneProgramTools();
      final authored = tools.authorSceneProgram(source: source);
      expect(authored.isValid, isTrue);
      expect(authored.project, isNotNull);
      var revision = 7;
      final toolBus = RefusionMcpCommandBus();
      const toolkit = RefusionMcpMvpToolkit();
      toolkit.register(
        bus: toolBus,
        config: RefusionMcpMvpToolkitConfig(
          projectStateReader: () => <String, Object?>{
            'projectId': 'active',
            'revision': revision,
          },
          timelineSummaryReader: () => <String, Object?>{'rowCount': 0},
          selectionReader: () =>
              <String, Object?>{'selected': const <String>[]},
          previewCaptureReader: (_) => <String, Object?>{},
          sceneProgramTools: tools,
          projectReader: () => authored.project!,
          rootSceneIdReader: () => authored.project!.scenes.first.id,
          sceneClipsReader: () => const <CompositionSceneClipModel>[],
          channelsReader: () => const <MotionPropertyChannelModel>[],
          textBindingsReader: () => const <MotionTextAnimationBindingModel>[],
          applySceneProgramCommit: (_) {
            revision += 1;
            return RefusionMcpApplySceneProgramCommitResult(
              revisionAfter: revision,
            );
          },
        ),
      );

      final dryRun = toolBus.execute(
        session: session,
        command: _command(
          type: 'refusion.apply_scene_program',
          capability: RefusionMcpCapability.sceneWrite,
          payload: <String, Object?>{'source': source},
        ),
        currentRevision: revision,
      );
      expect(dryRun.ok, isTrue);
      expect(dryRun.transactionId, isNotNull);
      expect(dryRun.payload['pending'], isTrue);

      final commit = toolBus.commitTransaction(
        session: session,
        transactionId: dryRun.transactionId!,
        expectedRevision: revision,
        actualRevision: revision,
      );
      expect(commit.ok, isTrue);
      expect(commit.revisionAfter, 8);
    });

    test('returns confirmation required when keyframe handler is not wired',
        () {
      final result = bus.execute(
        session: session,
        command: _command(
          type: 'refusion.keyframe_edit',
          capability: RefusionMcpCapability.motionWrite,
          payload: <String, Object?>{
            'targetId': 'node_1',
            'property': 'position.x',
          },
        ),
        currentRevision: 7,
      );
      expect(result.ok, isFalse);
      expect(result.requiresConfirmation, isTrue);
    });

    test('supports dryRun -> commit for custom keyframe mutation handler', () {
      var revision = 12;
      final toolBus = RefusionMcpCommandBus();
      const toolkit = RefusionMcpMvpToolkit();
      toolkit.register(
        bus: toolBus,
        config: RefusionMcpMvpToolkitConfig(
          projectStateReader: () => <String, Object?>{'revision': revision},
          timelineSummaryReader: () => <String, Object?>{'rows': 1},
          selectionReader: () => <String, Object?>{'selected': <String>[]},
          previewCaptureReader: (_) => <String, Object?>{},
          keyframeEditHandler: (_) => RefusionMcpCommandHandlingOutcome(
            summary: 'Keyframe edit prepared.',
            patchPreview: RefusionMcpPatchPreview(
              affectedObjects: <String>['node_1'],
              changedProperties: <String>['position.x'],
            ),
            commitOperation: () {
              revision += 1;
              return RefusionMcpCommitExecution(revisionAfter: revision);
            },
          ),
        ),
      );

      final dryRun = toolBus.execute(
        session: _sessionWithAllWrites(),
        command: _command(
          type: 'refusion.keyframe_edit',
          capability: RefusionMcpCapability.motionWrite,
          payload: const <String, Object?>{'targetId': 'node_1'},
        ),
        currentRevision: revision,
      );
      expect(dryRun.ok, isTrue);
      expect(dryRun.transactionId, isNotNull);

      final commit = toolBus.commitTransaction(
        session: _sessionWithAllWrites(),
        transactionId: dryRun.transactionId!,
        expectedRevision: 12,
        actualRevision: 12,
      );
      expect(commit.ok, isTrue);
      expect(commit.revisionAfter, 13);
    });
  });
}

RefusionMcpCommandEnvelope _command({
  required String type,
  required RefusionMcpCapability capability,
  Map<String, Object?> payload = const <String, Object?>{},
  RefusionMcpCommandMode mode = RefusionMcpCommandMode.dryRun,
  int? expectedRevision,
}) {
  return RefusionMcpCommandEnvelope(
    commandId: 'cmd_1',
    sessionId: 'session_1',
    projectId: 'active',
    type: type,
    capability: capability,
    mode: mode,
    idempotencyKey: 'turn-1',
    expectedRevision: expectedRevision,
    payload: payload,
  );
}

RefusionMcpSession _sessionWithAllWrites() {
  return RefusionMcpSession(
    id: 'session_1',
    clientName: 'test',
    clientVersion: '1.0.0',
    transport: 'stdio',
    activeProjectId: 'active',
    activeCompositionId: 'comp_1',
    timelineRevision: 12,
    grantedCapabilities: <RefusionMcpCapability>{
      RefusionMcpCapability.projectRead,
      RefusionMcpCapability.timelineRead,
      RefusionMcpCapability.previewRead,
      RefusionMcpCapability.timelineWrite,
      RefusionMcpCapability.motionWrite,
      RefusionMcpCapability.sceneWrite,
    },
  );
}
