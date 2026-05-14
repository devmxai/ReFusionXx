import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/presentation/services/refusion_mcp_cloud_bridge.dart';

void main() {
  group('RefusionMcpCloudBridge fast apply split', () {
    test(
      'syncNow returns before slow diagnostics complete and emits fast snapshot first',
      () async {
        final server = await _FakeMcpServer.start(
          diagnosticsDelay: const Duration(milliseconds: 220),
        );
        addTearDown(server.close);

        final snapshots = <RefusionMcpCloudBridgeSnapshot>[];
        final bridge = RefusionMcpCloudBridge(
          endpoint: server.endpoint,
          deviceId: 'test-device',
          contextReader: () => const RefusionMcpCloudContextState(
            projectId: 'project-1',
            compositionId: 'composition-1',
            playheadMs: 1200,
            timelineRevision: 2,
            foreground: true,
          ),
          onSnapshot: snapshots.add,
          interval: const Duration(seconds: 60),
          connectTimeout: const Duration(seconds: 2),
        );
        addTearDown(bridge.stop);

        final stopwatch = Stopwatch()..start();
        await bridge.syncNow();
        stopwatch.stop();

        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(1200),
          reason: 'fast path must not wait for slow diagnostics tools',
        );
        expect(snapshots, isNotEmpty);
        final firstSnapshot = snapshots.first;
        expect(firstSnapshot.canvasMetadata, isEmpty);

        await _waitFor(
          () => snapshots.any((snapshot) => snapshot.canvasMetadata.isNotEmpty),
        );
        final diagnosticSnapshot = snapshots.lastWhere(
          (snapshot) => snapshot.canvasMetadata.isNotEmpty,
        );
        expect(diagnosticSnapshot.canvasMetadata['width'], 1080);
      },
    );

    test('diagnostics in flight do not block a new fast sync cycle', () async {
      final server = await _FakeMcpServer.start(
        diagnosticsDelay: const Duration(milliseconds: 260),
      );
      addTearDown(server.close);

      final bridge = RefusionMcpCloudBridge(
        endpoint: server.endpoint,
        deviceId: 'test-device',
        contextReader: () => const RefusionMcpCloudContextState(
          projectId: 'project-1',
          compositionId: 'composition-1',
          playheadMs: 1800,
          timelineRevision: 3,
          foreground: true,
        ),
        onSnapshot: (_) {},
        interval: const Duration(seconds: 60),
        connectTimeout: const Duration(seconds: 2),
      );
      addTearDown(bridge.stop);

      await bridge.syncNow();
      final layersCallsAfterFirstSync = server.callCount('get_layers');

      await bridge.syncNow();

      expect(
        server.callCount('get_layers'),
        greaterThan(layersCallsAfterFirstSync),
        reason:
            'second fast sync should run even while diagnostics are running',
      );
    });
  });
}

Future<void> _waitFor(
  bool Function() predicate, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!predicate()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Condition was not met before timeout.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

class _FakeMcpServer {
  _FakeMcpServer._({
    required this.server,
    required this.endpoint,
    required this.diagnosticsDelay,
  });

  final HttpServer server;
  final Uri endpoint;
  final Duration diagnosticsDelay;
  final Map<String, int> _counts = <String, int>{};

  static Future<_FakeMcpServer> start({
    required Duration diagnosticsDelay,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final endpoint = Uri.parse(
      'http://${server.address.address}:${server.port}/mcp',
    );
    final fake = _FakeMcpServer._(
      server: server,
      endpoint: endpoint,
      diagnosticsDelay: diagnosticsDelay,
    );
    fake._serve();
    return fake;
  }

  int callCount(String toolName) => _counts[toolName] ?? 0;

  Future<void> close() async {
    await server.close(force: true);
  }

  void _serve() {
    unawaited(() async {
      await for (final request in server) {
        final bodyText = await utf8.decoder.bind(request).join();
        final body = jsonDecode(bodyText) as Map<String, Object?>;
        final params = (body['params'] as Map<String, Object?>?) ??
            const <String, Object?>{};
        final toolName = (params['name'] as String?) ?? '';
        _counts[toolName] = (_counts[toolName] ?? 0) + 1;

        if (_isDiagnosticsTool(toolName)) {
          await Future<void>.delayed(diagnosticsDelay);
        }

        final payload = _payloadForTool(toolName);
        final response = <String, Object?>{
          'jsonrpc': '2.0',
          'id': body['id'],
          'result': <String, Object?>{
            'content': const <Object?>[],
            'structuredContent': <String, Object?>{
              'ok': true,
              'summary': 'ok',
              'payload': payload,
            },
          },
        };
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(response));
        await request.response.close();
      }
    }());
  }

  bool _isDiagnosticsTool(String toolName) {
    switch (toolName) {
      case 'get_canvas_metadata':
      case 'get_visual_layout_summary':
      case 'get_element_geometry':
      case 'get_project_snapshot':
      case 'get_timeline_graph':
      case 'evaluate_frame':
        return true;
      default:
        return false;
    }
  }

  Map<String, Object?> _payloadForTool(String toolName) {
    switch (toolName) {
      case 'get_active_context':
        return <String, Object?>{
          'project': <String, Object?>{'id': 'project-1', 'revision': 3},
          'composition': <String, Object?>{'id': 'composition-1'},
          'liveEditor': <String, Object?>{
            'online': true,
            'sessionId': 'session-1',
          },
        };
      case 'get_pending_commands':
        return <String, Object?>{
          'commands': const <Map<String, Object?>>[],
        };
      case 'get_layers':
        return <String, Object?>{
          'revision': 3,
          'layers': const <Map<String, Object?>>[
            <String, Object?>{'id': 'layer-1', 'layer_kind': 'solid'},
          ],
        };
      case 'get_motion_channels':
        return <String, Object?>{
          'channels': const <Map<String, Object?>>[],
        };
      case 'get_canvas_metadata':
        return <String, Object?>{
          'width': 1080,
          'height': 1920,
        };
      case 'get_visual_layout_summary':
        return <String, Object?>{
          'summary': 'ok',
        };
      case 'get_element_geometry':
        return <String, Object?>{
          'layerId': 'layer-1',
        };
      case 'get_project_snapshot':
        return <String, Object?>{
          'revision': 3,
        };
      case 'get_timeline_graph':
        return <String, Object?>{
          'tracks': const <Object?>[],
        };
      case 'evaluate_frame':
        return <String, Object?>{
          'timeMs': 1200,
        };
      default:
        return const <String, Object?>{};
    }
  }
}
