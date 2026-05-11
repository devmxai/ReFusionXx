import 'package:meta/meta.dart';

import 'refusion_mcp_session.dart';

class RefusionMcpSessionStore {
  RefusionMcpSessionStore({
    DateTime Function()? clock,
    this.sessionTtl = const Duration(minutes: 30),
  }) : _clock = clock ?? (() => DateTime.now().toUtc());

  final DateTime Function() _clock;
  final Duration sessionTtl;
  final Map<String, RefusionMcpSession> _byId = <String, RefusionMcpSession>{};

  void upsert(RefusionMcpSession session) {
    _byId[session.id] = session.copyWith(lastSeenAt: _clock());
  }

  RefusionMcpSession? get(String id) {
    _purgeExpired();
    final session = _byId[id];
    if (session == null) {
      return null;
    }
    final now = _clock();
    final touched = session.copyWith(lastSeenAt: now);
    _byId[id] = touched;
    return touched;
  }

  bool remove(String id) {
    return _byId.remove(id) != null;
  }

  List<RefusionMcpSession> list() {
    _purgeExpired();
    final sessions = _byId.values.toList(growable: false);
    sessions.sort((left, right) => left.id.compareTo(right.id));
    return sessions;
  }

  void _purgeExpired() {
    if (sessionTtl <= Duration.zero) {
      return;
    }
    final now = _clock();
    final expiredIds = <String>[];
    for (final entry in _byId.entries) {
      if (now.difference(entry.value.lastSeenAt) >= sessionTtl) {
        expiredIds.add(entry.key);
      }
    }
    for (final id in expiredIds) {
      _byId.remove(id);
    }
  }
}
