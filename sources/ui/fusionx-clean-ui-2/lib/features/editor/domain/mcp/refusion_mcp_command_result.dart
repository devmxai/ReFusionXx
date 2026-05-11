import 'package:flutter/foundation.dart';

enum RefusionMcpCommandErrorCode {
  sessionNotFound,
  capabilityDenied,
  revisionConflict,
  validationFailed,
  transactionNotFound,
  confirmationRequired,
  projectNotOpen,
  selectionEmpty,
  previewUnavailable,
  bridgeUnavailable,
  timeout,
  unsupportedCommand,
  internalError,
}

@immutable
class RefusionMcpCommandError {
  const RefusionMcpCommandError({
    required this.code,
    required this.message,
    this.details = const <String, Object?>{},
  });

  final RefusionMcpCommandErrorCode code;
  final String message;
  final Map<String, Object?> details;
}

@immutable
class RefusionMcpCommandResult {
  RefusionMcpCommandResult({
    required this.ok,
    required this.summary,
    required this.sessionId,
    required this.revisionBefore,
    this.revisionAfter,
    this.transactionId,
    this.requiresConfirmation = false,
    this.error,
    List<String> diagnostics = const <String>[],
    List<String> resourceUris = const <String>[],
    Map<String, Object?> payload = const <String, Object?>{},
  })  : diagnostics = List.unmodifiable(diagnostics),
        resourceUris = List.unmodifiable(resourceUris),
        payload = Map.unmodifiable(payload);

  final bool ok;
  final String summary;
  final String sessionId;
  final int revisionBefore;
  final int? revisionAfter;
  final String? transactionId;
  final bool requiresConfirmation;
  final RefusionMcpCommandError? error;
  final List<String> diagnostics;
  final List<String> resourceUris;
  final Map<String, Object?> payload;

  factory RefusionMcpCommandResult.failure({
    required String sessionId,
    required int revisionBefore,
    required RefusionMcpCommandErrorCode code,
    required String message,
    Map<String, Object?> details = const <String, Object?>{},
    List<String> diagnostics = const <String>[],
    bool requiresConfirmation = false,
  }) {
    return RefusionMcpCommandResult(
      ok: false,
      summary: message,
      sessionId: sessionId,
      revisionBefore: revisionBefore,
      error: RefusionMcpCommandError(
        code: code,
        message: message,
        details: details,
      ),
      diagnostics: diagnostics,
      requiresConfirmation: requiresConfirmation,
    );
  }
}
