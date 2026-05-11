import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_agent_control_plane.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_capability.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_command.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_command_bus.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_command_result.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_mvp_toolkit.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_session.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_session_store.dart';
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
    });
  });
}
