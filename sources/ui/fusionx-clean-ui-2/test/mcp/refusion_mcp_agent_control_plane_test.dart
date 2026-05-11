import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_agent_control_plane.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_capability.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_command.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_command_bus.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_command_result.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_mvp_toolkit.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_security_policy.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_session.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_session_store.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_transaction.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_tool_registry.dart';

void main() {
  group('RefusionMcpAgentControlPlane', () {
    test('fails when session is missing', () {
      final controlPlane = RefusionMcpAgentControlPlane(
        commandBus: RefusionMcpCommandBus(),
        toolRegistry: RefusionMcpToolRegistry(),
        sessionStore: RefusionMcpSessionStore(),
        revisionReader: () => 5,
      );
      final result = controlPlane.executeTool(
        const RefusionMcpToolCallRequest(
          toolName: 'refusion.get_project_state',
          sessionId: 'missing',
          projectId: 'active',
          commandId: 'cmd_1',
          idempotencyKey: 'turn-1',
        ),
      );
      expect(result.ok, isFalse);
      expect(result.error?.code, RefusionMcpCommandErrorCode.sessionNotFound);
    });

    test('executes registered read tool through command bus', () {
      final bus = RefusionMcpCommandBus();
      const toolkit = RefusionMcpMvpToolkit();
      toolkit.register(
        bus: bus,
        config: RefusionMcpMvpToolkitConfig(
          projectStateReader: () => <String, Object?>{
            'projectId': 'active',
            'revision': 15,
          },
          timelineSummaryReader: () => <String, Object?>{'rows': 4},
          selectionReader: () => <String, Object?>{'selected': <String>[]},
          previewCaptureReader: (timeMs) => <String, Object?>{
            'resourceUri': 'refusion://preview/frame/${timeMs ?? 0}',
          },
        ),
      );
      final store = RefusionMcpSessionStore();
      store.upsert(
        RefusionMcpSession(
          id: 'session_1',
          clientName: 'codex',
          clientVersion: '1.0',
          transport: 'stdio',
          activeProjectId: 'active',
          activeCompositionId: 'comp_1',
          timelineRevision: 15,
          grantedCapabilities: <RefusionMcpCapability>{
            RefusionMcpCapability.projectRead,
          },
        ),
      );
      final controlPlane = RefusionMcpAgentControlPlane(
        commandBus: bus,
        toolRegistry: RefusionMcpToolRegistry(),
        sessionStore: store,
        revisionReader: () => 15,
      );
      final result = controlPlane.executeTool(
        const RefusionMcpToolCallRequest(
          toolName: 'refusion.get_project_state',
          sessionId: 'session_1',
          projectId: 'active',
          commandId: 'cmd_1',
          idempotencyKey: 'turn-1',
          mode: RefusionMcpCommandMode.dryRun,
        ),
      );
      expect(result.ok, isTrue);
      expect(result.payload['projectId'], 'active');
    });

    test('lists tool names from registry', () {
      final controlPlane = RefusionMcpAgentControlPlane(
        commandBus: RefusionMcpCommandBus(),
        toolRegistry: RefusionMcpToolRegistry(),
        sessionStore: RefusionMcpSessionStore(),
        revisionReader: () => 1,
      );
      final tools = controlPlane.listTools();
      expect(tools.contains('refusion.get_project_state'), isTrue);
      expect(tools.contains('refusion.validate_scene_program'), isTrue);
      expect(tools.contains('refusion.list_recent_transactions'), isTrue);
      expect(tools.contains('refusion.commit_transaction'), isTrue);
    });

    test('supports dry_run_command wrapper', () {
      final bus = RefusionMcpCommandBus();
      const toolkit = RefusionMcpMvpToolkit();
      toolkit.register(
        bus: bus,
        config: RefusionMcpMvpToolkitConfig(
          projectStateReader: () => <String, Object?>{
            'projectId': 'active',
            'revision': 6,
          },
          timelineSummaryReader: () => <String, Object?>{'rows': 1},
          selectionReader: () => <String, Object?>{'selected': <String>[]},
          previewCaptureReader: (_) => <String, Object?>{},
        ),
      );
      final store = RefusionMcpSessionStore();
      store.upsert(
        RefusionMcpSession(
          id: 'session_1',
          clientName: 'codex',
          clientVersion: '1.0',
          transport: 'stdio',
          activeProjectId: 'active',
          activeCompositionId: 'comp_1',
          timelineRevision: 6,
          grantedCapabilities: <RefusionMcpCapability>{
            RefusionMcpCapability.timelineRead,
            RefusionMcpCapability.projectRead,
          },
        ),
      );
      final controlPlane = RefusionMcpAgentControlPlane(
        commandBus: bus,
        toolRegistry: RefusionMcpToolRegistry(),
        sessionStore: store,
        revisionReader: () => 6,
      );
      final result = controlPlane.executeTool(
        const RefusionMcpToolCallRequest(
          toolName: 'refusion.dry_run_command',
          sessionId: 'session_1',
          projectId: 'active',
          commandId: 'cmd_dry_run',
          idempotencyKey: 'turn-2',
          payload: <String, Object?>{
            'toolName': 'refusion.get_project_state',
            'payload': <String, Object?>{},
          },
        ),
      );
      expect(result.ok, isTrue);
      expect(result.payload['projectId'], 'active');
    });

    test('lists recent committed transactions', () {
      final bus = RefusionMcpCommandBus();
      var revision = 9;
      const toolkit = RefusionMcpMvpToolkit();
      toolkit.register(
        bus: bus,
        config: RefusionMcpMvpToolkitConfig(
          projectStateReader: () => <String, Object?>{'revision': revision},
          timelineSummaryReader: () => <String, Object?>{'rows': 1},
          selectionReader: () => <String, Object?>{'selected': <String>[]},
          previewCaptureReader: (_) => <String, Object?>{},
          keyframeEditHandler: (_) => RefusionMcpCommandHandlingOutcome(
            summary: 'Keyframe edit prepared.',
            patchPreview: RefusionMcpPatchPreview(
              affectedObjects: <String>['node_1'],
              changedProperties: <String>['transform.position.x'],
            ),
            commitOperation: () {
              revision += 1;
              return RefusionMcpCommitExecution(revisionAfter: revision);
            },
          ),
        ),
      );
      final store = RefusionMcpSessionStore();
      store.upsert(
        RefusionMcpSession(
          id: 'session_1',
          clientName: 'codex',
          clientVersion: '1.0',
          transport: 'stdio',
          activeProjectId: 'active',
          activeCompositionId: 'comp_1',
          timelineRevision: 9,
          grantedCapabilities: <RefusionMcpCapability>{
            RefusionMcpCapability.motionWrite,
            RefusionMcpCapability.timelineWrite,
            RefusionMcpCapability.timelineRead,
          },
        ),
      );
      final controlPlane = RefusionMcpAgentControlPlane(
        commandBus: bus,
        toolRegistry: RefusionMcpToolRegistry(),
        sessionStore: store,
        revisionReader: () => revision,
      );
      final mutation = controlPlane.executeTool(
        const RefusionMcpToolCallRequest(
          toolName: 'refusion.keyframe_edit',
          sessionId: 'session_1',
          projectId: 'active',
          commandId: 'cmd_commit_1',
          idempotencyKey: 'turn-3',
          mode: RefusionMcpCommandMode.commit,
          expectedRevision: 9,
          payload: <String, Object?>{
            'action': 'add',
            'targetId': 'node_1',
            'property': 'position.x',
            'timeMs': 300,
            'value': 42,
          },
        ),
      );
      expect(mutation.ok, isTrue);
      final listed = controlPlane.executeTool(
        const RefusionMcpToolCallRequest(
          toolName: 'refusion.list_recent_transactions',
          sessionId: 'session_1',
          projectId: 'active',
          commandId: 'cmd_list_1',
          idempotencyKey: 'turn-4',
          payload: <String, Object?>{},
        ),
      );
      expect(listed.ok, isTrue);
      final recent = listed.payload['recentCommitted'] as List<Object?>;
      expect(recent, isNotEmpty);
    });

    test('blocks destructive commit without explicit confirmation', () {
      final bus = RefusionMcpCommandBus();
      bus.registerHandler(
        commandType: 'refusion.delete_layer',
        handler: (_) => RefusionMcpCommandHandlingOutcome(
          summary: 'Delete prepared.',
          commitOperation: () => const RefusionMcpCommitExecution(
            revisionAfter: 9,
          ),
        ),
      );
      final store = RefusionMcpSessionStore();
      store.upsert(
        RefusionMcpSession(
          id: 'session_1',
          clientName: 'codex',
          clientVersion: '1.0',
          transport: 'stdio',
          activeProjectId: 'active',
          activeCompositionId: 'comp_1',
          timelineRevision: 8,
          grantedCapabilities: <RefusionMcpCapability>{
            RefusionMcpCapability.timelineWrite,
          },
        ),
      );
      final controlPlane = RefusionMcpAgentControlPlane(
        commandBus: bus,
        toolRegistry: RefusionMcpToolRegistry(),
        sessionStore: store,
        revisionReader: () => 8,
      );
      final result = controlPlane.executeTool(
        const RefusionMcpToolCallRequest(
          toolName: 'refusion.delete_layer',
          sessionId: 'session_1',
          projectId: 'active',
          commandId: 'cmd_del_1',
          idempotencyKey: 'turn-5',
          mode: RefusionMcpCommandMode.commit,
          expectedRevision: 8,
          payload: <String, Object?>{
            'layerId': 'layer_1',
          },
        ),
      );
      expect(result.ok, isFalse);
      expect(
        result.error?.code,
        RefusionMcpCommandErrorCode.confirmationRequired,
      );
      expect(result.requiresConfirmation, isTrue);
    });

    test('blocks filesystem capability tools by default policy', () {
      final bus = RefusionMcpCommandBus();
      bus.registerHandler(
        commandType: 'refusion.filesystem_read',
        handler: (_) => RefusionMcpCommandHandlingOutcome(
          summary: 'Read prepared.',
        ),
      );
      final registry = RefusionMcpToolRegistry(
        tools: const <RefusionMcpToolDescriptor>[
          RefusionMcpToolDescriptor(
            name: 'refusion.filesystem_read',
            title: 'Filesystem Read',
            description: 'Read filesystem entry.',
            capability: RefusionMcpCapability.filesystemRead,
          ),
        ],
      );
      final store = RefusionMcpSessionStore();
      store.upsert(
        RefusionMcpSession(
          id: 'session_1',
          clientName: 'codex',
          clientVersion: '1.0',
          transport: 'stdio',
          activeProjectId: 'active',
          activeCompositionId: 'comp_1',
          timelineRevision: 8,
          grantedCapabilities: <RefusionMcpCapability>{
            RefusionMcpCapability.filesystemRead,
          },
        ),
      );
      final controlPlane = RefusionMcpAgentControlPlane(
        commandBus: bus,
        toolRegistry: registry,
        sessionStore: store,
        revisionReader: () => 8,
        securityPolicy: const RefusionMcpSecurityPolicy(),
      );
      final result = controlPlane.executeTool(
        const RefusionMcpToolCallRequest(
          toolName: 'refusion.filesystem_read',
          sessionId: 'session_1',
          projectId: 'active',
          commandId: 'cmd_fs_1',
          idempotencyKey: 'turn-6',
          mode: RefusionMcpCommandMode.dryRun,
        ),
      );
      expect(result.ok, isFalse);
      expect(result.error?.code, RefusionMcpCommandErrorCode.capabilityDenied);
    });
  });
}
