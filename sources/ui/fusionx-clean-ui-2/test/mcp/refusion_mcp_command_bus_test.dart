import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_capability.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_command.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_command_bus.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_command_result.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_session.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_transaction.dart';

void main() {
  group('RefusionMcpCommandBus', () {
    test('denies command without required capability', () {
      final bus = RefusionMcpCommandBus();
      bus.registerHandler(
        commandType: 'refusion.apply_scene_program',
        handler: (_) => RefusionMcpCommandHandlingOutcome(
          summary: 'ok',
          commitOperation: _noopCommit,
        ),
      );
      final session = _buildSession(
        capabilities: <RefusionMcpCapability>{
          RefusionMcpCapability.projectRead
        },
      );
      final command = _buildCommand(
        type: 'refusion.apply_scene_program',
        capability: RefusionMcpCapability.sceneWrite,
        mode: RefusionMcpCommandMode.commit,
      );
      final result = bus.execute(
        session: session,
        command: command,
        currentRevision: 4,
      );
      expect(result.ok, isFalse);
      expect(result.error?.code, RefusionMcpCommandErrorCode.capabilityDenied);
    });

    test('returns validation error when expected revision is missing in commit',
        () {
      final bus = RefusionMcpCommandBus();
      bus.registerHandler(
        commandType: 'refusion.apply_scene_program',
        handler: (_) => RefusionMcpCommandHandlingOutcome(
          summary: 'ok',
          commitOperation: _noopCommit,
        ),
      );
      final session = _buildSession(
        capabilities: <RefusionMcpCapability>{RefusionMcpCapability.sceneWrite},
      );
      final command = RefusionMcpCommandEnvelope(
        commandId: 'cmd',
        sessionId: session.id,
        projectId: 'active',
        type: 'refusion.apply_scene_program',
        capability: RefusionMcpCapability.sceneWrite,
        mode: RefusionMcpCommandMode.commit,
        idempotencyKey: 'turn',
      );
      final result = bus.execute(
        session: session,
        command: command,
        currentRevision: 4,
      );
      expect(result.ok, isFalse);
      expect(result.error?.code, RefusionMcpCommandErrorCode.validationFailed);
    });

    test('stages transaction on dryRun and commits by transaction id', () {
      final bus = RefusionMcpCommandBus();
      var revision = 9;
      bus.registerHandler(
        commandType: 'refusion.keyframe_edit',
        handler: (_) => RefusionMcpCommandHandlingOutcome(
          summary: 'Preview keyframe edit',
          patchPreview: RefusionMcpPatchPreview(
            affectedObjects: const <String>['text_1'],
            changedProperties: const <String>['positionX'],
          ),
          commitOperation: () {
            revision = 10;
            return RefusionMcpCommitExecution(
              revisionAfter: revision,
            );
          },
        ),
      );
      final session = _buildSession(
        capabilities: <RefusionMcpCapability>{
          RefusionMcpCapability.motionWrite,
          RefusionMcpCapability.timelineWrite,
        },
      );
      final dryRunCommand = _buildCommand(
        type: 'refusion.keyframe_edit',
        capability: RefusionMcpCapability.motionWrite,
        mode: RefusionMcpCommandMode.dryRun,
        expectedRevision: 9,
      );
      final dryRun = bus.execute(
        session: session,
        command: dryRunCommand,
        currentRevision: revision,
      );
      expect(dryRun.ok, isTrue);
      expect(dryRun.transactionId, isNotNull);
      final committed = bus.commitTransaction(
        session: session,
        transactionId: dryRun.transactionId!,
        expectedRevision: 9,
        actualRevision: 9,
      );
      expect(committed.ok, isTrue);
      expect(committed.revisionAfter, 10);
    });

    test('returns confirmation required when handler asks for it', () {
      final bus = RefusionMcpCommandBus();
      bus.registerHandler(
        commandType: 'refusion.delete_layer',
        handler: (_) => RefusionMcpCommandHandlingOutcome(
          summary: 'Delete needs confirmation.',
          requiresConfirmation: true,
        ),
      );
      final session = _buildSession(
        capabilities: <RefusionMcpCapability>{
          RefusionMcpCapability.timelineWrite,
        },
      );
      final command = _buildCommand(
        type: 'refusion.delete_layer',
        capability: RefusionMcpCapability.timelineWrite,
        mode: RefusionMcpCommandMode.commit,
      );
      final result = bus.execute(
        session: session,
        command: command,
        currentRevision: 7,
      );
      expect(result.ok, isFalse);
      expect(
        result.error?.code,
        RefusionMcpCommandErrorCode.confirmationRequired,
      );
      expect(result.requiresConfirmation, isTrue);
    });
  });
}

RefusionMcpSession _buildSession({
  required Set<RefusionMcpCapability> capabilities,
}) {
  return RefusionMcpSession(
    id: 'session_1',
    clientName: 'test',
    clientVersion: '1.0.0',
    transport: 'stdio',
    activeProjectId: 'active',
    activeCompositionId: 'comp_1',
    timelineRevision: 1,
    grantedCapabilities: capabilities,
  );
}

RefusionMcpCommandEnvelope _buildCommand({
  required String type,
  required RefusionMcpCapability capability,
  required RefusionMcpCommandMode mode,
  int? expectedRevision,
}) {
  return RefusionMcpCommandEnvelope(
    commandId: 'cmd_1',
    sessionId: 'session_1',
    projectId: 'active',
    type: type,
    capability: capability,
    mode: mode,
    idempotencyKey: 'turn-1',
    expectedRevision: expectedRevision ?? 7,
  );
}

RefusionMcpCommitExecution _noopCommit() {
  return const RefusionMcpCommitExecution(revisionAfter: 8);
}
