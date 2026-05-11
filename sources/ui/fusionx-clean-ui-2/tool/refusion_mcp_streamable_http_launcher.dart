import 'dart:async';
import 'dart:io';

import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_agent_control_plane.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_command_bus.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_command.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_hardening_policy.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_resource_provider.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_session_store.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_tool_registry.dart';
import 'package:refusion_app/features/editor/presentation/mcp/refusion_mcp_app_bridge.dart';
import 'package:refusion_app/features/editor/presentation/mcp/refusion_mcp_json_rpc_server.dart';
import 'package:refusion_app/features/editor/presentation/mcp/refusion_mcp_streamable_http_server.dart';

Future<void> main(List<String> args) async {
  final options = _parseArgs(args);

  final bus = RefusionMcpCommandBus();
  bus.registerHandler(
    commandType: 'refusion.get_project_state',
    handler: (_) {
      return RefusionMcpCommandHandlingOutcome(
        summary: 'Project state loaded.',
        payload: <String, Object?>{
          'projectId': 'active',
          'revision': 1,
        },
      );
    },
  );
  bus.registerHandler(
    commandType: 'refusion.get_timeline_summary',
    handler: (_) {
      return RefusionMcpCommandHandlingOutcome(
        summary: 'Timeline summary loaded.',
        payload: <String, Object?>{
          'rowCount': 0,
          'durationMs': 0,
        },
      );
    },
  );
  bus.registerHandler(
    commandType: 'refusion.get_selection',
    handler: (_) {
      return RefusionMcpCommandHandlingOutcome(
        summary: 'Selection loaded.',
        payload: <String, Object?>{
          'selected': const <String>[],
        },
      );
    },
  );
  bus.registerHandler(
    commandType: 'refusion.capture_preview_frame',
    handler: (context) {
      final timeMs = context.command.payload['timeMs'];
      return RefusionMcpCommandHandlingOutcome(
        summary: 'Preview frame captured.',
        payload: <String, Object?>{
          'resourceUri': 'refusion://preview/frame/${timeMs ?? 0}',
          'timeMs': timeMs ?? 0,
        },
        resourceUris: <String>['refusion://preview/frame/${timeMs ?? 0}'],
      );
    },
  );
  bus.registerHandler(
    commandType: 'refusion.get_security_profile',
    handler: (_) {
      return RefusionMcpCommandHandlingOutcome(
        summary: 'Security profile loaded.',
        payload: <String, Object?>{
          'pairing': <String, Object?>{
            'required': options.pairingToken != null,
          },
          'limits': <String, Object?>{
            'maxToolPayloadBytes': 65536,
            'maxCallsPerMinutePerSession': 120,
          },
          'restrictedCapabilities': const <String>[
            'filesystem.read',
            'filesystem.write',
            'export.start',
            'debug.diagnostics',
          ],
        },
      );
    },
  );
  bus.registerHandler(
    commandType: 'refusion.get_host_compatibility',
    handler: (_) {
      return RefusionMcpCommandHandlingOutcome(
        summary: 'Host compatibility profile loaded.',
        payload: <String, Object?>{
          'claude': <String, Object?>{
            'supported': true,
            'transport': 'stdio',
          },
          'codex': <String, Object?>{
            'supported': true,
            'transport': 'stdio',
          },
          'chatgpt': <String, Object?>{
            'supported': true,
            'requiresRemoteDomain': true,
            'requiredTransport': 'streamable-http',
            'domainSetupPath': 'Settings > Apps',
          },
        },
      );
    },
  );

  final sessionStore = RefusionMcpSessionStore();
  final resourceProvider = RefusionMcpResourceProvider(
    readers: <String, RefusionMcpResourceReader>{
      'refusion://project/active/state': () => <String, Object?>{
            'projectId': 'active',
            'revision': 1,
          },
      'refusion://timeline/summary': () => <String, Object?>{
            'rowCount': 0,
            'durationMs': 0,
          },
      'refusion://selection/current': () => <String, Object?>{
            'selected': const <String>[],
          },
    },
  );

  final toolRegistry = RefusionMcpToolRegistry();
  final controlPlane = RefusionMcpAgentControlPlane(
    commandBus: bus,
    toolRegistry: toolRegistry,
    sessionStore: sessionStore,
    revisionReader: () => 1,
  );
  final bridge = RefusionMcpAppBridge(
    controlPlane: controlPlane,
    sessionStore: sessionStore,
    resourceProvider: resourceProvider,
    hardeningPolicy: RefusionMcpHardeningPolicy(
      requiredPairingToken: options.pairingToken,
    ),
  );
  final jsonRpc = RefusionMcpJsonRpcServer(
    bridge: bridge,
    toolRegistry: toolRegistry,
  );
  final server = RefusionMcpStreamableHttpServer(
    jsonRpcServer: jsonRpc,
    endpointPath: options.path,
  );

  final address = options.host == '0.0.0.0'
      ? InternetAddress.anyIPv4
      : InternetAddress(options.host);
  final bound = await server.start(address: address, port: options.port);
  stdout.writeln(
      'refusion-mcp-http listening on http://${options.host}:${bound.port}${options.path}');
  stdout.writeln('tip: use tunnel for ChatGPT (public HTTPS required).');

  final done = Completer<void>();
  ProcessSignal.sigint.watch().listen((_) async {
    if (!done.isCompleted) {
      stdout.writeln('shutting down...');
      await server.stop(force: true);
      done.complete();
    }
  });
  await done.future;
}

class _LauncherOptions {
  const _LauncherOptions({
    required this.host,
    required this.port,
    required this.path,
    required this.pairingToken,
  });

  final String host;
  final int port;
  final String path;
  final String? pairingToken;
}

_LauncherOptions _parseArgs(List<String> args) {
  var host = '0.0.0.0';
  var port = 8787;
  var path = '/mcp';
  String? pairingToken = Platform.environment['REFUSION_MCP_PAIRING_TOKEN'];

  for (var index = 0; index < args.length; index += 1) {
    final value = args[index];
    if (value == '--host' && index + 1 < args.length) {
      host = args[++index];
      continue;
    }
    if (value == '--port' && index + 1 < args.length) {
      port = int.tryParse(args[++index]) ?? port;
      continue;
    }
    if (value == '--path' && index + 1 < args.length) {
      final raw = args[++index];
      path = raw.startsWith('/') ? raw : '/$raw';
      continue;
    }
    if (value == '--pairing-token' && index + 1 < args.length) {
      pairingToken = args[++index];
      continue;
    }
  }
  return _LauncherOptions(
    host: host,
    port: port,
    path: path,
    pairingToken: pairingToken,
  );
}
