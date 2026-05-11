import 'package:meta/meta.dart';

import '../../domain/mcp/refusion_mcp_agent_control_plane.dart';
import '../../domain/mcp/refusion_mcp_audit_log.dart';
import '../../domain/mcp/refusion_mcp_audit_persistence.dart';
import '../../domain/mcp/refusion_mcp_capability.dart';
import '../../domain/mcp/refusion_mcp_command_result.dart';
import '../../domain/mcp/refusion_mcp_hardening_policy.dart';
import '../../domain/mcp/refusion_mcp_prompt_provider.dart';
import '../../domain/mcp/refusion_mcp_resource_provider.dart';
import '../../domain/mcp/refusion_mcp_security_policy.dart';
import '../../domain/mcp/refusion_mcp_session.dart';
import '../../domain/mcp/refusion_mcp_session_store.dart';

@immutable
class RefusionMcpBridgeHealth {
  const RefusionMcpBridgeHealth({
    required this.ready,
    required this.sessionCount,
    required this.toolCount,
    required this.resourceCount,
  });

  final bool ready;
  final int sessionCount;
  final int toolCount;
  final int resourceCount;
}

class RefusionMcpAppBridge {
  RefusionMcpAppBridge({
    required RefusionMcpAgentControlPlane controlPlane,
    required RefusionMcpSessionStore sessionStore,
    required RefusionMcpResourceProvider resourceProvider,
    RefusionMcpPromptProvider? promptProvider,
    RefusionMcpSecurityPolicy securityPolicy =
        const RefusionMcpSecurityPolicy(),
    RefusionMcpHardeningPolicy? hardeningPolicy,
    RefusionMcpAuditLog? auditLog,
    RefusionMcpAuditPersistence? auditPersistence,
  })  : _controlPlane = controlPlane,
        _sessionStore = sessionStore,
        _resourceProvider = resourceProvider,
        _promptProvider = promptProvider ?? RefusionMcpPromptProvider(),
        _securityPolicy = securityPolicy,
        _hardeningPolicy = hardeningPolicy ?? RefusionMcpHardeningPolicy(),
        _auditLog = auditLog ??
            RefusionMcpAuditLog(
              persistence: auditPersistence,
            ) {
    _resourceProvider.registerReader(
      uri: 'refusion://mcp/audit/recent',
      reader: () {
        return <String, Object?>{
          'entries': _auditLog
              .recent(limit: 100)
              .map((entry) => entry.toJson())
              .toList(growable: false),
        };
      },
    );
  }

  final RefusionMcpAgentControlPlane _controlPlane;
  final RefusionMcpSessionStore _sessionStore;
  final RefusionMcpResourceProvider _resourceProvider;
  final RefusionMcpPromptProvider _promptProvider;
  final RefusionMcpSecurityPolicy _securityPolicy;
  final RefusionMcpHardeningPolicy _hardeningPolicy;
  final RefusionMcpAuditLog _auditLog;

  void openSession(RefusionMcpSession session) {
    _sessionStore.upsert(session);
    _auditLog.record(
      category: 'session',
      action: 'open',
      clientName: session.clientName,
      sessionId: session.id,
      ok: true,
      details: <String, Object?>{
        'capabilities': session.grantedCapabilities
            .map((capability) => capability.value)
            .toList(growable: false),
      },
    );
  }

  bool closeSession(String sessionId) {
    final session =
        _sessionStore.list().where((entry) => entry.id == sessionId);
    final clientName = session.isEmpty ? 'unknown' : session.first.clientName;
    final removed = _sessionStore.remove(sessionId);
    _auditLog.record(
      category: 'session',
      action: 'close',
      clientName: clientName,
      sessionId: sessionId,
      ok: removed,
    );
    return removed;
  }

  List<RefusionMcpSession> listSessions() {
    return _sessionStore.list();
  }

  List<String> listTools() {
    return _controlPlane.listTools();
  }

  List<String> listResourceUris() {
    return _resourceProvider.listUris();
  }

  List<RefusionMcpPromptDescriptor> listPrompts() {
    return _promptProvider.list();
  }

  RefusionMcpPromptResult getPrompt(String name) {
    return _promptProvider.get(name);
  }

  Set<RefusionMcpCapability> grantCapabilities(
    Set<RefusionMcpCapability> requested,
  ) {
    return _securityPolicy.grantRequestedCapabilities(requested);
  }

  RefusionMcpResourceResult readResource(String uri) {
    final result = _resourceProvider.read(uri);
    _auditLog.record(
      category: 'resource',
      action: 'read',
      clientName: 'system',
      sessionId: 'n/a',
      ok: result.ok,
      details: <String, Object?>{
        'uri': uri,
        'code': result.code?.name,
      },
    );
    return result;
  }

  RefusionMcpCommandResult executeTool(RefusionMcpToolCallRequest request) {
    if (!_hardeningPolicy.isPayloadWithinLimit(request.payload)) {
      return RefusionMcpCommandResult.failure(
        sessionId: request.sessionId,
        revisionBefore: 0,
        code: RefusionMcpCommandErrorCode.payloadTooLarge,
        message:
            'Payload exceeds max size (${_hardeningPolicy.maxToolPayloadBytes} bytes).',
        details: <String, Object?>{
          'payloadBytes': _hardeningPolicy.payloadBytes(request.payload),
          'maxPayloadBytes': _hardeningPolicy.maxToolPayloadBytes,
        },
      );
    }
    if (!_hardeningPolicy.allowToolCallForSession(request.sessionId)) {
      return RefusionMcpCommandResult.failure(
        sessionId: request.sessionId,
        revisionBefore: 0,
        code: RefusionMcpCommandErrorCode.rateLimited,
        message: 'Tool call rate limit exceeded for this session.',
      );
    }
    final startedAt = DateTime.now().toUtc();
    final result = _controlPlane.executeTool(request);
    final elapsedMs =
        DateTime.now().toUtc().difference(startedAt).inMilliseconds;
    _auditLog.record(
      category: 'tool',
      action: 'call',
      clientName: 'agent',
      sessionId: request.sessionId,
      ok: result.ok,
      toolName: request.toolName,
      revisionBefore: result.revisionBefore,
      revisionAfter: result.revisionAfter,
      details: <String, Object?>{
        'durationMs': elapsedMs,
        'mode': request.mode.name,
        'errorCode': result.error?.code.name,
      },
    );
    return _withTelemetryPayload(result, elapsedMs: elapsedMs);
  }

  RefusionMcpHardeningPolicy get hardeningPolicy => _hardeningPolicy;

  RefusionMcpCommandResult _withTelemetryPayload(
    RefusionMcpCommandResult result, {
    required int elapsedMs,
  }) {
    final nextPayload = <String, Object?>{
      ...result.payload,
      'telemetry': <String, Object?>{
        'durationMs': elapsedMs,
      },
      'progress': <String, Object?>{
        'state': 'completed',
        'percent': 100,
      },
    };
    return RefusionMcpCommandResult(
      ok: result.ok,
      summary: result.summary,
      sessionId: result.sessionId,
      revisionBefore: result.revisionBefore,
      revisionAfter: result.revisionAfter,
      transactionId: result.transactionId,
      requiresConfirmation: result.requiresConfirmation,
      error: result.error,
      diagnostics: result.diagnostics,
      resourceUris: result.resourceUris,
      payload: nextPayload,
    );
  }

  RefusionMcpBridgeHealth health() {
    return RefusionMcpBridgeHealth(
      ready: true,
      sessionCount: _sessionStore.list().length,
      toolCount: _controlPlane.listTools().length,
      resourceCount: _resourceProvider.listUris().length,
    );
  }
}
