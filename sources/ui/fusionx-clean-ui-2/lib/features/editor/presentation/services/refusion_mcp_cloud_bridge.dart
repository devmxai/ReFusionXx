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
    required this.timelineRevision,
    required this.foreground,
    this.editorLayers = const <Map<String, Object?>>[],
    this.timelineId = 'main',
  });

  final String projectId;
  final String compositionId;
  final int playheadMs;
  final int timelineRevision;
  final bool foreground;
  final List<Map<String, Object?>> editorLayers;
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
    this.remoteLayers = const <Map<String, Object?>>[],
    this.remoteMotionChannels = const <Map<String, Object?>>[],
    this.pendingCommands = const <Map<String, Object?>>[],
    this.canvasMetadata = const <String, Object?>{},
    this.primaryElementGeometry = const <String, Object?>{},
    this.visualLayoutSummary = const <String, Object?>{},
    this.error,
  });

  final bool ok;
  final String? projectId;
  final String? compositionId;
  final int? revision;
  final bool liveOnline;
  final DateTime updatedAtUtc;
  final int? remoteRevision;
  final List<Map<String, Object?>> remoteLayers;
  final List<Map<String, Object?>> remoteMotionChannels;
  final List<Map<String, Object?>> pendingCommands;
  final Map<String, Object?> canvasMetadata;
  final Map<String, Object?> primaryElementGeometry;
  final Map<String, Object?> visualLayoutSummary;
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
    this.status = 'pending',
    this.claimedByAgent,
    this.claimedAtUtc,
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
  final String status;
  final String? claimedByAgent;
  final DateTime? claimedAtUtc;
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

  Future<void> acknowledgeAppliedRevision({
    required String projectId,
    required String compositionId,
    required int revision,
  }) async {
    await acknowledgeAppliedCommands(
      projectId: projectId,
      compositionId: compositionId,
      revision: revision,
      commandIds: const <String>[],
    );
  }

  Future<void> acknowledgeAppliedCommands({
    required String projectId,
    required String compositionId,
    required int revision,
    required List<String> commandIds,
    bool appliedSuccessfully = true,
    Map<String, Object?> proof = const <String, Object?>{},
  }) async {
    final projectIdArg = _normalizedIdentifierOrNull(projectId);
    final compositionIdArg = _normalizedIdentifierOrNull(compositionId);
    if (projectIdArg == null || compositionIdArg == null || revision < 0) {
      return;
    }
    final normalizedCommandIds = commandIds
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    await _safeCallTool(
      toolName: 'ack_command_applied',
      arguments: <String, Object?>{
        'projectId': projectIdArg,
        'compositionId': compositionIdArg,
        'timelineRevision': revision,
        'revision': revision,
        'commandIds': normalizedCommandIds,
        'appliedSuccessfully': appliedSuccessfully,
        'proof': proof,
        'deviceId': _deviceId,
      },
    );
  }

  Future<void> syncNow() async {
    if (_syncInFlight) {
      return;
    }
    _syncInFlight = true;
    try {
      final state = _contextReader();
      final status = _foreground && state.foreground ? 'online' : 'background';
      final projectIdArg = _normalizedIdentifierOrNull(state.projectId);
      final compositionIdArg = _normalizedIdentifierOrNull(state.compositionId);
      final hasActiveComposition =
          projectIdArg != null && compositionIdArg != null;
      await _callTool(
        toolName: 'touch_editor_session',
        arguments: <String, Object?>{
          'deviceId': _deviceId,
          'hasActiveComposition': hasActiveComposition,
          if (projectIdArg != null) 'projectId': projectIdArg,
          if (compositionIdArg != null) 'compositionId': compositionIdArg,
          'timelineRevision': state.timelineRevision,
          'foreground': _foreground && state.foreground,
          'status': status,
          'platform': 'flutter',
        },
      );
      await _callTool(
        toolName: 'set_active_context',
        arguments: <String, Object?>{
          'deviceId': _deviceId,
          'hasActiveComposition': hasActiveComposition,
          if (projectIdArg != null) 'projectId': projectIdArg,
          if (compositionIdArg != null) 'compositionId': compositionIdArg,
          'timelineId': state.timelineId,
          'playheadMs': state.playheadMs,
          'timelineRevision': state.timelineRevision,
          'foreground': _foreground && state.foreground,
          'status': status,
          'platform': 'flutter',
          'appVersion': 'refusion-app',
        },
      );
      if (!hasActiveComposition) {
        final contextResponse = await _callTool(
          toolName: 'get_active_context',
          arguments: const <String, Object?>{},
          allowAgentSessionToken: true,
        );
        _emitSnapshot(
          _snapshotFromContextResponse(
            contextResponse,
            layersResult: null,
            motionChannelsResult: null,
            pendingCommandsResult: null,
            canvasMetadataResult: null,
            elementGeometryResult: null,
            visualLayoutSummaryResult: null,
            fallbackProjectId: state.projectId,
            fallbackCompositionId: state.compositionId,
          ),
        );
        return;
      }
      await _safeCallTool(
        toolName: 'sync_editor_layers',
        arguments: <String, Object?>{
          'projectId': projectIdArg,
          'compositionId': compositionIdArg,
          'layers': state.editorLayers,
        },
      );
      final contextResponse = await _callTool(
        toolName: 'get_active_context',
        arguments: const <String, Object?>{},
        allowAgentSessionToken: true,
      );
      final contextStructured = _asMap(contextResponse['structuredContent']);
      final contextPayload = _asMap(contextStructured['payload']);
      final contextLiveEditor = _asMap(contextPayload['liveEditor']);
      final liveSessionId = _asString(contextLiveEditor['sessionId']);
      final effectiveProjectId = projectIdArg;
      final effectiveCompositionId = compositionIdArg;
      final layersResponse = await _safeCallTool(
        toolName: 'get_layers',
        arguments: <String, Object?>{
          'projectId': effectiveProjectId,
          'compositionId': effectiveCompositionId,
        },
        allowAgentSessionToken: true,
      );
      final motionChannelsResponse = await _safeCallTool(
        toolName: 'get_motion_channels',
        arguments: <String, Object?>{
          'projectId': effectiveProjectId,
          'compositionId': effectiveCompositionId,
        },
        allowAgentSessionToken: true,
      );
      final pendingCommandsResponse = await _safeCallTool(
        toolName: 'get_pending_commands',
        arguments: <String, Object?>{
          'projectId': effectiveProjectId,
          'compositionId': effectiveCompositionId,
          if (liveSessionId != null) 'appSessionId': liveSessionId,
          'markReceived': true,
          'limit': 40,
        },
      );
      final canvasMetadataResponse = await _safeCallTool(
        toolName: 'get_canvas_metadata',
        arguments: <String, Object?>{
          'projectId': effectiveProjectId,
          'compositionId': effectiveCompositionId,
        },
        allowAgentSessionToken: true,
      );
      final visualLayoutSummaryResponse = await _safeCallTool(
        toolName: 'get_visual_layout_summary',
        arguments: <String, Object?>{
          'projectId': effectiveProjectId,
          'compositionId': effectiveCompositionId,
          'timeMs': state.playheadMs,
        },
        allowAgentSessionToken: true,
      );
      final firstLayerId = _asString(
        _asMap(
          _asListOfMap(
            _asMap(_asMap(layersResponse?['structuredContent'])['payload'])[
                'layers'],
          ).isNotEmpty
              ? _asListOfMap(
                  _asMap(_asMap(layersResponse?['structuredContent'])[
                      'payload'])['layers'],
                ).first
              : const <String, Object?>{},
        )['id'],
      );
      final elementGeometryResponse = await _safeCallTool(
        toolName: 'get_element_geometry',
        arguments: <String, Object?>{
          'projectId': effectiveProjectId,
          'compositionId': effectiveCompositionId,
          if (firstLayerId != null) 'layerId': firstLayerId,
          'timeMs': state.playheadMs,
        },
        allowAgentSessionToken: true,
      );
      _emitSnapshot(
        _snapshotFromContextResponse(
          contextResponse,
          layersResult: layersResponse,
          motionChannelsResult: motionChannelsResponse,
          pendingCommandsResult: pendingCommandsResponse,
          canvasMetadataResult: canvasMetadataResponse,
          elementGeometryResult: elementGeometryResponse,
          visualLayoutSummaryResult: visualLayoutSummaryResponse,
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
    required Map<String, Object?>? motionChannelsResult,
    required Map<String, Object?>? pendingCommandsResult,
    required Map<String, Object?>? canvasMetadataResult,
    required Map<String, Object?>? elementGeometryResult,
    required Map<String, Object?>? visualLayoutSummaryResult,
    required String fallbackProjectId,
    required String fallbackCompositionId,
  }) {
    final structured = _asMap(rpcResult['structuredContent']);
    final payload = _asMap(structured['payload']);
    final project = _asMap(payload['project']);
    final composition = _asMap(payload['composition']);
    final liveEditor = _asMap(payload['liveEditor']);
    int? remoteRevision;
    var remoteLayers = const <Map<String, Object?>>[];
    var remoteMotionChannels = const <Map<String, Object?>>[];
    var pendingCommands = const <Map<String, Object?>>[];
    var canvasMetadata = const <String, Object?>{};
    var primaryElementGeometry = const <String, Object?>{};
    var visualLayoutSummary = const <String, Object?>{};
    if (layersResult != null) {
      final layersStructured = _asMap(layersResult['structuredContent']);
      final layersPayload = _asMap(layersStructured['payload']);
      remoteRevision = _asInt(layersPayload['revision']);
      final layers = _asListOfMap(layersPayload['layers']);
      remoteLayers = layers;
    }
    if (motionChannelsResult != null) {
      final channelsStructured =
          _asMap(motionChannelsResult['structuredContent']);
      final channelsPayload = _asMap(channelsStructured['payload']);
      remoteMotionChannels = _asListOfMap(channelsPayload['channels']);
    }
    if (pendingCommandsResult != null) {
      final pendingStructured =
          _asMap(pendingCommandsResult['structuredContent']);
      final pendingPayload = _asMap(pendingStructured['payload']);
      pendingCommands = _asListOfMap(pendingPayload['commands']);
    }
    if (canvasMetadataResult != null) {
      final metadataStructured =
          _asMap(canvasMetadataResult['structuredContent']);
      canvasMetadata = _asMap(metadataStructured['payload']);
    }
    if (elementGeometryResult != null) {
      final geometryStructured =
          _asMap(elementGeometryResult['structuredContent']);
      primaryElementGeometry = _asMap(geometryStructured['payload']);
    }
    if (visualLayoutSummaryResult != null) {
      final summaryStructured = _asMap(
        visualLayoutSummaryResult['structuredContent'],
      );
      visualLayoutSummary = _asMap(summaryStructured['payload']);
    }
    return RefusionMcpCloudBridgeSnapshot(
      ok: structured['ok'] == true,
      projectId: _asString(project['id']) ?? fallbackProjectId,
      compositionId: _asString(composition['id']) ?? fallbackCompositionId,
      revision: _asInt(project['revision']),
      liveOnline: liveEditor['online'] == true,
      updatedAtUtc: DateTime.now().toUtc(),
      remoteRevision: remoteRevision,
      remoteLayers: List<Map<String, Object?>>.unmodifiable(remoteLayers),
      remoteMotionChannels: List<Map<String, Object?>>.unmodifiable(
        remoteMotionChannels,
      ),
      pendingCommands: List<Map<String, Object?>>.unmodifiable(pendingCommands),
      canvasMetadata: Map<String, Object?>.unmodifiable(canvasMetadata),
      primaryElementGeometry: Map<String, Object?>.unmodifiable(
        primaryElementGeometry,
      ),
      visualLayoutSummary: Map<String, Object?>.unmodifiable(
        visualLayoutSummary,
      ),
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
    final projectIdArg = _normalizedIdentifierOrNull(state.projectId);
    final compositionIdArg = _normalizedIdentifierOrNull(state.compositionId);
    final hasActiveComposition =
        projectIdArg != null && compositionIdArg != null;
    final response = await _callTool(
      toolName: 'generate_pairing_code',
      arguments: <String, Object?>{
        'deviceId': _deviceId,
        'hasActiveComposition': hasActiveComposition,
        if (projectIdArg != null) 'projectId': projectIdArg,
        if (compositionIdArg != null) 'compositionId': compositionIdArg,
        'timelineId': state.timelineId,
        'playheadMs': state.playheadMs,
        'timelineRevision': state.timelineRevision,
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
    final claimedAt = _asString(payload['claimedAt']);
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
      status: _asString(payload['status']) ?? 'pending',
      claimedByAgent: _asString(payload['claimedByAgent']),
      claimedAtUtc:
          claimedAt == null ? null : DateTime.tryParse(claimedAt)?.toUtc(),
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
      arguments: <String, Object?>{
        'code': normalizedCode,
        'keepAlive': true,
      },
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

String? _normalizedIdentifierOrNull(String? value) {
  if (value == null) {
    return null;
  }
  final normalized = value.trim();
  if (normalized.isEmpty) {
    return null;
  }
  return normalized;
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
