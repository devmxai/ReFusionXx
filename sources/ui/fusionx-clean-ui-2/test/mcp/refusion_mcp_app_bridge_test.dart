import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_agent_control_plane.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_capability.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_command.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_command_bus.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_command_result.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_hardening_policy.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_mvp_toolkit.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_resource_provider.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_session.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_session_store.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_tool_registry.dart';
import 'package:refusion_app/features/editor/presentation/mcp/refusion_mcp_app_bridge.dart';

void main() {
  group('RefusionMcpAppBridge', () {
    test('opens session, lists tools, reads resource, executes tool', () {
      final bus = RefusionMcpCommandBus();
      const toolkit = RefusionMcpMvpToolkit();
      toolkit.register(
        bus: bus,
        config: RefusionMcpMvpToolkitConfig(
          projectStateReader: () => <String, Object?>{
            'projectId': 'active',
            'revision': 2,
          },
          timelineSummaryReader: () => <String, Object?>{'rows': 1},
          selectionReader: () => <String, Object?>{'selected': <String>[]},
          previewCaptureReader: (timeMs) => <String, Object?>{
            'resourceUri': 'refusion://preview/frame/${timeMs ?? 0}',
          },
        ),
      );
      final sessions = RefusionMcpSessionStore();
      final resources = RefusionMcpResourceProvider(
        readers: <String, RefusionMcpResourceReader>{
          'refusion://project/active/state': () => <String, Object?>{
                'projectId': 'active',
              },
        },
      );
      final controlPlane = RefusionMcpAgentControlPlane(
        commandBus: bus,
        toolRegistry: RefusionMcpToolRegistry(),
        sessionStore: sessions,
        revisionReader: () => 2,
      );
      final bridge = RefusionMcpAppBridge(
        controlPlane: controlPlane,
        sessionStore: sessions,
        resourceProvider: resources,
      );
      bridge.openSession(
        RefusionMcpSession(
          id: 'session_1',
          clientName: 'codex',
          clientVersion: '1.0',
          transport: 'stdio',
          activeProjectId: 'active',
          activeCompositionId: 'comp_1',
          timelineRevision: 2,
          grantedCapabilities: <RefusionMcpCapability>{
            RefusionMcpCapability.projectRead,
          },
        ),
      );
      expect(bridge.listSessions().length, 1);
      expect(bridge.listTools().contains('refusion.get_project_state'), isTrue);
      expect(bridge.listPrompts(), isNotEmpty);
      final granted = bridge.grantCapabilities(<RefusionMcpCapability>{
        RefusionMcpCapability.projectRead,
        RefusionMcpCapability.filesystemRead,
      });
      expect(granted.contains(RefusionMcpCapability.projectRead), isTrue);
      expect(granted.contains(RefusionMcpCapability.filesystemRead), isFalse);
      final resource = bridge.readResource('refusion://project/active/state');
      expect(resource.ok, isTrue);

      final result = bridge.executeTool(
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
      final health = bridge.health();
      expect(health.ready, isTrue);
      expect(health.sessionCount, 1);
      expect(health.toolCount, greaterThan(0));
      expect(health.resourceCount, greaterThanOrEqualTo(1));
      expect(bridge.closeSession('session_1'), isTrue);
      expect(bridge.listSessions(), isEmpty);
    });

    test('enforces payload size and rate limits', () {
      var revision = 2;
      final bus = RefusionMcpCommandBus();
      const toolkit = RefusionMcpMvpToolkit();
      toolkit.register(
        bus: bus,
        config: RefusionMcpMvpToolkitConfig(
          projectStateReader: () => <String, Object?>{
            'projectId': 'active',
            'revision': revision,
          },
          timelineSummaryReader: () => <String, Object?>{'rows': 1},
          selectionReader: () => <String, Object?>{'selected': <String>[]},
          previewCaptureReader: (timeMs) => <String, Object?>{
            'resourceUri': 'refusion://preview/frame/${timeMs ?? 0}',
          },
        ),
      );
      final sessions = RefusionMcpSessionStore();
      final controlPlane = RefusionMcpAgentControlPlane(
        commandBus: bus,
        toolRegistry: RefusionMcpToolRegistry(),
        sessionStore: sessions,
        revisionReader: () => revision,
      );
      final bridge = RefusionMcpAppBridge(
        controlPlane: controlPlane,
        sessionStore: sessions,
        resourceProvider: RefusionMcpResourceProvider(),
        hardeningPolicy: RefusionMcpHardeningPolicy(
          maxToolPayloadBytes: 20,
          maxCallsPerMinutePerSession: 1,
        ),
      );
      bridge.openSession(
        RefusionMcpSession(
          id: 'session_limits',
          clientName: 'codex',
          clientVersion: '1.0',
          transport: 'stdio',
          activeProjectId: 'active',
          activeCompositionId: 'comp_1',
          timelineRevision: revision,
          grantedCapabilities: <RefusionMcpCapability>{
            RefusionMcpCapability.projectRead,
          },
        ),
      );

      final oversized = bridge.executeTool(
        const RefusionMcpToolCallRequest(
          toolName: 'refusion.get_project_state',
          sessionId: 'session_limits',
          projectId: 'active',
          commandId: 'cmd_big',
          idempotencyKey: 'big',
          mode: RefusionMcpCommandMode.dryRun,
          payload: <String, Object?>{
            'blob': 'this-payload-should-trigger-size-limit',
          },
        ),
      );
      expect(oversized.ok, isFalse);
      expect(
          oversized.error?.code, RefusionMcpCommandErrorCode.payloadTooLarge);

      final ok = bridge.executeTool(
        const RefusionMcpToolCallRequest(
          toolName: 'refusion.get_project_state',
          sessionId: 'session_limits',
          projectId: 'active',
          commandId: 'cmd_ok',
          idempotencyKey: 'ok',
          mode: RefusionMcpCommandMode.dryRun,
        ),
      );
      expect(ok.ok, isTrue);

      final rateLimited = bridge.executeTool(
        const RefusionMcpToolCallRequest(
          toolName: 'refusion.get_project_state',
          sessionId: 'session_limits',
          projectId: 'active',
          commandId: 'cmd_rate',
          idempotencyKey: 'rate',
          mode: RefusionMcpCommandMode.dryRun,
        ),
      );
      expect(rateLimited.ok, isFalse);
      expect(rateLimited.error?.code, RefusionMcpCommandErrorCode.rateLimited);
    });
  });
}
