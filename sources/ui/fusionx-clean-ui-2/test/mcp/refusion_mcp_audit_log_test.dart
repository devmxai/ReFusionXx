import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_audit_log.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_audit_persistence.dart';

void main() {
  group('RefusionMcpAuditLog', () {
    test('persists entries and hydrates from persistence', () {
      final persistence = _MemoryAuditPersistence();
      final log = RefusionMcpAuditLog(
        maxEntries: 10,
        persistence: persistence,
      );

      log.record(
        category: 'tool',
        action: 'call',
        clientName: 'codex',
        sessionId: 's1',
        ok: true,
        toolName: 'refusion.get_project_state',
      );

      expect(persistence.saved, isNotNull);
      expect(log.recent(limit: 10), hasLength(1));

      final hydrated = RefusionMcpAuditLog(
        maxEntries: 10,
        persistence: persistence,
      );
      expect(hydrated.recent(limit: 10), hasLength(1));
      expect(hydrated.recent(limit: 10).first.toolName,
          'refusion.get_project_state');
    });
  });
}

class _MemoryAuditPersistence implements RefusionMcpAuditPersistence {
  List<Map<String, Object?>> _rows = <Map<String, Object?>>[];

  List<Map<String, Object?>>? get saved => _rows;

  @override
  List<Map<String, Object?>> load() {
    return _rows
        .map((entry) => Map<String, Object?>.from(entry))
        .toList(growable: false);
  }

  @override
  void save(List<Map<String, Object?>> entries) {
    _rows = entries
        .map((entry) => Map<String, Object?>.from(entry))
        .toList(growable: false);
  }
}
