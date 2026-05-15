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
            workspaceId: 'workspace-1',
            playheadMs: 1200,
            timelineRevision: 2,
            foreground: true,
            canvasWidth: 1080,
            canvasHeight: 1920,
            durationMs: 8000,
            fps: 30,
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
          lessThan(1800),
          reason: 'fast path must not wait for slow diagnostics tools',
        );
        expect(snapshots, isNotEmpty);
        final firstSnapshot = snapshots.first;
        expect(firstSnapshot.canvasMetadata['width'], 1080);
        expect(firstSnapshot.canvasMetadata['height'], 1920);

        await _waitFor(
          () => snapshots.any((snapshot) => snapshot.canvasMetadata.isNotEmpty),
        );
        final diagnosticSnapshot = snapshots.lastWhere(
          (snapshot) => snapshot.canvasMetadata.isNotEmpty,
        );
        expect(diagnosticSnapshot.canvasMetadata['width'], 1080);
        expect(diagnosticSnapshot.canvasMetadata['height'], 1920);
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
          workspaceId: 'workspace-1',
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

    test(
      'fast sync falls back to local context when get_active_context is slow',
      () async {
        final server = await _FakeMcpServer.start(
          diagnosticsDelay: const Duration(milliseconds: 20),
          contextDelay: const Duration(seconds: 3),
        );
        addTearDown(server.close);

        final snapshots = <RefusionMcpCloudBridgeSnapshot>[];
        final bridge = RefusionMcpCloudBridge(
          endpoint: server.endpoint,
          deviceId: 'test-device',
          contextReader: () => const RefusionMcpCloudContextState(
            projectId: 'project-1',
            compositionId: 'composition-1',
            workspaceId: 'workspace-1',
            playheadMs: 1600,
            timelineRevision: 6,
            foreground: true,
          ),
          onSnapshot: snapshots.add,
          interval: const Duration(seconds: 60),
          connectTimeout: const Duration(seconds: 8),
        );
        addTearDown(bridge.stop);

        final stopwatch = Stopwatch()..start();
        await bridge.syncNow();
        stopwatch.stop();

        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(5000),
          reason: 'soft timeout must prevent long context stalls in fast path',
        );
        expect(snapshots, isNotEmpty);
        final firstSnapshot = snapshots.first;
        expect(firstSnapshot.projectId, 'project-1');
        expect(firstSnapshot.compositionId, 'composition-1');
      },
    );

    test(
      'fast sync waits for pending command bus instead of losing appReceived commands',
      () async {
        final server = await _FakeMcpServer.start(
          diagnosticsDelay: const Duration(milliseconds: 20),
          pendingCommandsDelay: const Duration(milliseconds: 1900),
          includePendingCommand: true,
        );
        addTearDown(server.close);

        final snapshots = <RefusionMcpCloudBridgeSnapshot>[];
        final bridge = RefusionMcpCloudBridge(
          endpoint: server.endpoint,
          deviceId: 'test-device',
          contextReader: () => const RefusionMcpCloudContextState(
            projectId: 'project-1',
            compositionId: 'composition-1',
            workspaceId: 'workspace-1',
            playheadMs: 1200,
            timelineRevision: 2,
            foreground: true,
            canvasWidth: 1080,
            canvasHeight: 1920,
            durationMs: 8000,
            fps: 30,
          ),
          onSnapshot: snapshots.add,
          interval: const Duration(seconds: 60),
          connectTimeout: const Duration(seconds: 8),
        );
        addTearDown(bridge.stop);

        await bridge.syncNow();

        expect(
          server.callCount('get_pending_commands'),
          greaterThan(0),
          reason: 'pending command bus must be queried during fast apply',
        );
        expect(snapshots, isNotEmpty);
        expect(
          snapshots.first.pendingCommands,
          isNotEmpty,
          reason:
              'pending commands must reach the app snapshot even when the command bus is slower than diagnostics',
        );
        final commandPayload = snapshots.first.pendingCommands.single['payload']
            as Map<String, Object?>;
        expect(commandPayload['layerId'], 'solid-layer-1');
      },
    );

    test(
      'fast sync falls back to unscoped pending commands when scoped response is empty',
      () async {
        final server = await _FakeMcpServer.start(
          diagnosticsDelay: const Duration(milliseconds: 20),
          scopedPendingEmptyButUnscopedHasCommand: true,
        );
        addTearDown(server.close);

        final snapshots = <RefusionMcpCloudBridgeSnapshot>[];
        final bridge = RefusionMcpCloudBridge(
          endpoint: server.endpoint,
          deviceId: 'test-device',
          contextReader: () => const RefusionMcpCloudContextState(
            projectId: 'project-1',
            compositionId: 'composition-1',
            workspaceId: 'workspace-1',
            playheadMs: 1200,
            timelineRevision: 2,
            foreground: true,
          ),
          onSnapshot: snapshots.add,
          interval: const Duration(seconds: 60),
          connectTimeout: const Duration(seconds: 8),
        );
        addTearDown(bridge.stop);

        await bridge.syncNow();

        expect(
            server.callCount('get_pending_commands'), greaterThanOrEqualTo(2));
        expect(snapshots, isNotEmpty);
        expect(snapshots.first.pendingCommands, isNotEmpty);
        final commandPayload = snapshots.first.pendingCommands.single['payload']
            as Map<String, Object?>;
        expect(commandPayload['kind'], 'text');
      },
    );

    test(
      'fast sync preserves scoped local identity when active context is stale',
      () async {
        final server = await _FakeMcpServer.start(
          diagnosticsDelay: const Duration(milliseconds: 20),
          activeProjectId: 'stale-project',
          activeCompositionId: 'stale-composition',
        );
        addTearDown(server.close);

        final snapshots = <RefusionMcpCloudBridgeSnapshot>[];
        final bridge = RefusionMcpCloudBridge(
          endpoint: server.endpoint,
          deviceId: 'test-device',
          contextReader: () => const RefusionMcpCloudContextState(
            projectId: 'project-1',
            compositionId: 'composition-1',
            workspaceId: 'workspace-1',
            playheadMs: 1600,
            timelineRevision: 6,
            foreground: true,
          ),
          onSnapshot: snapshots.add,
          interval: const Duration(seconds: 60),
          connectTimeout: const Duration(seconds: 8),
        );
        addTearDown(bridge.stop);

        await bridge.syncNow();

        expect(snapshots, isNotEmpty);
        final firstSnapshot = snapshots.first;
        expect(firstSnapshot.projectId, 'project-1');
        expect(firstSnapshot.compositionId, 'composition-1');
        expect(firstSnapshot.remoteLayers, isNotEmpty);
      },
    );

    test(
      'blank local context bootstraps from remote active context without editor sync',
      () async {
        final server = await _FakeMcpServer.start(
          diagnosticsDelay: const Duration(milliseconds: 20),
        );
        addTearDown(server.close);

        final snapshots = <RefusionMcpCloudBridgeSnapshot>[];
        final bridge = RefusionMcpCloudBridge(
          endpoint: server.endpoint,
          deviceId: 'test-device',
          contextReader: () => const RefusionMcpCloudContextState(
            projectId: '',
            compositionId: '',
            playheadMs: 0,
            timelineRevision: 1,
            foreground: true,
          ),
          onSnapshot: snapshots.add,
          interval: const Duration(seconds: 60),
          connectTimeout: const Duration(seconds: 2),
        );
        addTearDown(bridge.stop);

        await bridge.syncNow();

        expect(server.callCount('sync_editor_layers'), 0);
        expect(server.callCount('get_layers'), greaterThan(0));
        expect(snapshots, isNotEmpty);
        expect(snapshots.first.projectId, 'project-1');
        expect(snapshots.first.compositionId, 'composition-1');
        expect(snapshots.first.remoteLayers, isNotEmpty);
        expect(snapshots.first.canvasMetadata['width'], 1080);
        expect(snapshots.first.canvasMetadata['height'], 1920);
      },
    );

    test(
      'placeholder local context fails closed and bootstraps from remote context',
      () async {
        final server = await _FakeMcpServer.start(
          diagnosticsDelay: const Duration(milliseconds: 20),
        );
        addTearDown(server.close);

        final snapshots = <RefusionMcpCloudBridgeSnapshot>[];
        final bridge = RefusionMcpCloudBridge(
          endpoint: server.endpoint,
          deviceId: 'test-device',
          contextReader: () => const RefusionMcpCloudContextState(
            projectId: 'active',
            compositionId: 'comp_1',
            playheadMs: 0,
            timelineRevision: 1,
            foreground: true,
          ),
          onSnapshot: snapshots.add,
          interval: const Duration(seconds: 60),
          connectTimeout: const Duration(seconds: 2),
        );
        addTearDown(bridge.stop);

        await bridge.syncNow();

        expect(server.callCount('sync_editor_layers'), 0);
        expect(server.callCount('get_layers'), greaterThan(0));
        expect(snapshots, isNotEmpty);
        expect(snapshots.first.projectId, 'project-1');
        expect(snapshots.first.compositionId, 'composition-1');
      },
    );

    test(
      'blank local context ignores stale offline remote active context',
      () async {
        final server = await _FakeMcpServer.start(
          diagnosticsDelay: const Duration(milliseconds: 20),
          liveOnline: false,
        );
        addTearDown(server.close);

        final snapshots = <RefusionMcpCloudBridgeSnapshot>[];
        final bridge = RefusionMcpCloudBridge(
          endpoint: server.endpoint,
          deviceId: 'test-device',
          contextReader: () => const RefusionMcpCloudContextState(
            projectId: '',
            compositionId: '',
            playheadMs: 0,
            timelineRevision: 1,
            foreground: true,
          ),
          onSnapshot: snapshots.add,
          interval: const Duration(seconds: 60),
          connectTimeout: const Duration(seconds: 2),
        );
        addTearDown(bridge.stop);

        await bridge.syncNow();

        expect(server.callCount('get_layers'), 0);
        expect(server.callCount('sync_editor_layers'), 0);
        expect(snapshots, isNotEmpty);
        expect(snapshots.first.projectId, isEmpty);
        expect(snapshots.first.compositionId, isEmpty);
        expect(snapshots.first.remoteLayers, isEmpty);
      },
    );

    test(
      'project/composition without workspaceId fail closed as inactive context',
      () async {
        final server = await _FakeMcpServer.start(
          diagnosticsDelay: const Duration(milliseconds: 20),
        );
        addTearDown(server.close);

        final bridge = RefusionMcpCloudBridge(
          endpoint: server.endpoint,
          deviceId: 'test-device',
          contextReader: () => const RefusionMcpCloudContextState(
            projectId: 'project-1',
            compositionId: 'composition-1',
            playheadMs: 0,
            timelineRevision: 1,
            foreground: true,
          ),
          onSnapshot: (_) {},
          interval: const Duration(seconds: 60),
          connectTimeout: const Duration(seconds: 2),
        );
        addTearDown(bridge.stop);

        await bridge.syncNow();

        final touchArgs = server.lastArgs('touch_editor_session');
        final contextArgs = server.lastArgs('set_active_context');
        expect(touchArgs?['hasActiveComposition'], isFalse);
        expect(contextArgs?['hasActiveComposition'], isFalse);
        expect(server.callCount('sync_editor_layers'), 0);
      },
    );

    test(
      'active context publishes workspaceId when identity is valid',
      () async {
        final server = await _FakeMcpServer.start(
          diagnosticsDelay: const Duration(milliseconds: 20),
        );
        addTearDown(server.close);

        final bridge = RefusionMcpCloudBridge(
          endpoint: server.endpoint,
          deviceId: 'test-device',
          contextReader: () => const RefusionMcpCloudContextState(
            projectId: 'project-1',
            compositionId: 'composition-1',
            workspaceId: 'workspace-1',
            playheadMs: 1200,
            timelineRevision: 2,
            foreground: true,
          ),
          onSnapshot: (_) {},
          interval: const Duration(seconds: 60),
          connectTimeout: const Duration(seconds: 2),
        );
        addTearDown(bridge.stop);

        await bridge.syncNow();

        final touchArgs = server.lastArgs('touch_editor_session');
        final contextArgs = server.lastArgs('set_active_context');
        expect(touchArgs?['hasActiveComposition'], isTrue);
        expect(contextArgs?['hasActiveComposition'], isTrue);
        expect(touchArgs?['workspaceId'], 'workspace-1');
        expect(contextArgs?['workspaceId'], 'workspace-1');
      },
    );
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
    required this.contextDelay,
    required this.pendingCommandsDelay,
    required this.activeProjectId,
    required this.activeCompositionId,
    required this.liveOnline,
    required this.includePendingCommand,
    required this.scopedPendingEmptyButUnscopedHasCommand,
  });

  final HttpServer server;
  final Uri endpoint;
  final Duration diagnosticsDelay;
  final Duration contextDelay;
  final Duration pendingCommandsDelay;
  final String activeProjectId;
  final String activeCompositionId;
  final bool liveOnline;
  final bool includePendingCommand;
  final bool scopedPendingEmptyButUnscopedHasCommand;
  final Map<String, int> _counts = <String, int>{};
  final Map<String, Map<String, Object?>> _lastArgsByTool =
      <String, Map<String, Object?>>{};

  static Future<_FakeMcpServer> start({
    required Duration diagnosticsDelay,
    Duration contextDelay = Duration.zero,
    Duration pendingCommandsDelay = Duration.zero,
    String activeProjectId = 'project-1',
    String activeCompositionId = 'composition-1',
    bool liveOnline = true,
    bool includePendingCommand = false,
    bool scopedPendingEmptyButUnscopedHasCommand = false,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final endpoint = Uri.parse(
      'http://${server.address.address}:${server.port}/mcp',
    );
    final fake = _FakeMcpServer._(
      server: server,
      endpoint: endpoint,
      diagnosticsDelay: diagnosticsDelay,
      contextDelay: contextDelay,
      pendingCommandsDelay: pendingCommandsDelay,
      activeProjectId: activeProjectId,
      activeCompositionId: activeCompositionId,
      liveOnline: liveOnline,
      includePendingCommand: includePendingCommand,
      scopedPendingEmptyButUnscopedHasCommand:
          scopedPendingEmptyButUnscopedHasCommand,
    );
    fake._serve();
    return fake;
  }

  int callCount(String toolName) => _counts[toolName] ?? 0;

  Map<String, Object?>? lastArgs(String toolName) => _lastArgsByTool[toolName];

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
        if (toolName == 'get_active_context' && contextDelay > Duration.zero) {
          await Future<void>.delayed(contextDelay);
        }
        if (toolName == 'get_pending_commands' &&
            pendingCommandsDelay > Duration.zero) {
          await Future<void>.delayed(pendingCommandsDelay);
        }

        final args = (params['arguments'] as Map<String, Object?>?) ??
            const <String, Object?>{};
        _lastArgsByTool[toolName] = Map<String, Object?>.unmodifiable(args);
        final payload = _payloadForTool(toolName, args: args);
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

  Map<String, Object?> _payloadForTool(
    String toolName, {
    Map<String, Object?> args = const <String, Object?>{},
  }) {
    switch (toolName) {
      case 'get_active_context':
        return <String, Object?>{
          'project': <String, Object?>{'id': activeProjectId, 'revision': 3},
          'composition': <String, Object?>{
            'id': activeCompositionId,
            'aspect': 'story',
            'width': 1080,
            'height': 1920,
            'durationMs': 8000,
            'fps': 30,
          },
          'liveEditor': <String, Object?>{
            'online': liveOnline,
            'sessionId': 'session-1',
          },
        };
      case 'get_pending_commands':
        if (scopedPendingEmptyButUnscopedHasCommand) {
          final hasScopedSession = args['editorSessionId'] != null;
          if (hasScopedSession) {
            return const <String, Object?>{
              'commands': <Map<String, Object?>>[],
            };
          }
          return const <String, Object?>{
            'commands': <Map<String, Object?>>[
              <String, Object?>{
                'id': 'cmd-unscoped-1',
                'command_type': 'refusion.insert_layer',
                'revision_after': 4,
                'status': 'running',
                'payload': <String, Object?>{
                  'kind': 'text',
                  'payload': <String, Object?>{
                    'text': 'hello',
                  },
                },
              },
            ],
          };
        }
        return <String, Object?>{
          'commands': includePendingCommand
              ? const <Map<String, Object?>>[
                  <String, Object?>{
                    'id': 'cmd-1',
                    'command_type': 'refusion.insert_layer',
                    'revision_after': 3,
                    'status': 'running',
                    'payload': <String, Object?>{
                      'layerId': 'solid-layer-1',
                      'layerKind': 'solid',
                      'payload': <String, Object?>{
                        'color': '#FFFFFF',
                      },
                    },
                  },
                ]
              : const <Map<String, Object?>>[],
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
