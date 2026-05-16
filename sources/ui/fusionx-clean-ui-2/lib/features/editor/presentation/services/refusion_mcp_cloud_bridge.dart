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
    this.canvasWidth,
    this.canvasHeight,
    this.durationMs,
    this.fps,
    this.workspaceId,
    this.coordinateSystem = 'center-origin',
    this.origin = 'center',
  });

  final String projectId;
  final String compositionId;
  final int playheadMs;
  final int timelineRevision;
  final bool foreground;
  final List<Map<String, Object?>> editorLayers;
  final String timelineId;
  final int? canvasWidth;
  final int? canvasHeight;
  final int? durationMs;
  final int? fps;
  final String? workspaceId;
  final String coordinateSystem;
  final String origin;
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
    this.projectSnapshot = const <String, Object?>{},
    this.timelineGraph = const <String, Object?>{},
    this.frameEvaluation = const <String, Object?>{},
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
  final Map<String, Object?> projectSnapshot;
  final Map<String, Object?> timelineGraph;
  final Map<String, Object?> frameEvaluation;
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
  static const Duration _fastApplySoftTimeout = Duration(milliseconds: 1500);
  static const Duration _commandBusSoftTimeout = Duration(milliseconds: 2500);
  static const Duration _diagnosticsSoftTimeout = Duration(milliseconds: 1800);

  Timer? _timer;
  bool _foreground = true;
  int _requestIdSeed = 1;
  bool _fastSyncInFlight = false;
  bool _diagnosticsSyncInFlight = false;
  _DiagnosticsSyncRequest? _queuedDiagnosticsRequest;
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

  Future<bool> acknowledgeAppliedRevision({
    required String projectId,
    required String compositionId,
    required int revision,
  }) async {
    return acknowledgeAppliedCommands(
      projectId: projectId,
      compositionId: compositionId,
      revision: revision,
      commandIds: const <String>[],
    );
  }

  Future<bool> acknowledgeAppliedCommands({
    required String projectId,
    required String compositionId,
    int? revision,
    required List<String> commandIds,
    bool appliedSuccessfully = true,
    Map<String, Object?> proof = const <String, Object?>{},
    List<Map<String, Object?>> blockers = const <Map<String, Object?>>[],
    List<Map<String, Object?>> warnings = const <Map<String, Object?>>[],
    String? errorMessage,
  }) async {
    final projectIdArg = _normalizedProjectIdentifierOrNull(projectId);
    final compositionIdArg =
        _normalizedCompositionIdentifierOrNull(compositionId);
    if (projectIdArg == null || compositionIdArg == null) {
      return false;
    }
    final normalizedCommandIds = commandIds
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final response = await _safeCallTool(
      toolName: 'ack_command_applied',
      arguments: <String, Object?>{
        'projectId': projectIdArg,
        'compositionId': compositionIdArg,
        if (revision != null && revision >= 0) 'timelineRevision': revision,
        if (revision != null && revision >= 0) 'revision': revision,
        'commandIds': normalizedCommandIds,
        'appliedSuccessfully': appliedSuccessfully,
        'proof': proof,
        if (blockers.isNotEmpty) 'blockers': blockers,
        if (warnings.isNotEmpty) 'warnings': warnings,
        if (errorMessage != null && errorMessage.trim().isNotEmpty)
          'errorMessage': errorMessage.trim(),
        'deviceId': _deviceId,
      },
    );
    if (response == null) {
      return false;
    }
    final structured = _asMap(response['structuredContent']);
    final ok = structured['ok'];
    if (ok is bool) {
      return ok;
    }
    return true;
  }

  Future<void> syncNow() async {
    if (_fastSyncInFlight) {
      return;
    }
    _fastSyncInFlight = true;
    try {
      final state = _contextReader();
      final status = _foreground && state.foreground ? 'online' : 'background';
      final projectIdArg = _normalizedProjectIdentifierOrNull(state.projectId);
      final compositionIdArg =
          _normalizedCompositionIdentifierOrNull(state.compositionId);
      final workspaceIdArg =
          _normalizedWorkspaceIdentifierOrNull(state.workspaceId);
      // Local-first truth: project + composition are the mandatory runtime
      // identity. workspaceId is optional metadata and must never downgrade
      // an active composition to inactive.
      final hasActiveComposition =
          projectIdArg != null && compositionIdArg != null;
      _fireAndForgetTool(
        toolName: 'touch_editor_session',
        arguments: <String, Object?>{
          'deviceId': _deviceId,
          'hasActiveComposition': hasActiveComposition,
          if (projectIdArg != null) 'projectId': projectIdArg,
          if (compositionIdArg != null) 'compositionId': compositionIdArg,
          if (workspaceIdArg != null) 'workspaceId': workspaceIdArg,
          'timelineRevision': state.timelineRevision,
          'foreground': _foreground && state.foreground,
          'status': status,
          'platform': 'flutter',
        },
      );
      _fireAndForgetTool(
        toolName: 'set_active_context',
        arguments: <String, Object?>{
          'deviceId': _deviceId,
          'hasActiveComposition': hasActiveComposition,
          if (projectIdArg != null) 'projectId': projectIdArg,
          if (compositionIdArg != null) 'compositionId': compositionIdArg,
          if (workspaceIdArg != null) 'workspaceId': workspaceIdArg,
          'timelineId': state.timelineId,
          'playheadMs': state.playheadMs,
          'timelineRevision': state.timelineRevision,
          'foreground': _foreground && state.foreground,
          'status': status,
          'platform': 'flutter',
          'appVersion': 'refusion-app',
          if (state.canvasWidth != null && state.canvasWidth! > 0)
            'canvasWidth': state.canvasWidth,
          if (state.canvasHeight != null && state.canvasHeight! > 0)
            'canvasHeight': state.canvasHeight,
          if (state.durationMs != null && state.durationMs! > 0)
            'durationMs': state.durationMs,
          if (state.fps != null && state.fps! > 0) 'fps': state.fps,
          'coordinateSystem': state.coordinateSystem,
          'origin': state.origin,
        },
      );
      if (!hasActiveComposition) {
        final contextResponse = await _callTool(
          toolName: 'get_active_context',
          arguments: const <String, Object?>{},
          allowAgentSessionToken: true,
        );
        final contextStructured = _asMap(contextResponse['structuredContent']);
        final contextPayload = _asMap(contextStructured['payload']);
        final contextProject = _asMap(contextPayload['project']);
        final contextComposition = _asMap(contextPayload['composition']);
        final contextLiveEditor = _asMap(contextPayload['liveEditor']);
        final remoteProjectId = _normalizedProjectIdentifierOrNull(
          _asString(contextProject['id']) ?? '',
        );
        final remoteCompositionId = _normalizedCompositionIdentifierOrNull(
          _asString(contextComposition['id']) ?? '',
        );
        final liveSessionId = _asString(contextLiveEditor['editorSessionId']) ??
            _asString(contextLiveEditor['sessionId']);
        final remoteContextIsLive = contextLiveEditor['online'] == true;
        Map<String, Object?>? pendingCommandsResponse;
        Map<String, Object?>? layersResponse;
        Map<String, Object?>? motionChannelsResponse;
        if (remoteContextIsLive &&
            remoteProjectId != null &&
            remoteCompositionId != null) {
          pendingCommandsResponse = await _fetchPendingCommands(
            projectId: remoteProjectId,
            compositionId: remoteCompositionId,
            liveSessionId: liveSessionId,
            softTimeout: _fastApplySoftTimeout,
          );
          final hasPendingCommands =
              _pendingCommandList(pendingCommandsResponse).isNotEmpty;
          final pendingCommandTargetLayerIds = _pendingCommandTargetLayerIds(
            pendingCommandsResponse,
          );
          final layerReadArgs = <String, Object?>{
            'projectId': remoteProjectId,
            'compositionId': remoteCompositionId,
            if (pendingCommandTargetLayerIds.isNotEmpty)
              'layerIds': pendingCommandTargetLayerIds,
          };
          if (!hasPendingCommands) {
            final sceneContextResponse = await _safeCallTool(
              toolName: 'get_scene_context',
              arguments: layerReadArgs,
              allowAgentSessionToken: true,
              softTimeout: _fastApplySoftTimeout,
            );
            layersResponse =
                _layersToolResultFromSceneContext(sceneContextResponse);
          }
          final motionChannelsFuture = _safeCallTool(
            toolName: 'get_motion_channels',
            arguments: layerReadArgs,
            allowAgentSessionToken: true,
            softTimeout: _fastApplySoftTimeout,
          );
          if (!hasPendingCommands && layersResponse == null) {
            layersResponse = await _safeCallTool(
              toolName: 'get_layers',
              arguments: layerReadArgs,
              allowAgentSessionToken: true,
              softTimeout: _fastApplySoftTimeout,
            );
          }
          motionChannelsResponse = await motionChannelsFuture;
        }
        _emitSnapshot(
          _snapshotFromContextResponse(
            contextResponse,
            layersResult: layersResponse,
            motionChannelsResult: motionChannelsResponse,
            pendingCommandsResult: pendingCommandsResponse,
            canvasMetadataResult: null,
            elementGeometryResult: null,
            visualLayoutSummaryResult: null,
            projectSnapshotResult: null,
            timelineGraphResult: null,
            frameEvaluationResult: null,
            fallbackProjectId: remoteContextIsLive
                ? remoteProjectId ?? (projectIdArg ?? '')
                : (projectIdArg ?? ''),
            fallbackCompositionId: remoteContextIsLive
                ? remoteCompositionId ?? (compositionIdArg ?? '')
                : (compositionIdArg ?? ''),
            localCanvasMetadata: _localCanvasMetadata(state),
            preferFallbackScope: !remoteContextIsLive,
          ),
        );
        return;
      }
      _fireAndForgetTool(
        toolName: 'sync_editor_layers',
        arguments: <String, Object?>{
          'projectId': projectIdArg,
          'compositionId': compositionIdArg,
          'layers': state.editorLayers,
        },
      );
      final effectiveProjectId = projectIdArg;
      final effectiveCompositionId = compositionIdArg;
      final contextResponse = await _safeCallTool(
            toolName: 'get_active_context',
            arguments: const <String, Object?>{},
            allowAgentSessionToken: true,
            softTimeout: _fastApplySoftTimeout,
          ) ??
          _contextResponseFromState(
            state: state,
            projectId: effectiveProjectId,
            compositionId: effectiveCompositionId,
          );
      final contextStructured = _asMap(contextResponse['structuredContent']);
      final contextPayload = _asMap(contextStructured['payload']);
      final contextLiveEditor = _asMap(contextPayload['liveEditor']);
      final liveSessionId = _asString(contextLiveEditor['editorSessionId']) ??
          _asString(contextLiveEditor['sessionId']);
      final pendingCommandsResponse = await _fetchPendingCommands(
        projectId: effectiveProjectId,
        compositionId: effectiveCompositionId,
        liveSessionId: liveSessionId,
        softTimeout: _fastApplySoftTimeout,
      );
      final hasPendingCommands =
          _pendingCommandList(pendingCommandsResponse).isNotEmpty;
      final pendingCommandTargetLayerIds = _pendingCommandTargetLayerIds(
        pendingCommandsResponse,
      );
      final layerReadArgs = <String, Object?>{
        'projectId': effectiveProjectId,
        'compositionId': effectiveCompositionId,
        if (pendingCommandTargetLayerIds.isNotEmpty)
          'layerIds': pendingCommandTargetLayerIds,
      };
      Map<String, Object?>? layersResponse;
      if (!hasPendingCommands) {
        final sceneContextResponse = await _safeCallTool(
          toolName: 'get_scene_context',
          arguments: layerReadArgs,
          allowAgentSessionToken: true,
          softTimeout: _fastApplySoftTimeout,
        );
        layersResponse = _layersToolResultFromSceneContext(
          sceneContextResponse,
        );
      }
      final motionChannelsFuture = _safeCallTool(
        toolName: 'get_motion_channels',
        arguments: layerReadArgs,
        allowAgentSessionToken: true,
        softTimeout: _fastApplySoftTimeout,
      );
      if (!hasPendingCommands && layersResponse == null) {
        layersResponse = await _safeCallTool(
          toolName: 'get_layers',
          arguments: layerReadArgs,
          allowAgentSessionToken: true,
          softTimeout: _fastApplySoftTimeout,
        );
      }
      final motionChannelsResponse = await motionChannelsFuture;
      _emitSnapshot(
        _snapshotFromContextResponse(
          contextResponse,
          layersResult: layersResponse,
          motionChannelsResult: motionChannelsResponse,
          pendingCommandsResult: pendingCommandsResponse,
          canvasMetadataResult: null,
          elementGeometryResult: null,
          visualLayoutSummaryResult: null,
          projectSnapshotResult: null,
          timelineGraphResult: null,
          frameEvaluationResult: null,
          fallbackProjectId: state.projectId,
          fallbackCompositionId: state.compositionId,
          localCanvasMetadata: _localCanvasMetadata(state),
          preferFallbackScope: true,
        ),
      );
      _scheduleDiagnosticsSync(
        _DiagnosticsSyncRequest(
          state: state,
          contextResponse: contextResponse,
          layersResponse: layersResponse,
          motionChannelsResponse: motionChannelsResponse,
          pendingCommandsResponse: pendingCommandsResponse,
          projectId: effectiveProjectId,
          compositionId: effectiveCompositionId,
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
      _fastSyncInFlight = false;
    }
  }

  Future<Map<String, Object?>?> _fetchPendingCommands({
    required String projectId,
    required String compositionId,
    required String? liveSessionId,
    required Duration softTimeout,
  }) async {
    final commandBusTimeout =
        softTimeout.inMilliseconds > _commandBusSoftTimeout.inMilliseconds
            ? softTimeout
            : _commandBusSoftTimeout;
    final pendingCommandsResponse = await _safeCallTool(
      toolName: 'get_pending_commands',
      arguments: <String, Object?>{
        'projectId': projectId,
        'compositionId': compositionId,
        if (liveSessionId != null) 'editorSessionId': liveSessionId,
        'markReceived': true,
        'limit': 40,
      },
      softTimeout: commandBusTimeout,
    );
    // Strict local-first routing: do not fall back to unscoped fetch. Commands
    // must remain bound to the active editor session identity.
    return pendingCommandsResponse;
  }

  List<Map<String, Object?>> _pendingCommandList(
    Map<String, Object?>? pendingCommandsRpcResult,
  ) {
    if (pendingCommandsRpcResult == null) {
      return const <Map<String, Object?>>[];
    }
    final pendingStructured =
        _asMap(pendingCommandsRpcResult['structuredContent']);
    final pendingPayload = _asMap(pendingStructured['payload']);
    return _asListOfMap(pendingPayload['commands']);
  }

  void _scheduleDiagnosticsSync(_DiagnosticsSyncRequest request) {
    if (_diagnosticsSyncInFlight) {
      _queuedDiagnosticsRequest = request;
      return;
    }
    _diagnosticsSyncInFlight = true;
    unawaited(_runDiagnosticsSync(request));
  }

  Future<void> _runDiagnosticsSync(_DiagnosticsSyncRequest request) async {
    try {
      final spatialSnapshotResponse = await _safeCallTool(
        toolName: 'get_spatial_scene_snapshot',
        arguments: <String, Object?>{
          'projectId': request.projectId,
          'compositionId': request.compositionId,
          'timeMs': request.state.playheadMs,
        },
        allowAgentSessionToken: true,
        softTimeout: _diagnosticsSoftTimeout,
      );
      final spatialSnapshotPayload = _asMap(
        _asMap(
            _asMap(spatialSnapshotResponse?['structuredContent'])['payload']),
      );
      Map<String, Object?>? canvasMetadataResponse;
      Map<String, Object?>? visualLayoutSummaryResponse;
      Map<String, Object?>? elementGeometryResponse;
      Map<String, Object?>? projectSnapshotResponse;
      Map<String, Object?>? timelineGraphResponse;
      Map<String, Object?>? frameEvaluationResponse;
      if (spatialSnapshotPayload.isNotEmpty) {
        canvasMetadataResponse = _toolResultFromPayload(
          _asMap(spatialSnapshotPayload['canvasMetadata']),
        );
        visualLayoutSummaryResponse = _toolResultFromPayload(
          _asMap(spatialSnapshotPayload['visualLayoutSummary']),
        );
        elementGeometryResponse = _toolResultFromPayload(
          _asMap(spatialSnapshotPayload['primaryElementGeometry']),
        );
        projectSnapshotResponse = _toolResultFromPayload(
          _asMap(spatialSnapshotPayload['projectSnapshot']),
        );
        timelineGraphResponse = _toolResultFromPayload(
          _asMap(spatialSnapshotPayload['timelineGraph']),
        );
        frameEvaluationResponse = _toolResultFromPayload(
          _asMap(spatialSnapshotPayload['frameEvaluation']),
        );
      } else {
        canvasMetadataResponse = await _safeCallTool(
          toolName: 'get_canvas_metadata',
          arguments: <String, Object?>{
            'projectId': request.projectId,
            'compositionId': request.compositionId,
          },
          allowAgentSessionToken: true,
          softTimeout: _diagnosticsSoftTimeout,
        );
        visualLayoutSummaryResponse = await _safeCallTool(
          toolName: 'get_visual_layout_summary',
          arguments: <String, Object?>{
            'projectId': request.projectId,
            'compositionId': request.compositionId,
            'timeMs': request.state.playheadMs,
          },
          allowAgentSessionToken: true,
          softTimeout: _diagnosticsSoftTimeout,
        );
        final firstLayerId = _asString(
          _asMap(
            _asListOfMap(
              _asMap(_asMap(request.layersResponse?['structuredContent'])[
                  'payload'])['layers'],
            ).isNotEmpty
                ? _asListOfMap(
                    _asMap(_asMap(request.layersResponse?['structuredContent'])[
                        'payload'])['layers'],
                  ).first
                : const <String, Object?>{},
          )['id'],
        );
        elementGeometryResponse = await _safeCallTool(
          toolName: 'get_element_geometry',
          arguments: <String, Object?>{
            'projectId': request.projectId,
            'compositionId': request.compositionId,
            if (firstLayerId != null) 'layerId': firstLayerId,
            'timeMs': request.state.playheadMs,
          },
          allowAgentSessionToken: true,
          softTimeout: _diagnosticsSoftTimeout,
        );
        projectSnapshotResponse = await _safeCallTool(
          toolName: 'get_project_snapshot',
          arguments: <String, Object?>{
            'projectId': request.projectId,
            'compositionId': request.compositionId,
          },
          allowAgentSessionToken: true,
          softTimeout: _diagnosticsSoftTimeout,
        );
        timelineGraphResponse = await _safeCallTool(
          toolName: 'get_timeline_graph',
          arguments: <String, Object?>{
            'projectId': request.projectId,
            'compositionId': request.compositionId,
          },
          allowAgentSessionToken: true,
          softTimeout: _diagnosticsSoftTimeout,
        );
        frameEvaluationResponse = await _safeCallTool(
          toolName: 'evaluate_frame',
          arguments: <String, Object?>{
            'projectId': request.projectId,
            'compositionId': request.compositionId,
            'timeMs': request.state.playheadMs,
          },
          allowAgentSessionToken: true,
          softTimeout: _diagnosticsSoftTimeout,
        );
      }
      _emitSnapshot(
        _snapshotFromContextResponse(
          request.contextResponse,
          layersResult: request.layersResponse,
          motionChannelsResult: request.motionChannelsResponse,
          pendingCommandsResult: request.pendingCommandsResponse,
          canvasMetadataResult: canvasMetadataResponse,
          elementGeometryResult: elementGeometryResponse,
          visualLayoutSummaryResult: visualLayoutSummaryResponse,
          projectSnapshotResult: projectSnapshotResponse,
          timelineGraphResult: timelineGraphResponse,
          frameEvaluationResult: frameEvaluationResponse,
          fallbackProjectId: request.state.projectId,
          fallbackCompositionId: request.state.compositionId,
          localCanvasMetadata: _localCanvasMetadata(request.state),
          preferFallbackScope: true,
        ),
      );
    } finally {
      _diagnosticsSyncInFlight = false;
      final queued = _queuedDiagnosticsRequest;
      _queuedDiagnosticsRequest = null;
      if (queued != null) {
        _scheduleDiagnosticsSync(queued);
      }
    }
  }

  Map<String, Object?> _toolResultFromPayload(Map<String, Object?> payload) {
    return <String, Object?>{
      'structuredContent': <String, Object?>{
        'ok': true,
        'summary': 'ok',
        'payload': payload,
      },
    };
  }

  Map<String, Object?>? _layersToolResultFromSceneContext(
    Map<String, Object?>? sceneContextResult,
  ) {
    if (sceneContextResult == null) {
      return null;
    }
    final structured = _asMap(sceneContextResult['structuredContent']);
    if (structured['ok'] != true) {
      return null;
    }
    final payload = _asMap(structured['payload']);
    if (payload.isEmpty) {
      return null;
    }
    final snapshot = _asMap(payload['snapshot']);
    final projectSnapshot = _asMap(snapshot['projectSnapshot']);
    final layers = _asListOfMap(projectSnapshot['layers']);
    if (layers.isEmpty) {
      return null;
    }
    return _toolResultFromPayload(
      <String, Object?>{
        'revision': _asInt(payload['revision']) ??
            _asInt(projectSnapshot['revision']) ??
            0,
        'layers': layers,
        'legacyReadOnly': true,
        'source': 'scene_context',
      },
    );
  }

  List<String> _pendingCommandTargetLayerIds(
    Map<String, Object?>? pendingCommandsRpcResult,
  ) {
    if (pendingCommandsRpcResult == null) {
      return const <String>[];
    }
    final pendingStructured =
        _asMap(pendingCommandsRpcResult['structuredContent']);
    final pendingPayload = _asMap(pendingStructured['payload']);
    final pendingCommands = _asListOfMap(pendingPayload['commands']);
    final targetLayerIds = <String>{};
    for (final command in pendingCommands) {
      final payload = _asMap(command['payload']);
      final nestedPayload = _asMap(payload['payload']);
      final candidates = <String?>[
        _asString(payload['layerId']),
        _asString(payload['targetLayerId']),
        _asString(payload['requestedLayerId']),
        _asString(payload['clipId']),
        _asString(payload['localLayerId']),
        _asString(nestedPayload['layerId']),
        _asString(nestedPayload['targetLayerId']),
        _asString(nestedPayload['clipId']),
      ];
      for (final candidate in candidates) {
        if (candidate == null) {
          continue;
        }
        final normalized = candidate.trim();
        if (normalized.isNotEmpty) {
          targetLayerIds.add(normalized);
        }
      }
    }
    return List<String>.unmodifiable(targetLayerIds);
  }

  RefusionMcpCloudBridgeSnapshot _snapshotFromContextResponse(
    Map<String, Object?> rpcResult, {
    required Map<String, Object?>? layersResult,
    required Map<String, Object?>? motionChannelsResult,
    required Map<String, Object?>? pendingCommandsResult,
    required Map<String, Object?>? canvasMetadataResult,
    required Map<String, Object?>? elementGeometryResult,
    required Map<String, Object?>? visualLayoutSummaryResult,
    required Map<String, Object?>? projectSnapshotResult,
    required Map<String, Object?>? timelineGraphResult,
    required Map<String, Object?>? frameEvaluationResult,
    required String fallbackProjectId,
    required String fallbackCompositionId,
    required Map<String, Object?> localCanvasMetadata,
    bool preferFallbackScope = false,
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
    var projectSnapshot = const <String, Object?>{};
    var timelineGraph = const <String, Object?>{};
    var frameEvaluation = const <String, Object?>{};
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
    if (canvasMetadata.isEmpty && localCanvasMetadata.isNotEmpty) {
      canvasMetadata = localCanvasMetadata;
    }
    if (canvasMetadata.isEmpty) {
      final compositionWidth = _asInt(composition['width']);
      final compositionHeight = _asInt(composition['height']);
      if (compositionWidth != null &&
          compositionHeight != null &&
          compositionWidth > 0 &&
          compositionHeight > 0) {
        final fps = _asInt(composition['fps']) ?? 30;
        final durationMs = _asInt(composition['durationMs']) ?? 0;
        canvasMetadata = <String, Object?>{
          'width': compositionWidth,
          'height': compositionHeight,
          'canvasWidth': compositionWidth,
          'canvasHeight': compositionHeight,
          'durationMs': durationMs,
          'fps': fps,
          'aspect': _asString(composition['aspect']),
          'aspectRatio': compositionWidth / compositionHeight,
          'canvas': <String, Object?>{
            'width': compositionWidth,
            'height': compositionHeight,
            'durationMs': durationMs,
            'fps': fps,
          },
        };
      }
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
    if (projectSnapshotResult != null) {
      final snapshotStructured =
          _asMap(projectSnapshotResult['structuredContent']);
      projectSnapshot = _asMap(snapshotStructured['payload']);
    }
    if (timelineGraphResult != null) {
      final timelineStructured =
          _asMap(timelineGraphResult['structuredContent']);
      timelineGraph = _asMap(timelineStructured['payload']);
    }
    if (frameEvaluationResult != null) {
      final frameStructured =
          _asMap(frameEvaluationResult['structuredContent']);
      frameEvaluation = _asMap(frameStructured['payload']);
    }
    return RefusionMcpCloudBridgeSnapshot(
      ok: structured['ok'] == true,
      projectId: preferFallbackScope
          ? fallbackProjectId
          : (_asString(project['id']) ?? fallbackProjectId),
      compositionId: preferFallbackScope
          ? fallbackCompositionId
          : (_asString(composition['id']) ?? fallbackCompositionId),
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
      projectSnapshot: Map<String, Object?>.unmodifiable(projectSnapshot),
      timelineGraph: Map<String, Object?>.unmodifiable(timelineGraph),
      frameEvaluation: Map<String, Object?>.unmodifiable(frameEvaluation),
      error: structured['ok'] == true ? null : _asString(structured['summary']),
    );
  }

  Map<String, Object?> _localCanvasMetadata(
    RefusionMcpCloudContextState state,
  ) {
    final canvasWidth = state.canvasWidth;
    final canvasHeight = state.canvasHeight;
    if (canvasWidth == null ||
        canvasHeight == null ||
        canvasWidth <= 0 ||
        canvasHeight <= 0) {
      return const <String, Object?>{};
    }
    final fps = state.fps ?? 30;
    final durationMs = state.durationMs ?? 0;
    final currentFrame =
        fps > 0 ? ((state.playheadMs / 1000.0) * fps).round() : 0;
    final halfWidth = canvasWidth / 2.0;
    final halfHeight = canvasHeight / 2.0;
    return <String, Object?>{
      'width': canvasWidth,
      'height': canvasHeight,
      'canvasWidth': canvasWidth,
      'canvasHeight': canvasHeight,
      'durationMs': durationMs,
      'fps': fps,
      'currentTimeMs': state.playheadMs,
      'currentFrame': currentFrame,
      'coordinateSystem': state.coordinateSystem,
      'origin': state.origin,
      'aspectRatio': canvasHeight == 0 ? null : canvasWidth / canvasHeight,
      'canvas': <String, Object?>{
        'width': canvasWidth,
        'height': canvasHeight,
        'durationMs': durationMs,
        'fps': fps,
        'coordinateSystem': state.coordinateSystem,
        'origin': state.origin,
      },
      'safeZones': <String, Object?>{
        'title': <String, Object?>{
          'top': (canvasHeight * 0.1).round(),
          'bottom': (canvasHeight * 0.1).round(),
          'left': (canvasWidth * 0.06).round(),
          'right': (canvasWidth * 0.06).round(),
        },
        'action': <String, Object?>{
          'top': (canvasHeight * 0.05).round(),
          'bottom': (canvasHeight * 0.05).round(),
          'left': (canvasWidth * 0.03).round(),
          'right': (canvasWidth * 0.03).round(),
        },
      },
      'anchors': <String, Object?>{
        'topLeft': <String, Object?>{'x': -halfWidth, 'y': -halfHeight},
        'topCenter': <String, Object?>{'x': 0.0, 'y': -halfHeight},
        'topRight': <String, Object?>{'x': halfWidth, 'y': -halfHeight},
        'centerLeft': <String, Object?>{'x': -halfWidth, 'y': 0.0},
        'center': <String, Object?>{'x': 0.0, 'y': 0.0},
        'centerRight': <String, Object?>{'x': halfWidth, 'y': 0.0},
        'bottomLeft': <String, Object?>{'x': -halfWidth, 'y': halfHeight},
        'bottomCenter': <String, Object?>{'x': 0.0, 'y': halfHeight},
        'bottomRight': <String, Object?>{'x': halfWidth, 'y': halfHeight},
      },
    };
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

  Map<String, Object?> _contextResponseFromState({
    required RefusionMcpCloudContextState state,
    required String projectId,
    required String compositionId,
  }) {
    return <String, Object?>{
      'structuredContent': <String, Object?>{
        'ok': true,
        'summary': 'Local app context fallback.',
        'payload': <String, Object?>{
          'hasProject': true,
          'project': <String, Object?>{
            'id': projectId,
            'name': 'MCP Project',
            'revision': state.timelineRevision,
          },
          'composition': <String, Object?>{
            'id': compositionId,
            'name': 'Story',
          },
          'timeline': <String, Object?>{
            'id': state.timelineId,
            'playheadMs': state.playheadMs,
          },
          'liveEditor': <String, Object?>{
            'online': _foreground && state.foreground,
            'deviceId': _deviceId,
            'foreground': _foreground && state.foreground,
            if (_normalizedWorkspaceIdentifierOrNull(state.workspaceId) != null)
              'workspaceId': _normalizedWorkspaceIdentifierOrNull(
                state.workspaceId,
              ),
          },
        },
      },
    };
  }

  Future<Map<String, Object?>?> _safeCallTool({
    required String toolName,
    required Map<String, Object?> arguments,
    bool allowAgentSessionToken = false,
    Duration? softTimeout,
  }) async {
    try {
      final callFuture = _callTool(
        toolName: toolName,
        arguments: arguments,
        allowAgentSessionToken: allowAgentSessionToken,
      );
      if (softTimeout != null) {
        return await callFuture.timeout(softTimeout);
      }
      return await callFuture;
    } catch (_) {
      return null;
    }
  }

  void _fireAndForgetTool({
    required String toolName,
    required Map<String, Object?> arguments,
    bool allowAgentSessionToken = false,
    Duration? softTimeout,
  }) {
    unawaited(
      _safeCallTool(
        toolName: toolName,
        arguments: arguments,
        allowAgentSessionToken: allowAgentSessionToken,
        softTimeout: softTimeout,
      ),
    );
  }

  Future<RefusionMcpCloudPairingCode> generatePairingCode() async {
    final state = _contextReader();
    final projectIdArg = _normalizedProjectIdentifierOrNull(state.projectId);
    final compositionIdArg =
        _normalizedCompositionIdentifierOrNull(state.compositionId);
    final workspaceIdArg =
        _normalizedWorkspaceIdentifierOrNull(state.workspaceId);
    final hasActiveComposition =
        projectIdArg != null && compositionIdArg != null;
    final response = await _callTool(
      toolName: 'generate_pairing_code',
      arguments: <String, Object?>{
        'deviceId': _deviceId,
        'hasActiveComposition': hasActiveComposition,
        if (projectIdArg != null) 'projectId': projectIdArg,
        if (compositionIdArg != null) 'compositionId': compositionIdArg,
        if (workspaceIdArg != null) 'workspaceId': workspaceIdArg,
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

class _DiagnosticsSyncRequest {
  const _DiagnosticsSyncRequest({
    required this.state,
    required this.contextResponse,
    required this.layersResponse,
    required this.motionChannelsResponse,
    required this.pendingCommandsResponse,
    required this.projectId,
    required this.compositionId,
  });

  final RefusionMcpCloudContextState state;
  final Map<String, Object?> contextResponse;
  final Map<String, Object?>? layersResponse;
  final Map<String, Object?>? motionChannelsResponse;
  final Map<String, Object?>? pendingCommandsResponse;
  final String projectId;
  final String compositionId;
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

String? _normalizedProjectIdentifierOrNull(String? value) {
  if (value == null) {
    return null;
  }
  final normalized = value.trim();
  if (normalized.isEmpty) {
    return null;
  }
  final lower = normalized.toLowerCase();
  if (const <String>{
    'active',
    'default',
    'motion-project',
    'project',
  }.contains(lower)) {
    return null;
  }
  return normalized;
}

String? _normalizedCompositionIdentifierOrNull(String? value) {
  if (value == null) {
    return null;
  }
  final normalized = value.trim();
  if (normalized.isEmpty) {
    return null;
  }
  final lower = normalized.toLowerCase();
  if (const <String>{
    'active-composition',
    'active',
    'scene-main',
    'comp_1',
    'main',
    'default',
  }.contains(lower)) {
    return null;
  }
  return normalized;
}

String? _normalizedWorkspaceIdentifierOrNull(String? value) {
  if (value == null) {
    return null;
  }
  final normalized = value.trim();
  if (normalized.isEmpty) {
    return null;
  }
  final lower = normalized.toLowerCase();
  if (const <String>{
    'active',
    'default',
    'workspace',
    'workspace-main',
    'main',
  }.contains(lower)) {
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
