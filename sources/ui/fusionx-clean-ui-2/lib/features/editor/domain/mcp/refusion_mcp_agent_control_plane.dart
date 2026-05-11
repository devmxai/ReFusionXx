import 'package:flutter/foundation.dart';

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
    final securityResult = _securityPolicy.evaluateToolCall(
      context: RefusionMcpToolCallContext(
        requestedToolName: request.toolName,
        descriptor: descriptor,
        session: session,
        currentRevision: revision,
        mode: request.mode == RefusionMcpCommandMode.commit
            ? RefusionMcpSecurityMode.commit
            : RefusionMcpSecurityMode.dryRun,
        payload: request.payload,
      ),
    );
    if (securityResult != null) {
      return securityResult;
    }
    final command = RefusionMcpCommandEnvelope(
      commandId: request.commandId,
      sessionId: request.sessionId,
      projectId: request.projectId,
      type: request.toolName,
      capability: descriptor.capability,
      mode: request.mode,
      idempotencyKey: request.idempotencyKey,
      expectedRevision: request.expectedRevision,
      payload: request.payload,
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
