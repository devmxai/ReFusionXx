import 'package:meta/meta.dart';

import 'refusion_mcp_command_result.dart';
import 'refusion_mcp_transaction.dart';

@immutable
class RefusionMcpTransactionCommitResult {
  const RefusionMcpTransactionCommitResult({
    required this.transaction,
    required this.revisionAfter,
  });

  final RefusionMcpCommittedTransaction transaction;
  final int revisionAfter;
}

@immutable
class RefusionMcpTransactionManagerUndoResult {
  const RefusionMcpTransactionManagerUndoResult({
    required this.transaction,
    required this.revisionAfter,
  });

  final RefusionMcpCommittedTransaction transaction;
  final int revisionAfter;
}

@immutable
class RefusionMcpTransactionManagerRedoResult {
  const RefusionMcpTransactionManagerRedoResult({
    required this.transaction,
    required this.revisionAfter,
  });

  final RefusionMcpCommittedTransaction transaction;
  final int revisionAfter;
}

class RefusionMcpTransactionManager {
  RefusionMcpTransactionManager({
    String Function()? idFactory,
    DateTime Function()? clock,
  })  : _idFactory = idFactory ?? _defaultIdFactory,
        _clock = clock ?? (() => DateTime.now().toUtc());

  final String Function() _idFactory;
  final DateTime Function() _clock;
  final Map<String, _PendingEntry> _pendingById = <String, _PendingEntry>{};
  final List<_CommittedEntry> _undoStack = <_CommittedEntry>[];
  final List<_CommittedEntry> _redoStack = <_CommittedEntry>[];

  List<RefusionMcpPendingTransaction> get pendingTransactions {
    return _pendingById.values
        .map((entry) => entry.pending)
        .toList(growable: false);
  }

  List<RefusionMcpCommittedTransaction> get recentCommittedTransactions {
    return _undoStack
        .map((entry) => entry.committed)
        .toList(growable: false)
        .reversed
        .toList(growable: false);
  }

  RefusionMcpPendingTransaction stage(RefusionMcpTransactionDraft draft) {
    final transactionId = _idFactory();
    final pending = RefusionMcpPendingTransaction(
      id: transactionId,
      command: draft.command,
      revisionBefore: draft.revisionBefore,
      summary: draft.summary,
      patchPreview: draft.patchPreview,
      createdAt: _clock(),
    );
    _pendingById[transactionId] = _PendingEntry(
      pending: pending,
      commitOperation: draft.commit,
    );
    return pending;
  }

  RefusionMcpTransactionCommitResult commit({
    required String transactionId,
    required int expectedRevision,
    required int actualRevision,
  }) {
    if (expectedRevision != actualRevision) {
      throw RefusionMcpTransactionManagerException(
        code: RefusionMcpCommandErrorCode.revisionConflict,
        message: 'Expected revision $expectedRevision does not match actual '
            'revision $actualRevision.',
      );
    }
    final pendingEntry = _pendingById.remove(transactionId);
    if (pendingEntry == null) {
      throw const RefusionMcpTransactionManagerException(
        code: RefusionMcpCommandErrorCode.transactionNotFound,
        message: 'Pending transaction not found.',
      );
    }
    final RefusionMcpCommitExecution commit;
    try {
      commit = pendingEntry.commitOperation();
    } catch (error) {
      throw RefusionMcpTransactionManagerException(
        code: RefusionMcpCommandErrorCode.internalError,
        message: 'Transaction commit failed: $error',
      );
    }
    final committed = RefusionMcpCommittedTransaction(
      id: pendingEntry.pending.id,
      command: pendingEntry.pending.command,
      revisionBefore: pendingEntry.pending.revisionBefore,
      revisionAfter: commit.revisionAfter,
      summary: commit.summary ?? pendingEntry.pending.summary,
      committedAt: _clock(),
    );
    _undoStack.add(
      _CommittedEntry(
        committed: committed,
        undo: commit.undo,
        redo: commit.redo,
      ),
    );
    _redoStack.clear();
    return RefusionMcpTransactionCommitResult(
      transaction: committed,
      revisionAfter: commit.revisionAfter,
    );
  }

  RefusionMcpTransactionManagerUndoResult undo() {
    if (_undoStack.isEmpty) {
      throw const RefusionMcpTransactionManagerException(
        code: RefusionMcpCommandErrorCode.transactionNotFound,
        message: 'No committed transaction to undo.',
      );
    }
    final entry = _undoStack.removeLast();
    if (entry.undo == null) {
      throw const RefusionMcpTransactionManagerException(
        code: RefusionMcpCommandErrorCode.internalError,
        message: 'Undo operation is not available for this transaction.',
      );
    }
    final revisionAfter = entry.undo!.call();
    _redoStack.add(entry);
    return RefusionMcpTransactionManagerUndoResult(
      transaction: entry.committed,
      revisionAfter: revisionAfter,
    );
  }

  RefusionMcpTransactionManagerRedoResult redo() {
    if (_redoStack.isEmpty) {
      throw const RefusionMcpTransactionManagerException(
        code: RefusionMcpCommandErrorCode.transactionNotFound,
        message: 'No transaction available for redo.',
      );
    }
    final entry = _redoStack.removeLast();
    if (entry.redo == null) {
      throw const RefusionMcpTransactionManagerException(
        code: RefusionMcpCommandErrorCode.internalError,
        message: 'Redo operation is not available for this transaction.',
      );
    }
    final revisionAfter = entry.redo!.call();
    _undoStack.add(entry);
    return RefusionMcpTransactionManagerRedoResult(
      transaction: entry.committed,
      revisionAfter: revisionAfter,
    );
  }
}

@immutable
class RefusionMcpTransactionManagerException implements Exception {
  const RefusionMcpTransactionManagerException({
    required this.code,
    required this.message,
  });

  final RefusionMcpCommandErrorCode code;
  final String message;
}

class _PendingEntry {
  const _PendingEntry({
    required this.pending,
    required this.commitOperation,
  });

  final RefusionMcpPendingTransaction pending;
  final RefusionMcpCommitOperation commitOperation;
}

class _CommittedEntry {
  const _CommittedEntry({
    required this.committed,
    required this.undo,
    required this.redo,
  });

  final RefusionMcpCommittedTransaction committed;
  final RefusionMcpUndoOperation? undo;
  final RefusionMcpRedoOperation? redo;
}

String _defaultIdFactory() {
  return 'txn_${DateTime.now().microsecondsSinceEpoch}';
}
