import 'package:meta/meta.dart';

import 'refusion_mcp_capability.dart';

enum RefusionMcpCommandMode {
  dryRun,
  commit,
}

enum RefusionMcpCommandIssueCode {
  missingCommandId,
  missingSessionId,
  missingProjectId,
  missingIdempotencyKey,
  missingType,
  missingExpectedRevision,
}

@immutable
class RefusionMcpCommandIssue {
  const RefusionMcpCommandIssue({
    required this.code,
    required this.message,
  });

  final RefusionMcpCommandIssueCode code;
  final String message;
}

@immutable
class RefusionMcpCommandEnvelope {
  RefusionMcpCommandEnvelope({
    required this.commandId,
    required this.sessionId,
    required this.projectId,
    required this.type,
    required this.capability,
    required this.mode,
    required this.idempotencyKey,
    this.expectedRevision,
    Map<String, Object?> payload = const <String, Object?>{},
  }) : payload = Map.unmodifiable(payload);

  final String commandId;
  final String sessionId;
  final String projectId;
  final String type;
  final RefusionMcpCapability capability;
  final RefusionMcpCommandMode mode;
  final String idempotencyKey;
  final int? expectedRevision;
  final Map<String, Object?> payload;

  bool get isMutation => mode == RefusionMcpCommandMode.commit;

  List<RefusionMcpCommandIssue> validate() {
    final issues = <RefusionMcpCommandIssue>[];
    if (commandId.trim().isEmpty) {
      issues.add(
        const RefusionMcpCommandIssue(
          code: RefusionMcpCommandIssueCode.missingCommandId,
          message: 'commandId is required.',
        ),
      );
    }
    if (sessionId.trim().isEmpty) {
      issues.add(
        const RefusionMcpCommandIssue(
          code: RefusionMcpCommandIssueCode.missingSessionId,
          message: 'sessionId is required.',
        ),
      );
    }
    if (projectId.trim().isEmpty) {
      issues.add(
        const RefusionMcpCommandIssue(
          code: RefusionMcpCommandIssueCode.missingProjectId,
          message: 'projectId is required.',
        ),
      );
    }
    if (type.trim().isEmpty) {
      issues.add(
        const RefusionMcpCommandIssue(
          code: RefusionMcpCommandIssueCode.missingType,
          message: 'command type is required.',
        ),
      );
    }
    if (idempotencyKey.trim().isEmpty) {
      issues.add(
        const RefusionMcpCommandIssue(
          code: RefusionMcpCommandIssueCode.missingIdempotencyKey,
          message: 'idempotencyKey is required.',
        ),
      );
    }
    if (isMutation && expectedRevision == null) {
      issues.add(
        const RefusionMcpCommandIssue(
          code: RefusionMcpCommandIssueCode.missingExpectedRevision,
          message: 'expectedRevision is required for commit mode.',
        ),
      );
    }
    return issues;
  }
}
