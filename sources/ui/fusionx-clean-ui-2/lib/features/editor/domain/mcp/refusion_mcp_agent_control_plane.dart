import 'package:meta/meta.dart';

import 'refusion_mcp_command.dart';
import 'refusion_mcp_command_bus.dart';
import 'refusion_mcp_command_result.dart';
import 'refusion_mcp_security_policy.dart';
import 'refusion_mcp_session.dart';
import 'refusion_mcp_session_store.dart';
import 'refusion_mcp_transaction.dart';
import 'refusion_mcp_tool_registry.dart';

typedef RefusionMcpRevisionReader = int Function();

@immutable
class RefusionMcpToolCallRequest {
  const RefusionMcpToolCallRequest({
    required this.toolName,
    required this.sessionId,
    required this.projectId,
    required this.commandId,
    required this.idempotencyKey,
    this.mode = RefusionMcpCommandMode.dryRun,
    this.expectedRevision,
    this.payload = const <String, Object?>{},
  });

  final String toolName;
  final String sessionId;
  final String projectId;
  final String commandId;
  final String idempotencyKey;
  final RefusionMcpCommandMode mode;
  final int? expectedRevision;
  final Map<String, Object?> payload;
}

class RefusionMcpAgentControlPlane {
  RefusionMcpAgentControlPlane({
    required RefusionMcpCommandBus commandBus,
    required RefusionMcpToolRegistry toolRegistry,
    required RefusionMcpSessionStore sessionStore,
    required RefusionMcpRevisionReader revisionReader,
    RefusionMcpSecurityPolicy securityPolicy =
        const RefusionMcpSecurityPolicy(),
  })  : _commandBus = commandBus,
        _toolRegistry = toolRegistry,
        _sessionStore = sessionStore,
        _revisionReader = revisionReader,
        _securityPolicy = securityPolicy;

  final RefusionMcpCommandBus _commandBus;
  final RefusionMcpToolRegistry _toolRegistry;
  final RefusionMcpSessionStore _sessionStore;
  final RefusionMcpRevisionReader _revisionReader;
  final RefusionMcpSecurityPolicy _securityPolicy;

  RefusionMcpCommandResult executeTool(RefusionMcpToolCallRequest request) {
    final revision = _revisionReader();
    final session = _sessionStore.get(request.sessionId);
    if (session == null) {
      return RefusionMcpCommandResult.failure(
        sessionId: request.sessionId,
        revisionBefore: revision,
        code: RefusionMcpCommandErrorCode.sessionNotFound,
        message: 'Session `${request.sessionId}` was not found.',
      );
    }
    switch (request.toolName) {
      case 'refusion.dry_run_command':
        return _dryRunCommand(
          request: request,
          session: session,
          revision: revision,
        );
      case 'refusion.commit_transaction':
        return _commandBus.commitTransaction(
          session: session,
          transactionId: _readTransactionId(request.payload),
          expectedRevision: request.expectedRevision ?? revision,
          actualRevision: revision,
        );
      case 'refusion.undo_transaction':
        return _commandBus.undo(
          session: session,
          currentRevision: revision,
        );
      case 'refusion.redo_transaction':
        return _commandBus.redo(
          session: session,
          currentRevision: revision,
        );
      case 'refusion.list_recent_transactions':
        return RefusionMcpCommandResult(
          ok: true,
          summary: 'Recent transactions loaded.',
          sessionId: session.id,
          revisionBefore: revision,
          revisionAfter: revision,
          payload: <String, Object?>{
            'pending': _commandBus.pendingTransactions
                .map((entry) => _serializePending(entry))
                .toList(growable: false),
            'recentCommitted': _commandBus.recentCommittedTransactions
                .map((entry) => _serializeCommitted(entry))
                .toList(growable: false),
          },
        );
      default:
        break;
    }
    final descriptor = _toolRegistry.find(request.toolName);
    if (descriptor == null) {
      return RefusionMcpCommandResult.failure(
        sessionId: request.sessionId,
        revisionBefore: revision,
        code: RefusionMcpCommandErrorCode.unsupportedCommand,
        message: 'Unknown tool `${request.toolName}`.',
      );
    }
    final normalizedRequest = _normalizeRequestWithCanonicalTransaction(
      request: request,
      descriptor: descriptor,
      session: session,
      revision: revision,
    );
    if (!normalizedRequest.ok) {
      return RefusionMcpCommandResult.failure(
        sessionId: request.sessionId,
        revisionBefore: revision,
        code: RefusionMcpCommandErrorCode.validationFailed,
        message: normalizedRequest.message ?? 'Invalid transaction.',
      );
    }
    final effectiveRequest = normalizedRequest.request ?? request;
    final securityResult = _securityPolicy.evaluateToolCall(
      context: RefusionMcpToolCallContext(
        requestedToolName: effectiveRequest.toolName,
        descriptor: descriptor,
        session: session,
        currentRevision: revision,
        mode: effectiveRequest.mode == RefusionMcpCommandMode.commit
            ? RefusionMcpSecurityMode.commit
            : RefusionMcpSecurityMode.dryRun,
        payload: effectiveRequest.payload,
      ),
    );
    if (securityResult != null) {
      return securityResult;
    }
    final command = RefusionMcpCommandEnvelope(
      commandId: effectiveRequest.commandId,
      sessionId: effectiveRequest.sessionId,
      projectId: effectiveRequest.projectId,
      type: effectiveRequest.toolName,
      capability: descriptor.capability,
      mode: effectiveRequest.mode,
      idempotencyKey: effectiveRequest.idempotencyKey,
      expectedRevision: effectiveRequest.expectedRevision,
      payload: effectiveRequest.payload,
    );
    return _commandBus.execute(
      session: session,
      command: command,
      currentRevision: revision,
    );
  }

  List<String> listTools() {
    return _toolRegistry
        .list()
        .map((tool) => tool.name)
        .toList(growable: false);
  }

  String _readTransactionId(Map<String, Object?> payload) {
    final value = payload['transactionId'];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return '';
  }

  _RequestNormalization _normalizeRequestWithCanonicalTransaction({
    required RefusionMcpToolCallRequest request,
    required RefusionMcpToolDescriptor descriptor,
    required RefusionMcpSession session,
    required int revision,
  }) {
    if (descriptor.mutating) {
      final identityValidation = _validateMutatingSessionIdentity(
        request: request,
        session: session,
      );
      if (!identityValidation.ok) {
        return identityValidation;
      }
    }
    var transaction = _readPayload(request.payload['transaction']);
    if (transaction.isEmpty && descriptor.mutating) {
      transaction = _synthesizeCanonicalTransaction(
        request: request,
        session: session,
        revision: revision,
      );
    }
    if (transaction.isEmpty) {
      return _RequestNormalization(ok: true, request: request);
    }
    final validation = _validateCanonicalTransaction(transaction);
    if (!validation.ok) {
      return _RequestNormalization(
        ok: false,
        message: validation.message,
      );
    }
    if (descriptor.mutating) {
      final scopeValidation = _validateMutatingTransactionScope(
        transaction: transaction,
        session: session,
      );
      if (!scopeValidation.ok) {
        return scopeValidation;
      }
    }
    final transactionProjectId = _readString(transaction['projectId']);
    final fallbackProjectId = transactionProjectId ?? request.projectId;
    final projectId = fallbackProjectId.trim().isEmpty
        ? request.projectId
        : fallbackProjectId;
    final transactionIdempotencyKey =
        _readString(transaction['idempotencyKey']);
    final idempotencyKey = (request.idempotencyKey.trim().isNotEmpty
            ? request.idempotencyKey
            : transactionIdempotencyKey) ??
        'txn-${DateTime.now().microsecondsSinceEpoch}';
    final transactionId = _readString(transaction['transactionId']);
    final commandId = request.commandId.trim().isNotEmpty
        ? request.commandId
        : (transactionId == null ? request.commandId : 'cmd_$transactionId');
    final expectedRevision =
        request.expectedRevision ?? _readInt(transaction['baseRevision']);
    final payload = <String, Object?>{
      ...request.payload,
      'transaction': transaction,
      if (request.payload['baseRevision'] == null &&
          transaction['baseRevision'] is int)
        'baseRevision': transaction['baseRevision'],
      if (request.payload['schemaVersion'] == null &&
          transaction['schemaVersion'] is int)
        'schemaVersion': transaction['schemaVersion'],
    };
    return _RequestNormalization(
      ok: true,
      request: RefusionMcpToolCallRequest(
        toolName: request.toolName,
        sessionId: request.sessionId,
        projectId: projectId,
        commandId: commandId,
        idempotencyKey: idempotencyKey,
        mode: request.mode,
        expectedRevision: expectedRevision,
        payload: payload,
      ),
    );
  }

  _RequestNormalization _validateCanonicalTransaction(
    Map<String, Object?> transaction,
  ) {
    final schemaVersion = _readInt(transaction['schemaVersion']);
    final baseRevision = _readInt(transaction['baseRevision']);
    final idempotencyKey = _readString(transaction['idempotencyKey']);
    final projectId = _readString(transaction['projectId']);
    final compositionId = _readString(transaction['compositionId']);
    final operations = transaction['operations'];
    final issues = <String>[];
    if (schemaVersion == null || schemaVersion <= 0) {
      issues.add('transaction.schemaVersion must be a positive integer');
    }
    if (baseRevision == null || baseRevision < 0) {
      issues.add('transaction.baseRevision must be >= 0');
    }
    if (idempotencyKey == null) {
      issues.add('transaction.idempotencyKey is required');
    }
    if (projectId == null) {
      issues.add('transaction.projectId is required');
    }
    if (compositionId == null) {
      issues.add('transaction.compositionId is required');
    }
    if (operations is! List || operations.isEmpty) {
      issues.add('transaction.operations must be a non-empty array');
    }
    if (issues.isNotEmpty) {
      return _RequestNormalization(
        ok: false,
        message:
            'Canonical transaction validation failed: ${issues.join('; ')}.',
      );
    }
    return _RequestNormalization(ok: true);
  }

  _RequestNormalization _validateMutatingSessionIdentity({
    required RefusionMcpToolCallRequest request,
    required RefusionMcpSession session,
  }) {
    final activeProjectId = _normalizeProjectIdentity(session.activeProjectId);
    final activeCompositionId =
        _normalizeCompositionIdentity(session.activeCompositionId);
    if (activeProjectId == null || activeCompositionId == null) {
      return _RequestNormalization(
        ok: false,
        message:
            'Mutating MCP commands require a real active workspace identity before execution.',
      );
    }
    final requestedProjectId = _normalizeProjectIdentity(request.projectId);
    if (requestedProjectId != null && requestedProjectId != activeProjectId) {
      return _RequestNormalization(
        ok: false,
        message:
            'Mutating MCP commands must target the active workspace project `${activeProjectId}`.',
      );
    }
    return _RequestNormalization(ok: true);
  }

  _RequestNormalization _validateMutatingTransactionScope({
    required Map<String, Object?> transaction,
    required RefusionMcpSession session,
  }) {
    final activeProjectId = _normalizeProjectIdentity(session.activeProjectId);
    final activeCompositionId =
        _normalizeCompositionIdentity(session.activeCompositionId);
    if (activeProjectId == null || activeCompositionId == null) {
      return _RequestNormalization(
        ok: false,
        message:
            'Mutating MCP commands require a real active workspace identity before execution.',
      );
    }
    final transactionProjectId =
        _normalizeProjectIdentity(_readString(transaction['projectId']));
    if (transactionProjectId == null ||
        transactionProjectId != activeProjectId) {
      return _RequestNormalization(
        ok: false,
        message:
            'Mutating transaction project scope must match active workspace project `${activeProjectId}`.',
      );
    }
    final transactionCompositionId = _normalizeCompositionIdentity(
      _readString(transaction['compositionId']),
    );
    if (transactionCompositionId == null ||
        transactionCompositionId != activeCompositionId) {
      return _RequestNormalization(
        ok: false,
        message:
            'Mutating transaction composition scope must match active workspace composition `${activeCompositionId}`.',
      );
    }
    return _RequestNormalization(ok: true);
  }

  Map<String, Object?> _synthesizeCanonicalTransaction({
    required RefusionMcpToolCallRequest request,
    required RefusionMcpSession session,
    required int revision,
  }) {
    final baseRevision = request.expectedRevision ?? revision;
    final safeProjectId =
        _normalizeProjectIdentity(session.activeProjectId) ?? request.projectId;
    final safeCompositionId =
        _normalizeCompositionIdentity(session.activeCompositionId) ??
            session.activeCompositionId.trim();
    return <String, Object?>{
      'transactionId': 'txn_${request.commandId}',
      'schemaVersion': 1,
      'baseRevision': baseRevision < 0 ? 0 : baseRevision,
      'idempotencyKey': request.idempotencyKey.trim().isEmpty
          ? 'mcp-${DateTime.now().microsecondsSinceEpoch}'
          : request.idempotencyKey,
      'projectId': safeProjectId,
      'compositionId': safeCompositionId,
      'intent': _intentForToolName(request.toolName),
      'operations': <Map<String, Object?>>[
        <String, Object?>{
          'kind': request.toolName,
          'payload': request.payload,
        },
      ],
      'source': 'mcpAgent',
    };
  }

  String _intentForToolName(String toolName) {
    switch (toolName) {
      case 'refusion.insert_layer':
        return 'layerInsert';
      case 'refusion.update_layer':
      case 'refusion.set_text_style':
        return 'layerUpdate';
      case 'refusion.delete_layer':
        return 'layerDelete';
      case 'refusion.apply_motion_patch':
      case 'refusion.keyframe_edit':
      case 'refusion.set_element_transform':
        return 'keyframeBatchApply';
      case 'refusion.set_layer_style':
      case 'refusion.set_border':
      case 'refusion.set_glow':
      case 'refusion.set_layer_mask':
        return 'effectApply';
      default:
        return 'layerUpdate';
    }
  }

  RefusionMcpCommandResult _dryRunCommand({
    required RefusionMcpToolCallRequest request,
    required RefusionMcpSession session,
    required int revision,
  }) {
    final targetToolName = request.payload['toolName'] as String?;
    if (targetToolName == null || targetToolName.trim().isEmpty) {
      return RefusionMcpCommandResult.failure(
        sessionId: session.id,
        revisionBefore: revision,
        code: RefusionMcpCommandErrorCode.validationFailed,
        message: 'dry_run_command requires payload.toolName.',
      );
    }
    if (targetToolName == 'refusion.dry_run_command') {
      return RefusionMcpCommandResult.failure(
        sessionId: session.id,
        revisionBefore: revision,
        code: RefusionMcpCommandErrorCode.validationFailed,
        message: 'dry_run_command cannot target itself.',
      );
    }
    final nestedPayload = _readPayload(request.payload['payload']);
    final nestedRequest = RefusionMcpToolCallRequest(
      toolName: targetToolName,
      sessionId: request.sessionId,
      projectId: request.projectId,
      commandId: '${request.commandId}:dryrun',
      idempotencyKey: '${request.idempotencyKey}:dryrun',
      mode: RefusionMcpCommandMode.dryRun,
      expectedRevision: request.expectedRevision,
      payload: nestedPayload,
    );
    return executeTool(nestedRequest);
  }

  Map<String, Object?> _readPayload(Object? payload) {
    if (payload is Map<String, Object?>) {
      return payload;
    }
    if (payload is Map) {
      final casted = <String, Object?>{};
      for (final entry in payload.entries) {
        if (entry.key is String) {
          casted[entry.key as String] = entry.value;
        }
      }
      return casted;
    }
    return const <String, Object?>{};
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

  String? _readString(Object? value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }

  String? _normalizeProjectIdentity(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
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

  String? _normalizeCompositionIdentity(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
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
      'composition_unknown',
    }.contains(lower)) {
      return null;
    }
    return normalized;
  }

  Map<String, Object?> _serializePending(RefusionMcpPendingTransaction value) {
    return <String, Object?>{
      'id': value.id,
      'commandType': value.command.type,
      'capability': value.command.capability.value,
      'revisionBefore': value.revisionBefore,
      'summary': value.summary,
      'createdAtUtc': value.createdAt.toIso8601String(),
      'affectedObjects': value.patchPreview.affectedObjects,
      'changedProperties': value.patchPreview.changedProperties,
    };
  }

  Map<String, Object?> _serializeCommitted(
    RefusionMcpCommittedTransaction value,
  ) {
    return <String, Object?>{
      'id': value.id,
      'commandType': value.command.type,
      'capability': value.command.capability.value,
      'revisionBefore': value.revisionBefore,
      'revisionAfter': value.revisionAfter,
      'summary': value.summary,
      'committedAtUtc': value.committedAt.toIso8601String(),
    };
  }
}

class _RequestNormalization {
  const _RequestNormalization({
    required this.ok,
    this.request,
    this.message,
  });

  final bool ok;
  final RefusionMcpToolCallRequest? request;
  final String? message;
}
