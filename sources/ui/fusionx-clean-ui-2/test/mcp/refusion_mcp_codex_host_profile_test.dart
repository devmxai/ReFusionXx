import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_agent_control_plane.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_command_bus.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_hardening_policy.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_mvp_toolkit.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_resource_provider.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_session_store.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_tool_registry.dart';
import 'package:refusion_app/features/editor/presentation/mcp/refusion_mcp_app_bridge.dart';
import 'package:refusion_app/features/editor/presentation/mcp/refusion_mcp_json_rpc_server.dart';

void main() {
  group('Refusion MCP Codex host compatibility', () {
    test('supports discovery + session open + dry-run command path', () {
      final bus = RefusionMcpCommandBus();
      const toolkit = RefusionMcpMvpToolkit();
      toolkit.register(
        bus: bus,
        config: RefusionMcpMvpToolkitConfig(
          projectStateReader: () => <String, Object?>{
            'projectId': 'active',
            'revision': 9,
          },
          timelineSummaryReader: () => <String, Object?>{'rowCount': 2},
          selectionReader: () => <String, Object?>{'selected': <String>[]},
          previewCaptureReader: (timeMs) => <String, Object?>{
            'resourceUri': 'refusion://preview/frame/${timeMs ?? 0}',
          },
        ),
      );

      final sessionStore = RefusionMcpSessionStore();
      final resourceProvider = RefusionMcpResourceProvider(
        readers: <String, RefusionMcpResourceReader>{
          'refusion://project/active/state': () => <String, Object?>{
                'projectId': 'active',
                'revision': 9,
              },
        },
      );
      final registry = RefusionMcpToolRegistry();
      final controlPlane = RefusionMcpAgentControlPlane(
        commandBus: bus,
        toolRegistry: registry,
        sessionStore: sessionStore,
        revisionReader: () => 9,
      );
      final bridge = RefusionMcpAppBridge(
        controlPlane: controlPlane,
        sessionStore: sessionStore,
        resourceProvider: resourceProvider,
        hardeningPolicy: RefusionMcpHardeningPolicy(
          requiredPairingToken: 'codex-local-token',
        ),
      );
      final server = RefusionMcpJsonRpcServer(
        bridge: bridge,
        toolRegistry: registry,
      );

      final initialize = server.handle(
        <String, Object?>{
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'initialize',
          'params': const <String, Object?>{},
        },
      );
      expect(initialize['error'], isNull);

      final toolsList = server.handle(
        <String, Object?>{
          'jsonrpc': '2.0',
          'id': 2,
          'method': 'tools/list',
          'params': const <String, Object?>{},
        },
      );
      final toolsResult = toolsList['result'] as Map<String, Object?>;
      final tools = (toolsResult['tools'] as List).cast<Map<String, Object?>>();
      expect(
        tools.any((tool) => tool['name'] == 'refusion.get_project_state'),
        isTrue,
      );

      final resourcesList = server.handle(
        <String, Object?>{
          'jsonrpc': '2.0',
          'id': 3,
          'method': 'resources/list',
          'params': const <String, Object?>{},
        },
      );
      final resourcesResult = resourcesList['result'] as Map<String, Object?>;
      final resources =
          (resourcesResult['resources'] as List).cast<Map<String, Object?>>();
      expect(
        resources.any(
          (resource) => resource['uri'] == 'refusion://project/active/state',
        ),
        isTrue,
      );

      final promptsList = server.handle(
        <String, Object?>{
          'jsonrpc': '2.0',
          'id': 4,
          'method': 'prompts/list',
          'params': const <String, Object?>{},
        },
      );
      final promptsResult = promptsList['result'] as Map<String, Object?>;
      final prompts =
          (promptsResult['prompts'] as List).cast<Map<String, Object?>>();
      expect(prompts.isNotEmpty, isTrue);

      final open = server.handle(
        <String, Object?>{
          'jsonrpc': '2.0',
          'id': 5,
          'method': 'refusion/session/open',
          'params': <String, Object?>{
            'pairingToken': 'codex-local-token',
            'session': <String, Object?>{
              'id': 'codex_session',
              'clientName': 'codex',
              'clientVersion': '1.0.0',
              'transport': 'stdio',
              'activeProjectId': 'active',
              'activeCompositionId': 'comp_1',
              'timelineRevision': 9,
              'capabilities': <String>[
                'project.read',
                'timeline.read',
                'preview.read',
              ],
            },
          },
        },
      );
      expect(open['error'], isNull);

      final dryRunWrapped = server.handle(
        <String, Object?>{
          'jsonrpc': '2.0',
          'id': 6,
          'method': 'tools/call',
          'params': <String, Object?>{
            'name': 'refusion.dry_run_command',
            'arguments': <String, Object?>{
              'sessionId': 'codex_session',
              'projectId': 'active',
              'commandId': 'cmd_6',
              'idempotencyKey': 'turn-6',
              'mode': 'dryRun',
              'expectedRevision': 9,
              'payload': <String, Object?>{
                'toolName': 'refusion.get_project_state',
                'payload': const <String, Object?>{},
              },
            },
          },
        },
      );
      final dryResult = dryRunWrapped['result'] as Map<String, Object?>;
      final structured = dryResult['structuredContent'] as Map<String, Object?>;
      expect(structured['ok'], isTrue);
      final payload = structured['payload'] as Map<String, Object?>;
      expect(payload['projectId'], 'active');
    });
  });
}
