import 'package:flutter/foundation.dart';

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
  }) : _clock = clock ?? (() => DateTime.now().toUtc());

  final int maxEntries;
  final DateTime Function() _clock;
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
  }

  List<RefusionMcpAuditEvent> recent({int limit = 100}) {
    final normalizedLimit = limit.clamp(1, maxEntries);
    final start = _entries.length > normalizedLimit
        ? _entries.length - normalizedLimit
        : 0;
    return _entries.sublist(start).toList(growable: false);
  }
}
