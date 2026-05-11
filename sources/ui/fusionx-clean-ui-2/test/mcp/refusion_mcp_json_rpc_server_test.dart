import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_agent_control_plane.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_capability.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_command_bus.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_hardening_policy.dart';
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
              'capabilities': <String>[
                'project.read',
                'filesystem.read',
                'export.start',
              ],
            },
          },
        },
      );
      final openResult = open['result'] as Map<String, Object?>;
      expect(openResult['sessionId'], 'session_1');
      final granted =
          (openResult['grantedCapabilities'] as List).cast<String>();
      expect(granted.contains('project.read'), isTrue);
      expect(granted.contains('filesystem.read'), isFalse);
      expect(granted.contains('export.start'), isFalse);

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

    test('auto-bootstrap default session on tools/call when missing', () {
      final call = server.handle(
        <String, Object?>{
          'jsonrpc': '2.0',
          'id': 10,
          'method': 'tools/call',
          'params': <String, Object?>{
            'name': 'refusion.get_project_state',
            'arguments': <String, Object?>{
              'sessionId': 'default',
              'projectId': 'active',
              'commandId': 'cmd_auto',
              'idempotencyKey': 'turn-auto',
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

      final sessions = server.handle(
        <String, Object?>{
          'jsonrpc': '2.0',
          'id': 11,
          'method': 'refusion/session/list',
          'params': const <String, Object?>{},
        },
      );
      final listed =
          (sessions['result'] as Map<String, Object?>)['sessions'] as List;
      expect(
        listed.any(
          (entry) => entry is Map<String, Object?> && entry['id'] == 'default',
        ),
        isTrue,
      );
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

    test('lists prompts and fetches prompt definition', () {
      final listResponse = server.handle(
        <String, Object?>{
          'jsonrpc': '2.0',
          'id': 6,
          'method': 'prompts/list',
          'params': const <String, Object?>{},
        },
      );
      final listResult = listResponse['result'] as Map<String, Object?>;
      final prompts =
          (listResult['prompts'] as List).cast<Map<String, Object?>>();
      expect(prompts, isNotEmpty);

      final firstPromptName = prompts.first['name'] as String;
      final promptResponse = server.handle(
        <String, Object?>{
          'jsonrpc': '2.0',
          'id': 7,
          'method': 'prompts/get',
          'params': <String, Object?>{
            'name': firstPromptName,
          },
        },
      );
      final promptResult = promptResponse['result'] as Map<String, Object?>;
      expect(promptResult['description'], isNotNull);
      expect((promptResult['messages'] as List).isNotEmpty, isTrue);
    });

    test('requires pairing token when hardening policy is configured', () {
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
      final resourceProvider = RefusionMcpResourceProvider();
      final registry = RefusionMcpToolRegistry();
      final controlPlane = RefusionMcpAgentControlPlane(
        commandBus: bus,
        toolRegistry: registry,
        sessionStore: sessionStore,
        revisionReader: () => 5,
      );
      final hardenedBridge = RefusionMcpAppBridge(
        controlPlane: controlPlane,
        sessionStore: sessionStore,
        resourceProvider: resourceProvider,
        hardeningPolicy: RefusionMcpHardeningPolicy(
          requiredPairingToken: 'pair-123',
        ),
      );
      final hardenedServer = RefusionMcpJsonRpcServer(
        bridge: hardenedBridge,
        toolRegistry: registry,
      );

      final denied = hardenedServer.handle(
        <String, Object?>{
          'jsonrpc': '2.0',
          'id': 8,
          'method': 'refusion/session/open',
          'params': <String, Object?>{
            'session': <String, Object?>{
              'id': 'session_secure',
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
      expect(denied['error'], isNotNull);

      final allowed = hardenedServer.handle(
        <String, Object?>{
          'jsonrpc': '2.0',
          'id': 9,
          'method': 'refusion/session/open',
          'params': <String, Object?>{
            'pairingToken': 'pair-123',
            'session': <String, Object?>{
              'id': 'session_secure',
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
      expect(allowed['error'], isNull);
      final result = allowed['result'] as Map<String, Object?>;
      expect(result['sessionId'], 'session_secure');

      final missingSessionCall = hardenedServer.handle(
        <String, Object?>{
          'jsonrpc': '2.0',
          'id': 12,
          'method': 'tools/call',
          'params': <String, Object?>{
            'name': 'refusion.get_project_state',
            'arguments': <String, Object?>{
              'sessionId': 'default',
              'projectId': 'active',
              'commandId': 'cmd_secure',
              'idempotencyKey': 'turn-secure',
              'mode': 'dryRun',
              'payload': const <String, Object?>{},
            },
          },
        },
      );
      final missingResult =
          missingSessionCall['result'] as Map<String, Object?>;
      expect(missingResult['isError'], isTrue);
      final missingStructured =
          missingResult['structuredContent'] as Map<String, Object?>;
      expect(missingStructured['code'], 'sessionNotFound');
    });
  });
}
