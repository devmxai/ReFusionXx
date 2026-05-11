import 'dart:async';
import 'dart:io';

import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_agent_control_plane.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_command_bus.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_command.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_hardening_policy.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_resource_provider.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_session_store.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_tool_registry.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_transaction.dart';
import 'package:refusion_app/features/editor/presentation/mcp/refusion_mcp_app_bridge.dart';
import 'package:refusion_app/features/editor/presentation/mcp/refusion_mcp_json_rpc_server.dart';
import 'package:refusion_app/features/editor/presentation/mcp/refusion_mcp_streamable_http_server.dart';

Future<void> main(List<String> args) async {
  final options = _parseArgs(args);
  final runtime = _MockMcpRuntimeState();

  final bus = RefusionMcpCommandBus();
  bus.registerHandler(
    commandType: 'refusion.get_project_state',
    handler: (_) {
      return RefusionMcpCommandHandlingOutcome(
        summary: 'Project state loaded.',
        payload: runtime.projectStatePayload(),
      );
    },
  );
  bus.registerHandler(
    commandType: 'refusion.get_timeline_summary',
    handler: (_) {
      return RefusionMcpCommandHandlingOutcome(
        summary: 'Timeline summary loaded.',
        payload: runtime.timelineSummaryPayload(),
      );
    },
  );
  bus.registerHandler(
    commandType: 'refusion.get_selection',
    handler: (_) {
      return RefusionMcpCommandHandlingOutcome(
        summary: 'Selection loaded.',
        payload: runtime.selectionPayload(),
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
          'revision': runtime.revision,
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
  bus.registerHandler(
    commandType: 'refusion.insert_layer',
    handler: (context) {
      final payload = context.command.payload;
      final layer = runtime.previewLayer(
        kind: (payload['layerKind'] as String?) ?? 'solid',
        name: (payload['name'] as String?)?.trim(),
        startMs: _readInt(payload['startMs']) ?? 0,
        durationMs: _readInt(payload['durationMs']) ?? 3000,
        colorHex: _readColorHex(payload),
      );
      return RefusionMcpCommandHandlingOutcome(
        summary: 'Layer insert is ready to commit.',
        patchPreview: RefusionMcpPatchPreview(
          affectedObjects: <String>[layer['id'] as String],
          changedProperties: const <String>['layers', 'timeline', 'revision'],
          diagnostics: const <String>[],
        ),
        commitOperation: () {
          runtime.insertLayer(layer);
          return RefusionMcpCommitExecution(
            revisionAfter: runtime.revision,
            summary: 'Layer inserted (${layer['kind']}).',
          );
        },
        payload: <String, Object?>{
          'layer': layer,
          'previewTimeline': runtime.timelineSummaryPayload(),
        },
      );
    },
  );
  bus.registerHandler(
    commandType: 'refusion.apply_scene_program',
    handler: (context) {
      final source = context.command.payload['source'] as String?;
      final inferredColor = runtime.inferSolidColorFromSource(source);
      final layer = runtime.previewLayer(
        kind: 'solid',
        name: 'Scene Background',
        startMs: 0,
        durationMs: 3000,
        colorHex: inferredColor ?? '#FFFFFF',
      );
      return RefusionMcpCommandHandlingOutcome(
        summary: 'Scene program apply is ready to commit.',
        patchPreview: RefusionMcpPatchPreview(
          affectedObjects: <String>[layer['id'] as String],
          changedProperties: const <String>[
            'sceneProgram',
            'layers',
            'revision'
          ],
          diagnostics: const <String>[],
        ),
        commitOperation: () {
          runtime.insertLayer(layer);
          runtime.lastAppliedSource = source;
          return RefusionMcpCommitExecution(
            revisionAfter: runtime.revision,
            summary: 'Scene program applied in mock runtime.',
          );
        },
        payload: <String, Object?>{
          'isMockRuntime': true,
          'previewTimeline': runtime.timelineSummaryPayload(),
        },
      );
    },
  );
  bus.registerHandler(
    commandType: 'refusion.apply_motion_patch',
    handler: (_) => runtime.noopMutationOutcome('Motion patch'),
  );
  bus.registerHandler(
    commandType: 'refusion.keyframe_edit',
    handler: (_) => runtime.noopMutationOutcome('Keyframe edit'),
  );
  bus.registerHandler(
    commandType: 'refusion.set_element_transform',
    handler: (_) => runtime.noopMutationOutcome('Element transform'),
  );
  bus.registerHandler(
    commandType: 'refusion.split_at_playhead',
    handler: (_) => runtime.noopMutationOutcome('Split at playhead'),
  );
  bus.registerHandler(
    commandType: 'refusion.trim_layer',
    handler: (_) => runtime.noopMutationOutcome('Trim layer'),
  );
  bus.registerHandler(
    commandType: 'refusion.move_layer',
    handler: (_) => runtime.noopMutationOutcome('Move layer'),
  );
  bus.registerHandler(
    commandType: 'refusion.delete_layer',
    handler: (_) => runtime.noopMutationOutcome('Delete layer'),
  );

  final sessionStore = RefusionMcpSessionStore();
  final resourceProvider = RefusionMcpResourceProvider(
    readers: <String, RefusionMcpResourceReader>{
      'refusion://project/active/state': runtime.projectStatePayload,
      'refusion://timeline/summary': runtime.timelineSummaryPayload,
      'refusion://selection/current': runtime.selectionPayload,
    },
  );

  final toolRegistry = RefusionMcpToolRegistry();
  final controlPlane = RefusionMcpAgentControlPlane(
    commandBus: bus,
    toolRegistry: toolRegistry,
    sessionStore: sessionStore,
    revisionReader: () => runtime.revision,
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

class _MockMcpRuntimeState {
  int revision = 1;
  final List<Map<String, Object?>> _layers = <Map<String, Object?>>[];
  String? lastAppliedSource;

  Map<String, Object?> projectStatePayload() {
    return <String, Object?>{
      'projectId': 'active',
      'revision': revision,
      'layerCount': _layers.length,
      if (lastAppliedSource != null) 'lastAppliedSource': lastAppliedSource,
    };
  }

  Map<String, Object?> timelineSummaryPayload() {
    return <String, Object?>{
      'rowCount': _layers.length,
      'durationMs': _timelineDurationMs(),
      'layers': _layers.map((layer) => Map<String, Object?>.from(layer)).toList(
            growable: false,
          ),
    };
  }

  Map<String, Object?> selectionPayload() {
    final selected = _layers.isEmpty
        ? const <String>[]
        : <String>[_layers.last['id'] as String];
    return <String, Object?>{
      'selected': selected,
    };
  }

  Map<String, Object?> previewLayer({
    required String kind,
    required int startMs,
    required int durationMs,
    String? name,
    String? colorHex,
  }) {
    final sanitizedDuration = durationMs <= 0 ? 3000 : durationMs;
    return <String, Object?>{
      'id': 'layer_${_layers.length + 1}',
      'kind': kind,
      'name':
          (name == null || name.isEmpty) ? 'Layer ${_layers.length + 1}' : name,
      'startMs': startMs < 0 ? 0 : startMs,
      'durationMs': sanitizedDuration,
      if (colorHex != null) 'color': colorHex,
    };
  }

  RefusionMcpCommandHandlingOutcome noopMutationOutcome(String label) {
    return RefusionMcpCommandHandlingOutcome(
      summary: '$label is ready to commit.',
      patchPreview: RefusionMcpPatchPreview(
        affectedObjects: const <String>['timeline'],
        changedProperties: const <String>['revision'],
      ),
      commitOperation: () {
        revision += 1;
        return RefusionMcpCommitExecution(
          revisionAfter: revision,
          summary: '$label committed in mock runtime.',
        );
      },
      payload: <String, Object?>{
        'isMockRuntime': true,
      },
    );
  }

  void insertLayer(Map<String, Object?> layer) {
    _layers.add(Map<String, Object?>.from(layer));
    revision += 1;
  }

  String? inferSolidColorFromSource(String? source) {
    if (source == null || source.isEmpty) {
      return null;
    }
    final upper = source.toUpperCase();
    final hashIndex = upper.indexOf('#');
    if (hashIndex < 0) {
      return null;
    }
    final end = (hashIndex + 7 <= upper.length) ? hashIndex + 7 : upper.length;
    final candidate = upper.substring(hashIndex, end);
    final valid = RegExp(r'^#[0-9A-F]{6}$').hasMatch(candidate);
    return valid ? candidate : null;
  }

  int _timelineDurationMs() {
    if (_layers.isEmpty) {
      return 0;
    }
    var maxEnd = 0;
    for (final layer in _layers) {
      final start = layer['startMs'] is int ? layer['startMs'] as int : 0;
      final duration =
          layer['durationMs'] is int ? layer['durationMs'] as int : 0;
      final end = start + duration;
      if (end > maxEnd) {
        maxEnd = end;
      }
    }
    return maxEnd;
  }
}

String? _readColorHex(Map<String, Object?> payload) {
  final directColor = payload['color'];
  if (directColor is String &&
      RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(directColor)) {
    return directColor.toUpperCase();
  }
  final style = payload['style'];
  if (style is Map) {
    final color = style['color'];
    if (color is String && RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(color)) {
      return color.toUpperCase();
    }
  }
  return null;
}

int? _readInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  return null;
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
