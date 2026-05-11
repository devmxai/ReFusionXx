import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_capability.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_command.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_command_bus.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_mvp_toolkit.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_session.dart';

void main() {
  group('RefusionMcpMvpToolkit', () {
    late RefusionMcpCommandBus bus;
    late RefusionMcpSession session;

    setUp(() {
      bus = RefusionMcpCommandBus();
      session = RefusionMcpSession(
        id: 'session_1',
        clientName: 'test',
        clientVersion: '1.0.0',
        transport: 'stdio',
        activeProjectId: 'active',
        activeCompositionId: 'comp_1',
        timelineRevision: 7,
        grantedCapabilities: <RefusionMcpCapability>{
          RefusionMcpCapability.projectRead,
          RefusionMcpCapability.timelineRead,
          RefusionMcpCapability.previewRead,
          RefusionMcpCapability.sceneWrite,
        },
      );
      const toolkit = RefusionMcpMvpToolkit();
      toolkit.register(
        bus: bus,
        config: RefusionMcpMvpToolkitConfig(
          projectStateReader: () => <String, Object?>{
            'projectId': 'active',
            'revision': 7,
          },
          timelineSummaryReader: () => <String, Object?>{
            'rowCount': 3,
          },
          selectionReader: () => <String, Object?>{
            'selected': <String>['clip_1'],
          },
          previewCaptureReader: (timeMs) => <String, Object?>{
            'timeMs': timeMs ?? 0,
            'resourceUri': 'refusion://preview/frame/${timeMs ?? 0}',
          },
        ),
      );
    });

    test('returns project state from command bus', () {
      final result = bus.execute(
        session: session,
        command: _command(
          type: 'refusion.get_project_state',
          capability: RefusionMcpCapability.projectRead,
        ),
        currentRevision: 7,
      );
      expect(result.ok, isTrue);
      expect(result.payload['projectId'], 'active');
    });

    test('returns preview resource uri', () {
      final result = bus.execute(
        session: session,
        command: _command(
          type: 'refusion.capture_preview_frame',
          capability: RefusionMcpCapability.previewRead,
          payload: <String, Object?>{'timeMs': 1200},
        ),
        currentRevision: 7,
      );
      expect(result.ok, isTrue);
      expect(result.resourceUris, contains('refusion://preview/frame/1200'));
    });

    test('validates scene program source through toolkit', () {
      final source = File(
        '/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/test/fixtures/refusion_scene_programs/first_generated_scene.json',
      ).readAsStringSync();
      final result = bus.execute(
        session: session,
        command: _command(
          type: 'refusion.validate_scene_program',
          capability: RefusionMcpCapability.sceneWrite,
          payload: <String, Object?>{'source': source},
        ),
        currentRevision: 7,
      );
      expect(result.ok, isTrue);
      expect(result.payload['isValid'], isTrue);
    });
  });
}

RefusionMcpCommandEnvelope _command({
  required String type,
  required RefusionMcpCapability capability,
  Map<String, Object?> payload = const <String, Object?>{},
}) {
  return RefusionMcpCommandEnvelope(
    commandId: 'cmd_1',
    sessionId: 'session_1',
    projectId: 'active',
    type: type,
    capability: capability,
    mode: RefusionMcpCommandMode.dryRun,
    idempotencyKey: 'turn-1',
    payload: payload,
  );
}
