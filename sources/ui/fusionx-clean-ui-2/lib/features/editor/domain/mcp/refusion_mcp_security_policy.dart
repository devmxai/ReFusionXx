import 'package:meta/meta.dart';

import 'refusion_mcp_capability.dart';
import 'refusion_mcp_command_result.dart';
import 'refusion_mcp_session.dart';
import 'refusion_mcp_tool_registry.dart';

@immutable
class RefusionMcpSecurityPolicy {
  const RefusionMcpSecurityPolicy({
    this.allowFilesystemRead = false,
    this.allowFilesystemWrite = false,
    this.allowExportStart = false,
    this.allowDebugDiagnostics = false,
    this.destructiveToolNames = const <String>{
      'refusion.delete_layer',
    },
  });

  final bool allowFilesystemRead;
  final bool allowFilesystemWrite;
  final bool allowExportStart;
  final bool allowDebugDiagnostics;
  final Set<String> destructiveToolNames;

  Set<RefusionMcpCapability> grantRequestedCapabilities(
    Set<RefusionMcpCapability> requested,
  ) {
    final granted = <RefusionMcpCapability>{};
    for (final capability in requested) {
      if (_isCapabilityAllowed(capability)) {
        granted.add(capability);
      }
    }
    return granted;
  }

  RefusionMcpCommandResult? evaluateToolCall({
    required RefusionMcpToolCallContext context,
  }) {
    if (!_isCapabilityAllowed(context.descriptor.capability)) {
      return RefusionMcpCommandResult.failure(
        sessionId: context.session.id,
        revisionBefore: context.currentRevision,
        code: RefusionMcpCommandErrorCode.capabilityDenied,
        message:
            'Capability `${context.descriptor.capability.value}` is blocked by security policy.',
      );
    }
    if (context.mode == RefusionMcpSecurityMode.commit &&
        destructiveToolNames.contains(context.requestedToolName) &&
        context.payload['confirmed'] != true) {
      return RefusionMcpCommandResult.failure(
        sessionId: context.session.id,
        revisionBefore: context.currentRevision,
        code: RefusionMcpCommandErrorCode.confirmationRequired,
        message:
            'Tool `${context.requestedToolName}` requires explicit confirmation.',
        requiresConfirmation: true,
        details: const <String, Object?>{
          'requiredField': 'payload.confirmed=true',
        },
      );
    }
    return null;
  }

  bool _isCapabilityAllowed(RefusionMcpCapability capability) {
    switch (capability) {
      case RefusionMcpCapability.filesystemRead:
        return allowFilesystemRead;
      case RefusionMcpCapability.filesystemWrite:
        return allowFilesystemWrite;
      case RefusionMcpCapability.exportStart:
        return allowExportStart;
      case RefusionMcpCapability.debugDiagnostics:
        return allowDebugDiagnostics;
      default:
        return true;
    }
  }
}

enum RefusionMcpSecurityMode {
  dryRun,
  commit,
}

@immutable
class RefusionMcpToolCallContext {
  const RefusionMcpToolCallContext({
    required this.requestedToolName,
    required this.descriptor,
    required this.session,
    required this.currentRevision,
    required this.mode,
    this.payload = const <String, Object?>{},
  });

  final String requestedToolName;
  final RefusionMcpToolDescriptor descriptor;
  final RefusionMcpSession session;
  final int currentRevision;
  final RefusionMcpSecurityMode mode;
  final Map<String, Object?> payload;
}
