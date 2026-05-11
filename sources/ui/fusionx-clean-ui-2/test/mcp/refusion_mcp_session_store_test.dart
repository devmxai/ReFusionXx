import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_capability.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_session.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_session_store.dart';

void main() {
  group('RefusionMcpSessionStore', () {
    test('upserts and reads session', () {
      final store = RefusionMcpSessionStore();
      final session = RefusionMcpSession(
        id: 'session_a',
        clientName: 'codex',
        clientVersion: '1.0',
        transport: 'stdio',
        activeProjectId: 'active',
        activeCompositionId: 'comp_1',
        timelineRevision: 10,
        grantedCapabilities: <RefusionMcpCapability>{
          RefusionMcpCapability.projectRead,
        },
      );
      store.upsert(session);
      final read = store.get('session_a');
      expect(read, isNotNull);
      expect(read!.id, 'session_a');
    });

    test('removes session', () {
      final store = RefusionMcpSessionStore();
      store.upsert(
        RefusionMcpSession(
          id: 'session_b',
          clientName: 'codex',
          clientVersion: '1.0',
          transport: 'stdio',
          activeProjectId: 'active',
          activeCompositionId: 'comp_1',
          timelineRevision: 1,
        ),
      );
      expect(store.remove('session_b'), isTrue);
      expect(store.get('session_b'), isNull);
    });

    test('expires stale sessions by ttl', () {
      var now = DateTime.utc(2026, 5, 11, 12, 0, 0);
      final store = RefusionMcpSessionStore(
        clock: () => now,
        sessionTtl: const Duration(minutes: 5),
      );
      store.upsert(
        RefusionMcpSession(
          id: 'session_expire',
          clientName: 'codex',
          clientVersion: '1.0',
          transport: 'stdio',
          activeProjectId: 'active',
          activeCompositionId: 'comp_1',
          timelineRevision: 1,
        ),
      );
      expect(store.get('session_expire'), isNotNull);
      now = now.add(const Duration(minutes: 6));
      expect(store.get('session_expire'), isNull);
      expect(store.list(), isEmpty);
    });
  });
}
