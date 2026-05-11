import 'package:flutter/foundation.dart';

import 'refusion_mcp_capability.dart';
import 'refusion_mcp_command.dart';
import 'refusion_mcp_command_result.dart';
import 'refusion_mcp_session.dart';
import 'refusion_mcp_transaction.dart';
import 'refusion_mcp_transaction_manager.dart';

typedef RefusionMcpCommandHandler = RefusionMcpCommandHandlingOutcome Function(
  RefusionMcpCommandHandlingContext context,
);

@immutable
class RefusionMcpCommandHandlingContext {
  const RefusionMcpCommandHandlingContext({
    required this.command,
    required this.session,
    required this.currentRevision,
  });

  final RefusionMcpCommandEnvelope command;
  final RefusionMcpSession session;
  final int currentRevision;
}

@immutable
class RefusionMcpCommandHandlingOutcome {
  RefusionMcpCommandHandlingOutcome({
    required this.summary,
    this.requiresConfirmation = false,
    RefusionMcpPatchPreview? patchPreview,
    this.diagnostics = const <String>[],
    this.resourceUris = const <String>[],
    this.payload = const <String, Object?>{},
    this.commitOperation,
  }) : patchPreview = patchPreview ?? RefusionMcpPatchPreview();

  final String summary;
  final bool requiresConfirmation;
  final RefusionMcpPatchPreview patchPreview;
  final List<String> diagnostics;
  final List<String> resourceUris;
  final Map<String, Object?> payload;
  final RefusionMcpCommitOperation? commitOperation;
}

class RefusionMcpCommandBus {
  RefusionMcpCommandBus({
    RefusionMcpTransactionManager? transactionManager,
  }) : _transactionManager =
            transactionManager ?? RefusionMcpTransactionManager();

  final RefusionMcpTransactionManager _transactionManager;
  final Map<String, RefusionMcpCommandHandler> _handlers =
      <String, RefusionMcpCommandHandler>{};

  void registerHandler({
    required String commandType,
    required RefusionMcpCommandHandler handler,
  }) {
    _handlers[commandType] = handler;
  }

  RefusionMcpCommandResult execute({
    required RefusionMcpSession session,
    required RefusionMcpCommandEnvelope command,
    required int currentRevision,
  }) {
    final issues = command.validate();
    if (issues.isNotEmpty) {
      return RefusionMcpCommandResult.failure(
        sessionId: session.id,
        revisionBefore: currentRevision,
        code: RefusionMcpCommandErrorCode.validationFailed,
        message: issues.first.message,
        details: <String, Object?>{
          'issues':
              issues.map((issue) => issue.message).toList(growable: false),
        },
      );
    }
    if (!session.hasCapability(command.capability)) {
      return RefusionMcpCommandResult.failure(
        sessionId: session.id,
        revisionBefore: currentRevision,
        code: RefusionMcpCommandErrorCode.capabilityDenied,
        message: 'Missing capability `${command.capability.value}`.',
      );
    }
    if (command.expectedRevision != null &&
        command.expectedRevision != currentRevision) {
      return RefusionMcpCommandResult.failure(
        sessionId: session.id,
        revisionBefore: currentRevision,
        code: RefusionMcpCommandErrorCode.revisionConflict,
        message: 'Expected revision ${command.expectedRevision} does not match '
            'actual revision $currentRevision.',
        details: <String, Object?>{
          'expectedRevision': command.expectedRevision,
          'actualRevision': currentRevision,
        },
      );
    }
    final handler = _handlers[command.type];
    if (handler == null) {
      return RefusionMcpCommandResult.failure(
        sessionId: session.id,
        revisionBefore: currentRevision,
        code: RefusionMcpCommandErrorCode.unsupportedCommand,
        message: 'Unsupported command type `${command.type}`.',
      );
    }

    final context = RefusionMcpCommandHandlingContext(
      command: command,
      session: session,
      currentRevision: currentRevision,
    );
    final outcome = handler(context);
    if (outcome.requiresConfirmation) {
      return RefusionMcpCommandResult.failure(
        sessionId: session.id,
        revisionBefore: currentRevision,
        code: RefusionMcpCommandErrorCode.confirmationRequired,
        message: outcome.summary,
        requiresConfirmation: true,
        diagnostics: outcome.diagnostics,
      );
    }
    final commitOperation = outcome.commitOperation;
    if (command.mode == RefusionMcpCommandMode.dryRun) {
      if (commitOperation == null) {
        return RefusionMcpCommandResult(
          ok: true,
          summary: outcome.summary,
          sessionId: session.id,
          revisionBefore: currentRevision,
          revisionAfter: currentRevision,
          diagnostics: outcome.diagnostics,
          resourceUris: outcome.resourceUris,
          payload: outcome.payload,
        );
      }
      final pending = _transactionManager.stage(
        RefusionMcpTransactionDraft(
          command: command,
          revisionBefore: currentRevision,
          summary: outcome.summary,
          commit: commitOperation,
          patchPreview: outcome.patchPreview,
        ),
      );
      return RefusionMcpCommandResult(
        ok: true,
        summary: outcome.summary,
        sessionId: session.id,
        revisionBefore: currentRevision,
        revisionAfter: currentRevision,
        transactionId: pending.id,
        diagnostics: outcome.diagnostics,
        resourceUris: outcome.resourceUris,
        payload: <String, Object?>{
          ...outcome.payload,
          'pending': true,
          'patchPreview': <String, Object?>{
            'affectedObjects': pending.patchPreview.affectedObjects,
            'changedProperties': pending.patchPreview.changedProperties,
            'diagnostics': pending.patchPreview.diagnostics,
          },
        },
      );
    }
    if (commitOperation == null) {
      return RefusionMcpCommandResult(
        ok: true,
        summary: outcome.summary,
        sessionId: session.id,
        revisionBefore: currentRevision,
        revisionAfter: currentRevision,
        diagnostics: outcome.diagnostics,
        resourceUris: outcome.resourceUris,
        payload: outcome.payload,
      );
    }
    final staged = _transactionManager.stage(
      RefusionMcpTransactionDraft(
        command: command,
        revisionBefore: currentRevision,
        summary: outcome.summary,
        commit: commitOperation,
        patchPreview: outcome.patchPreview,
      ),
    );
    try {
      final committed = _transactionManager.commit(
        transactionId: staged.id,
        expectedRevision: command.expectedRevision ?? currentRevision,
        actualRevision: currentRevision,
      );
      return RefusionMcpCommandResult(
        ok: true,
        summary: committed.transaction.summary,
        sessionId: session.id,
        revisionBefore: currentRevision,
        revisionAfter: committed.revisionAfter,
        transactionId: committed.transaction.id,
        diagnostics: outcome.diagnostics,
        resourceUris: outcome.resourceUris,
        payload: outcome.payload,
      );
    } on RefusionMcpTransactionManagerException catch (error) {
      return RefusionMcpCommandResult.failure(
        sessionId: session.id,
        revisionBefore: currentRevision,
        code: error.code,
        message: error.message,
      );
    }
  }

  RefusionMcpCommandResult commitTransaction({
    required RefusionMcpSession session,
    required String transactionId,
    required int expectedRevision,
    required int actualRevision,
  }) {
    if (!session.hasCapability(RefusionMcpCapability.timelineWrite) &&
        !session.hasCapability(RefusionMcpCapability.motionWrite) &&
        !session.hasCapability(RefusionMcpCapability.sceneWrite)) {
      return RefusionMcpCommandResult.failure(
        sessionId: session.id,
        revisionBefore: actualRevision,
        code: RefusionMcpCommandErrorCode.capabilityDenied,
        message: 'Missing write capability for transaction commit.',
      );
    }
    try {
      final committed = _transactionManager.commit(
        transactionId: transactionId,
        expectedRevision: expectedRevision,
        actualRevision: actualRevision,
      );
      return RefusionMcpCommandResult(
        ok: true,
        summary: committed.transaction.summary,
        sessionId: session.id,
        revisionBefore: actualRevision,
        revisionAfter: committed.revisionAfter,
        transactionId: committed.transaction.id,
      );
    } on RefusionMcpTransactionManagerException catch (error) {
      return RefusionMcpCommandResult.failure(
        sessionId: session.id,
        revisionBefore: actualRevision,
        code: error.code,
        message: error.message,
      );
    }
  }

  RefusionMcpCommandResult undo({
    required RefusionMcpSession session,
    required int currentRevision,
  }) {
    if (!session.hasCapability(RefusionMcpCapability.timelineWrite) &&
        !session.hasCapability(RefusionMcpCapability.motionWrite) &&
        !session.hasCapability(RefusionMcpCapability.sceneWrite)) {
      return RefusionMcpCommandResult.failure(
        sessionId: session.id,
        revisionBefore: currentRevision,
        code: RefusionMcpCommandErrorCode.capabilityDenied,
        message: 'Missing write capability for undo.',
      );
    }
    try {
      final undone = _transactionManager.undo();
      return RefusionMcpCommandResult(
        ok: true,
        summary: 'Undo ${undone.transaction.summary}',
        sessionId: session.id,
        revisionBefore: currentRevision,
        revisionAfter: undone.revisionAfter,
        transactionId: undone.transaction.id,
      );
    } on RefusionMcpTransactionManagerException catch (error) {
      return RefusionMcpCommandResult.failure(
        sessionId: session.id,
        revisionBefore: currentRevision,
        code: error.code,
        message: error.message,
      );
    }
  }

  RefusionMcpCommandResult redo({
    required RefusionMcpSession session,
    required int currentRevision,
  }) {
    if (!session.hasCapability(RefusionMcpCapability.timelineWrite) &&
        !session.hasCapability(RefusionMcpCapability.motionWrite) &&
        !session.hasCapability(RefusionMcpCapability.sceneWrite)) {
      return RefusionMcpCommandResult.failure(
        sessionId: session.id,
        revisionBefore: currentRevision,
        code: RefusionMcpCommandErrorCode.capabilityDenied,
        message: 'Missing write capability for redo.',
      );
    }
    try {
      final redone = _transactionManager.redo();
      return RefusionMcpCommandResult(
        ok: true,
        summary: 'Redo ${redone.transaction.summary}',
        sessionId: session.id,
        revisionBefore: currentRevision,
        revisionAfter: redone.revisionAfter,
        transactionId: redone.transaction.id,
      );
    } on RefusionMcpTransactionManagerException catch (error) {
      return RefusionMcpCommandResult.failure(
        sessionId: session.id,
        revisionBefore: currentRevision,
        code: error.code,
        message: error.message,
      );
    }
  }

  List<RefusionMcpPendingTransaction> get pendingTransactions {
    return _transactionManager.pendingTransactions;
  }

  List<RefusionMcpCommittedTransaction> get recentCommittedTransactions {
    return _transactionManager.recentCommittedTransactions;
  }
}
