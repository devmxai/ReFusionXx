import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/timeline_time.dart';

class RefusionMcpCloudContextState {
  const RefusionMcpCloudContextState({
    required this.projectId,
    required this.compositionId,
    required this.playheadMs,
    required this.foreground,
    this.timelineId = 'main',
  });

  final String projectId;
  final String compositionId;
  final int playheadMs;
  final bool foreground;
  final String timelineId;
}

class RefusionMcpCloudBridgeSnapshot {
  const RefusionMcpCloudBridgeSnapshot({
    required this.ok,
    required this.projectId,
    required this.compositionId,
    required this.revision,
    required this.liveOnline,
    required this.updatedAtUtc,
    this.error,
  });

  final bool ok;
  final String? projectId;
  final String? compositionId;
  final int? revision;
  final bool liveOnline;
  final DateTime updatedAtUtc;
  final String? error;
}

typedef RefusionMcpCloudContextReader = RefusionMcpCloudContextState Function();
typedef RefusionMcpCloudSnapshotListener = void Function(
  RefusionMcpCloudBridgeSnapshot snapshot,
);

class RefusionMcpCloudBridge {
  RefusionMcpCloudBridge({
    required Uri endpoint,
    required String deviceId,
    required RefusionMcpCloudContextReader contextReader,
    required RefusionMcpCloudSnapshotListener onSnapshot,
    HttpClient? httpClient,
    this.interval = const Duration(seconds: 8),
    this.connectTimeout = const Duration(seconds: 8),
  })  : _endpoint = endpoint,
        _deviceId = deviceId,
        _contextReader = contextReader,
        _onSnapshot = onSnapshot,
        _httpClient = httpClient ?? HttpClient();

  final Uri _endpoint;
  final String _deviceId;
  final RefusionMcpCloudContextReader _contextReader;
  final RefusionMcpCloudSnapshotListener _onSnapshot;
  final HttpClient _httpClient;
  final Duration interval;
  final Duration connectTimeout;

  Timer? _timer;
  bool _foreground = true;
  int _requestIdSeed = 1;
  bool _syncInFlight = false;

  bool get isRunning => _timer != null;

  Future<void> start() async {
    if (_timer != null) {
      return;
    }
    _timer = Timer.periodic(interval, (_) {
      unawaited(syncNow());
    });
    await syncNow();
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _httpClient.close(force: true);
  }

  Future<void> setForeground(bool value) async {
    _foreground = value;
    await syncNow();
  }

  Future<void> syncNow() async {
    if (_syncInFlight) {
      return;
    }
    _syncInFlight = true;
    try {
      final state = _contextReader();
      final status = _foreground && state.foreground ? 'online' : 'background';
      await _callTool(
        toolName: 'touch_editor_session',
        arguments: <String, Object?>{
          'deviceId': _deviceId,
          'projectId': state.projectId,
          'compositionId': state.compositionId,
          'foreground': _foreground && state.foreground,
          'status': status,
          'platform': 'flutter',
        },
      );
      await _callTool(
        toolName: 'set_active_context',
        arguments: <String, Object?>{
          'deviceId': _deviceId,
          'projectId': state.projectId,
          'compositionId': state.compositionId,
          'timelineId': state.timelineId,
          'playheadMs': state.playheadMs,
          'foreground': _foreground && state.foreground,
          'status': status,
          'platform': 'flutter',
          'appVersion': 'refusion-app',
        },
      );
      final contextResponse = await _callTool(
        toolName: 'get_active_context',
        arguments: const <String, Object?>{},
      );
      _emitSnapshot(
        _snapshotFromContextResponse(
          contextResponse,
          fallbackProjectId: state.projectId,
          fallbackCompositionId: state.compositionId,
        ),
      );
    } catch (error) {
      _emitSnapshot(
        RefusionMcpCloudBridgeSnapshot(
          ok: false,
          projectId: null,
          compositionId: null,
          revision: null,
          liveOnline: false,
          updatedAtUtc: DateTime.now().toUtc(),
          error: error.toString(),
        ),
      );
    } finally {
      _syncInFlight = false;
    }
  }

  RefusionMcpCloudBridgeSnapshot _snapshotFromContextResponse(
    Map<String, Object?> rpcResult, {
    required String fallbackProjectId,
    required String fallbackCompositionId,
  }) {
    final structured = _asMap(rpcResult['structuredContent']);
    final payload = _asMap(structured['payload']);
    final project = _asMap(payload['project']);
    final composition = _asMap(payload['composition']);
    final liveEditor = _asMap(payload['liveEditor']);
    return RefusionMcpCloudBridgeSnapshot(
      ok: structured['ok'] == true,
      projectId: _asString(project['id']) ?? fallbackProjectId,
      compositionId: _asString(composition['id']) ?? fallbackCompositionId,
      revision: _asInt(project['revision']),
      liveOnline: liveEditor['online'] == true,
      updatedAtUtc: DateTime.now().toUtc(),
      error: structured['ok'] == true ? null : _asString(structured['summary']),
    );
  }

  Future<Map<String, Object?>> _callTool({
    required String toolName,
    required Map<String, Object?> arguments,
  }) async {
    final requestBody = <String, Object?>{
      'jsonrpc': '2.0',
      'id': _nextRequestId(),
      'method': 'tools/call',
      'params': <String, Object?>{
        'name': toolName,
        'arguments': arguments,
      },
    };
    final response = await _postJson(requestBody);
    final error = _asMap(response['error']);
    if (error.isNotEmpty) {
      throw StateError(
        'MCP RPC error ${error['code']}: ${error['message']}',
      );
    }
    final result = _asMap(response['result']);
    final isError = result['isError'] == true;
    if (isError) {
      final structured = _asMap(result['structuredContent']);
      final summary = _asString(structured['summary']) ?? 'Tool call failed.';
      throw StateError(summary);
    }
    return result;
  }

  Future<Map<String, Object?>> _postJson(Map<String, Object?> body) async {
    final request = await _httpClient
        .postUrl(_endpoint)
        .timeout(connectTimeout);
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(body));
    final response = await request.close().timeout(connectTimeout);
    final responseBody = await utf8.decoder.bind(response).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'HTTP ${response.statusCode}: ${response.reasonPhrase}',
      );
    }
    if (responseBody.trim().isEmpty) {
      throw StateError('Empty MCP response payload.');
    }
    final decoded = jsonDecode(responseBody);
    if (decoded is! Map) {
      throw StateError('Invalid MCP response payload.');
    }
    return _asMap(decoded);
  }

  int _nextRequestId() {
    final id = _requestIdSeed;
    _requestIdSeed += 1;
    return id;
  }

  void _emitSnapshot(RefusionMcpCloudBridgeSnapshot snapshot) {
    _onSnapshot(snapshot);
  }
}

Map<String, Object?> _asMap(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    final mapped = <String, Object?>{};
    for (final entry in value.entries) {
      if (entry.key is String) {
        mapped[entry.key as String] = entry.value;
      }
    }
    return mapped;
  }
  return const <String, Object?>{};
}

String? _asString(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

int? _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  return null;
}

String refusionMcpCloudDeviceId() {
  final seed = DateTime.now().millisecondsSinceEpoch;
  return 'flutter-device-$seed';
}

Uri? refusionMcpCloudEndpointFromEnvironment() {
  const fallbackEndpoint =
      'https://wygydvczsgnocihbihje.supabase.co/functions/v1/mcp';
  const endpointValue = String.fromEnvironment(
    'REFUSION_MCP_REMOTE_URL',
    defaultValue: fallbackEndpoint,
  );
  if (endpointValue.trim().isEmpty) {
    return null;
  }
  return Uri.tryParse(endpointValue.trim());
}

int refusionMcpPlayheadMs(TimelineTime value) => value.inMilliseconds;
