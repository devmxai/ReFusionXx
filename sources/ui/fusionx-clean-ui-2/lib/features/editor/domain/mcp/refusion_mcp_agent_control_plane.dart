import 'package:flutter/foundation.dart';

import 'refusion_mcp_command.dart';
import 'refusion_mcp_command_bus.dart';
import 'refusion_mcp_command_result.dart';
import 'refusion_mcp_session_store.dart';
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
  })  : _commandBus = commandBus,
        _toolRegistry = toolRegistry,
        _sessionStore = sessionStore,
        _revisionReader = revisionReader;

  final RefusionMcpCommandBus _commandBus;
  final RefusionMcpToolRegistry _toolRegistry;
  final RefusionMcpSessionStore _sessionStore;
  final RefusionMcpRevisionReader _revisionReader;

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
}
