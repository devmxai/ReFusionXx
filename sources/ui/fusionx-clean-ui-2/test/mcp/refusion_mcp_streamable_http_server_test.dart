import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_agent_control_plane.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_command_bus.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_mvp_toolkit.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_resource_provider.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_session_store.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_tool_registry.dart';
import 'package:refusion_app/features/editor/presentation/mcp/refusion_mcp_app_bridge.dart';
import 'package:refusion_app/features/editor/presentation/mcp/refusion_mcp_json_rpc_server.dart';
import 'package:refusion_app/features/editor/presentation/mcp/refusion_mcp_streamable_http_server.dart';

void main() {
  group('RefusionMcpStreamableHttpServer', () {
    late RefusionMcpStreamableHttpServer streamable;
    late Uri endpoint;
    late Uri rootEndpoint;

    setUp(() async {
      final bus = RefusionMcpCommandBus();
      const toolkit = RefusionMcpMvpToolkit();
      toolkit.register(
        bus: bus,
        config: RefusionMcpMvpToolkitConfig(
          projectStateReader: () => <String, Object?>{
            'projectId': 'active',
            'revision': 5,
          },
          timelineSummaryReader: () => <String, Object?>{
            'rowCount': 1,
          },
          selectionReader: () => <String, Object?>{
            'selected': const <String>[],
          },
          previewCaptureReader: (timeMs) => <String, Object?>{
            'resourceUri': 'refusion://preview/frame/${timeMs ?? 0}',
          },
        ),
      );

      final sessionStore = RefusionMcpSessionStore();
      final toolRegistry = RefusionMcpToolRegistry();
      final controlPlane = RefusionMcpAgentControlPlane(
        commandBus: bus,
        toolRegistry: toolRegistry,
        sessionStore: sessionStore,
        revisionReader: () => 5,
      );
      final bridge = RefusionMcpAppBridge(
        controlPlane: controlPlane,
        sessionStore: sessionStore,
        resourceProvider: RefusionMcpResourceProvider(),
      );
      final jsonRpc = RefusionMcpJsonRpcServer(
        bridge: bridge,
        toolRegistry: toolRegistry,
      );
      streamable = RefusionMcpStreamableHttpServer(jsonRpcServer: jsonRpc);
      final server = await streamable.start(
        address: InternetAddress.loopbackIPv4,
        port: 0,
      );
      endpoint = Uri.parse('http://127.0.0.1:${server.port}/mcp');
      rootEndpoint = Uri.parse('http://127.0.0.1:${server.port}/');
    });

    tearDown(() async {
      await streamable.stop(force: true);
    });

    test('responds to POST initialize', () async {
      final client = HttpClient();
      addTearDown(client.close);
      final request = await client.postUrl(endpoint);
      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode(<String, Object?>{
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'initialize',
          'params': const <String, Object?>{},
        }),
      );
      final response = await request.close();
      expect(response.statusCode, HttpStatus.ok);
      final text = await utf8.decoder.bind(response).join();
      final decoded = jsonDecode(text) as Map<String, Object?>;
      expect(decoded.containsKey('result'), isTrue);
    });

    test('responds to GET with streamable http metadata', () async {
      final client = HttpClient();
      addTearDown(client.close);
      final request = await client.getUrl(endpoint);
      final response = await request.close();
      expect(response.statusCode, HttpStatus.ok);
      final text = await utf8.decoder.bind(response).join();
      final decoded = jsonDecode(text) as Map<String, Object?>;
      expect(decoded['transport'], 'streamable-http');
    });

    test('accepts root alias for hosts that send base domain only', () async {
      final client = HttpClient();
      addTearDown(client.close);
      final request = await client.postUrl(rootEndpoint);
      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode(<String, Object?>{
          'jsonrpc': '2.0',
          'id': 99,
          'method': 'initialize',
          'params': const <String, Object?>{},
        }),
      );
      final response = await request.close();
      expect(response.statusCode, HttpStatus.ok);
      final text = await utf8.decoder.bind(response).join();
      final decoded = jsonDecode(text) as Map<String, Object?>;
      expect(decoded.containsKey('result'), isTrue);
    });
  });
}
