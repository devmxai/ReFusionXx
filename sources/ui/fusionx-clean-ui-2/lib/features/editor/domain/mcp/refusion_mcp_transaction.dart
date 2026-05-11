import 'package:flutter/foundation.dart';

import 'refusion_mcp_command.dart';

typedef RefusionMcpCommitOperation = RefusionMcpCommitExecution Function();
typedef RefusionMcpUndoOperation = int Function();
typedef RefusionMcpRedoOperation = int Function();

@immutable
class RefusionMcpPatchPreview {
  RefusionMcpPatchPreview({
    List<String> affectedObjects = const <String>[],
    List<String> changedProperties = const <String>[],
    List<String> diagnostics = const <String>[],
  })  : affectedObjects = List.unmodifiable(affectedObjects),
        changedProperties = List.unmodifiable(changedProperties),
        diagnostics = List.unmodifiable(diagnostics);

  final List<String> affectedObjects;
  final List<String> changedProperties;
  final List<String> diagnostics;
}

@immutable
class RefusionMcpCommitExecution {
  const RefusionMcpCommitExecution({
    required this.revisionAfter,
    this.summary,
    this.undo,
    this.redo,
  });

  final int revisionAfter;
  final String? summary;
  final RefusionMcpUndoOperation? undo;
  final RefusionMcpRedoOperation? redo;
}

@immutable
class RefusionMcpTransactionDraft {
  RefusionMcpTransactionDraft({
    required this.command,
    required this.revisionBefore,
    required this.summary,
    required this.commit,
    RefusionMcpPatchPreview? patchPreview,
  }) : patchPreview = patchPreview ?? RefusionMcpPatchPreview();

  final RefusionMcpCommandEnvelope command;
  final int revisionBefore;
  final String summary;
  final RefusionMcpPatchPreview patchPreview;
  final RefusionMcpCommitOperation commit;
}

@immutable
class RefusionMcpPendingTransaction {
  RefusionMcpPendingTransaction({
    required this.id,
    required this.command,
    required this.revisionBefore,
    required this.summary,
    required this.patchPreview,
    required this.createdAt,
  });

  final String id;
  final RefusionMcpCommandEnvelope command;
  final int revisionBefore;
  final String summary;
  final RefusionMcpPatchPreview patchPreview;
  final DateTime createdAt;
}

@immutable
class RefusionMcpCommittedTransaction {
  RefusionMcpCommittedTransaction({
    required this.id,
    required this.command,
    required this.revisionBefore,
    required this.revisionAfter,
    required this.summary,
    required this.committedAt,
  });

  final String id;
  final RefusionMcpCommandEnvelope command;
  final int revisionBefore;
  final int revisionAfter;
  final String summary;
  final DateTime committedAt;
}
