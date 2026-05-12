import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

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
    this.remoteRevision,
    this.latestSolidColorHex,
    this.error,
  });

  final bool ok;
  final String? projectId;
  final String? compositionId;
  final int? revision;
  final bool liveOnline;
  final DateTime updatedAtUtc;
  final int? remoteRevision;
  final String? latestSolidColorHex;
  final String? error;
}

class RefusionMcpCloudPairingCode {
  const RefusionMcpCloudPairingCode({
    required this.code,
    required this.expiresAtUtc,
    required this.qrData,
    required this.link,
    required this.projectId,
    required this.compositionId,
    required this.timelineId,
    required this.playheadMs,
    required this.timelineRevision,
    required this.deviceId,
  });

  final String code;
  final DateTime expiresAtUtc;
  final String qrData;
  final String link;
  final String projectId;
  final String compositionId;
  final String timelineId;
  final int playheadMs;
  final int timelineRevision;
  final String deviceId;
}

class RefusionMcpCloudAgentSessionAttachment {
  const RefusionMcpCloudAgentSessionAttachment({
    required this.agentSessionToken,
    required this.agentSessionId,
    required this.projectId,
    required this.compositionId,
    required this.timelineId,
    required this.playheadMs,
    required this.timelineRevision,
    required this.capabilities,
    required this.expiresAtUtc,
  });

  final String agentSessionToken;
  final String agentSessionId;
  final String projectId;
  final String compositionId;
  final String timelineId;
  final int playheadMs;
  final int timelineRevision;
  final List<String> capabilities;
  final DateTime expiresAtUtc;
}

class RefusionMcpCloudPairingCodeStatus {
  const RefusionMcpCloudPairingCodeStatus({
    required this.code,
    required this.exists,
    required this.status,
    required this.secondsRemaining,
    this.claimedByAgent,
    this.claimedAtUtc,
    this.expiresAtUtc,
  });

  final String code;
  final bool exists;
  final String status;
  final int secondsRemaining;
  final String? claimedByAgent;
  final DateTime? claimedAtUtc;
  final DateTime? expiresAtUtc;

  bool get isClaimed => status == 'claimed';
  bool get isTerminal =>
      status == 'claimed' || status == 'expired' || status == 'revoked';
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
    this.authBearerToken,
    String? agentSessionToken,
    HttpClient? httpClient,
    this.interval = const Duration(seconds: 8),
    this.connectTimeout = const Duration(seconds: 8),
  })  : _endpoint = endpoint,
        _deviceId = deviceId,
        _contextReader = contextReader,
        _onSnapshot = onSnapshot,
        _agentSessionToken = agentSessionToken,
        _httpClient = httpClient ?? HttpClient();

  final Uri _endpoint;
  final String _deviceId;
  final RefusionMcpCloudContextReader _contextReader;
  final RefusionMcpCloudSnapshotListener _onSnapshot;
  final HttpClient _httpClient;
  final String? authBearerToken;
  final Duration interval;
  final Duration connectTimeout;

  Timer? _timer;
  bool _foreground = true;
  int _requestIdSeed = 1;
  bool _syncInFlight = false;
  String? _agentSessionToken;

  bool get isRunning => _timer != null;
  String? get agentSessionToken => _agentSessionToken;

  void setAgentSessionToken(String token) {
    final normalized = token.trim();
    _agentSessionToken = normalized.isEmpty ? null : normalized;
  }

  void clearAgentSessionToken() {
    _agentSessionToken = null;
  }

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
      final projectIdArg =
          _isUuidLike(state.projectId) ? state.projectId : null;
      final compositionIdArg =
          _isUuidLike(state.compositionId) ? state.compositionId : null;
      await _callTool(
        toolName: 'touch_editor_session',
        arguments: <String, Object?>{
          'deviceId': _deviceId,
          if (projectIdArg != null) 'projectId': projectIdArg,
          if (compositionIdArg != null) 'compositionId': compositionIdArg,
          'foreground': _foreground && state.foreground,
          'status': status,
          'platform': 'flutter',
        },
      );
      await _callTool(
        toolName: 'set_active_context',
        arguments: <String, Object?>{
          'deviceId': _deviceId,
          if (projectIdArg != null) 'projectId': projectIdArg,
          if (compositionIdArg != null) 'compositionId': compositionIdArg,
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
        allowAgentSessionToken: true,
      );
      final contextStructured = _asMap(contextResponse['structuredContent']);
      final contextPayload = _asMap(contextStructured['payload']);
      final contextProject = _asMap(contextPayload['project']);
      final contextComposition = _asMap(contextPayload['composition']);
      final cloudProjectId = _asString(contextProject['id']);
      final cloudCompositionId = _asString(contextComposition['id']);
      final layersResponse = await _safeCallTool(
        toolName: 'get_layers',
        arguments: <String, Object?>{
          if (cloudProjectId != null) 'projectId': cloudProjectId,
          if (cloudCompositionId != null) 'compositionId': cloudCompositionId,
        },
        allowAgentSessionToken: true,
      );
      _emitSnapshot(
        _snapshotFromContextResponse(
          contextResponse,
          layersResult: layersResponse,
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
    required Map<String, Object?>? layersResult,
    required String fallbackProjectId,
    required String fallbackCompositionId,
  }) {
    final structured = _asMap(rpcResult['structuredContent']);
    final payload = _asMap(structured['payload']);
    final project = _asMap(payload['project']);
    final composition = _asMap(payload['composition']);
    final liveEditor = _asMap(payload['liveEditor']);
    int? remoteRevision;
    String? latestSolidColorHex;
    if (layersResult != null) {
      final layersStructured = _asMap(layersResult['structuredContent']);
      final layersPayload = _asMap(layersStructured['payload']);
      remoteRevision = _asInt(layersPayload['revision']);
      final layers = _asListOfMap(layersPayload['layers']);
      for (final layer in layers.reversed) {
        if (_asString(layer['layer_kind']) != 'solid') {
          continue;
        }
        final payload = _asMap(layer['payload']);
        final color = _asString(payload['color']);
        if (color != null) {
          latestSolidColorHex = color;
          break;
        }
      }
    }
    return RefusionMcpCloudBridgeSnapshot(
      ok: structured['ok'] == true,
      projectId: _asString(project['id']) ?? fallbackProjectId,
      compositionId: _asString(composition['id']) ?? fallbackCompositionId,
      revision: _asInt(project['revision']),
      liveOnline: liveEditor['online'] == true,
      updatedAtUtc: DateTime.now().toUtc(),
      remoteRevision: remoteRevision,
      latestSolidColorHex: latestSolidColorHex,
      error: structured['ok'] == true ? null : _asString(structured['summary']),
    );
  }

  Future<Map<String, Object?>> _callTool({
    required String toolName,
    required Map<String, Object?> arguments,
    bool allowAgentSessionToken = false,
  }) async {
    final mergedArguments = <String, Object?>{
      ...arguments,
    };
    if (allowAgentSessionToken &&
        _agentSessionToken != null &&
        _agentSessionToken!.trim().isNotEmpty &&
        mergedArguments['agentSessionToken'] == null) {
      mergedArguments['agentSessionToken'] = _agentSessionToken;
    }
    final requestBody = <String, Object?>{
      'jsonrpc': '2.0',
      'id': _nextRequestId(),
      'method': 'tools/call',
      'params': <String, Object?>{
        'name': toolName,
        'arguments': mergedArguments,
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

  Future<Map<String, Object?>?> _safeCallTool({
    required String toolName,
    required Map<String, Object?> arguments,
    bool allowAgentSessionToken = false,
  }) async {
    try {
      return await _callTool(
        toolName: toolName,
        arguments: arguments,
        allowAgentSessionToken: allowAgentSessionToken,
      );
    } catch (_) {
      return null;
    }
  }

  Future<RefusionMcpCloudPairingCode> generatePairingCode() async {
    final state = _contextReader();
    final response = await _callTool(
      toolName: 'generate_pairing_code',
      arguments: <String, Object?>{
        'deviceId': _deviceId,
        if (_isUuidLike(state.projectId)) 'projectId': state.projectId,
        if (_isUuidLike(state.compositionId))
          'compositionId': state.compositionId,
        'timelineId': state.timelineId,
        'playheadMs': state.playheadMs,
        'platform': 'flutter',
        'appVersion': 'refusion-app',
      },
    );
    final structured = _asMap(response['structuredContent']);
    final payload = _asMap(structured['payload']);
    final context = _asMap(payload['context']);
    final code = _asString(payload['code']);
    final qrData = _asString(payload['qrData']);
    final link = _asString(payload['link']);
    final expiresAt = _asString(payload['expiresAt']);
    if (code == null || qrData == null || link == null || expiresAt == null) {
      throw StateError('Pairing payload missing required fields.');
    }
    return RefusionMcpCloudPairingCode(
      code: code,
      expiresAtUtc: DateTime.parse(expiresAt).toUtc(),
      qrData: qrData,
      link: link,
      projectId: _asString(context['projectId']) ?? '',
      compositionId: _asString(context['compositionId']) ?? '',
      timelineId: _asString(context['timelineId']) ?? 'main',
      playheadMs: _asInt(context['playheadMs']) ?? 0,
      timelineRevision: _asInt(context['timelineRevision']) ?? 1,
      deviceId: _asString(context['deviceId']) ?? _deviceId,
    );
  }

  Future<RefusionMcpCloudAgentSessionAttachment> attachPairingCode({
    required String code,
    String agentClientName = 'ReFusionApp',
  }) async {
    final response = await _callTool(
      toolName: 'attach_pairing_code',
      arguments: <String, Object?>{
        'code': code,
        'agentClientName': agentClientName,
      },
    );
    final structured = _asMap(response['structuredContent']);
    final payload = _asMap(structured['payload']);
    final context = _asMap(payload['context']);
    final token = _asString(payload['agentSessionToken']);
    final sessionId = _asString(payload['agentSessionId']);
    final expiresAt = _asString(payload['expiresAt']);
    if (token == null || sessionId == null || expiresAt == null) {
      throw StateError('Agent session payload missing required fields.');
    }
    final capabilities = <String>[];
    final dynamicCaps = payload['capabilities'];
    if (dynamicCaps is List) {
      for (final value in dynamicCaps) {
        final capability = _asString(value);
        if (capability != null) {
          capabilities.add(capability);
        }
      }
    }
    setAgentSessionToken(token);
    return RefusionMcpCloudAgentSessionAttachment(
      agentSessionToken: token,
      agentSessionId: sessionId,
      projectId: _asString(context['projectId']) ?? '',
      compositionId: _asString(context['compositionId']) ?? '',
      timelineId: _asString(context['timelineId']) ?? 'main',
      playheadMs: _asInt(context['playheadMs']) ?? 0,
      timelineRevision: _asInt(context['timelineRevision']) ?? 1,
      capabilities: List<String>.unmodifiable(capabilities),
      expiresAtUtc: DateTime.parse(expiresAt).toUtc(),
    );
  }

  Future<void> disconnectAgent({String? reason}) async {
    try {
      await _callTool(
        toolName: 'disconnect_agent',
        arguments: <String, Object?>{
          if (reason != null && reason.trim().isNotEmpty)
            'reason': reason.trim(),
        },
        allowAgentSessionToken: true,
      );
    } finally {
      clearAgentSessionToken();
    }
  }

  Future<RefusionMcpCloudPairingCodeStatus> getPairingCodeStatus({
    required String code,
  }) async {
    final normalizedCode = code.trim().toUpperCase();
    if (normalizedCode.isEmpty) {
      throw StateError('Pairing code is required.');
    }
    final response = await _callTool(
      toolName: 'get_pairing_code_status',
      arguments: <String, Object?>{'code': normalizedCode},
    );
    final structured = _asMap(response['structuredContent']);
    final payload = _asMap(structured['payload']);
    final status = _asString(payload['status']) ?? 'pending';
    final exists = payload['exists'] == true;
    final secondsRemaining = _asInt(payload['secondsRemaining']) ?? 0;
    final claimedByAgent = _asString(payload['claimedByAgent']);
    final claimedAt = _asString(payload['claimedAt']);
    final expiresAt = _asString(payload['expiresAt']);
    return RefusionMcpCloudPairingCodeStatus(
      code: normalizedCode,
      exists: exists,
      status: status,
      secondsRemaining: secondsRemaining,
      claimedByAgent: claimedByAgent,
      claimedAtUtc:
          claimedAt == null ? null : DateTime.tryParse(claimedAt)?.toUtc(),
      expiresAtUtc:
          expiresAt == null ? null : DateTime.tryParse(expiresAt)?.toUtc(),
    );
  }

  Future<Map<String, Object?>> _postJson(Map<String, Object?> body) async {
    final request =
        await _httpClient.postUrl(_endpoint).timeout(connectTimeout);
    request.headers.contentType = ContentType.json;
    final bearer = authBearerToken?.trim();
    if (bearer != null && bearer.isNotEmpty) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $bearer');
    }
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

List<Map<String, Object?>> _asListOfMap(Object? value) {
  if (value is! List) {
    return const <Map<String, Object?>>[];
  }
  final result = <Map<String, Object?>>[];
  for (final item in value) {
    result.add(_asMap(item));
  }
  return result;
}

bool _isUuidLike(String? value) {
  if (value == null) {
    return false;
  }
  final normalized = value.trim();
  if (normalized.isEmpty) {
    return false;
  }
  final uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );
  return uuidPattern.hasMatch(normalized);
}

String refusionMcpCloudDeviceId() {
  const explicit = String.fromEnvironment(
    'REFUSION_MCP_DEVICE_ID',
    defaultValue: '',
  );
  final explicitNormalized = explicit.trim();
  if (explicitNormalized.isNotEmpty) {
    return explicitNormalized;
  }
  String host = 'unknown-host';
  try {
    final resolved = Platform.localHostname.trim();
    if (resolved.isNotEmpty) {
      host = resolved;
    }
  } catch (_) {}
  final fingerprint =
      '${Platform.operatingSystem}|${Platform.operatingSystemVersion}|$host';
  final digest = sha256.convert(utf8.encode(fingerprint)).toString();
  return 'flutter-device-${digest.substring(0, 16)}';
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

String? refusionMcpCloudBearerTokenFromEnvironment() {
  const tokenValue = String.fromEnvironment(
    'REFUSION_MCP_BEARER_TOKEN',
    defaultValue: '',
  );
  final normalized = tokenValue.trim();
  if (normalized.isEmpty) {
    return null;
  }
  return normalized;
}

int refusionMcpPlayheadMs(TimelineTime value) => value.inMilliseconds;
