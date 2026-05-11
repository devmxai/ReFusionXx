import 'package:meta/meta.dart';

import 'refusion_mcp_audit_persistence.dart';

@immutable
class RefusionMcpAuditEvent {
  const RefusionMcpAuditEvent({
    required this.timestampUtc,
    required this.category,
    required this.action,
    required this.clientName,
    required this.sessionId,
    required this.ok,
    this.toolName,
    this.capability,
    this.revisionBefore,
    this.revisionAfter,
    this.details = const <String, Object?>{},
  });

  final DateTime timestampUtc;
  final String category;
  final String action;
  final String clientName;
  final String sessionId;
  final bool ok;
  final String? toolName;
  final String? capability;
  final int? revisionBefore;
  final int? revisionAfter;
  final Map<String, Object?> details;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'timestampUtc': timestampUtc.toIso8601String(),
      'category': category,
      'action': action,
      'clientName': clientName,
      'sessionId': sessionId,
      'ok': ok,
      'toolName': toolName,
      'capability': capability,
      'revisionBefore': revisionBefore,
      'revisionAfter': revisionAfter,
      'details': details,
    };
  }
}

class RefusionMcpAuditLog {
  RefusionMcpAuditLog({
    this.maxEntries = 500,
    DateTime Function()? clock,
    RefusionMcpAuditPersistence? persistence,
  })  : _clock = clock ?? (() => DateTime.now().toUtc()),
        _persistence = persistence {
    _hydrate();
  }

  final int maxEntries;
  final DateTime Function() _clock;
  final RefusionMcpAuditPersistence? _persistence;
  final List<RefusionMcpAuditEvent> _entries = <RefusionMcpAuditEvent>[];

  void record({
    required String category,
    required String action,
    required String clientName,
    required String sessionId,
    required bool ok,
    String? toolName,
    String? capability,
    int? revisionBefore,
    int? revisionAfter,
    Map<String, Object?> details = const <String, Object?>{},
  }) {
    _entries.add(
      RefusionMcpAuditEvent(
        timestampUtc: _clock(),
        category: category,
        action: action,
        clientName: clientName,
        sessionId: sessionId,
        ok: ok,
        toolName: toolName,
        capability: capability,
        revisionBefore: revisionBefore,
        revisionAfter: revisionAfter,
        details: details,
      ),
    );
    if (_entries.length > maxEntries) {
      _entries.removeRange(0, _entries.length - maxEntries);
    }
    _persist();
  }

  List<RefusionMcpAuditEvent> recent({int limit = 100}) {
    final normalizedLimit = limit.clamp(1, maxEntries);
    final start = _entries.length > normalizedLimit
        ? _entries.length - normalizedLimit
        : 0;
    return _entries.sublist(start).toList(growable: false);
  }

  void _hydrate() {
    final persistence = _persistence;
    if (persistence == null) {
      return;
    }
    final rows = persistence.load();
    for (final row in rows) {
      final timestampRaw = row['timestampUtc'] as String?;
      final timestamp = timestampRaw == null
          ? _clock()
          : (DateTime.tryParse(timestampRaw)?.toUtc() ?? _clock());
      _entries.add(
        RefusionMcpAuditEvent(
          timestampUtc: timestamp,
          category: (row['category'] as String?) ?? 'unknown',
          action: (row['action'] as String?) ?? 'unknown',
          clientName: (row['clientName'] as String?) ?? 'unknown',
          sessionId: (row['sessionId'] as String?) ?? 'unknown',
          ok: row['ok'] == true,
          toolName: row['toolName'] as String?,
          capability: row['capability'] as String?,
          revisionBefore: row['revisionBefore'] as int?,
          revisionAfter: row['revisionAfter'] as int?,
          details: (row['details'] as Map?)?.map((key, value) {
                return MapEntry(key.toString(), value);
              }) ??
              const <String, Object?>{},
        ),
      );
    }
    if (_entries.length > maxEntries) {
      _entries.removeRange(0, _entries.length - maxEntries);
    }
  }

  void _persist() {
    final persistence = _persistence;
    if (persistence == null) {
      return;
    }
    persistence.save(
      _entries
          .map((entry) => entry.toJson())
          .toList(growable: false)
          .cast<Map<String, Object?>>(),
    );
  }
}
