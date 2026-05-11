import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_agent_control_plane.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_capability.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_command_bus.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_mvp_toolkit.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_resource_provider.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_session_store.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_tool_registry.dart';
import 'package:refusion_app/features/editor/presentation/mcp/refusion_mcp_app_bridge.dart';
import 'package:refusion_app/features/editor/presentation/mcp/refusion_mcp_json_rpc_server.dart';

void main() {
  group('RefusionMcpJsonRpcServer', () {
    late RefusionMcpJsonRpcServer server;

    setUp(() {
      final bus = RefusionMcpCommandBus();
      const toolkit = RefusionMcpMvpToolkit();
      toolkit.register(
        bus: bus,
        config: RefusionMcpMvpToolkitConfig(
          projectStateReader: () => <String, Object?>{
            'projectId': 'active',
            'revision': 5,
          },
          timelineSummaryReader: () => <String, Object?>{'rows': 2},
          selectionReader: () => <String, Object?>{'selected': <String>[]},
          previewCaptureReader: (_) => <String, Object?>{
            'resourceUri': 'refusion://preview/frame/0',
          },
        ),
      );
      final sessionStore = RefusionMcpSessionStore();
      final resourceProvider = RefusionMcpResourceProvider(
        readers: <String, RefusionMcpResourceReader>{
          'refusion://project/active/state': () => <String, Object?>{
                'projectId': 'active',
                'revision': 5,
              },
        },
      );
      final registry = RefusionMcpToolRegistry();
      final controlPlane = RefusionMcpAgentControlPlane(
        commandBus: bus,
        toolRegistry: registry,
        sessionStore: sessionStore,
        revisionReader: () => 5,
      );
      final bridge = RefusionMcpAppBridge(
        controlPlane: controlPlane,
        sessionStore: sessionStore,
        resourceProvider: resourceProvider,
      );
      server = RefusionMcpJsonRpcServer(
        bridge: bridge,
        toolRegistry: registry,
      );
    });

    test('returns initialize and tools list payloads', () {
      final initialize = server.handle(
        <String, Object?>{
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'initialize',
          'params': const <String, Object?>{},
        },
      );
      expect(initialize['error'], isNull);
      final initializeResult = initialize['result'] as Map<String, Object?>;
      expect(initializeResult['protocolVersion'], isNotNull);

      final toolsList = server.handle(
        <String, Object?>{
          'jsonrpc': '2.0',
          'id': 2,
          'method': 'tools/list',
          'params': const <String, Object?>{},
        },
      );
      final listResult = toolsList['result'] as Map<String, Object?>;
      final tools = (listResult['tools'] as List).cast<Map<String, Object?>>();
      expect(
        tools.any((tool) => tool['name'] == 'refusion.get_project_state'),
        isTrue,
      );
    });

    test('opens session then calls tool through tools/call', () {
      final open = server.handle(
        <String, Object?>{
          'jsonrpc': '2.0',
          'id': 3,
          'method': 'refusion/session/open',
          'params': <String, Object?>{
            'session': <String, Object?>{
              'id': 'session_1',
              'clientName': 'codex',
              'clientVersion': '1.0.0',
              'transport': 'stdio',
              'activeProjectId': 'active',
              'activeCompositionId': 'comp_1',
              'timelineRevision': 5,
              'capabilities': <String>['project.read'],
            },
          },
        },
      );
      expect(
          (open['result'] as Map<String, Object?>)['sessionId'], 'session_1');

      final call = server.handle(
        <String, Object?>{
          'jsonrpc': '2.0',
          'id': 4,
          'method': 'tools/call',
          'params': <String, Object?>{
            'name': 'refusion.get_project_state',
            'arguments': <String, Object?>{
              'sessionId': 'session_1',
              'projectId': 'active',
              'commandId': 'cmd_1',
              'idempotencyKey': 'turn-1',
              'mode': 'dryRun',
              'payload': const <String, Object?>{},
            },
          },
        },
      );
      final result = call['result'] as Map<String, Object?>;
      expect(result['isError'], isFalse);
      final structured = (result['structuredContent']
          as Map<String, Object?>)['payload'] as Map<String, Object?>;
      expect(structured['projectId'], 'active');
    });

    test('reads resource through resources/read', () {
      final response = server.handle(
        <String, Object?>{
          'jsonrpc': '2.0',
          'id': 5,
          'method': 'resources/read',
          'params': <String, Object?>{
            'uri': 'refusion://project/active/state',
          },
        },
      );
      final result = response['result'] as Map<String, Object?>;
      final contents =
          (result['contents'] as List).cast<Map<String, Object?>>();
      expect(contents, isNotEmpty);
      final payload =
          jsonDecode(contents.first['text'] as String) as Map<String, Object?>;
      expect(payload['projectId'], 'active');
    });
  });
}
